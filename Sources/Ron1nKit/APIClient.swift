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

  public init(timeout: TimeInterval = 10) {
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = timeout
    session = URLSession(configuration: config)
  }

  public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
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

  func get<T: Decodable>(_ path: String) async throws(APIError) -> T {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let header = (credenziali?.header ?? [:]).merging(token?.header ?? [:]) { $1 }
    for (nome, valore) in header {
      request.setValue(valore, forHTTPHeaderField: nome)
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await transport.send(request)
    } catch {
      throw APIError(error)
    }
    guard let http = response as? HTTPURLResponse else { throw .rispostaInattesa(codice: nil) }
    if APIClient.versoAccess(http) { throw .accesso(conToken: credenziali != nil) }
    if http.statusCode == 401 { throw .login(conToken: token != nil) }
    guard (200..<300).contains(http.statusCode) else { throw .stato(http.statusCode) }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
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
