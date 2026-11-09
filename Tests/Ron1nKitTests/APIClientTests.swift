import Foundation
import Testing

@testable import Ron1nKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Risponde sempre la stessa cosa e ricorda l'ultima richiesta.
final class TransportFinto: HTTPTransport, @unchecked Sendable {
  enum Esito {
    case risposta(Int, String, header: [String: String] = [:])
    case errore(Error)
    /// Un esito per invio; l'ultimo si ripete.
    indirect case sequenza([Esito])
  }

  let esito: Esito
  private(set) var richiesta: URLRequest?
  private(set) var invii = 0

  init(_ esito: Esito) { self.esito = esito }

  func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
    richiesta = request
    invii += 1
    var esito = esito
    if case .sequenza(let elenco) = esito { esito = elenco[min(invii, elenco.count) - 1] }
    switch esito {
    case .risposta(let codice, let corpo, let header):
      let response = HTTPURLResponse(
        url: request.url!, statusCode: codice, httpVersion: nil, headerFields: header)!
      return (Data(corpo.utf8), response)
    case .errore(let errore):
      throw errore
    case .sequenza:
      throw URLError(.unknown)
    }
  }
}

@Suite struct APIClientTests {
  @Test func healthChiamaIlPercorsoGiusto() async throws {
    let transport = TransportFinto(.risposta(200, #"{"ok":true,"database":"ok"}"#))
    let health = try await APIClient(transport: transport).health()
    #expect(health == Health(ok: true, database: .ok))
    #expect(transport.richiesta?.url?.absoluteString == "https://home.ron1n.space/api/v1/health")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Accept") == "application/json")
  }

  @Test(arguments: [
    ("disabled", DatabaseState.disabled),
    ("starting", .starting),
    ("unavailable", .unavailable),
    ("migrating", .sconosciuto("migrating")),
  ])
  func statiDelDatabase(valore: String, atteso: DatabaseState) async throws {
    let transport = TransportFinto(.risposta(200, #"{"ok":true,"database":"\#(valore)"}"#))
    let health = try await APIClient(transport: transport).health()
    #expect(health.database == atteso)
  }

  @Test func codiceDiErrore() async {
    let transport = TransportFinto(.risposta(503, "{}"))
    await #expect(throws: APIError.stato(503)) { try await APIClient(transport: transport).health() }
  }

  @Test func jsonNonValido() async {
    let transport = TransportFinto(.risposta(200, "<html>Caddy</html>"))
    await #expect(throws: APIError.rispostaInattesa(codice: nil)) {
      try await APIClient(transport: transport).health()
    }
  }

  @Test(arguments: [
    (URLError.Code.cannotFindHost, APIError.nonRaggiungibile(codice: -1003)),
    (.timedOut, .nonRaggiungibile(codice: -1001)),
    (.notConnectedToInternet, .nonRaggiungibile(codice: -1009)),
    (.secureConnectionFailed, .certificato(codice: -1200)),
    (.serverCertificateHasBadDate, .certificato(codice: -1201)),
    (.serverCertificateUntrusted, .certificato(codice: -1202)),
    (.serverCertificateHasUnknownRoot, .certificato(codice: -1203)),
    (.serverCertificateNotYetValid, .certificato(codice: -1204)),
    (.clientCertificateRejected, .certificato(codice: -1205)),
    (.clientCertificateRequired, .certificato(codice: -1206)),
    (.badServerResponse, .rispostaInattesa(codice: -1011)),
  ])
  func erroriDiRete(codice: URLError.Code, atteso: APIError) async {
    let transport = TransportFinto(.errore(URLError(codice)))
    await #expect(throws: atteso) { try await APIClient(transport: transport).health() }
  }

  @Test func codiceTLSDallErroreSottostante() async {
    let sotto = NSError(
      domain: "kCFErrorDomainCFNetwork", code: -1200, userInfo: ["_kCFStreamErrorCodeKey": -9802])
    let errore = URLError(.secureConnectionFailed, userInfo: [NSUnderlyingErrorKey: sotto])
    let transport = TransportFinto(.errore(errore))
    await #expect(throws: APIError.certificato(codice: -1200, tls: -9802)) {
      try await APIClient(transport: transport).health()
    }
  }

  @Test func codiceTLSDiretto() async {
    let errore = URLError(.serverCertificateUntrusted, userInfo: ["_kCFStreamErrorCodeKey": -9813])
    let transport = TransportFinto(.errore(errore))
    await #expect(throws: APIError.certificato(codice: -1202, tls: -9813)) {
      try await APIClient(transport: transport).health()
    }
  }

  @Test func certificatoRifiutatoDaiOS() async {
    let motivo = "“home.ron1n.space” certificate is not trusted"
    let errore = URLError(.cancelled, userInfo: [APIError.chiaveMotivoTLS: motivo])
    let transport = TransportFinto(.errore(errore))
    await #expect(throws: APIError.certificato(codice: -999, motivo: motivo)) {
      try await APIClient(transport: transport).health()
    }
  }

  @Test func annullataSenzaMotivo() async {
    let transport = TransportFinto(.errore(URLError(.cancelled)))
    await #expect(throws: APIError.nonRaggiungibile(codice: -999)) {
      try await APIClient(transport: transport).health()
    }
    // Una volta sola: la seconda annullata è quella che si mostra.
    #expect(transport.invii == 2)
  }

  @Test func annullataUnaVoltaSiRiprova() async throws {
    let transport = TransportFinto(
      .sequenza([.errore(URLError(.cancelled)), .risposta(200, #"{"ok":true,"database":"ok"}"#)]))
    let health = try await APIClient(transport: transport).health()
    #expect(health.ok)
    #expect(transport.invii == 2)
  }

  @Test func certificatoRifiutatoNonSiRiprova() async {
    let errore = URLError(.cancelled, userInfo: [APIError.chiaveMotivoTLS: "non attendibile"])
    let transport = TransportFinto(.errore(errore))
    _ = try? await APIClient(transport: transport).health()
    #expect(transport.invii == 1)
  }

  @Test func loginPassegueroSiRiprova() async throws {
    let transport = TransportFinto(
      .sequenza([.risposta(401, "{}"), .risposta(200, #"{"ok":true,"database":"ok"}"#)]))
    let client = APIClient(token: TokenRon1n("r1n_abcdefghijklmnopqrstu"), transport: transport)
    #expect(try await client.health().ok)
    #expect(transport.invii == 2)
  }

  @Test func loginRifiutatoDueVolte() async {
    let transport = TransportFinto(.risposta(401, "{}"))
    let client = APIClient(token: TokenRon1n("r1n_abcdefghijklmnopqrstu"), transport: transport)
    await #expect(throws: APIError.login(conToken: true)) { try await client.health() }
    #expect(transport.invii == 2)
  }

  @Test func senzaTokenIl401NonSiRiprova() async {
    let transport = TransportFinto(.risposta(401, "{}"))
    await #expect(throws: APIError.login(conToken: false)) {
      try await APIClient(transport: transport).health()
    }
    #expect(transport.invii == 1)
  }

  @Test func erroreCheNonEDiRete() async {
    struct Altro: Error {}
    let transport = TransportFinto(.errore(Altro()))
    await #expect(throws: APIError.nonRaggiungibile(codice: nil)) {
      try await APIClient(transport: transport).health()
    }
  }
}
