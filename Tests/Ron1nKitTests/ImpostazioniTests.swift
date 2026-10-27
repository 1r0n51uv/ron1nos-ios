import Foundation
import Testing

@testable import Ron1nKit

@Suite struct ImpostazioniTests {
  @Test func iQuattroGruppi() {
    let gruppi = VoceImpostazioni.gruppi
    #expect(gruppi.map(\.titolo) == ["Questo iPhone", "ron1nOS", "Account", "Sistema"])
    #expect(gruppi.flatMap(\.voci).count == VoceImpostazioni.allCases.count)
    #expect(gruppi[0].voci.map(\.titolo) == ["Accesso", "Notifiche e Salute"])
  }

  @Test func loStatoInBreve() {
    var preferenze = Preferenze.predefinite
    preferenze.disabledModules = ["notes", "home"]
    preferenze.appearance.glass = .medium
    let stato = StatoImpostazioni(
      preferenze: preferenze, credenziali: true, login: .valido, notificheAccese: 2, widget: 6,
      sessioni: 1, token: 2,
      integrazioni: [
        Integrazione(id: "postgres", name: "Postgres", state: .connected, checkedAt: "x"),
        Integrazione(id: "yazio", name: "YAZIO", state: .notConfigured, checkedAt: "x"),
      ], versioneApp: "0.1.120")
    let riepiloghi = VoceImpostazioni.allCases.map { stato.riepilogo($0) ?? "-" }
    let attesi = [
      "collegato", "2 accese", "medio", "6 widget", "7 accesi", "prima Dieta", "kg · kcal", "1 sessione",
      "2 token", "1 di 2 collegate", "-", "0.1.120",
    ]
    #expect(riepiloghi == attesi)
    #expect(!VoceImpostazioni.allCases.contains { stato.segnale($0) })
  }

  @Test func iProblemiInRosso() {
    let senza = StatoImpostazioni(preferenze: .predefinite, credenziali: false)
    #expect(senza.riepilogo(.accesso) == "da configurare")
    #expect(senza.segnale(.accesso))
    #expect(senza.riepilogo(.notifiche) == "spente")
    #expect(senza.riepilogo(.dashboard) == nil)
    let rifiutato = StatoImpostazioni(
      preferenze: .predefinite, credenziali: true, login: .tokenRifiutato,
      integrazioni: [Integrazione(id: "glances", name: "Glances", state: .error, checkedAt: "x")])
    #expect(rifiutato.riepilogo(.accesso) == "token rifiutato")
    #expect(rifiutato.riepilogo(.integrazioni) == "1 in errore")
    #expect(rifiutato.segnale(.integrazioni))
  }

  @Test func sessioniTokenEIntegrazioni() async throws {
    let elenco = """
      {"sessions":[{"id":"s1","device":"Safari su iPhone","createdAt":"a","lastSeenAt":"b","current":true}]}
      """
    let sessioni = TransportFinto(.risposta(200, elenco))
    let lette = try await APIClient(transport: sessioni).sessioniWeb()
    #expect(sessioni.richiesta?.url?.path == "/api/v1/auth/sessions")
    #expect(lette.first?.current == true)

    let token = TransportFinto(
      .risposta(200, #"{"tokens":[{"id":"t1","name":"iPhone","createdAt":"a","lastUsedAt":null}]}"#))
    let letti = try await APIClient(transport: token).tokenApp()
    #expect(token.richiesta?.url?.path == "/api/v1/auth/tokens")
    #expect(letti == [TokenApp(id: "t1", name: "iPhone", createdAt: "a")])

    let json = """
      {"integrations":[{"id":"homeassistant","name":"Home Assistant","state":"not_configured",
       "message":null,"checkedAt":"c","env":["HA_URL","HA_TOKEN"]}]}
      """
    let servizi = TransportFinto(.risposta(200, json))
    let integrazioni = try await APIClient(transport: servizi).integrazioni()
    #expect(servizi.richiesta?.url?.path == "/api/v1/integrations")
    #expect(integrazioni.first?.state == .notConfigured)
    #expect(integrazioni.first?.env == ["HA_URL", "HA_TOKEN"])
  }
}
