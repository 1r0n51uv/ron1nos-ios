import Foundation
import Testing

@testable import Ron1nKit

@Suite struct PromemoriaTests {
  @Test func orariDallePreferenze() throws {
    let json = """
      {"navOrder":["pasti","allenamenti","documenti","note","casa","server"],"disabledModules":[],
       "reminders":{"meals":{"lunch":"12:45","dinner":"25:00"},"water":["09:00","nove"]}}
      """
    let preferenze = try JSONDecoder().decode(Preferenze.self, from: Data(json.utf8))
    #expect(preferenze.reminders.orario("lunch") == "12:45")
    // Un orario che non si capisce vale il predefinito.
    #expect(preferenze.reminders.orario("dinner") == "20:00")
    #expect(preferenze.reminders.orario("breakfast") == "07:30")
    #expect(preferenze.reminders.water == ["09:00"])

    let senza = try JSONDecoder().decode(Preferenze.self, from: Data("{}".utf8))
    #expect(senza.reminders == .predefiniti)
  }

  @Test func orariValidi() {
    #expect(Promemoria.minuti("07:30") == 450)
    #expect(Promemoria.minuti("7:30") == nil)
    #expect(Promemoria.minuti("24:00") == nil)
    #expect(Promemoria.testo(ore: 7, minuti: 5) == "07:05")
    #expect(Promemoria.ordina(["19:00", "10:00", "19:00", "x"]) == ["10:00", "19:00"])
  }

  @Test func salvaSoloIPromemoria() async throws {
    let transport = TransportFinto(.risposta(200, "{}"))
    let promemoria = Promemoria(meals: ["lunch": "12:45"], water: ["10:00"])
    _ = try await APIClient(transport: transport).salvaPromemoria(promemoria)
    #expect(transport.richiesta?.httpMethod == "PATCH")
    #expect(transport.richiesta?.url?.path == "/api/v1/preferences")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    let reminders = try #require(json["reminders"] as? [String: Any])
    #expect(reminders["meals"] as? [String: String] == ["lunch": "12:45"])
    #expect(reminders["water"] as? [String] == ["10:00"])
    #expect(json.count == 1)
  }

  static func giorno(acqua: Int) -> GiornoDieta {
    let pranzo = SlotGiorno.Pianificato(id: "p1", kcal: 620, recipeName: "Pasta al pomodoro")
    let slots = [
      SlotGiorno(slot: "breakfast", state: "eaten"),
      SlotGiorno(slot: "morning_snack", state: "skipped"),
      SlotGiorno(slot: "lunch", state: "planned", planned: pranzo),
      SlotGiorno(slot: "afternoon_snack", state: "empty"),
      SlotGiorno(slot: "dinner", state: "empty"),
    ]
    return GiornoDieta(
      date: "2026-10-27", totals: Macro(kcal: 600, protein: 30, carbs: 70, fat: 20),
      goal: Macro(kcal: 1900, protein: 130, carbs: 210, fat: 60, waterMl: 2000), slots: slots, waterMl: acqua)
  }

  @Test func pastiNonMangiatiEAcquaSottoQuota() throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let adesso = try #require(calendario.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 11)))
    let notifiche = PromemoriaDieta.notifiche(
      giorni: [PromemoriaTests.giorno(acqua: 500)], promemoria: .predefiniti, oggi: "2026-10-27",
      adesso: adesso, fuso: fuso)

    let pasti = notifiche.filter { $0.gruppo == .pasti }
    #expect(
      pasti.map(\.id) == [
        "pasto-2026-10-27-lunch", "pasto-2026-10-27-afternoon_snack", "pasto-2026-10-27-dinner",
      ])
    let pranzo = try #require(pasti.first)
    #expect(pranzo.titolo == "Pranzo?")
    #expect(pranzo.corpo == "In programma Pasta al pomodoro")
    #expect(pranzo.categoria == PromemoriaDieta.categoriaPasto)
    #expect(pranzo.dati == ["giorno": "2026-10-27", "slot": "lunch", "piano": "p1"])
    #expect(calendario.component(.hour, from: pranzo.quando) == 13)
    // Senza piano non c'è niente da segnare: niente pulsanti.
    #expect(pasti[1].categoria == nil)
    #expect(pasti[1].corpo == "Niente di registrato per ora")

    // 500 ml: alle 13 ne servono 800, alle 16 1.200, alle 19 1.600; le 10 sono passate.
    let acqua = notifiche.filter { $0.gruppo == .acqua }
    #expect(
      acqua.map(\.id) == ["acqua-2026-10-27-13:00", "acqua-2026-10-27-16:00", "acqua-2026-10-27-19:00"])
    #expect(acqua.first?.corpo == "0,5 / 2,0 l · un bicchiere?")

    let bevuto = PromemoriaDieta.notifiche(
      giorni: [PromemoriaTests.giorno(acqua: 1000)], promemoria: .predefiniti, oggi: "2026-10-27",
      adesso: adesso, fuso: fuso)
    let ancora = bevuto.filter { $0.gruppo == .acqua }.map(\.id)
    #expect(ancora == ["acqua-2026-10-27-16:00", "acqua-2026-10-27-19:00"])
  }

  @Test func quotaAllOra() {
    #expect(PromemoriaDieta.quotaAllOra(7 * 60) == 0)
    #expect(PromemoriaDieta.quotaAllOra(22 * 60) == 1)
    #expect(PromemoriaDieta.quotaAllOra(6 * 60) == 0)
    #expect(PromemoriaDieta.quotaAllOra(23 * 60) == 1)
  }
}
