import Foundation
import Testing

@testable import Ron1nKit

@Suite struct SpesaTests {
  static let lista = """
    {"items":[
      {"id":"s1","foodId":"f1","name":"Pasta","grams":320,"text":null,"checked":false,
       "source":"generated"},
      {"id":"s2","foodId":null,"name":"Caffè","grams":null,"text":"1 pacco","checked":true,
       "source":"manual"},
      {"id":"s3","foodId":null,"name":"Sale","grams":null,"text":null,"checked":false,
       "source":"manual"}
    ]}
    """

  @Test func laListaConLeQuantita() async throws {
    let transport = TransportFinto(.risposta(200, SpesaTests.lista))
    let lista = try await APIClient(transport: transport).spesa()
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/shopping")
    #expect(lista.items.map(\.quantita) == ["320 g", "1 pacco", nil])
    #expect(lista.items.map(\.dalPiano) == [true, false, false])
    #expect(lista.riepilogo == "2 da prendere · 1 presa")
    #expect(lista.added == nil)

    let presa = VoceSpesa(id: "s1", name: "Pasta", grams: 320, checked: true, source: "generated")
    #expect(lista.sostituendo(presa).spuntate == 2)
    #expect(lista.senza("s2").items.map(\.id) == ["s1", "s3"])
  }

  @Test func aggiungereSpuntareETogliere() async throws {
    let voce =
      #"{"id":"s4","foodId":null,"name":"Uova","grams":null,"text":"6","checked":false,"#
      + #""source":"manual"}"#
    let nuova = TransportFinto(.risposta(201, voce))
    let aggiunta = try await APIClient(transport: nuova).aggiungiSpesa(nome: " Uova ", quantita: "6")
    #expect(nuova.richiesta?.httpMethod == "POST")
    let corpo = try #require(nuova.richiesta?.httpBody)
    let inviato = try JSONSerialization.jsonObject(with: corpo) as? [String: String]
    #expect(inviato == ["name": "Uova", "text": "6"])
    #expect(aggiunta.quantita == "6")

    let senzaQuantita = TransportFinto(.risposta(201, voce))
    _ = try await APIClient(transport: senzaQuantita).aggiungiSpesa(nome: "Uova")
    let vuoto = try #require(senzaQuantita.richiesta?.httpBody)
    #expect(String(decoding: vuoto, as: UTF8.self) == #"{"name":"Uova"}"#)

    let spunta = TransportFinto(.risposta(200, voce))
    _ = try await APIClient(transport: spunta).spunta("s4", true)
    #expect(spunta.richiesta?.httpMethod == "PATCH")
    #expect(spunta.richiesta?.url?.path == "/api/v1/nutrition/shopping/s4")
    let spuntaCorpo = try #require(spunta.richiesta?.httpBody)
    #expect(String(decoding: spuntaCorpo, as: UTF8.self) == #"{"checked":true}"#)

    let elimina = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: elimina).eliminaVoceSpesa("s4")
    #expect(elimina.richiesta?.httpMethod == "DELETE")
    #expect(elimina.richiesta?.url?.path == "/api/v1/nutrition/shopping/s4")

    let togli = TransportFinto(.risposta(200, #"{"items":[],"removed":3}"#))
    let dopo = try await APIClient(transport: togli).togliSpuntate()
    #expect(togli.richiesta?.url?.path == "/api/v1/nutrition/shopping/checked")
    #expect(dopo.removed == 3)
  }

  @Test func generaSuUnIntervallo() async throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let oggi = try #require(calendario.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 9)))
    let settimana = IntervalloSpesa.prossimi(7, da: oggi, fuso: fuso)
    #expect(settimana.inizio == "2026-10-27")
    #expect(settimana.fine == "2026-11-02")
    #expect(settimana.giorni == 7)
    #expect(settimana.problema == nil)

    let transport = TransportFinto(.risposta(200, #"{"items":[],"added":5}"#))
    let lista = try await APIClient(transport: transport).generaSpesa(settimana)
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/shopping/generate")
    let corpo = try #require(transport.richiesta?.httpBody)
    let inviato = try JSONSerialization.jsonObject(with: corpo) as? [String: String]
    #expect(inviato == ["from": "2026-10-27", "to": "2026-11-02"])
    #expect(lista.added == 5)
  }

  @Test func intervalloNonValido() throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    let oggi = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(IntervalloSpesa.prossimi(31, da: oggi, fuso: fuso).problema == nil)
    #expect(IntervalloSpesa.prossimi(32, da: oggi, fuso: fuso).problema == "Al massimo 31 giorni.")
    let indietro = IntervalloSpesa(da: oggi, a: oggi.addingTimeInterval(-86_400 * 2), fuso: fuso)
    #expect(indietro.problema == "La fine viene prima dell'inizio.")
  }
}
