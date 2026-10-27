import Foundation
import Testing

@testable import Ron1nKit

@Suite struct EserciziTests {
  static let panca = """
    {"name":"Panca piana","key":"panca piana","image":null,"group":"petto","timed":false,
     "best1RMKg":102.5,"heaviestKg":90,"bestDurationSeconds":null,"sessions":40,"range":"3m",
     "points":[
       {"sessionId":"a","day":"2026-10-20","best1RMKg":100,"volumeKg":3000,"bestDurationSeconds":0,
        "totalDurationSeconds":0},
       {"sessionId":"b","day":"2026-10-26","best1RMKg":102.5,"volumeKg":3200,"bestDurationSeconds":0,
        "totalDurationSeconds":0}],
     "records":[{"kind":"e1rm","value":102.5,"weightKg":null,"day":"2026-10-26","sessionId":"b"}],
     "recent":[{"sessionId":"b","day":"2026-10-26","best1RMKg":102.5,
       "sets":[{"warmup":true,"weightKg":40,"reps":10,"durationSeconds":null},
               {"warmup":false,"weightKg":90,"reps":4,"durationSeconds":null}]}]}
    """

  @Test func laPaginaDellEsercizio() async throws {
    let transport = TransportFinto(.risposta(200, EserciziTests.panca))
    let esercizio = try await APIClient(transport: transport).esercizioPalestra("Panca piana", periodo: .tre)
    let url = try #require(transport.richiesta?.url)
    #expect(url.path(percentEncoded: true) == "/api/v1/workout/exercises/Panca%20piana")
    #expect(url.query == "range=3m")
    #expect(esercizio.numeri().map(\.valore) == ["102,5 kg", "90 kg", "40"])
    #expect(esercizio.numeri().map(\.titolo) == ["1RM STIMATO", "PESO PIÙ ALTO", "SESSIONI"])
    #expect(esercizio.valori(.migliore) == [100, 102.5])
    #expect(esercizio.valori(.totale) == [3000, 3200])
    #expect(esercizio.records.map { $0.testo() } == ["1RM stimato · 102,5 kg"])
    #expect(esercizio.recent[0].sets.map { $0.testo() } == ["40 kg × 10", "90 kg × 4"])
    #expect(esercizio.nomeGruppo == "Petto")
  }

  @Test func unEsercizioATempo() {
    let punto = DettaglioEsercizio.Punto(
      sessionId: "a", day: "2026-10-26", bestDurationSeconds: 60, totalDurationSeconds: 150)
    let plank = DettaglioEsercizio(
      name: "Plank", key: "plank", timed: true, bestDurationSeconds: 90, sessions: 10, points: [punto])
    #expect(plank.numeri().map(\.valore) == ["1:30", "10"])
    #expect(plank.valori(.totale) == [150])
    #expect(DettaglioEsercizio.Grafico.migliore.titolo(aTempo: true) == "Durata migliore")
    #expect(DettaglioEsercizio.Grafico.totale.titolo(aTempo: false) == "Volume")
  }

  @Test func unNomeConLaBarraRestaUnSegmento() async throws {
    let transport = TransportFinto(.risposta(200, EserciziTests.panca))
    _ = try await APIClient(transport: transport).esercizioPalestra("Lat machine / presa 50%")
    let url = try #require(transport.richiesta?.url)
    #expect(url.path(percentEncoded: true) == "/api/v1/workout/exercises/Lat%20machine%20%2F%20presa%2050%25")
  }

  @Test func daCompletare() {
    let senzaGruppo = EsercizioPalestra(name: "A", key: "a", image: nil, group: nil, lastDay: "2026-10-26")
    let completo = EsercizioPalestra(
      name: "B", key: "b", image: ImmagineEsercizio(catalogId: "x", url: "u"), group: "petto",
      lastDay: "2026-10-26")
    #expect(senzaGruppo.daCompletare)
    #expect(!completo.daCompletare)
  }
}
