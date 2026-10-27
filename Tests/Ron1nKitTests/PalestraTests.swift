import Foundation
import Testing

@testable import Ron1nKit

@Suite struct PalestraTests {
  static let riepilogo = """
    {"today":"2026-10-27","thisWeek":2,"streakDays":3,
     "last":{"id":"s1","day":"2026-10-26","routine":"Push","startedAt":"2026-10-26T17:00:00Z",
      "durationSeconds":3900,
      "exercise":{"name":"Panca piana","image":{"catalogId":"Barbell_Bench_Press","source":"dictionary",
       "url":"/api/v1/workout/catalog/images/Barbell_Bench_Press/0.jpg"}}},
     "weeks":[{"monday":"2026-10-19","count":3},{"monday":"2026-10-26","count":2}]}
    """

  @Test func ultimoAllenamentoConLaFoto() throws {
    let json = Data(PalestraTests.riepilogo.utf8)
    let riepilogo = try JSONDecoder().decode(RiepilogoAllenamento.self, from: json)
    let ultimo = try #require(riepilogo.last)
    #expect(ultimo.id == "s1")
    #expect(ultimo.exercise?.name == "Panca piana")
    #expect(ultimo.exercise?.image?.percorso == "workout/catalog/images/Barbell_Bench_Press/0.jpg")
    #expect(riepilogo.testoUltimo == "Push · ieri · 1 h 05 min")
    #expect(riepilogo.ultime12.map(\.count) == [3, 2])
    #expect(!riepilogo.vuoto)

    let nuovo = RiepilogoAllenamento(
      today: "2026-10-27", last: nil, thisWeek: 0, streakDays: 0,
      weeks: [RiepilogoAllenamento.Settimana(monday: "2026-10-26", count: 0)])
    #expect(nuovo.vuoto)
  }

  @Test func percorsoDellaFoto() {
    let atteso = "workout/catalog/images/a/0.jpg"
    #expect(ImmagineEsercizio.percorso("/api/v1/workout/catalog/images/a/0.jpg") == atteso)
    #expect(ImmagineEsercizio.percorso("workout/catalog/images/a/0.jpg") == atteso)
  }

  @Test func iPiuAllenati() async throws {
    let elenco = """
      {"exercises":[
        {"name":"Panca piana","key":"panca piana","image":null,"group":"petto","timed":false,"sets":120,
         "sessions":40,"lastDay":"2026-10-26","best1RMKg":102.5,"bestDurationSeconds":null,"trend":[95,100]},
        {"name":"Plank","key":"plank","image":null,"group":null,"timed":true,"sets":30,"sessions":10,
         "lastDay":"2026-10-20","best1RMKg":null,"bestDurationSeconds":90,"trend":[60,90]}
      ]}
      """
    let transport = TransportFinto(.risposta(200, elenco))
    let esercizi = try await APIClient(transport: transport).eserciziPalestra(piuAllenati: true, limite: 6)
    let url = try #require(transport.richiesta?.url)
    #expect(url.path == "/api/v1/workout/exercises")
    #expect(url.query == "sort=sets&limit=6")
    #expect(esercizi.map { $0.migliore() } == ["1RM 102,5 kg", "1:30"])
    #expect(esercizi.map(\.nomeGruppo) == ["Petto", "Da assegnare"])

    let cerca = TransportFinto(.risposta(200, #"{"exercises":[]}"#))
    _ = try await APIClient(transport: cerca).eserciziPalestra(cerca: " panca ", daCompletare: true)
    #expect(cerca.richiesta?.url?.query == "q=panca&incomplete=true")
  }

  @Test func record() async throws {
    let elenco = """
      {"records":[
        {"kind":"e1rm","value":102.5,"weightKg":null,"day":"2026-10-26","sessionId":"s1",
         "exercise":{"name":"Panca piana","key":"panca piana","image":null}},
        {"kind":"reps","value":8,"weightKg":80,"day":"2026-10-20","sessionId":"s2",
         "exercise":{"name":"Squat","key":"squat","image":null}}
      ]}
      """
    let transport = TransportFinto(.risposta(200, elenco))
    let record = try await APIClient(transport: transport).recordPalestra()
    #expect(transport.richiesta?.url?.query == "days=30&limit=3")
    #expect(record.map { $0.testo() } == ["1RM stimato · 102,5 kg", "8 ripetizioni a 80 kg"])
    let durata = RecordPalestra(kind: "duration", value: 75, day: "2026-10-01", sessionId: "s")
    #expect(durata.testo() == "Durata · 1:15")
    let peso = RecordPalestra(kind: "weight", value: 100, day: "2026-10-01", sessionId: "s")
    #expect(peso.testo(Formati(weightUnit: .lb)) == "Peso più alto · 220,5 lb")
  }

  @Test func tempi() {
    #expect(Palestra.tempo(45) == "45 s")
    #expect(Palestra.tempo(90) == "1:30")
    #expect(Palestra.tempo(725) == "12:05")
  }
}
