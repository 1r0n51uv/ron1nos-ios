import Foundation
import Testing

@testable import Ron1nKit

@Suite struct ModuloDocumentoTests {
  static let passaporto = TipoDocumento(
    id: "t1", name: "Passaporto", icon: "passport",
    fields: [
      CampoTipo(key: "number", label: "Numero", kind: "code"),
      CampoTipo(key: "issue_date", label: "Data di rilascio", kind: "date", copyable: false),
    ])

  @Test func formVuotiComeSulSito() {
    let documento = ModuloDocumento(genere: .documento, tipo: ModuloDocumentoTests.passaporto)
    #expect(documento.titolo == "Passaporto")
    #expect(documento.titolare == "Io")
    #expect(documento.avvisi == [90, 30, 7])
    #expect(documento.liberi.isEmpty)

    let info = ModuloDocumento(
      genere: .conInfo, tipo: ModuloDocumentoTests.passaporto, nomeFile: "contratto.pdf")
    #expect(info.tipo == nil)
    #expect(info.titolo == "contratto")
    #expect(info.liberi.count == 1)
    #expect(ModuloDocumento.senzaEstensione(".bashrc") == ".bashrc")
  }

  @Test func problemiSulCampo() {
    var modulo = ModuloDocumento(genere: .documento, tipo: ModuloDocumentoTests.passaporto)
    modulo.titolo = "  "
    modulo.scadenza = "2030-02-30"
    modulo.valori["issue_date"] = "15/01/2017"
    modulo.tag = String(repeating: "x", count: 41)
    #expect(modulo.problemi["Titolo"] == "Serve un titolo.")
    #expect(modulo.problemi["Scadenza"] == "Data non valida.")
    #expect(modulo.problemi["Data di rilascio"] == "Data non valida.")
    #expect(modulo.problemi["Tag"] == "Ogni tag al massimo 40 caratteri.")
    #expect(!modulo.valido)

    modulo.titolo = "Passaporto"
    modulo.scadenza = "2030-01-31"
    modulo.valori["issue_date"] = "2017-01-15"
    modulo.tag = "viaggi"
    #expect(modulo.valido)
    #expect(modulo.campo(di: "Data di rilascio: data non valida") == "Data di rilascio")
    #expect(modulo.campo(di: "Tipo di documento sconosciuto") == nil)
  }

  @Test func corpoDiUnFileConInfo() async throws {
    var modulo = ModuloDocumento(genere: .conInfo, nomeFile: "contratto.pdf")
    modulo.liberi = [
      Documento.CampoLibero(label: " IBAN ", value: " IT00 "),
      Documento.CampoLibero(label: "", value: ""),
    ]
    modulo.tag = "casa, , luce "
    modulo.scadenza = "2030-01-31"
    let transport = TransportFinto(.risposta(201, DocumentoTests.passaporto))
    let esito = try await APIClient(transport: transport).creaDocumento(modulo)
    guard case .fatto(let documento) = esito else {
      Issue.record("atteso un documento")
      return
    }
    #expect(documento.id == "d1")
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/documents/documents")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["typeId"] is NSNull)
    #expect(json["expiresOn"] is NSNull)
    #expect(json["title"] as? String == "contratto")
    #expect(json["tags"] as? [String] == ["casa", "luce"])
    let extra = try #require(json["extra"] as? [[String: String]])
    #expect(extra == [["label": "IBAN", "value": "IT00"]])
  }

  @Test func ilServerRifiutaConUnMessaggio() async throws {
    var modulo = ModuloDocumento(genere: .documento, tipo: ModuloDocumentoTests.passaporto)
    modulo.valori["issue_date"] = "2017-01-15"
    let errore = #"{"error":"invalid_request","message":"Data di rilascio: data non valida"}"#
    let transport = TransportFinto(.risposta(400, errore))
    let esito = try await APIClient(transport: transport).modificaDocumento("d1", modulo)
    #expect(esito == .rifiutato("Data di rilascio: data non valida"))
    #expect(transport.richiesta?.httpMethod == "PATCH")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["typeId"] as? String == "t1")
    #expect(json["fields"] as? [String: String] == ["issue_date": "2017-01-15"])
  }

  @Test func caricaUnAllegato() async throws {
    let json = """
      {"id":"f9","name":"fronte.jpg","mime":"image/jpeg","size":4,"label":"fronte","position":0,
       "hasThumb":true,"createdAt":"2026-10-27T10:00:00Z"}
      """
    let transport = TransportFinto(.risposta(201, json))
    let esito = try await APIClient(transport: transport).caricaAllegato(
      "d1", file: Data("jpeg".utf8), nome: "fronte.jpg", tipo: "image/jpeg", etichetta: "fronte")
    let atteso = Documento.Allegato(
      id: "f9", name: "fronte.jpg", mime: "image/jpeg", size: 4, label: "fronte", hasThumb: true)
    #expect(esito == .fatto(atteso))
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.url?.path == "/api/v1/documents/documents/d1/files")
    let tipo = richiesta.value(forHTTPHeaderField: "Content-Type") ?? ""
    #expect(tipo.hasPrefix("multipart/form-data; boundary="))
    let corpo = String(decoding: richiesta.httpBody ?? Data(), as: UTF8.self)
    #expect(corpo.contains("name=\"label\"\r\n\r\nfronte\r\n"))
    #expect(corpo.contains("filename=\"fronte.jpg\"\r\nContent-Type: image/jpeg\r\n\r\njpeg"))

    let pieno = TransportFinto(.risposta(413, #"{"error":"file_too_large","message":"File oltre i 20 MB"}"#))
    let rifiutato = try await APIClient(transport: pieno).caricaAllegato(
      "d1", file: Data(), nome: "x.pdf", tipo: "application/pdf", etichetta: "altro")
    #expect(rifiutato == .rifiutato("File oltre i 20 MB"))
  }
}
