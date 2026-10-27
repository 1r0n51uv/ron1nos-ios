import Foundation
import Testing

@testable import Ron1nKit

@Suite struct StoricoTests {
  static let pagina = """
    {"sessions":[
      {"id":"s2","day":"2026-10-26","routine":"Push","startedAt":"2026-10-26T17:00:00Z",
       "durationSeconds":3900,
       "exercises":[{"name":"Panca piana","image":null},{"name":"Croci","image":null}]},
      {"id":"s1","day":"2026-10-20","routine":"","startedAt":"2026-10-20T17:00:00Z","durationSeconds":null,
       "exercises":[]}
    ],"nextCursor":"c2"}
    """

  @Test func unaPaginaDelloStorico() async throws {
    let transport = TransportFinto(.risposta(200, StoricoTests.pagina))
    let pagina = try await APIClient(transport: transport).sessioniPalestra(routine: "Push", cursore: "c1")
    let url = try #require(transport.richiesta?.url)
    #expect(url.path == "/api/v1/workout/sessions")
    #expect(url.query == "routine=Push&cursor=c1")
    #expect(pagina.sessions.map(\.titolo) == ["Push", "Allenamento"])
    let sottotitoli = pagina.sessions.map { $0.sottotitolo(oggi: "2026-10-27") }
    #expect(sottotitoli == ["ieri · 1 h 05 min", "martedì 20 ottobre"])
    #expect(pagina.sessions[0].exercises.map(\.name) == ["Panca piana", "Croci"])
  }

  @Test func loStoricoSiAllungaAPagine() {
    var storico = StoricoPalestra()
    #expect(!storico.finito)
    storico.aggiungi(
      PaginaSessioni(
        sessions: [SessionePalestra(id: "a", day: "2026-10-26", routine: "Push")], nextCursor: "c"))
    #expect(storico.cursore == "c")
    #expect(storico.chiedeAltre(storico.sessioni[0]))
    storico.aggiungi(
      PaginaSessioni(sessions: [
        SessionePalestra(id: "a", day: "2026-10-26", routine: "Push"),
        SessionePalestra(id: "b", day: "2026-10-20", routine: "Pull"),
      ]))
    #expect(storico.sessioni.map(\.id) == ["a", "b"])
    #expect(storico.finito)
    #expect(!storico.chiedeAltre(storico.sessioni[1]))
    storico.togli("a")
    #expect(storico.sessioni.map(\.id) == ["b"])
  }

  @Test func leRoutine() async throws {
    let transport = TransportFinto(.risposta(200, #"{"routines":["Push","Pull"]}"#))
    let routine = try await APIClient(transport: transport).routinePalestra()
    #expect(transport.richiesta?.url?.path == "/api/v1/workout/routines")
    #expect(routine == ["Push", "Pull"])
  }

  @Test func ilDettaglio() async throws {
    let json = """
      {"id":"s2","day":"2026-10-26","routine":"Push","startedAt":"2026-10-26T17:00:00Z",
       "durationSeconds":3900,"volumeKg":4200,"exercises":[
        {"name":"Panca piana","key":"panca piana","image":null,"timed":false,"volumeKg":3200,"record":true,
         "sets":[{"index":0,"warmup":true,"weightKg":40,"reps":10,"durationSeconds":null},
                 {"index":1,"warmup":false,"weightKg":82.5,"reps":8,"durationSeconds":null}]},
        {"name":"Trazioni","key":"trazioni","image":null,"timed":false,"volumeKg":1000,"record":false,
         "sets":[{"index":0,"warmup":false,"weightKg":0,"reps":12,"durationSeconds":null}]},
        {"name":"Plank","key":"plank","image":null,"timed":true,"volumeKg":0,"record":false,
         "sets":[{"index":0,"warmup":false,"weightKg":0,"reps":null,"durationSeconds":90},
                 {"index":1,"warmup":false,"weightKg":10,"reps":null,"durationSeconds":45}]}
      ]}
      """
    let transport = TransportFinto(.risposta(200, json))
    let sessione = try await APIClient(transport: transport).sessionePalestra("s2")
    #expect(transport.richiesta?.url?.path == "/api/v1/workout/sessions/s2")
    #expect(sessione.titolo == "Push")
    #expect(sessione.barre.map(\.key) == ["panca piana", "trazioni"])
    #expect(sessione.piuPesante == "panca piana")
    #expect(sessione.quota(sessione.exercises[1]) == 1000.0 / 3200.0)
    let serie = sessione.exercises.flatMap(\.sets).map { $0.testo() }
    #expect(serie == ["40 kg × 10", "82,5 kg × 8", "× 12", "1:30", "10 kg · 45 s"])
    #expect(sessione.exercises[0].sets[0].warmup)
  }

  @Test func eliminaUnaSessione() async throws {
    let transport = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: transport).eliminaSessione("s2")
    #expect(transport.richiesta?.httpMethod == "DELETE")
    #expect(transport.richiesta?.url?.path == "/api/v1/workout/sessions/s2")
  }
}
