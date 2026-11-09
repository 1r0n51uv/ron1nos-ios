import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Chi fa davvero la richiesta HTTP. Nei test è finto.
public protocol HTTPTransport: Sendable {
  func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/// URLSession, con un timeout breve: se il server non risponde è meglio
/// saperlo subito.
public struct URLSessionTransport: HTTPTransport {
  let session: URLSession

  /// Una sola sessione per tutta l'app: `sessione.client` crea un client a
  /// ogni uso, e una sessione nuova a ogni richiesta rifaceva la
  /// connessione TLS e non si chiudeva mai.
  private static let condivisa = creaSessione(timeout: 10)

  private static func creaSessione(timeout: TimeInterval) -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = timeout
    return URLSession(configuration: config)
  }

  public init(timeout: TimeInterval = 10) {
    session = timeout == 10 ? URLSessionTransport.condivisa : URLSessionTransport.creaSessione(timeout: timeout)
  }

  /// La richiesta gira in un task suo: se la pagina che l'ha chiesta si
  /// chiude o il pull to refresh finisce, il task di SwiftUI viene annullato
  /// ma la richiesta no, e non torna più "URLError -999". Il timeout la
  /// limita comunque.
  public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
    let session = session
    return try await Task { try await URLSessionTransport.invia(request, con: session) }.value
  }

  private static func invia(_ request: URLRequest, con session: URLSession) async throws -> (
    Data, URLResponse
  ) {
    #if canImport(Security)
      // Un delegato per richiesta: valuta lui il certificato e, se iOS lo
      // rifiuta, ne ricorda il motivo da mostrare (IOS-002).
      let verifica = VerificaTLS()
      do {
        return try await session.data(for: request, delegate: verifica)
      } catch let errore as URLError {
        guard let motivo = verifica.motivo else { throw errore }
        var info = errore.userInfo
        info[APIError.chiaveMotivoTLS] = motivo
        throw URLError(errore.code, userInfo: info)
      }
    #else
      try await session.data(for: request)
    #endif
  }
}

#if canImport(Security)
  import Security

  /// Valuta il certificato del server con la fiducia di sistema, la stessa di
  /// Safari: se iOS si fida lo accetta, se no tiene il motivo che dà
  /// SecTrust ("non attendibile", "non conforme"…) e chiude la connessione.
  final class VerificaTLS: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _motivo: String?

    var motivo: String? { lock.withLock { _motivo } }

    /// Niente redirect: Cloudflare Access rimanda al suo login (una pagina
    /// HTML su un altro dominio) chi non ha un token valido. L'app vuole il
    /// 302 così com'è, per dirlo (IOS-004).
    func urlSession(
      _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
      newRequest request: URLRequest
    ) async -> URLRequest? {
      nil
    }

    func urlSession(
      _ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
      guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
        let trust = challenge.protectionSpace.serverTrust
      else { return (.performDefaultHandling, nil) }
      var errore: CFError?
      if SecTrustEvaluateWithError(trust, &errore) {
        return (.useCredential, URLCredential(trust: trust))
      }
      let motivo = errore.map { CFErrorCopyDescription($0) as String } ?? "certificato rifiutato"
      lock.withLock { _motivo = motivo }
      return (.cancelAuthenticationChallenge, nil)
    }
  }
#endif

/// Client dell'API `/api/v1` di ron1nOS, la stessa della dashboard web.
public struct APIClient: Sendable {
  /// Il backend ron1nOS, pubblicato dal Cloudflare Tunnel dell'hub dietro
  /// Cloudflare Access (SETUP-008).
  public static let indirizzoPredefinito = URL(string: "https://home.ron1n.space/api/v1")!

  public let baseURL: URL
  /// Il service token di Access, se c'è. Senza, Access rimanda al login.
  public let credenziali: CredenzialiAccesso?
  /// Il token di ron1nOS (IOS-005), se c'è. Senza, con il login acceso le
  /// rotte rispondono 401.
  public let token: TokenRon1n?
  let transport: HTTPTransport

  public init(
    baseURL: URL = APIClient.indirizzoPredefinito, credenziali: CredenzialiAccesso? = nil,
    token: TokenRon1n? = nil, transport: HTTPTransport = URLSessionTransport()
  ) {
    self.baseURL = baseURL
    self.credenziali = credenziali
    self.token = token
    self.transport = transport
  }

  /// `GET /health`: risponde anche senza login.
  public func health() async throws(APIError) -> Health {
    try await get("health")
  }

