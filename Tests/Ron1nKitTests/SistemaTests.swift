import Foundation
import Testing

@testable import Ron1nKit

@Suite struct SistemaTests {
  @Test func statiDelleIntegrazioni() {
    #expect(Integrazione.Stato.connected.testo == "collegato")
    #expect(Integrazione.Stato.error.testo == "errore")
    #expect(Integrazione.Stato.notConfigured.testo == "non configurato")
  }

  @Test func verificaUnServizio() async throws {
    let json = #"{"id":"glances","name":"Glances","state":"connected","checkedAt":"x","env":[]}"#
    let transport = TransportFinto(.risposta(200, json))
    let servizio = try await APIClient(transport: transport).verificaIntegrazione("glances")
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/integrations/glances/check")
    #expect(servizio.state == .connected)
  }

  @Test func leInformazioni() async throws {
    let json = """
      {"version":{"commit":"a1b2c3d4e5f6","builtAt":"2026-10-27T10:00:00Z"},
       "startedAt":"2026-10-25T10:00:00Z","uptimeSeconds":180000}
      """
    let transport = TransportFinto(.risposta(200, json))
    let info = try await APIClient(transport: transport).informazioni()
    #expect(transport.richiesta?.url?.path == "/api/v1/about")
    #expect(info.commitBreve == "a1b2c3d")
    #expect(info.indirizzoCommit?.absoluteString == "https://github.com/1r0n51uv/ron1nOS/commit/a1b2c3d4e5f6")
    #expect(Formato.acceso(info.uptimeSeconds) == "2 g")

    let locale = Informazioni(version: .init(), startedAt: "x", uptimeSeconds: 0)
    #expect(locale.commitBreve == "build locale")
    #expect(locale.indirizzoCommit == nil)
  }

  @Test func ilNomeDelBackup() {
    let data = Date(timeIntervalSince1970: 1_793_059_200)  // 2026-10-27 UTC
    #expect(EsitoBackup.nomeFile(adesso: data, fuso: .gmt) == "ron1nos-configurazione-2026-10-27.json")
  }

  @Test func esportaEImporta() async throws {
    let file = Data(#"{"format":1}"#.utf8)
    let esporta = TransportFinto(.risposta(200, #"{"format":1}"#))
    let scaricato = try await APIClient(transport: esporta).esportaConfigurazione()
    #expect(esporta.richiesta?.url?.path == "/api/v1/preferences/export")
    #expect(scaricato == file)

    let prova = TransportFinto(.risposta(200, #"{"changes":["Aspetto"],"notes":[],"applied":false}"#))
    let anteprima = try await APIClient(transport: prova).importaConfigurazione(file, conferma: false)
    #expect(prova.richiesta?.httpMethod == "POST")
    #expect(prova.richiesta?.url?.query == nil)
    #expect(prova.richiesta?.httpBody == file)
    #expect(anteprima == .fatto(EsitoBackup(changes: ["Aspetto"])))

    let scrivi = TransportFinto(.risposta(200, #"{"changes":[],"notes":[],"applied":true}"#))
    let fatto = try await APIClient(transport: scrivi).importaConfigurazione(file, conferma: true)
    #expect(scrivi.richiesta?.url?.query == "confirm=1")
    guard case .fatto(let esito) = fatto else {
      Issue.record("atteso l'esito")
      return
    }
    #expect(esito.applied)
    #expect(esito.nienteDaCambiare)
  }

  @Test func unFileNonValido() async throws {
    let errore = #"{"error":"invalid_layout","message":"Un layout del file non è valido."}"#
    let transport = TransportFinto(.risposta(422, errore))
    let esito = try await APIClient(transport: transport).importaConfigurazione(Data(), conferma: false)
    #expect(esito == .rifiutato("Un layout del file non è valido."))
    let rotto = TransportFinto(.risposta(503, #"{"error":"database_unavailable","message":"no"}"#))
    await #expect(throws: APIError.stato(503)) {
      _ = try await APIClient(transport: rotto).importaConfigurazione(Data(), conferma: true)
    }
  }
}
