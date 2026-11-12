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

  @Test func leAzioniViaggiano() async throws {
    var modulo = ModuloRicetta(nome: "Branzino")
    modulo.righe = [Bozza(Alimento(id: "f1", name: "Branzino", kcal: 100), testoGrammi: "200")]
    modulo.azioni = [AzioneRicetta(id: "a1", title: " Scongela ", daysBefore: 1, time: "21:00")]
    #expect(modulo.valido)
    let post = TransportFinto(.risposta(201, RicetteTests.dettaglio))
    _ = try await APIClient(transport: post).creaRicetta(modulo)
    let corpo = try #require(post.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    let azioni = try #require(json["actions"] as? [[String: Any]])
    #expect(azioni.first?["title"] as? String == "Scongela")
    #expect(azioni.first?["daysBefore"] as? Int == 1)
    #expect(azioni.first?["enabled"] as? Bool == true)

    modulo.azioni[0].time = "sera"
    #expect(modulo.problema == "Controlla le azioni: servono un titolo e un orario.")
  }
}