  /// `GET /auth/me`: con il login acceso chiede il token.
  public func me() async throws(APIError) -> Me {
    try await get("auth/me")
  }

  func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws(APIError) -> T {
    let data = try await dati(path, query: query)
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
  }

  /// Una richiesta che cambia dati (`PUT`, `POST`, `PATCH`, `DELETE`), con
  /// il corpo in JSON se c'è.
  func invia<T: Decodable>(
    _ metodo: String, _ path: String, corpo: (any Encodable & Sendable)? = nil
  ) async throws(APIError) -> T {
    var json: Data?
    if let corpo {
      do {
        json = try JSONEncoder().encode(corpo)
      } catch {
        throw .rispostaInattesa(codice: nil)
      }
    }
    let data = try await dati(path, metodo: metodo, corpo: json)
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
  }

  /// Il corpo della risposta così com'è, dopo i controlli di Access, login e
  /// codice HTTP.
  func dati(
    _ path: String, query: [URLQueryItem] = [], metodo: String = "GET", corpo: Data? = nil
  ) async throws(APIError) -> Data {
    let (data, http) = try await risposta(path, query: query, metodo: metodo, corpo: corpo)
    guard (200..<300).contains(http.statusCode) else { throw .stato(http.statusCode) }
    return data
  }

  /// La risposta dopo i controlli di Access e login, con qualunque codice
  /// HTTP: serve a chi deve leggere il messaggio di un errore.
  func risposta(
    _ path: String, query: [URLQueryItem] = [], metodo: String = "GET", corpo: Data? = nil,
    tipo: String = "application/json"
  ) async throws(APIError) -> (Data, HTTPURLResponse) {
    var url = baseURL
    // Un segmento con `%2F` (un nome con la barra) resta un segmento solo.
    for parte in path.split(separator: "/") {
      url = url.appending(component: String(parte).removingPercentEncoding ?? String(parte))
    }
    if !query.isEmpty { url.append(queryItems: query) }
    var request = URLRequest(url: url)
    request.httpMethod = metodo
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let corpo {
      request.httpBody = corpo
      request.setValue(tipo, forHTTPHeaderField: "Content-Type")
    }
    let header = (credenziali?.header ?? [:]).merging(token?.header ?? [:]) { $1 }
    for (nome, valore) in header {
      request.setValue(valore, forHTTPHeaderField: nome)
    }

    var (data, http) = try await invio(request)
    // Un 401 con il token in mano è quasi sempre un intoppo passeggero del
    // backend (riavvio, database che parte): si riprova una volta. Con il
    // token davvero revocato costa mezzo secondo.
    if http.statusCode == 401, token != nil, !Task.isCancelled {
      try? await Task.sleep(nanoseconds: 500_000_000)
      (data, http) = try await invio(request)
    }
    if APIClient.versoAccess(http) { throw .accesso(conToken: credenziali != nil) }
    if http.statusCode == 401 { throw .login(conToken: token != nil) }
    return (data, http)
  }

  /// Una richiesta al trasporto. Una connessione annullata da iOS senza che
  /// sia colpa del certificato (-999) si ripete una volta.
  private func invio(_ request: URLRequest) async throws(APIError) -> (Data, HTTPURLResponse) {
    var riprovata = false
    while true {
      do {
        let (data, response) = try await transport.send(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.rispostaInattesa(codice: nil) }
        return (data, http)
      } catch {
        if let errore = error as? APIError { throw errore }
        let annullata = (error as? URLError).map {
          $0.code == .cancelled && $0.userInfo[APIError.chiaveMotivoTLS] == nil
        }
        if annullata == true, !riprovata, !Task.isCancelled {
          riprovata = true
          continue
        }
        throw APIError(error)
      }
    }
  }

  /// Un nome dentro un percorso, come `workout/exercises/{name}`: la barra
  /// non lo spezza in due segmenti.
  public static func segmento(_ testo: String) -> String {
    testo.replacingOccurrences(of: "%", with: "%25").replacingOccurrences(of: "/", with: "%2F")
  }

  /// Un redirect verso il login di Cloudflare Access
  /// (`<team>.cloudflareaccess.com`): token mancante o non valido.
  static func versoAccess(_ http: HTTPURLResponse) -> Bool {
    guard (300..<400).contains(http.statusCode),
      let location = http.value(forHTTPHeaderField: "Location"),
      let host = URL(string: location)?.host()?.lowercased()
    else { return false }
    return host == "cloudflareaccess.com" || host.hasSuffix(".cloudflareaccess.com")
  }
}
