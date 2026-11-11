import Foundation
import Testing

@testable import Ron1nKit

@Suite struct AlimentiTests {
  static let yogurt = Alimento(
    source: "openfoodfacts", externalId: "5201054017111", name: "Yogurt greco bianco 2%", brand: "Fage",
    barcode: "5201054017111", servingSizeG: 170, kcal: 73, protein: 9, carbs: 4, fat: 2)
  static let pane = Alimento(id: "f1", name: "Pane", kcal: 265, protein: 9, carbs: 49, fat: 3)

  @Test func fonteESottotitolo() {
    #expect(AlimentiTests.yogurt.fonte == "OFF")
    #expect(AlimentiTests.pane.fonte == "mio")
    #expect(Alimento(source: "usda", name: "Rice", kcal: 130).fonte == "USDA")
    #expect(Alimento(source: "yazio", name: "Riso", kcal: 130).fonte == "YAZIO")
    #expect(AlimentiTests.yogurt.sottotitolo() == "Fage · 73 kcal / 100 g")
    #expect(AlimentiTests.pane.sottotitolo() == "265 kcal / 100 g")
    #expect(AlimentiTests.pane.chiave == "f1")
    #expect(AlimentiTests.yogurt.chiave == "openfoodfacts:5201054017111")
  }

  @Test func sottoDueCaratteriNonChiamaIlServer() async throws {
    let transport = TransportFinto(.risposta(200, #"{"results":[],"unavailable":[]}"#))
    let risultati = try await APIClient(transport: transport).cercaAlimenti(" y ")
    #expect(risultati.results.isEmpty)
    #expect(transport.richiesta == nil)
  }

  @Test func ricercaConSoloItalia() async throws {
    let corpo = """
      {"results":[{"id":null,"source":"openfoodfacts","externalId":"5201054017111",
        "name":"Yogurt greco bianco 2%","brand":"Fage","barcode":"5201054017111","servingSizeG":170,
        "kcal":73,"protein":9,"carbs":4,"fat":2,"caffeineMg":null,"yazioProductId":null}],
       "unavailable":["usda"]}
      """
    let transport = TransportFinto(.risposta(200, corpo))
    let risultati = try await APIClient(transport: transport).cercaAlimenti("yogurt greco")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/foods/search")
    #expect(transport.richiesta?.url?.query == "q=yogurt%20greco")
    #expect(risultati.results.first?.name == "Yogurt greco bianco 2%")
    #expect(risultati.results.first?.id == nil)
    #expect(risultati.avviso == "USDA non risponde")

    let mondo = TransportFinto(.risposta(200, corpo))
    _ = try await APIClient(transport: mondo).cercaAlimenti("joghurt", soloItalia: false)
    #expect(mondo.richiesta?.url?.query == "q=joghurt&italy=0")
    #expect(RisultatiRicerca(results: []).avviso == nil)
  }

  @Test func grammiPropostiEValidi() {
    // La porzione dell'alimento, se c'è.
    #expect(Bozza(AlimentiTests.yogurt).testoGrammi == "170")
    #expect(Bozza(AlimentiTests.pane).testoGrammi == "100")
    var bozza = Bozza(AlimentiTests.pane, testoGrammi: "")
    #expect(!bozza.valida)
    bozza.testoGrammi = "8"
    #expect(bozza.grammi == 8)
    bozza.testoGrammi = "80,5"
    #expect(bozza.grammi == 80.5)
    bozza.testoGrammi = "0"
    #expect(!bozza.valida)
    bozza.testoGrammi = "9000"
    #expect(!bozza.valida)
    bozza.testoGrammi = "abc"
    #expect(!bozza.valida)
  }

  @Test func macroMentreSiScrive() {
    var bozza = Bozza(AlimentiTests.pane, testoGrammi: "50")
    #expect(bozza.macro.kcal == 132.5)
    #expect(bozza.macro.carbs == 24.5)
    bozza.testoGrammi = "100"
    #expect(bozza.macro.kcal == 265)
    let righe = [bozza, Bozza(AlimentiTests.yogurt, testoGrammi: "170")]
    #expect(righe.totale.kcal == 265 + 73 * 1.7)
    #expect(righe.salvabile)
    #expect(![Bozza].init().salvabile)
    #expect(![bozza, Bozza(AlimentiTests.pane, testoGrammi: "")].salvabile)
  }
}
