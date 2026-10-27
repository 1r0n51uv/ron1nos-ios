import Foundation
import Testing

@testable import Ron1nKit

@Suite struct AvvisiScadenzeTests {
  let roma = TimeZone(identifier: "Europe/Rome")!

  func data(_ testo: String) -> Date {
    ISO8601DateFormatter().date(from: testo)!
  }

  @Test func unAvvisoPerPreavvisoEIlGiornoDopo() {
    let passaporto = DocumentoBreve(
      id: "p", typeName: "Passaporto", title: "Passaporto di Anna", holder: "Anna", expiresOn: "2027-01-31",
      warnings: [30, 7])
    let notifiche = AvvisiScadenze.notifiche([passaporto], adesso: data("2026-10-27T10:00:00Z"), fuso: roma)
    #expect(notifiche.map(\.id) == ["scadenza-p-30", "scadenza-p-7", "scadenza-p-scaduto"])
    let attesi = [
      "Passaporto · scade tra 30 giorni", "Passaporto · scade tra 7 giorni", "Passaporto · scaduto",
    ]
    #expect(notifiche.map(\.corpo) == attesi)
    #expect(notifiche[0].quando == data("2027-01-01T08:00:00Z"))
    #expect(notifiche[2].quando == data("2027-02-01T08:00:00Z"))
    #expect(notifiche.allSatisfy { $0.gruppo == .scadenze && $0.dati == ["documento": "p"] })
    #expect(notifiche.allSatisfy { !$0.corpo.contains("Anna") })
  }

  @Test func soloNelFuturoEPredefiniti() {
    let senzaTipo = DocumentoBreve(id: "s", title: "Bolletta", expiresOn: "2026-11-20")
    let senzaData = DocumentoBreve(id: "n", title: "Nota")
    let notifiche = AvvisiScadenze.notifiche(
      [senzaTipo, senzaData], adesso: data("2026-10-27T10:00:00Z"), fuso: roma)
    #expect(notifiche.map(\.id) == ["scadenza-s-7", "scadenza-s-scaduto"])
    #expect(notifiche[0].corpo == "Documento · scade tra 7 giorni")
  }
}
