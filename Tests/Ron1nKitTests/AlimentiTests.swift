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

  @Test func recentiPerSlot() async throws {
    let corpo = """
      {"results":[{"id":"f1","source":"custom","externalId":null,"name":"Caffè","brand":null,
        "barcode":null,"servingSizeG":null,"kcal":2,"protein":0,"carbs":0,"fat":0,"caffeineMg":40,
        "yazioProductId":null}]}
      """
    let transport = TransportFinto(.risposta(200, corpo))
    let recenti = try await APIClient(transport: transport).alimentiRecenti(slot: "breakfast")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/foods/recent")
    #expect(transport.richiesta?.url?.query == "slot=breakfast")
    #expect(recenti.map(\.name) == ["Caffè"])
  }

  @Test func codiceSconosciutoNonEUnErrore() async throws {
    let corpo = """
      {"id":"f1","source":"custom","externalId":null,"name":"Pane","brand":null,"barcode":"123",
       "servingSizeG":null,"kcal":265,"protein":9,"carbs":49,"fat":3,"caffeineMg":null,
       "yazioProductId":null}
      """
    let trovato = TransportFinto(.risposta(200, corpo))
    #expect(try await APIClient(transport: trovato).alimentoDaCodice("123")?.name == "Pane")
    let ignoto = TransportFinto(.risposta(404, #"{"error":"not_found"}"#))
    #expect(try await APIClient(transport: ignoto).alimentoDaCodice("999") == nil)
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

  @Test func registraRigheDelCatalogoEEsterne() async throws {
    let transport = TransportFinto(.risposta(201, GiornoCompletoTests.corpo))
    let righe = [
      Bozza(AlimentiTests.pane, testoGrammi: "80"), Bozza(AlimentiTests.yogurt, testoGrammi: "170"),
    ]
    let giorno = try await APIClient(transport: transport).registraPasto(
      giorno: "2026-10-27", slot: "lunch", righe: righe)
    #expect(giorno.date == "2026-10-27")
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.httpMethod == "POST")
    #expect(richiesta.url?.path == "/api/v1/nutrition/meals")
    let corpo = try #require(richiesta.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["date"] as? String == "2026-10-27")
    #expect(json["slot"] as? String == "lunch")
    let items = try #require(json["items"] as? [[String: Any]])
    #expect(items.count == 2)
    #expect(items[0]["foodId"] as? String == "f1")
    #expect(items[0]["grams"] as? Double == 80)
    #expect(items[0]["food"] == nil)
    let candidato = try #require(items[1]["food"] as? [String: Any])
    #expect(candidato["source"] as? String == "openfoodfacts")
    #expect(candidato["externalId"] as? String == "5201054017111")
    #expect(candidato["kcal"] as? Double == 73)
    #expect(items[1]["foodId"] == nil)
  }

  @Test func correggereUnaRiga() async throws {
    let patch = TransportFinto(.risposta(200, GiornoCompletoTests.corpo))
    _ = try await APIClient(transport: patch).cambiaGrammi("r1", 60)
    #expect(patch.richiesta?.httpMethod == "PATCH")
    #expect(patch.richiesta?.url?.path == "/api/v1/nutrition/meals/items/r1")
    let corpo = try #require(patch.richiesta?.httpBody)
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"grams":60}"#)

    let delete = TransportFinto(.risposta(200, GiornoCompletoTests.corpo))
    _ = try await APIClient(transport: delete).togliRiga("r1")
    #expect(delete.richiesta?.httpMethod == "DELETE")
    #expect(delete.richiesta?.url?.path == "/api/v1/nutrition/meals/items/r1")
  }
}

