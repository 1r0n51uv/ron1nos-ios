import Foundation
import Testing

@testable import Ron1nKit

@Suite struct AndamentoTests {
  static let report = """
    {"days":30,"from":"2026-09-28","to":"2026-10-27",
     "series":[
       {"date":"2026-10-26","kcal":1820,"protein":120,"carbs":200,"fat":60,"logged":true,
        "goalKcal":1900},
       {"date":"2026-10-27","kcal":0,"protein":0,"carbs":0,"fat":0,"logged":false,"goalKcal":1900}
     ],
     "averageKcal":1840,"trendKcalPerWeek":-85.4,
     "adherence":{"inTarget":18,"total":22,"pct":82},
     "macros":{"protein":118,"carbs":205,"fat":58},"goal":{"protein":130,"carbs":210,"fat":60},
     "weight":{"points":[{"date":"2026-10-01","kg":93.7},{"date":"2026-10-27","kg":92.5}],
      "first":93.7,"last":92.5,"delta":-1.2}}
    """

  @Test func leggeIlReport() async throws {
    let transport = TransportFinto(.risposta(200, AndamentoTests.report))
    let andamento = try await APIClient(transport: transport).andamentoDieta(giorni: 90)
    let url = try #require(transport.richiesta?.url)
    #expect(url.path == "/api/v1/nutrition/report")
    #expect(url.query == "days=90")
    #expect(andamento.registrati.map(\.date) == ["2026-10-26"])
    #expect(andamento.testoAderenza == "18 giorni su 22 · 82%")
    #expect(andamento.testoTendenza() == "−85 kcal a settimana")
    #expect(andamento.testoPeso() == "−1,2 kg nel periodo")
    #expect(andamento.weight.points.count == 2)
    #expect(andamento.macros?.protein == 118)
  }

  @Test func senzaDati() throws {
    let vuoto = """
      {"days":30,"from":"2026-09-28","to":"2026-10-27","series":[],"averageKcal":null,
       "trendKcalPerWeek":null,"adherence":{"inTarget":0,"total":0,"pct":null},"macros":null,
       "goal":null,"weight":{"points":[],"first":null,"last":null,"delta":null}}
      """
    let andamento = try JSONDecoder().decode(AndamentoDieta.self, from: Data(vuoto.utf8))
    #expect(andamento.testoAderenza == "—")
    #expect(andamento.testoTendenza() == "—")
    #expect(andamento.testoPeso() == "—")
    #expect(andamento.registrati.isEmpty)
  }

  @Test func tendenzaInKJ() throws {
    let andamento = try JSONDecoder().decode(AndamentoDieta.self, from: Data(AndamentoTests.report.utf8))
    let formati = Formati(energyUnit: .kJ)
    #expect(andamento.testoTendenza(formati) == "−357 kJ a settimana")
  }

  @Test func laDataDelGrafico() throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    let data = try #require(AndamentoDieta.data("2026-10-25", fuso: fuso))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    #expect(Striscia.testo(data, calendario: calendario) == "2026-10-25")
    #expect(AndamentoDieta.data("ieri") == nil)
  }
}
