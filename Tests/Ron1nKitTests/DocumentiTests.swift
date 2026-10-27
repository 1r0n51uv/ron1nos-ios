import Foundation
import Testing

@testable import Ron1nKit

@Suite struct DocumentiTests {
  static let elenco = """
    [
     {"id":"p","typeId":"t1","typeName":"Passaporto","typeIcon":"passport","title":"Passaporto","holder":"Io",
      "expiresOn":"2030-01-01","expiry":{"status":"ok","daysLeft":1200},"tags":[],
      "pinnedAt":"2026-10-01T10:00:00Z","files":2,"thumbFileId":"f1",
      "firstFile":{"mime":"image/jpeg","size":1000},"updatedAt":"2026-10-01T10:00:00Z"},
     {"id":"c","typeId":"t2","typeName":"Carta d'identità","typeIcon":"id-card","title":"CI","holder":"Anna",
      "expiresOn":"2026-11-20","expiry":{"status":"expiring","daysLeft":24},"tags":[],"pinnedAt":null,
      "files":0,"thumbFileId":null,"firstFile":null,"updatedAt":"2026-10-01T10:00:00Z"},
     {"id":"s","typeId":null,"typeName":null,"typeIcon":null,"title":"Bolletta","holder":"Io",
      "expiresOn":null,"expiry":null,"tags":["casa"],"pinnedAt":null,
      "files":1,"thumbFileId":null,"firstFile":null,"updatedAt":"2026-10-01T10:00:00Z"},
     {"id":"x","typeId":"t3","typeName":"Patente","typeIcon":"car","title":"Patente","holder":"Io",
      "expiresOn":"2026-10-01","expiry":{"status":"expired","daysLeft":-26},"tags":[],"pinnedAt":null,
      "files":0,"thumbFileId":null,"firstFile":null,"updatedAt":"2026-10-01T10:00:00Z"},
     {"id":"a","typeId":"t3","typeName":"Assicurazione","typeIcon":"car","title":"RC auto","holder":"Io",
      "expiresOn":null,"expiry":null,"tags":[],"pinnedAt":null,
      "files":0,"thumbFileId":null,"firstFile":null,"updatedAt":"2026-10-01T10:00:00Z"}
    ]
    """

  @Test func fissatiInScadenzaEPerTipo() async throws {
    let transport = TransportFinto(.risposta(200, DocumentiTests.elenco))
    let filtro = FiltroDocumenti(cerca: " casa ", tipo: FiltroDocumenti.senzaTipo, titolare: "Io")
    let documenti = try await APIClient(transport: transport).elencoDocumenti(filtro)
    let url = try #require(transport.richiesta?.url)
    #expect(url.path == "/api/v1/documents/documents")
    #expect(url.query == "q=casa&type=none&holder=Io")
    #expect(filtro.attivo)

    let elenco = ElencoDocumenti(documenti)
    #expect(elenco.fissati.map(\.id) == ["p"])
    #expect(elenco.fissati[0].thumbFileId == "f1")
    #expect(elenco.inScadenza.map(\.id) == ["x", "c"])
    #expect(elenco.perTipo.map(\.tipo) == ["Assicurazione", "File"])
    #expect(elenco.perTipo[1].documenti.map(\.id) == ["s"])
    #expect(!elenco.vuoto)
    let sottotitoli = elenco.inScadenza.map(\.sottotitolo)
    #expect(sottotitoli == ["Patente · scaduto", "Carta d'identità · Anna · scade tra 24 giorni"])
  }

  @Test func tipiETitolari() async throws {
    let tipi = """
      [{"id":"t1","key":"passport","name":"Passaporto","icon":"passport","preset":true,"documents":1,
        "fields":[{"key":"number","label":"Numero","kind":"code","copyable":true}]}]
      """
    let transport = TransportFinto(.risposta(200, tipi))
    let elenco = try await APIClient(transport: transport).tipiDocumento()
    #expect(transport.richiesta?.url?.path == "/api/v1/documents/types")
    #expect(elenco[0].fields == [CampoTipo(key: "number", label: "Numero", kind: "code", copyable: true)])

    let nomi = TransportFinto(.risposta(200, #"["Io","Anna"]"#))
    #expect(try await APIClient(transport: nomi).titolari() == ["Io", "Anna"])
    #expect(nomi.richiesta?.url?.path == "/api/v1/documents/holders")
  }

  @Test func miniatura() async throws {
    let transport = TransportFinto(.risposta(200, "jpeg"))
    let dati = try await APIClient(transport: transport).miniaturaDocumento("p", file: "f1")
    #expect(dati == Data("jpeg".utf8))
    #expect(transport.richiesta?.url?.path == "/api/v1/documents/documents/p/files/f1")
    #expect(transport.richiesta?.url?.query == "variant=thumb")
  }
}
