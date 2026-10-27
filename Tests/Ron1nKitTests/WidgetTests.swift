import Foundation
import Testing

@testable import Ron1nKit

@Suite struct WidgetTests {
  @Test func opzioniConPredefiniti() {
    var metrica = ElementoLayout(id: "server.metric", misura: .small, variant: "compact")
    #expect(metrica.opzione("metric", predefinita: "cpu") == "cpu")
    #expect(metrica.compatto)
    metrica.options = ["metric": .testo("ram"), "limit": .numero(2), "macros": .elenco(["fat"])]
    #expect(metrica.opzione("metric", predefinita: "cpu") == "ram")
    #expect(metrica.opzione("limit", predefinita: 3) == 2)
    #expect(metrica.opzione("macros", predefinita: ["protein"]) == ["fat"])
    #expect(metrica.opzione("altro", predefinita: 3) == 3)
  }

  @Test func prossimoPastoEIntegratori() async throws {
    let corpo = """
      {"date":"2026-10-27","totals":{"kcal":900,"protein":40,"carbs":100,"fat":30},"goal":null,"quota":null,
       "nextSlot":"dinner","slots":[
         {"slot":"lunch","state":"eaten","meal":null,"planned":null},
         {"slot":"dinner","state":"planned","meal":null,
          "planned":{"id":"p1","status":"planned","recipeId":null,"recipeName":null,"templateName":null,
                     "kcal":620,"protein":30,"carbs":70,"fat":20,
                     "items":[{"name":"Pasta"},{"name":"Pomodoro"}]}}],
       "supplements":[{"id":"a","name":"Vitamina D","taken":true},{"id":"b","name":"Omega 3","taken":false}]}
      """
    let giorno = try await APIClient(transport: TransportFinto(.risposta(200, corpo))).dieta()
    #expect(giorno.titoloProssimoPasto == "Cena")
    #expect(giorno.pianificato(Formati()) == "Pasta, Pomodoro · 620 kcal")
    #expect(giorno.testoIntegratori == "1 di 2 integratori")
    #expect(giorno.mancanoIntegratori == "Mancano Omega 3")
  }

  @Test func giornoSenzaPiano() {
    let giorno = GiornoDieta(
      date: "2026-10-27", totals: Macro(kcal: 0, protein: 0, carbs: 0, fat: 0), nextSlot: "lunch",
      slots: [SlotGiorno(slot: "lunch", state: "empty")], supplements: [])
    #expect(giorno.pianificato(Formati()) == "Niente pianificato")
    #expect(giorno.testoIntegratori == "Nessun integratore attivo.")
    #expect(giorno.mancanoIntegratori == nil)
    let finito = GiornoDieta(date: "2026-10-27", totals: Macro(kcal: 0, protein: 0, carbs: 0, fat: 0))
    #expect(finito.titoloProssimoPasto == "Pasti completati")
    #expect(finito.pianificato(Formati()) == nil)
  }

  @Test func allenamento() async throws {
    let corpo = """
      {"today":"2026-10-27","last":{"id":"s1","day":"2026-10-26","routine":"Push",
       "startedAt":"2026-10-26T17:00:00Z","durationSeconds":3900,"exercise":null},
       "thisWeek":2,"streakDays":3,
       "weeks":[{"monday":"2026-10-19","count":4},{"monday":"2026-10-26","count":2}]}
      """
    let transport = TransportFinto(.risposta(200, corpo))
    let riepilogo = try await APIClient(transport: transport).allenamento()
    #expect(transport.richiesta?.url?.path == "/api/v1/workout/summary")
    #expect(riepilogo.testoUltimo == "Push · ieri · 1 h 05 min")
    #expect(riepilogo.weeks.map(\.count) == [4, 2])
    #expect(Giorni.relativo("2026-10-20", oggi: "2026-10-27") == "martedì 20 ottobre")
    #expect(Giorni.relativo("2026-10-27", oggi: "2026-10-27") == "oggi")
    #expect(Formato.durata(2700) == "45 min")
  }

  @Test func documenti() async throws {
    let corpo = """
      [{"id":"1","typeName":"Passaporto","title":"Passaporto","holder":"Io",
        "expiry":{"status":"expiring","daysLeft":30},"pinnedAt":null},
       {"id":"2","typeName":null,"title":"Bolletta","holder":"Anna","expiry":null,"pinnedAt":"2026-10-01"},
       {"id":"3","typeName":"Patente","title":"Patente","holder":"Io",
        "expiry":{"status":"ok","daysLeft":400},"pinnedAt":null},
       {"id":"4","typeName":"Carta d'identità","title":"CI","holder":"Anna",
        "expiry":{"status":"expired","daysLeft":-3},"pinnedAt":null}]
      """
    let transport = TransportFinto(.risposta(200, corpo))
    let lista = try await APIClient(transport: transport).documenti()
    #expect(transport.richiesta?.url?.path == "/api/v1/documents/documents")
    let vista = VistaDocumenti(lista)
    #expect(vista.fissati.map(\.id) == ["2"])
    #expect(vista.inScadenza.map(\.id) == ["4", "1"])
    #expect(vista.prossimo == 400)
    #expect(vista.inScadenza.map(\.etichetta) == ["Carta d'identità · Anna", "Passaporto"])
    #expect(vista.inScadenza.compactMap(\.expiry?.testo) == ["Scaduto", "Scade tra 30 giorni"])
  }

  @Test func risorse() {
    let stato = StatoServer(cpu: 12, ram: 48, disk: 91, uptimeSec: 0)
    #expect(stato.percentuale(.disk) == 91)
    #expect(stato.percentuale(.net) == nil)
    #expect(RisorsaServer(rawValue: "ram")?.titolo == "RAM")
  }
}
