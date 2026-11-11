import Foundation
import Testing

@testable import Ron1nKit

@Suite struct DietaTests {
  let giorno = """
    {"date":"2026-10-23","goal":{"kcal":2000,"protein":140,"carbs":220,"fat":70,"waterMl":null},
     "quota":{"kcal":2200,"baseKcal":2000,"activityKcal":200},
     "totals":{"kcal":1450,"protein":82.4,"carbs":160,"fat":51.6},"plannedKcal":0,"slots":[],
     "suggestedSlot":"dinner","nextSlot":null,"waterMl":0,"caffeine":null,"supplements":[]}
    """

  @Test func leggeIlGiorno() async throws {
    let transport = TransportFinto(.risposta(200, giorno))
    let dieta = try await APIClient(transport: transport).dieta()
    #expect(transport.richiesta?.url?.absoluteString == "https://home.ron1n.space/api/v1/nutrition/day")
    #expect(dieta.testoKcal == "1.450 / 2.200 kcal")
    #expect(dieta.testoRimanenti == "750 kcal rimanenti")
    #expect(dieta.avanzamento == 1450.0 / 2200.0)
    #expect(!dieta.oltre)
    #expect(dieta.macro.map(\.testo) == ["82 / 140 g", "160 / 220 g", "52 / 70 g"])
  }

  @Test func senzaObiettivo() async throws {
    let corpo = """
      {"date":"2026-10-23","goal":null,"quota":null,
       "totals":{"kcal":900,"protein":40,"carbs":100,"fat":30}}
      """
    let dieta = try await APIClient(transport: TransportFinto(.risposta(200, corpo))).dieta()
    #expect(dieta.testoKcal == "900 kcal")
    #expect(dieta.testoRimanenti == nil)
    #expect(dieta.avanzamento == nil)
    #expect(dieta.macro.first?.testo == "40 g")
  }

  @Test func oltreLaQuota() {
    let dieta = GiornoDieta(
      date: "2026-10-23", totals: Macro(kcal: 2300, protein: 0, carbs: 0, fat: 0),
      quota: .init(kcal: 2200))
    #expect(dieta.oltre)
    #expect(dieta.avanzamento == 1)
    #expect(dieta.testoRimanenti == "100 kcal oltre")
  }

