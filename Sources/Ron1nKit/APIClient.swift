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
    try await session.data(for: request)
  }
}

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
