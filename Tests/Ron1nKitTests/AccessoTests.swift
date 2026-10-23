import Foundation
import Testing

@testable import Ron1nKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite struct AccessoTests {
  let attese = CredenzialiAccesso(clientId: "abc123.access", clientSecret: "f00dcafe")

  @Test func jsonDiCloudflare() {
    let testo = #"{"id":"7d0e","name":"ron1nos-ios","client_id":"abc123.access","client_secret":"f00dcafe"}"#
    #expect(CredenzialiAccesso.leggi(da: testo) == attese)
  }

  @Test func jsonDentroResult() {
    let testo = #"{"success":true,"result":{"client_id":"abc123.access","client_secret":"f00dcafe"}}"#
    #expect(CredenzialiAccesso.leggi(da: testo) == attese)
  }

  @Test func righeDiHeader() {
    let testo = "CF-Access-Client-Id: abc123.access\ncf-access-client-secret:f00dcafe\n"
    #expect(CredenzialiAccesso.leggi(da: testo) == attese)
  }

  @Test func dueRighe() {
    #expect(CredenzialiAccesso.leggi(da: "  abc123.access\n\nf00dcafe  ") == attese)
  }

  @Test(arguments: ["", "solo una riga", "{\"client_id\":\"abc\"}", "a b\nc", "uno\ndue\ntre"])
  func testoNonValido(testo: String) {
    #expect(CredenzialiAccesso.leggi(da: testo) == nil)
  }

  @Test func archivioInMemoria() {
    let archivio = ArchivioInMemoria()
    #expect(archivio.carica() == nil)
    archivio.salva(attese)
    #expect(archivio.carica() == attese)
    archivio.cancella()
    #expect(archivio.carica() == nil)
  }

  @Test func headerNellaRichiesta() async throws {
    let transport = TransportFinto(.risposta(200, #"{"ok":true,"database":"ok"}"#))
    _ = try await APIClient(credenziali: attese, transport: transport).health()
    #expect(transport.richiesta?.value(forHTTPHeaderField: "CF-Access-Client-Id") == "abc123.access")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "CF-Access-Client-Secret") == "f00dcafe")
  }

  @Test func senzaTokenNienteHeader() async throws {
    let transport = TransportFinto(.risposta(200, #"{"ok":true,"database":"ok"}"#))
    _ = try await APIClient(transport: transport).health()
    #expect(transport.richiesta?.value(forHTTPHeaderField: "CF-Access-Client-Id") == nil)
  }

  @Test(arguments: [false, true])
  func redirectAlLoginDiAccess(conToken: Bool) async {
    let login = "https://crimson-lab-3627.cloudflareaccess.com/cdn-cgi/access/login/home.ron1n.space"
    let transport = TransportFinto(.risposta(302, "", header: ["Location": login]))
    let client = APIClient(credenziali: conToken ? attese : nil, transport: transport)
    await #expect(throws: APIError.accesso(conToken: conToken)) { try await client.health() }
  }

  @Test func altroRedirect() async {
    let transport = TransportFinto(.risposta(302, "", header: ["Location": "https://esempio.it/"]))
    await #expect(throws: APIError.stato(302)) { try await APIClient(transport: transport).health() }
  }

  @Test func testiDellAccesso() {
    #expect(APIError.accesso(conToken: false).titolo == "Manca l'accesso")
    #expect(APIError.accesso(conToken: true).suggerimento.contains("scaduto"))
    #expect(APIError.accesso(conToken: false).dettaglio == "HTTP 302 · Cloudflare Access")
    #expect(Controllo.fallito(.accesso(conToken: false), quando: Date()).backend == "accesso negato")
  }
}
