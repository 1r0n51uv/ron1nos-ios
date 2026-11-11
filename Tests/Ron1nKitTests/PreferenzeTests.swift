import Foundation
import Testing

@testable import Ron1nKit

@Suite struct PreferenzeTests {
  let completo = """
    {"appearance":{"background":"image","glass":"strong","density":"compact"},
     "disabledModules":["notes"],"navOrder":["server","pasti","allenamenti","documenti","note","casa"],
     "formats":{"timeZone":"America/New_York","weightUnit":"lb","energyUnit":"kJ"},
     "reminders":{"meals":{},"water":[]},
     "updatedAt":"2026-10-27T10:00:00.000Z","backgroundImage":"2026-10-26T09:00:00.000Z","stored":true}
    """

  @Test func leggeAspettoEFormati() async throws {
    let preferenze = try await APIClient(transport: TransportFinto(.risposta(200, completo))).preferenze()
    #expect(preferenze.appearance == Aspetto(background: .image, glass: .strong, density: .compact))
    #expect(preferenze.formats == Formati(timeZone: "America/New_York", weightUnit: .lb, energyUnit: .kJ))
    #expect(preferenze.backgroundImage == "2026-10-26T09:00:00.000Z")
    #expect(preferenze.sfondo == .image)
  }

  @Test func valoriSconosciutiTornanoAiPredefiniti() async throws {
    let corpo = """
      {"appearance":{"background":"arcobaleno","glass":"light"},"formats":{"weightUnit":"stone"}}
      """
    let preferenze = try await APIClient(transport: TransportFinto(.risposta(200, corpo))).preferenze()
    #expect(preferenze.appearance == Aspetto(background: .brace, glass: .light, density: .comfortable))
    #expect(preferenze.formats == Formati())
  }

  @Test func immagineSenzaFileTornaBrace() {
    var preferenze = Preferenze.predefinite
    preferenze.appearance.background = .image
    #expect(preferenze.sfondo == .brace)
    preferenze.backgroundImage = "2026-10-26T09:00:00.000Z"
    #expect(preferenze.sfondo == .image)
  }

  @Test func veloEDensita() {
    #expect(Aspetto(glass: .light).velo == 0.04)
    #expect(Aspetto().velo == 0.06)
    #expect(Aspetto(glass: .strong).velo == 0.10)
    #expect(Aspetto().padding == 20)
    #expect(Aspetto().spazio == 14)
    #expect(Aspetto(density: .compact).padding == 14)
    #expect(Aspetto(density: .compact).spazio == 10)
  }

  @Test func unitaDiPesoEdEnergia() {
    let base = Formati()
    #expect(base.energia(1840) == "1.840 kcal")
    #expect(Formati(energyUnit: .kJ).energia(1840) == "7.699 kJ")
    #expect(base.peso(92.5) == "92,5 kg")
    #expect(base.peso(85) == "85 kg")
    #expect(Formati(weightUnit: .lb).peso(100) == "220,5 lb")
    #expect(base.fuso.identifier == "Europe/Rome")
    #expect(Formati(timeZone: "Marte/Base").fuso.identifier == "Europe/Rome")
  }

  @Test func memoriaSulTelefono() throws {
    let defaults = try #require(UserDefaults(suiteName: "test-preferenze-\(UUID().uuidString)"))
    let memoria = MemoriaPreferenze(defaults: defaults)
    #expect(memoria.carica() == nil)
    var preferenze = Preferenze.predefinite
    preferenze.appearance.glass = .strong
    preferenze.formats.energyUnit = .kJ
    memoria.salva(preferenze)
    #expect(memoria.carica() == preferenze)
  }

  @Test func immagineDiSfondo() async throws {
    let transport = TransportFinto(.risposta(200, "JPEG"))
    let dati = try await APIClient(transport: transport).immagineSfondo(versione: "2026-10-26T09:00:00Z")
    #expect(dati == Data("JPEG".utf8))
    #expect(transport.richiesta?.url?.path == "/api/v1/preferences/background")
    #expect(transport.richiesta?.url?.query?.hasPrefix("v=2026-10-26T09") == true)
  }
}

@Suite struct EnergiaDietaTests {
  @Test func kJ() {
    let giorno = GiornoDieta(
      date: "2026-10-27", totals: Macro(kcal: 1000, protein: 0, carbs: 0, fat: 0), quota: .init(kcal: 2000))
    let kJ = Formati(energyUnit: .kJ)
    #expect(giorno.testoEnergia(kJ) == "4.184 / 8.368 kJ")
    #expect(giorno.testoRimanenti(kJ) == "4.184 kJ rimanenti")
    #expect(giorno.testoKcal == "1.000 / 2.000 kcal")
  }
}
