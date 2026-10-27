import Foundation
import Testing

@testable import Ron1nKit

@Suite struct TemplateTests {
  static let elenco = """
    {"templates":[{"id":"t1","name":"Settimana tipo","dayKcal":[1800,1750,0,0,0,0,0],
     "cells":[
       {"weekday":1,"slot":"lunch","recipeId":"r1","foodId":null,"grams":null,
        "name":"Pasta al pomodoro","kcal":620},
       {"weekday":1,"slot":"breakfast","recipeId":null,"foodId":"f1","grams":120,
        "name":"Yogurt","kcal":110},
       {"weekday":2,"slot":"dinner","recipeId":null,"foodId":"f2","grams":200,"name":"Salmone",
        "kcal":410}
     ]}]}
    """

  @Test func elencoEGriglia() async throws {
    let transport = TransportFinto(.risposta(200, TemplateTests.elenco))
    let elenco = try await APIClient(transport: transport).template()
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/templates")
    let template = try #require(elenco.first)
    #expect(template.sottotitolo == "2 giorni · 3 pasti")
    #expect(template.kcal(giorno: 1) == 1800)
    #expect(template.kcal(giorno: 9) == 0)

    let lunedi = template.slot(giorno: 1)
    #expect(lunedi.map(\.slot) == GiornoDieta.ordineSlot)
    #expect(lunedi.map { $0.cella?.name } == ["Yogurt", nil, "Pasta al pomodoro", nil, nil])
    #expect(lunedi[0].cella?.dettaglio == "120 g")
    #expect(lunedi[2].cella?.dettaglio == "Ricetta")
    #expect(template.slot(giorno: 3).allSatisfy { $0.cella == nil })
  }

  @Test func applicaUnaSettimana() async throws {
    let transport = TransportFinto(.risposta(200, #"{"created":4,"replaced":2,"kept":1}"#))
    let esito = try await APIClient(transport: transport).applicaTemplate("t1", lunedi: "2026-11-02")
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/templates/t1/apply")
    let corpo = try #require(transport.richiesta?.httpBody)
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"monday":"2026-11-02"}"#)
    #expect(esito.testo == "4 pasti creati · 2 sostituiti · 1 lasciato com'era")
    #expect(EsitoTemplate(created: 1, replaced: 0, kept: 0).testo == "1 pasto creato · 0 sostituiti")
  }

  @Test func eliminaUnTemplate() async throws {
    let transport = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: transport).eliminaTemplate("t1")
    #expect(transport.richiesta?.httpMethod == "DELETE")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/templates/t1")
  }

  @Test func ilLunediDellaSettimana() throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    // Martedì 27 ottobre 2026, alle 23:30 di Roma.
    let martedi = try #require(
      calendario.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 23, minute: 30)))
    #expect(Settimana.lunedi(di: martedi, fuso: fuso) == "2026-10-26")
    #expect(Settimana.lunedi(di: martedi, piu: 1, fuso: fuso) == "2026-11-02")
    #expect(Settimana.giorno(di: martedi, fuso: fuso) == 2)
    // La domenica appartiene alla settimana che finisce, non a quella dopo.
    let domenica = try #require(calendario.date(from: DateComponents(year: 2026, month: 11, day: 1)))
    #expect(Settimana.lunedi(di: domenica, fuso: fuso) == "2026-10-26")
    #expect(Settimana.giorno(di: domenica, fuso: fuso) == 7)
    let lunedi = try #require(calendario.date(from: DateComponents(year: 2026, month: 10, day: 26)))
    #expect(Settimana.lunedi(di: lunedi, fuso: fuso) == "2026-10-26")
    #expect(Settimana.giorno(di: lunedi, fuso: fuso) == 1)
  }
}
