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
