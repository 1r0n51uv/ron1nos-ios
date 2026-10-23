import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Chi fa davvero la richiesta HTTP. Nei test è finto.
public protocol HTTPTransport: Sendable {
  func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

/// URLSession, con un timeout breve: se Tailscale è spento è meglio saperlo
/// subito.
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
  /// Il backend ron1nOS dietro Caddy, raggiungibile dalla tailnet.
  public static let indirizzoPredefinito = URL(string: "https://ron1n.home/api/v1")!

  public let baseURL: URL
  let transport: HTTPTransport

  public init(baseURL: URL = APIClient.indirizzoPredefinito, transport: HTTPTransport = URLSessionTransport())
  {
    self.baseURL = baseURL
    self.transport = transport
  }

  /// `GET /health`: risponde anche senza login.
  public func health() async throws(APIError) -> Health {
    try await get("health")
  }

  func get<T: Decodable>(_ path: String) async throws(APIError) -> T {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await transport.send(request)
    } catch {
      throw APIError(error)
    }
    guard let http = response as? HTTPURLResponse else { throw .rispostaInattesa(codice: nil) }
    guard (200..<300).contains(http.statusCode) else { throw .stato(http.statusCode) }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
  }
}