  @Test func moduloSpento() async {
    let transport = TransportFinto(.risposta(404, #"{"error":"module_disabled"}"#))
    let client = APIClient(transport: transport)
    #expect(await Carico.da { try await client.dieta() } == .spento)
  }

  @Test func errore() async {
    let client = APIClient(transport: TransportFinto(.risposta(503, "{}")))
    #expect(await Carico.da { try await client.dieta() } == .fallito(.stato(503)))
  }
}

@Suite struct FormatoTests {
  @Test(arguments: [
    (0.0, 0, "0"), (999, 0, "999"), (1450, 0, "1.450"), (1_234_567, 0, "1.234.567"),
    (2.45, 1, "2,5"), (12.04, 1, "12,0"), (-3.2, 1, "−3,2"), (1500.5, 1, "1.500,5"),
  ])
  func numeri(valore: Double, decimali: Int, atteso: String) {
    #expect(Formato.numero(valore, decimali: decimali) == atteso)
  }

  @Test func velocita() {
    #expect(Formato.velocita(0) == "0 kB/s")
    #expect(Formato.velocita(512_000) == "512 kB/s")
    #expect(Formato.velocita(2_400_000) == "2,4 MB/s")
  }

  @Test func tempi() {
    #expect(Formato.acceso(5 * 3_600) == "5 h")
    #expect(Formato.acceso(3 * 86_400) == "3 g")
    #expect(Formato.rimanente(nil) == "tempo non stimabile")
    #expect(Formato.rimanente(30) == "meno di 1 min")
    #expect(Formato.rimanente(600) == "10 min")
    #expect(Formato.rimanente(3_900) == "1 h 5 min")
    #expect(Formato.percento(41.6) == "42%")
  }
}

@Suite struct GiornoCompletoTests {
  static let corpo = """
    {"date":"2026-10-27","goal":{"kcal":2200,"protein":140,"carbs":240,"fat":70,"waterMl":2500},
     "quota":{"kcal":2350,"baseKcal":2200,"activityKcal":150},
     "totals":{"kcal":1450,"protein":82,"carbs":150,"fat":45},
     "plannedKcal":620,"suggestedSlot":"afternoon_snack","nextSlot":"dinner","waterMl":1500,
     "caffeine":{"totalMg":180,"mealsMg":60},
     "supplements":[{"id":"a","name":"Vitamina D","dose":"1","schedule":"daily","taken":true}],
     "slots":[
       {"slot":"breakfast","state":"eaten","planned":null,
        "meal":{"id":"m1","kcal":430,"protein":20,"carbs":50,"fat":12,
          "items":[{"id":"r1","foodId":"f1","name":"Pane","grams":80,"kcal":210,"protein":7,
            "carbs":40,"fat":1,"origin":"ron1nos","sync":"synced"},
            {"id":"r2","foodId":null,"name":"Uova","grams":120,"kcal":220,"protein":13,"carbs":1,
             "fat":11,"origin":"ron1nos","sync":"unmatched"}]}},
       {"slot":"morning_snack","state":"skipped","planned":null,"meal":null},
       {"slot":"lunch","state":"empty","planned":null,"meal":null},
       {"slot":"dinner","state":"planned","meal":null,
        "planned":{"id":"p1","status":"planned","kcal":620,"protein":40,"carbs":60,"fat":20,
          "recipeId":null,"recipeName":"Pasta al pomodoro","templateName":null,"items":[]}}
     ]}
    """

  @Test func leggeIlGiornoDiUnaData() async throws {
    let transport = TransportFinto(.risposta(200, GiornoCompletoTests.corpo))
    let giorno = try await APIClient(transport: transport).dieta("2026-10-27")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/day")
    #expect(transport.richiesta?.url?.query == "date=2026-10-27")
    #expect(giorno.plannedKcal == 620)
    #expect(giorno.suggestedSlot == "afternoon_snack")
    #expect(giorno.waterMl == 1500)
    #expect(giorno.caffeine?.totalMg == 180)
    #expect(giorno.kcalObiettivo == 2350)
  }

  @Test func cinqueSlotSempreNellOrdineDelSito() throws {
    let giorno = try JSONDecoder().decode(GiornoDieta.self, from: Data(GiornoCompletoTests.corpo.utf8))
    let slot = giorno.slotInOrdine
    #expect(slot.map(\.slot) == GiornoDieta.ordineSlot)
    #expect(slot.map(\.titolo) == ["Colazione", "Spuntino", "Pranzo", "Merenda", "Cena"])
    // La merenda non c'è nella risposta: vale vuota.
    #expect(slot[3].vuoto)
    #expect(slot[1].saltato)
    #expect(slot[0].mangiato)
    #expect(slot[0].kcal == 430)
    #expect(slot[0].elenco == "Pane 80 g · Uova 120 g")
    #expect(slot[4].kcal == 620)
    #expect(slot[4].elenco == "Pasta al pomodoro")
    #expect(slot[4].planned?.id == "p1")
    #expect(slot[2].elenco == nil)
  }

  @Test func statoVersoYazioDiOgniRiga() throws {
    let giorno = try JSONDecoder().decode(GiornoDieta.self, from: Data(GiornoCompletoTests.corpo.utf8))
    let righe = try #require(giorno.slotInOrdine.first?.meal?.items)
    #expect(righe.map(\.sync) == ["synced", "unmatched"])
    #expect(righe[0].statoYazio == "Inviata a YAZIO")
    #expect(righe[1].statoYazio == "Senza equivalente su YAZIO")
    #expect(RigaPasto(id: "x", name: "Mela", grams: 100, kcal: 52).statoYazio == nil)
  }

  @Test func segnaUnPianoMangiato() async throws {
    let transport = TransportFinto(.risposta(200, "{}"))
    try await APIClient(transport: transport).statoPiano("p1", "eaten")
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.httpMethod == "PUT")
    #expect(richiesta.url?.path == "/api/v1/nutrition/plans/p1/status")
    let corpo = try #require(richiesta.httpBody)
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"status":"eaten"}"#)
  }

  @Test func unErroreArrivaAChiChiama() async {
    let transport = TransportFinto(.risposta(503, #"{"error":"database_unavailable"}"#))
    await #expect(throws: APIError.self) {
      try await APIClient(transport: transport).statoPiano("p1", "eaten")
    }
  }
}
