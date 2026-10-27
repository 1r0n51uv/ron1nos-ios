import Foundation
import Testing

@testable import Ron1nKit

@Suite struct AccountTests {
  let fuso = TimeZone(identifier: "Europe/Rome")!

  @Test func quandoComeSulSito() throws {
    let adesso = try #require(CollegamentoYazio.istante("2026-10-27T15:00:00Z"))
    #expect(Formato.momento("2026-10-27T14:59:30Z", adesso: adesso, fuso: fuso) == "ora")
    #expect(Formato.momento("2026-10-27T14:48:00Z", adesso: adesso, fuso: fuso) == "12 min fa")
    #expect(Formato.momento("2026-10-27T09:05:00.123Z", adesso: adesso, fuso: fuso) == "oggi alle 10:05")
    #expect(Formato.momento("2026-10-26T13:05:00Z", adesso: adesso, fuso: fuso) == "26/10 alle 14:05")
    #expect(Formato.momento("boh", adesso: adesso, fuso: fuso) == nil)
  }

  @Test func ilTokenDiQuestoTelefono() throws {
    let json = """
      {"tokens":[{"id":"a","name":"iPad","createdAt":"x","lastUsedAt":null,"current":false},
                 {"id":"b","name":"iPhone","createdAt":"x","lastUsedAt":"y","current":true},
                 {"id":"c","name":"Vecchio","createdAt":"x","lastUsedAt":null}]}
      """
    struct Elenco: Decodable { let tokens: [TokenApp] }
    let elenco = try JSONDecoder().decode(Elenco.self, from: Data(json.utf8))
    #expect(elenco.tokens.map(\.current) == [false, true, false])
  }

  @Test func creaERevoca() async throws {
    let risposta = """
      {"id":"t1","name":"iPhone","createdAt":"x","lastUsedAt":null,"current":false,"token":"r1n_abc"}
      """
    let creato = TransportFinto(.risposta(201, risposta))
    let token = try await APIClient(transport: creato).creaToken(nome: " iPhone ")
    #expect(creato.richiesta?.httpMethod == "POST")
    #expect(creato.richiesta?.url?.path == "/api/v1/auth/tokens")
    let corpo = try #require(creato.richiesta?.httpBody)
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"name":"iPhone"}"#)
    #expect(token == TokenCreato(id: "t1", name: "iPhone", token: "r1n_abc"))

    let revoca = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: revoca).revocaToken("t1")
    #expect(revoca.richiesta?.httpMethod == "DELETE")
    #expect(revoca.richiesta?.url?.path == "/api/v1/auth/tokens/t1")
  }

  @Test func leSessioni() async throws {
    let una = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: una).chiudiSessione("s1")
    #expect(una.richiesta?.url?.path == "/api/v1/auth/sessions/s1")
    #expect(una.richiesta?.httpMethod == "DELETE")
    let tutte = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: tutte).chiudiSessioniWeb()
    #expect(tutte.richiesta?.url?.path == "/api/v1/auth/sessions")
  }

  @Test func ilNome() {
    #expect(NomeToken.problema("  ") == "Serve un nome.")
    #expect(NomeToken.problema(String(repeating: "a", count: 61)) == "Al massimo 60 caratteri.")
    #expect(NomeToken.problema("iPhone") == nil)
  }
}
