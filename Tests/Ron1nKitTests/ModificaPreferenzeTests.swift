import Foundation
import Testing

@testable import Ron1nKit

@Suite struct ModificaPreferenzeTests {
  @Test func soloIGruppiCambiati() async throws {
    let risposta = """
      {"appearance":{"background":"nero","glass":"strong","density":"compact"},"disabledModules":[],
       "navOrder":["pasti","allenamenti","documenti","note","casa","server"],
       "formats":{"timeZone":"Europe/Rome","weightUnit":"kg","energyUnit":"kcal"},
       "reminders":{"meals":{},"water":[]},"updatedAt":null,"backgroundImage":null,"stored":true}
      """
    let transport = TransportFinto(.risposta(200, risposta))
    let aspetto = Aspetto(background: .nero, glass: .strong, density: .compact)
    let salvate = try await APIClient(transport: transport).modificaPreferenze(
      ModificaPreferenze(appearance: aspetto))
    #expect(transport.richiesta?.httpMethod == "PATCH")
    #expect(transport.richiesta?.url?.path == "/api/v1/preferences")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json.keys.sorted() == ["appearance"])
    #expect(salvate.appearance == aspetto)
  }

  @Test func accendereESpegnereUnModulo() {
    var preferenze = Preferenze.predefinite
    preferenze.disabledModules = ["notes"]
    let spegni = ModificaPreferenze.modulo("server", acceso: false, in: preferenze)
    #expect(spegni.disabledModules == ["notes", "server"])
    let accendi = ModificaPreferenze.modulo("notes", acceso: true, in: preferenze)
    #expect(accendi.disabledModules == [])
    #expect(spegni.applicata(a: preferenze).disabledModules == ["notes", "server"])
    #expect(spegni.applicata(a: preferenze).navOrder == preferenze.navOrder)
  }

  @Test func laNavigazione() {
    var preferenze = Preferenze.predefinite
    let ordine = VoceNavigazione.sposta(preferenze.navOrder, da: [5], a: 0)
    #expect(ordine == ["server", "pasti", "allenamenti", "documenti", "note", "casa"])
    #expect(VoceNavigazione.sposta(ordine, da: [0], a: 6).last == "server")
    preferenze.navOrder = ordine
    let riepilogo = VoceNavigazione.riepilogo(preferenze)
    #expect(riepilogo.barra == "Server, Dieta, Palestra")
    #expect(riepilogo.altro == "Documenti, Torrent")
    #expect(VoceNavigazione.titolo("casa") == "Casa")
  }

  @Test func titoliEdEsempi() {
    #expect(Aspetto.Vetro.strong.titolo == "Intenso")
    #expect(Aspetto.Densita.compact.titolo == "Compatta")
    #expect(ModuloRon1n.allCases.count == StatoImpostazioni.moduli.count)
    #expect(Formati(weightUnit: .lb).esempioPeso() == "80 kg = 176,4 lb")
    #expect(Formati(energyUnit: .kJ).esempioEnergia() == "2000 kcal = 8.368 kJ")
  }

  @Test func loSfondo() async throws {
    let transport = TransportFinto(.risposta(413, #"{"error":"file_too_large","message":"Oltre i 5 MB."}"#))
    let client = APIClient(transport: transport)
    let esito = try await client.caricaSfondo(Data([1]), nome: "a.jpg", tipo: "image/jpeg")
    #expect(transport.richiesta?.httpMethod == "PUT")
    #expect(transport.richiesta?.url?.path == "/api/v1/preferences/background")
    #expect(esito == .rifiutato("Oltre i 5 MB."))
  }
}
