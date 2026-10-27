import Foundation
import Testing

@testable import Ron1nKit

@Suite struct NotificheTests {
  let adesso = Date(timeIntervalSince1970: 1_800_000_000)

  func notifica(_ id: String, _ gruppo: GruppoNotifiche, tra secondi: Double) -> NotificaLocale {
    NotificaLocale(
      id: id, gruppo: gruppo, titolo: "t", corpo: "c", quando: adesso.addingTimeInterval(secondi))
  }

  @Test func soloGruppiAccesiEFuturi() {
    let candidate = [
      notifica("a", .pasti, tra: 300),
      notifica("b", .acqua, tra: 100),
      notifica("c", .pasti, tra: -60),
      notifica("d", .scadenze, tra: 50),
    ]
    let scelte = ScelteNotifiche(accesi: [.pasti, .scadenze])
    let risultato = PianoNotifiche.scegli(candidate, scelte: scelte, adesso: adesso)
    #expect(risultato.map(\.id) == ["d", "a"])
  }

  @Test func alMassimo64SenzaDoppioni() {
    let candidate = (0..<100).map { notifica("n\($0)", .acqua, tra: Double(100 - $0) * 60) }
    let acqua = ScelteNotifiche(accesi: [.acqua])
    let doppione = notifica("n99", .acqua, tra: 1)
    let scelte = PianoNotifiche.scegli(candidate + [doppione], scelte: acqua, adesso: adesso)
    #expect(scelte.count == PianoNotifiche.massimo)
    #expect(scelte.first?.id == "n99")
    #expect(scelte.first?.quando == adesso.addingTimeInterval(60))
  }

  @Test func tuttoSpentoAllInizio() throws {
    let defaults = try #require(UserDefaults(suiteName: "test-notifiche-\(UUID().uuidString)"))
    let memoria = MemoriaNotifiche(defaults: defaults)
    #expect(memoria.carica() == ScelteNotifiche())
    var scelte = memoria.carica()
    scelte.imposta(.acqua, acceso: true)
    scelte.imposta(.pasti, acceso: true)
    scelte.imposta(.pasti, acceso: false)
    memoria.salva(scelte)
    #expect(memoria.carica().accesi == [.acqua])
    #expect(GruppoNotifiche.allCases.map(\.titolo) == ["Pasti", "Acqua", "Scadenze documenti"])
  }
}

@Suite struct PermessoNotificheTests {
  @Test func loStatoDelPermesso() {
    #expect(PermessoNotifiche.nonChiesto.testo == "da chiedere")
    #expect(PermessoNotifiche.concesso.testo == "concesso")
    #expect(PermessoNotifiche.negato.testo == "negato in iOS")
    #expect(PermessoNotifiche.negato.segnale)
    #expect(!PermessoNotifiche.concesso.segnale)
    #expect(PermessoNotifiche.nonChiesto.spiegazione.contains("prima volta"))
  }
}
