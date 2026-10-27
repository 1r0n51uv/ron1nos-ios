import Foundation
import Testing

@testable import Ron1nKit

@Suite struct ImportLiftinTests {
  static let esito = """
    {"newSessions":12,"updatedSessions":1,"unchangedSessions":200,"deletedSessions":0,"newSets":240,
     "updatedSets":3,"skippedRows":2,"from":"2025-01-03","to":"2026-10-26"}
    """

  @Test func anteprimaInMultipart() async throws {
    let transport = TransportFinto(.risposta(200, ImportLiftinTests.esito))
    let file = Data("Date;Duration;Routine;Exercise;Set\n".utf8)
    let risposta = try await APIClient(transport: transport).anteprimaImport(file, nome: "liftin.csv")
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.httpMethod == "POST")
    #expect(richiesta.url?.path == "/api/v1/workout/import/preview")
    let tipo = try #require(richiesta.value(forHTTPHeaderField: "Content-Type"))
    #expect(tipo.hasPrefix("multipart/form-data; boundary=ron1nOS-"))
    let dati = try #require(richiesta.httpBody)
    let corpo = String(decoding: dati, as: UTF8.self)
    #expect(corpo.contains("Content-Disposition: form-data; name=\"file\"; filename=\"liftin.csv\""))
    #expect(corpo.contains("Date;Duration;Routine;Exercise;Set"))

    guard case .pronto(let esito) = risposta else {
      Issue.record("attesi i conti")
      return
    }
    #expect(esito.periodo == "Dal 3 gennaio 2025 al 26 ottobre 2026")
    let titoli = esito.righe.map(\.0)
    #expect(titoli == ["Allenamenti nuovi", "Allenamenti aggiornati", "Già presenti", "Righe scartate"])
    #expect(esito.righe.first?.1 == "12")
    #expect(!esito.nienteDiNuovo)
  }

  @Test func fileRifiutatoConIlTestoDelServer() async throws {
    let errore = #"{"error":"invalid_request","message":"Mancano le colonne Date, Exercise."}"#
    let transport = TransportFinto(.risposta(400, errore))
    let risposta = try await APIClient(transport: transport).importa(Data(), nome: "vuoto.csv")
    #expect(transport.richiesta?.url?.path == "/api/v1/workout/import")
    #expect(risposta == .rifiutato("Mancano le colonne Date, Exercise."))
  }

  @Test func altriErroriRestanoErrori() async {
    let transport = TransportFinto(.risposta(503, "{}"))
    await #expect(throws: APIError.stato(503)) {
      _ = try await APIClient(transport: transport).importa(Data(), nome: "x.csv")
    }
  }
}
