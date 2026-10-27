import Foundation
import Testing

@testable import Ron1nKit

@Suite struct TipiDocumentoTests {
  static let tipo = """
    {"id":"t9","key":null,"name":"Tessera","icon":"card","preset":false,"documents":0,
     "fields":[{"key":"numero","label":"Numero","kind":"code","copyable":true}]}
    """

  @Test func validazione() {
    var modulo = ModuloTipo()
    #expect(modulo.problema == "Serve un nome.")
    modulo.nome = "Tessera"
    modulo.campi = [CampoTipo(label: " ")]
    #expect(modulo.problema == "Ogni campo vuole un'etichetta.")
    modulo.campi = [CampoTipo(label: "Numero", kind: "code")]
    #expect(modulo.problema == nil)
    #expect(ModuloTipo.nomeGenere("code") == "Codice")
  }

  @Test func creaConICampiNuoviSenzaChiave() async throws {
    let modulo = ModuloTipo(
      nome: " Tessera ", icona: "card",
      campi: [
        CampoTipo(key: "numero", label: "Numero", kind: "code"), CampoTipo(label: " Scade ", kind: "date"),
      ])
    let transport = TransportFinto(.risposta(201, TipiDocumentoTests.tipo))
    let esito = try await APIClient(transport: transport).creaTipo(modulo)
    guard case .fatto(let tipo) = esito else {
      Issue.record("atteso un tipo")
      return
    }
    #expect(tipo.id == "t9")
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/documents/types")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["name"] as? String == "Tessera")
    let campi = try #require(json["fields"] as? [[String: Any]])
    #expect(campi[0]["key"] as? String == "numero")
    #expect(campi[1]["key"] == nil)
    #expect(campi[1]["label"] as? String == "Scade")
  }

  @Test func modificaEdElimina() async throws {
    let patch = TransportFinto(.risposta(200, TipiDocumentoTests.tipo))
    _ = try await APIClient(transport: patch).modificaTipo("t9", ModuloTipo(nome: "Tessera"))
    #expect(patch.richiesta?.httpMethod == "PATCH")
    #expect(patch.richiesta?.url?.path == "/api/v1/documents/types/t9")

    let ok = TransportFinto(.risposta(204, ""))
    #expect(try await APIClient(transport: ok).eliminaTipo("t9") == nil)
    let inUso = TransportFinto(
      .risposta(409, #"{"error":"type_in_use","message":"Lo usano 2 documenti"}"#))
    #expect(try await APIClient(transport: inUso).eliminaTipo("t9") == "Lo usano 2 documenti")
  }
}
