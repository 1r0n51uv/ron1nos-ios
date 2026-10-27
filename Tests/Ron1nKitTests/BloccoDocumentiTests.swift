import Foundation
import Testing

@testable import Ron1nKit

@Suite struct BloccoDocumentiTests {
  @Test func loSbloccoDuraUnMinutoInBackground() {
    var blocco = BloccoDocumenti()
    #expect(!blocco.aperto)
    blocco.sblocca()
    #expect(blocco.aperto)

    let zero = Date(timeIntervalSince1970: 0)
    blocco.entraInBackground(zero)
    blocco.torna(zero.addingTimeInterval(59))
    #expect(blocco.aperto)

    blocco.entraInBackground(zero.addingTimeInterval(100))
    blocco.entraInBackground(zero.addingTimeInterval(150))
    blocco.torna(zero.addingTimeInterval(161))
    #expect(!blocco.aperto)
  }

  @Test func spentoNonChiedeNulla() throws {
    #expect(BloccoDocumenti(attivo: false).aperto)
    let defaults = try #require(UserDefaults(suiteName: "prova-\(UUID().uuidString)"))
    #expect(BloccoDocumenti(defaults: defaults).attivo)
    defaults.set(false, forKey: BloccoDocumenti.chiave)
    #expect(!BloccoDocumenti(defaults: defaults).attivo)
  }
}
