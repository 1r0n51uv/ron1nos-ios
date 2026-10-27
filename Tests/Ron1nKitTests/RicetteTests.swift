import Foundation
import Testing

@testable import Ron1nKit

@Suite struct RicetteTests {
  static let dettaglio = """
    {"id":"r1","name":"Pasta al pomodoro","notes":"Per due","grams":420,"kcal":620,"protein":22,
     "carbs":90,"fat":14,
     "items":[
       {"id":"i1","foodId":"f1","name":"Pasta","grams":160,"kcal":560,"protein":18,"carbs":112,
        "fat":3,"missing":false},
       {"id":"i2","foodId":null,"name":"Pomodoro","grams":260,"kcal":60,"protein":4,"carbs":12,
        "fat":1,"missing":true}
     ]}
    """

  static func ricetta() throws -> Ricetta {
    try JSONDecoder().decode(Ricetta.self, from: Data(RicetteTests.dettaglio.utf8))
  }

  @Test func elencoEDettaglio() async throws {
    let elenco = TransportFinto(.risposta(200, "{\"recipes\":[\(RicetteTests.dettaglio)]}"))
    let ricette = try await APIClient(transport: elenco).ricette()
    #expect(elenco.richiesta?.url?.path == "/api/v1/nutrition/recipes")
    #expect(ricette.map(\.name) == ["Pasta al pomodoro"])
    #expect(ricette.first?.sottotitolo() == "620 kcal · 420 g")
    #expect(ricette.first?.incompleta == true)

    let una = TransportFinto(.risposta(200, RicetteTests.dettaglio))
    let ricetta = try await APIClient(transport: una).ricetta("r1")
    #expect(una.richiesta?.url?.path == "/api/v1/nutrition/recipes/r1")
    #expect(ricetta.items.count == 2)
  }

  @Test func ilModuloPartiDallaRicettaSenzaLeRigheMancanti() throws {
    let modulo = ModuloRicetta(try RicetteTests.ricetta())
    #expect(modulo.nome == "Pasta al pomodoro")
    #expect(modulo.note == "Per due")
    // Il pomodoro è stato eliminato dal catalogo: resta fuori.
    #expect(modulo.righe.map(\.alimento.name) == ["Pasta"])
    #expect(modulo.righe.first?.testoGrammi == "160")
    // I valori per 100 g si ricavano dalla riga: 560 kcal per 160 g.
    #expect(modulo.righe.first?.alimento.kcal == 350)
    #expect(modulo.totale.kcal == 560)
    #expect(modulo.valido)
  }

  @Test func validazioneDelModulo() {
    var modulo = ModuloRicetta()
    #expect(modulo.problema == "Serve un nome.")
    modulo.nome = "Insalata"
    #expect(modulo.problema == "Serve almeno un alimento.")
    let pane = Alimento(id: "f1", name: "Pane", kcal: 265)
    modulo.righe = [Bozza(pane, testoGrammi: "")]
    #expect(modulo.problema == "Controlla i grammi.")
    modulo.righe = [Bozza(pane, testoGrammi: "80")]
    #expect(modulo.valido)
    modulo.nome = String(repeating: "a", count: 201)
    #expect(modulo.problema == "Il nome è troppo lungo.")
    modulo.nome = "Insalata"
    modulo.righe = (0..<51).map { _ in Bozza(pane, testoGrammi: "10") }
    #expect(modulo.problema == "Al massimo 50 alimenti.")
  }

  @Test func creaECorreggi() async throws {
    var modulo = ModuloRicetta(nome: " Insalata ", note: "  ")
    modulo.righe = [Bozza(Alimento(id: "f1", name: "Lattuga", kcal: 15), testoGrammi: "120")]
    let post = TransportFinto(.risposta(201, RicetteTests.dettaglio))
    _ = try await APIClient(transport: post).creaRicetta(modulo)
    #expect(post.richiesta?.httpMethod == "POST")
    let corpo = try #require(post.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["name"] as? String == "Insalata")
    #expect(json["notes"] is NSNull)
    let items = try #require(json["items"] as? [[String: Any]])
    #expect(items.first?["foodId"] as? String == "f1")
    #expect(items.first?["grams"] as? Double == 120)

    let put = TransportFinto(.risposta(200, RicetteTests.dettaglio))
    _ = try await APIClient(transport: put).correggiRicetta("r1", modulo)
    #expect(put.richiesta?.httpMethod == "PUT")
    #expect(put.richiesta?.url?.path == "/api/v1/nutrition/recipes/r1")

    let delete = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: delete).eliminaRicetta("r1")
    #expect(delete.richiesta?.httpMethod == "DELETE")
  }

  @Test func registraEPianificaUnaRicetta() async throws {
    let post = TransportFinto(.risposta(201, GiornoCompletoTests.corpo))
    _ = try await APIClient(transport: post).registraRicetta(
      giorno: "2026-10-27", slot: "dinner", ricetta: "r1", porzioni: 0.5)
    #expect(post.richiesta?.httpMethod == "POST")
    #expect(post.richiesta?.url?.path == "/api/v1/nutrition/meals")
    let corpo = try #require(post.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["slot"] as? String == "dinner")
    let items = try #require(json["items"] as? [[String: Any]])
    #expect(items.first?["recipeId"] as? String == "r1")
    #expect(items.first?["factor"] as? Double == 0.5)

    let put = TransportFinto(.risposta(200, GiornoCompletoTests.corpo))
    _ = try await APIClient(transport: put).pianificaRicetta(
      giorno: "2026-11-02", slot: "lunch", ricetta: "r1")
    #expect(put.richiesta?.httpMethod == "PUT")
    #expect(put.richiesta?.url?.path == "/api/v1/nutrition/plans")
  }

  @Test func pianificaAlimentiEToglieIlPiano() async throws {
    let put = TransportFinto(.risposta(200, GiornoCompletoTests.corpo))
    let righe = [Bozza(Alimento(id: "f1", name: "Riso", kcal: 130), testoGrammi: "90")]
    _ = try await APIClient(transport: put).pianificaPasto(
      giorno: "2026-10-28", slot: "lunch", righe: righe)
    #expect(put.richiesta?.httpMethod == "PUT")
    #expect(put.richiesta?.url?.path == "/api/v1/nutrition/plans")

    let delete = TransportFinto(.risposta(200, GiornoCompletoTests.corpo))
    _ = try await APIClient(transport: delete).eliminaPiano("p1")
    #expect(delete.richiesta?.httpMethod == "DELETE")
    #expect(delete.richiesta?.url?.path == "/api/v1/nutrition/plans/p1")
  }

  @Test func unPastoGiaMangiatoEUnConflitto() async {
    let transport = TransportFinto(.risposta(409, #"{"error":"plan_eaten"}"#))
    await #expect(throws: APIError.self) {
      _ = try await APIClient(transport: transport).pianificaRicetta(
        giorno: "2026-10-27", slot: "lunch", ricetta: "r1")
    }
  }
}
