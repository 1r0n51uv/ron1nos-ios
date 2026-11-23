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

  @Test func laFotoGenerataSiAvviaESiLegge() async throws {
    let json = RicetteTests.dettaglio.replacingOccurrences(
      of: #""id":"r1""#,
      with: #""id":"r1","photo":{"state":"failed","error":"Il dojo non risponde"}"#)
    let transport = TransportFinto(.risposta(202, json))
    let ricetta = try await APIClient(transport: transport).generaFoto("r1")
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/recipes/r1/photo/generate")
    #expect(ricetta.photo == FotoInPreparazione(state: "failed", error: "Il dojo non risponde"))
    #expect(ricetta.photo?.inCorso == false)
  }

  @Test func unaRicettaSenzaFotoInPreparazioneNonLaHa() throws {
    let ricetta = try JSONDecoder().decode(Ricetta.self, from: Data(RicetteTests.dettaglio.utf8))
    #expect(ricetta.photo == nil)
  }

  @Test func soloLeFotoDelServerSiCaricanoConAccesso() async throws {
    let (percorso, query) = try #require(
      APIClient.percorsoProprio("/api/v1/nutrition/recipes/r1/photo?v=1792578600"))
    #expect(percorso == "nutrition/recipes/r1/photo")
    #expect(query == [URLQueryItem(name: "v", value: "1792578600")])
    #expect(APIClient.percorsoProprio("https://images.yazio-cdn.com/a.jpg") == nil)

    let transport = TransportFinto(.risposta(200, "PNG"))
    let dati = try await APIClient(transport: transport).foto("/api/v1/nutrition/recipes/r1/photo?v=5")
    #expect(dati == Data("PNG".utf8))
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/recipes/r1/photo")
    #expect(transport.richiesta?.url?.query == "v=5")
  }

  // MARK: Categorie e composte (IOS-046)

  static let composta = """
    {"id":"c1","name":"Pranzo leggero","notes":null,"categories":["cold","lunch","brunch"],
     "parts":[
       {"id":"p1","role":"course","recipeId":"r1","name":"Pollo","imageUrl":null,"factor":1,"kcal":165},
       {"id":"p2","role":"side","recipeId":"r2","name":"Zucchine","imageUrl":null,"factor":1.5,"kcal":51}],
     "grams":450,"kcal":216,"protein":30,"carbs":5,"fat":3,
     "items":[{"id":"p1/i1","foodId":"f1","name":"Petto di pollo","grams":150,"kcal":165,"protein":23,
               "carbs":0,"fat":1,"missing":false}]}
    """

  @Test func leCategorieSiLeggonoNellOrdineFissoEUnaSconosciutaSiSalta() throws {
    let ricetta = try JSONDecoder().decode(Ricetta.self, from: Data(RicetteTests.composta.utf8))
    #expect(ricetta.categorie == [.lunch, .cold])
    #expect(ricetta.categorie.map(\.nome) == ["Pranzo", "Freddo"])
    #expect(ricetta.composta)
    #expect(ricetta.parts.map(\.role) == [.course, .side])
    // Senza categorie né parti, come un server di prima.
    let semplice = try RicetteTests.ricetta()
    #expect(semplice.categorie.isEmpty)
    #expect(!semplice.composta)
  }

  @Test func ilModuloDiUnaCompostaPartePerParteEInviaSoloLeParti() throws {
    let ricetta = try JSONDecoder().decode(Ricetta.self, from: Data(RicetteTests.composta.utf8))
    let modulo = ModuloRicetta(ricetta)
    #expect(modulo.composta)
    #expect(modulo.righe.isEmpty)
    #expect(modulo.categorie == [.lunch, .cold])
    // 51 kcal per 1,5 porzioni: 34 a porzione.
    #expect(modulo.parti.map(\.kcal) == [165, 34])
    #expect(modulo.kcalParti == 216)
    #expect(modulo.valido)

    let json = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(modulo.corpo)) as? [String: Any])
    #expect(json["items"] == nil)
    #expect(json["categories"] as? [String] == ["lunch", "cold"])
    let parti = try #require(json["parts"] as? [[String: Any]])
    #expect(parti.map { $0["role"] as? String } == ["course", "side"])
    #expect(parti.map { $0["recipeId"] as? String } == ["r1", "r2"])
    #expect(parti.map { $0["factor"] as? Double } == [1, 1.5])
  }

  @Test func laValidazioneDiUnaCompostaVuoleLeParti() throws {
    var modulo = ModuloRicetta(nome: "Cena", composta: true)
    #expect(modulo.problema == "Scegli almeno una ricetta.")
    let pollo = Ricetta(id: "r1", name: "Pollo", grams: 150, kcal: 165)
    modulo.parti = [BozzaParte(ruolo: .course, pollo)]
    #expect(modulo.valido)
    modulo.parti[0].porzioni = 0.2
    #expect(modulo.problema == "Controlla le porzioni.")
    modulo.parti[0].porzioni = 1
    modulo.parti = Array(repeating: modulo.parti[0], count: 11)
    #expect(modulo.problema == "Al massimo 10 parti.")
  }

  @Test func unaRicettaSempliceInviaLeRigheEMaiLeParti() throws {
    var modulo = ModuloRicetta(try RicetteTests.ricetta())
    modulo.categorie = [.snack, .hot]
    let json = try #require(
      try JSONSerialization.jsonObject(with: JSONEncoder().encode(modulo.corpo)) as? [String: Any])
    #expect(json["parts"] == nil)
    #expect((json["items"] as? [Any])?.count == 1)
    #expect(json["categories"] as? [String] == ["snack", "hot"])
  }

  @Test func ilFiltroPerCategoria() throws {
    let a = Ricetta(id: "a", name: "A", categories: ["cold"], grams: 1, kcal: 1)
    let b = Ricetta(id: "b", name: "B", categories: ["hot", "dinner"], grams: 1, kcal: 1)
    #expect(RicercaRicette.conCategoria([a, b], nil).map(\.id) == ["a", "b"])
    #expect(RicercaRicette.conCategoria([a, b], .hot).map(\.id) == ["b"])
    #expect(RicercaRicette.conCategoria([a, b], .lunch).isEmpty)
  }

  @Test func cambiaCategorieInviaUnaPatch() async throws {
    let transport = TransportFinto(.risposta(200, RicetteTests.composta))
    let ricetta = try await APIClient(transport: transport).cambiaCategorie("c1", [.cold, .lunch])
    #expect(ricetta.id == "c1")
    #expect(transport.richiesta?.httpMethod == "PATCH")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/recipes/c1")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["categories"] as? [String] == ["cold", "lunch"])
  }

  @Test func programmaLaRicettaInUnGiornoEUnoSlot() async throws {
    let transport = TransportFinto(.risposta(200, "{}"))
    try await APIClient(transport: transport).programmaRicetta("r1", giorno: "2026-11-16", slot: "dinner")
    #expect(transport.richiesta?.httpMethod == "PUT")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/plans")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(json["date"] as? String == "2026-11-16")
    #expect(json["slot"] as? String == "dinner")
    let voci = try #require(json["items"] as? [[String: Any]])
    #expect(voci.first?["recipeId"] as? String == "r1")
  }

  @Test func laRicettaInSpesaAggiungeUnaVocePerIngredienteSalvoQuelliEliminati() async throws {
    let transport = TransportFinto(
      .risposta(
        200,
        #"{"id":"s1","foodId":null,"name":"Pasta","grams":null,"text":"160 g","checked":false,"source":"manual"}"#
      ))
    let aggiunte = try await APIClient(transport: transport).ricettaInSpesa(try RicetteTests.ricetta())
    // Il pomodoro è stato eliminato dal catalogo: resta fuori.
    #expect(aggiunte == 1)
    #expect(transport.invii == 1)
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/shopping")
  }
}