@Suite struct AlimentiPersonaliTests {
  @Test func validazioneComeIlBackend() {
    var modulo = AlimentoPersonale()
    #expect(modulo.problema == "Serve un nome.")
    modulo.nome = "  "
    #expect(!modulo.valido)
    modulo.nome = "Pane di segale"
    #expect(modulo.problema == "Le kcal per 100 g vanno da 0 a 900.")
    modulo.kcal = "901"
    #expect(modulo.problema == "Le kcal per 100 g vanno da 0 a 900.")
    modulo.kcal = "265"
    #expect(modulo.problema == "Le proteine per 100 g vanno da 0 a 100.")
    modulo.proteine = "9"
    modulo.carboidrati = "49"
    modulo.grassi = "3"
    #expect(modulo.valido)
    modulo.porzione = "mezzo"
    #expect(modulo.problema == "La porzione non è un numero.")
    modulo.porzione = "80"
    modulo.caffeina = "molta"
    #expect(modulo.problema == "La caffeina non è un numero.")
    modulo.caffeina = ""
    modulo.codice = "12345"
    #expect(modulo.problema == "Il codice a barre è di almeno 8 cifre.")
    modulo.codice = "5201054017111"
    #expect(modulo.valido)
    modulo.nome = String(repeating: "a", count: 201)
    #expect(modulo.problema == "Il nome è troppo lungo.")
  }

  @Test func iCampiVuotiViaggianoANull() async throws {
    let risposta = """
      {"id":"f9","source":"custom","externalId":null,"name":"Pane di segale","brand":null,
       "barcode":null,"servingSizeG":null,"kcal":265,"protein":9,"carbs":49,"fat":3,
       "caffeineMg":null,"yazioProductId":null}
      """
    let transport = TransportFinto(.risposta(201, risposta))
    let modulo = AlimentoPersonale(
      nome: " Pane di segale ", marca: "  ", kcal: "265", proteine: "9", carboidrati: "49", grassi: "3")
    let creato = try await APIClient(transport: transport).creaAlimento(modulo)
    #expect(creato.id == "f9")
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.httpMethod == "POST")
    #expect(richiesta.url?.path == "/api/v1/nutrition/foods")
    let corpo = try #require(richiesta.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["name"] as? String == "Pane di segale")
    #expect(json["brand"] is NSNull)
    #expect(json["barcode"] is NSNull)
    #expect(json["kcal"] as? Double == 265)
  }

  @Test func elencoCorreggiEElimina() async throws {
    let elenco = """
      {"foods":[{"id":"f9","source":"custom","externalId":null,"name":"Pane di segale","brand":"Mulino",
        "barcode":"5201054017111","servingSizeG":80,"kcal":265,"protein":9,"carbs":49,"fat":3,
        "caffeineMg":null,"yazioProductId":null}]}
      """
    let lettura = TransportFinto(.risposta(200, elenco))
    let alimenti = try await APIClient(transport: lettura).alimentiPersonali()
    #expect(lettura.richiesta?.url?.path == "/api/v1/nutrition/foods")
    #expect(alimenti.map(\.name) == ["Pane di segale"])

    // I campi del modulo partono dall'alimento letto.
    let modulo = AlimentoPersonale(try #require(alimenti.first))
    #expect(modulo.nome == "Pane di segale")
    #expect(modulo.marca == "Mulino")
    #expect(modulo.codice == "5201054017111")
    #expect(modulo.porzione == "80")
    #expect(modulo.kcal == "265")
    #expect(modulo.valido)

    let patch = TransportFinto(.risposta(200, elenco.replacingOccurrences(of: #"{"foods":["#, with: "")))
    _ = try? await APIClient(transport: patch).correggiAlimento("f9", modulo)
    #expect(patch.richiesta?.httpMethod == "PATCH")
    #expect(patch.richiesta?.url?.path == "/api/v1/nutrition/foods/f9")

    let delete = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: delete).eliminaAlimento("f9")
    #expect(delete.richiesta?.httpMethod == "DELETE")
    #expect(delete.richiesta?.url?.path == "/api/v1/nutrition/foods/f9")
  }

  @Test func codiceGiaUsatoEUnConflitto() async {
    let transport = TransportFinto(.risposta(409, #"{"error":"barcode_exists"}"#))
    await #expect(throws: APIError.self) {
      _ = try await APIClient(transport: transport).creaAlimento(
        AlimentoPersonale(nome: "Pane", kcal: "265", proteine: "9", carboidrati: "49", grassi: "3"))
    }
  }
}
