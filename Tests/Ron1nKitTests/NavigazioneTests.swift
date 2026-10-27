import Testing

@testable import Ron1nKit

@Suite struct NavigazioneTests {
  @Test func predefinita() {
    let nav = Navigazione(.predefinite)
    #expect(nav.schede == [.home, .dieta, .palestra, .documenti, .altro])
    #expect(nav.altro == [.server, .torrent, .impostazioni])
  }

  @Test func seguiLOrdineDelSito() {
    let preferenze = Preferenze(
      disabledModules: [], navOrder: ["server", "note", "pasti", "casa", "documenti", "allenamenti"])
    let nav = Navigazione(preferenze)
    #expect(nav.schede == [.home, .server, .dieta, .documenti, .altro])
    #expect(nav.altro == [.palestra, .torrent, .impostazioni])
  }

  @Test func unModuloSpentoSparisce() {
    let preferenze = Preferenze(
      disabledModules: ["workout", "downloads"], navOrder: Preferenze.predefinite.navOrder)
    let nav = Navigazione(preferenze)
    #expect(nav.schede == [.home, .dieta, .documenti, .server, .altro])
    #expect(nav.altro == [.impostazioni])
    #expect(!nav.contiene(.palestra))
    #expect(!nav.contiene(.torrent))
    #expect(nav.contiene(.impostazioni))
  }

  @Test func pochiModuliAccesi() {
    let preferenze = Preferenze(
      disabledModules: ["nutrition", "workout", "documents", "server"], navOrder: [])
    let nav = Navigazione(preferenze)
    #expect(nav.schede == [.home, .torrent, .altro])
    #expect(nav.altro == [.impostazioni])
  }

  @Test func preferenzeIncomplete() async throws {
    let transport = TransportFinto(.risposta(200, #"{"disabledModules":["notes"],"appearance":{}}"#))
    let preferenze = try await APIClient(transport: transport).preferenze()
    #expect(transport.richiesta?.url?.path == "/api/v1/preferences")
    #expect(preferenze.disabledModules == ["notes"])
    #expect(preferenze.navOrder == Preferenze.predefinite.navOrder)
  }
}
