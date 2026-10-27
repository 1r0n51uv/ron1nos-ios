import Foundation
import Testing

@testable import Ron1nKit

@Suite struct DocumentoTests {
  static let passaporto = """
    {"id":"d1","typeId":"t1","type":{"id":"t1","name":"Passaporto","icon":"passport","fields":[
       {"key":"number","label":"Numero","kind":"code","copyable":true},
       {"key":"issued","label":"Rilasciato il","kind":"date","copyable":false},
       {"key":"office","label":"Ufficio","kind":"text","copyable":true}]},
     "title":"Passaporto","holder":"Anna","expiresOn":"2030-01-31",
     "expiry":{"status":"ok","daysLeft":1200},"warnings":[90,30],"tags":["viaggi"],
     "pinnedAt":"2026-10-01T10:00:00Z","fields":{"number":"YA1234567","issued":"2020-01-31"},
     "extra":[{"label":"PIN","value":"1234"}],"notes":"Nel cassetto",
     "files":[{"id":"f1","name":"fronte.jpg","mime":"image/jpeg","size":1000,"label":"fronte","position":0,
       "hasThumb":true,"createdAt":"2026-10-01T10:00:00Z"},
      {"id":"f2","name":"scansione.pdf","mime":"application/pdf","size":5000,"label":"pagina","position":1,
       "hasThumb":false,"createdAt":"2026-10-01T10:00:00Z"}],
     "createdAt":"2026-10-01T10:00:00Z","updatedAt":"2026-10-01T10:00:00Z"}
    """

  @Test func campiNellOrdineDelTipo() async throws {
    let transport = TransportFinto(.risposta(200, DocumentoTests.passaporto))
    let documento = try await APIClient(transport: transport).documento("d1")
    #expect(transport.richiesta?.url?.path == "/api/v1/documents/documents/d1")
    #expect(documento.campi.map(\.etichetta) == ["Numero", "Rilasciato il", "PIN"])
    #expect(documento.campi.map(\.valore) == ["YA1234567", "31/01/2020", "1234"])
    #expect(documento.campi.map(\.copiabile) == [true, false, true])
    #expect(documento.fissato)
    #expect(documento.sottotitolo == "Passaporto · Anna · scade tra 1200 giorni")
    #expect(documento.files.map(\.immagine) == [true, false])
    #expect(documento.files.map(\.pdf) == [false, true])
    #expect(documento.files[0].etichetta == "Fronte")
  }

  @Test func copiaTutto() throws {
    let json = Data(DocumentoTests.passaporto.utf8)
    let documento = try JSONDecoder().decode(Documento.self, from: json)
    let atteso = """
      Passaporto
      Titolare: Anna
      Scadenza: 31/01/2030
      Numero: YA1234567
      Rilasciato il: 31/01/2020
      PIN: 1234
      Note: Nel cassetto
      """
    #expect(documento.testoCompleto == atteso)
  }

  @Test func fissaEdElimina() async throws {
    let patch = TransportFinto(.risposta(200, DocumentoTests.passaporto))
    _ = try await APIClient(transport: patch).fissaDocumento("d1", fissato: false)
    #expect(patch.richiesta?.httpMethod == "PATCH")
    #expect(String(decoding: patch.richiesta?.httpBody ?? Data(), as: UTF8.self) == #"{"pinned":false}"#)

    let delete = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: delete).eliminaDocumento("d1")
    #expect(delete.richiesta?.httpMethod == "DELETE")
    #expect(delete.richiesta?.url?.path == "/api/v1/documents/documents/d1")
  }

  @Test func allegatoEPdf() async throws {
    let file = TransportFinto(.risposta(200, "jpeg"))
    #expect(try await APIClient(transport: file).allegato("d1", file: "f1") == Data("jpeg".utf8))
    #expect(file.richiesta?.url?.path == "/api/v1/documents/documents/d1/files/f1")
    #expect(file.richiesta?.url?.query == nil)

    let pdf = TransportFinto(.risposta(200, "%PDF"))
    _ = try await APIClient(transport: pdf).pdfRiepilogo("d1")
    #expect(pdf.richiesta?.url?.path == "/api/v1/documents/documents/d1/summary.pdf")
  }
}
