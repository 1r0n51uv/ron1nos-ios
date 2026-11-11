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
}
