import Foundation
import Testing

@testable import Ron1nKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite struct TokenRon1nTests {
  let token = TokenRon1n("r1n_AbCdEfGhIjKlMnOpQrStUv-_0123456789")

  @Test(arguments: [
    "r1n_AbCdEfGhIjKlMnOpQrStUv-_0123456789",
    "  r1n_AbCdEfGhIjKlMnOpQrStUv-_0123456789\n",
    "Bearer r1n_AbCdEfGhIjKlMnOpQrStUv-_0123456789",
  ])
  func leggeIlToken(testo: String) {
    #expect(TokenRon1n.leggi(da: testo) == token)
  }

  @Test(arguments: ["", "r1n_", "r1n_corto", "abc_AbCdEfGhIjKlMnOpQrStUv", "r1n_AbCdEfGh IjKlMnOpQrStUv"])
  func testoNonValido(testo: String) {
    #expect(TokenRon1n.leggi(da: testo) == nil)
  }

  @Test func archivioInMemoria() {
    let archivio = TokenInMemoria()
    #expect(archivio.carica() == nil)
    archivio.salva(token)
    #expect(archivio.carica() == token)
    archivio.cancella()
    #expect(archivio.carica() == nil)
  }

  @Test func headerInsiemeAQuelliDiAccess() async throws {
    let transport = TransportFinto(.risposta(200, #"{"enabled":true}"#))
    let credenziali = CredenzialiAccesso(clientId: "abc.access", clientSecret: "f00d")
    _ = try await APIClient(credenziali: credenziali, token: token, transport: transport).me()
    #expect(transport.richiesta?.url?.absoluteString == "https://home.ron1n.space/api/v1/auth/me")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Authorization") == "Bearer \(token.valore)")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "CF-Access-Client-Id") == "abc.access")
  }

  @Test(arguments: [false, true])
  func quattrocentouno(conToken: Bool) async {
    let transport = TransportFinto(.risposta(401, #"{"error":"unauthenticated"}"#))
    let client = APIClient(token: conToken ? token : nil, transport: transport)
    await #expect(throws: APIError.login(conToken: conToken)) { try await client.me() }
  }

  @Test(arguments: [
    (200, #"{"enabled":true}"#, StatoLogin.valido),
    (200, #"{"enabled":false}"#, .spento),
    (401, "{}", .mancaToken),
    (503, "{}", .nonVerificato),
  ])
  func statoDelLogin(codice: Int, corpo: String, atteso: StatoLogin) async {
    let client = APIClient(transport: TransportFinto(.risposta(codice, corpo)))
    #expect(await StatoLogin.verifica(con: client) == atteso)
  }

  @Test func tokenRifiutato() async {
    let client = APIClient(token: token, transport: TransportFinto(.risposta(401, "{}")))
    let stato = await StatoLogin.verifica(con: client)
    #expect(stato == .tokenRifiutato)
    #expect(stato.problema)
    #expect(!StatoLogin.valido.problema)
  }

  @Test func testiDelLogin() {
    #expect(APIError.login(conToken: false).titolo == "Manca il token ron1nOS")
    #expect(APIError.login(conToken: false).suggerimento.contains("Impostazioni › App iOS"))
    #expect(APIError.login(conToken: true).suggerimento.contains("revocato"))
    #expect(APIError.login(conToken: true).dettaglio == "HTTP 401 · ron1nOS")
    #expect(!APIError.login(conToken: true).suggerimento.contains("!"))
  }
}
