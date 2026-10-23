import Foundation
import Testing

@testable import Ron1nKit

@Suite struct ControlloTests {
  let ora = Date(timeIntervalSince1970: 1_792_764_000)  // 2026-10-23 16:00:00 a Roma

  @Test func riuscito() async {
    let transport = TransportFinto(.risposta(200, #"{"ok":true,"database":"starting"}"#))
    let controllo = await Controllo.esegui(con: APIClient(transport: transport), adesso: { [ora] in ora })
    #expect(controllo == .riuscito(Health(ok: true, database: .starting), quando: ora))
    #expect(controllo.backend == "raggiungibile")
  }

  @Test func fallito() async {
    let transport = TransportFinto(.errore(URLError(.cannotConnectToHost)))
    let controllo = await Controllo.esegui(con: APIClient(transport: transport), adesso: { [ora] in ora })
    #expect(controllo == .fallito(.nonRaggiungibile(codice: -1004), quando: ora))
    #expect(controllo.backend == "non raggiungibile")
  }

  @Test func backendCheRispondeMale() {
    #expect(Controllo.fallito(.stato(500), quando: ora).backend == "risponde con errori")
    #expect(Controllo.fallito(.certificato(codice: -1202), quando: ora).backend == "non raggiungibile")
  }

  @Test func oraDelControllo() {
    let roma = TimeZone(identifier: "Europe/Rome")!
    #expect(
      Controllo.riuscito(Health(ok: true, database: .ok), quando: ora).testoOra(fuso: roma)
        == "Ultimo controllo · 16:00:00")
    #expect(Controllo.inCorso.testoOra(fuso: roma) == nil)
  }

  @Test func testiDelDatabase() {
    #expect(DatabaseState.ok.testo == "pronto")
    #expect(DatabaseState.unavailable.testo == "non risponde")
    #expect(DatabaseState.unavailable.problema)
    #expect(!DatabaseState.disabled.problema)
  }

  @Test func messaggiSenzaPuntiEsclamativi() {
    let errori: [APIError] = [
      .nonRaggiungibile(codice: nil), .certificato(codice: -1202), .stato(401), .stato(500),
      .rispostaInattesa(codice: nil),
    ]
    for errore in errori {
      #expect(!errore.titolo.contains("!"))
      #expect(!errore.suggerimento.contains("!"))
    }
  }

  @Test func dettaglioDelCodice() {
    #expect(APIError.certificato(codice: -1202).dettaglio == "URLError -1202")
    #expect(APIError.nonRaggiungibile(codice: -1004).dettaglio == "URLError -1004")
    #expect(APIError.stato(503).dettaglio == "HTTP 503")
    #expect(APIError.nonRaggiungibile(codice: nil).dettaglio == nil)
    #expect(APIError.rispostaInattesa(codice: nil).dettaglio == nil)
  }

  @Test func suggerimentiDiRete() {
    #expect(APIError.certificato(codice: -1202).suggerimento.contains("Impostazioni certificati attendibili"))
    #expect(APIError.nonRaggiungibile(codice: -1001).suggerimento.contains("SideStore"))
  }
}
