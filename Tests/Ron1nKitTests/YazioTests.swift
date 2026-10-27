import Foundation
import Testing

@testable import Ron1nKit

@Suite struct YazioTests {
  static let collegamento = """
    {"configured":true,"state":"connected","error":null,"lastSyncAt":"2026-10-27T13:05:00.000Z",
     "syncEnabled":true,"queue":2,"unmatched":1,
     "imported":{"goal":null,"activityKcal":320,"weight":{"day":"2026-10-27","kg":92.5}}}
    """

  @Test func statoDelCollegamento() async throws {
    let transport = TransportFinto(.risposta(200, YazioTests.collegamento))
    let collegamento = try await APIClient(transport: transport).collegamentoYazio()
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/yazio")
    #expect(collegamento.testoStato == "Collegato")
    #expect(collegamento.unmatched == 1)
    #expect(!collegamento.inErrore)

    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    // 13:05 UTC sono le 14:05 a Roma.
    let dopo = try #require(CollegamentoYazio.istante("2026-10-27T13:17:30Z"))
    #expect(collegamento.testoUltimaSincronizzazione(adesso: dopo, fuso: fuso) == "12 min fa")
    let sera = try #require(CollegamentoYazio.istante("2026-10-27T19:00:00Z"))
    #expect(collegamento.testoUltimaSincronizzazione(adesso: sera, fuso: fuso) == "oggi alle 14:05")
    let domani = try #require(CollegamentoYazio.istante("2026-10-28T09:00:00Z"))
    #expect(collegamento.testoUltimaSincronizzazione(adesso: domani, fuso: fuso) == "27/10 alle 14:05")
  }

  @Test func statiDiversi() {
    let spento = CollegamentoYazio(configured: false, state: "disconnected", syncEnabled: false)
    #expect(spento.testoStato == "Non configurato")
    #expect(spento.testoUltimaSincronizzazione() == "Mai")
    let pausa = CollegamentoYazio(configured: true, state: "connected", syncEnabled: false)
    #expect(pausa.testoStato == "Collegato · in pausa")
    let errore = CollegamentoYazio(
      configured: true, state: "error", error: "Password errata", syncEnabled: true)
    #expect(errore.testoStato == "Errore")
    #expect(errore.inErrore)
  }

  @Test func accendereESincronizzare() async throws {
    let interruttore = TransportFinto(.risposta(200, YazioTests.collegamento))
    _ = try await APIClient(transport: interruttore).sincronizzazioneYazio(false)
    #expect(interruttore.richiesta?.httpMethod == "PUT")
    #expect(interruttore.richiesta?.url?.path == "/api/v1/nutrition/yazio/sync")
    let corpo = try #require(interruttore.richiesta?.httpBody)
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"enabled":false}"#)

    let giro = TransportFinto(.risposta(200, YazioTests.collegamento))
    _ = try await APIClient(transport: giro).sincronizzaYazio()
    #expect(giro.richiesta?.httpMethod == "POST")
    #expect(giro.richiesta?.url?.path == "/api/v1/nutrition/yazio/sync")
  }

  @Test func alimentiSenzaEquivalente() async throws {
    let elenco = """
      {"foods":[{"food":{"id":"f1","name":"Pane di segale","brand":null,"source":"custom","kcal":265},
       "rows":3,"last":{"day":"2026-10-26","slot":"lunch","grams":120}}]}
      """
    let transport = TransportFinto(.risposta(200, elenco))
    let alimenti = try await APIClient(transport: transport).senzaEquivalente()
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/yazio/unmatched")
    #expect(alimenti.first?.sottotitolo == "3 righe · ultima a Pranzo, 120 g")

    let prodotti = TransportFinto(.risposta(200, #"{"products":[]}"#))
    _ = try await APIClient(transport: prodotti).prodottiYazio("pane")
    #expect(prodotti.richiesta?.url?.query == "q=pane")

    let abbina = TransportFinto(.risposta(200, #"{"foods":[]}"#))
    let resto = try await APIClient(transport: abbina).abbinaYazio("f1", prodotto: nil)
    #expect(abbina.richiesta?.httpMethod == "PUT")
    #expect(abbina.richiesta?.url?.path == "/api/v1/nutrition/foods/f1/yazio")
    let corpo = try #require(abbina.richiesta?.httpBody)
    // Senza prodotto il null va scritto: l'alimento resta solo in ron1nOS.
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"productId":null}"#)
    #expect(resto.isEmpty)
  }

  @Test func obiettivoAMano() async throws {
    let risposta = """
      {"current":{"id":"g1","source":"manual","kcal":1900,"protein":130,"carbs":210,"fat":60,
       "waterMl":2500,"effectiveFrom":"2026-10-01"},"history":[],"editable":true}
      """
    let transport = TransportFinto(.risposta(200, risposta))
    let obiettivi = try await APIClient(transport: transport).obiettiviDieta()
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/goals")
    #expect(obiettivi.editable)
    let corrente = try #require(obiettivi.current)

    var modulo = ModuloObiettivo(corrente)
    #expect(modulo.kcal == "1.900")
    #expect(modulo.acqua == "2.500")
    #expect(modulo.valido)
    modulo.kcal = "500"
    #expect(modulo.problema == "Le kcal vanno da 800 a 8.000.")
    modulo.kcal = "2.000"
    modulo.grassi = ""
    #expect(modulo.problema == "Servono proteine, carboidrati e grassi.")
    modulo.grassi = "62,5"
    modulo.acqua = ""
    #expect(modulo.valido)

    let salvato = """
      {"id":"g2","source":"manual","kcal":2000,"protein":130,"carbs":210,"fat":62.5,"waterMl":null,
       "effectiveFrom":"2026-10-27"}
      """
    let salva = TransportFinto(.risposta(201, salvato))
    let nuovo = try await APIClient(transport: salva).nuovoObiettivo(modulo)
    #expect(salva.richiesta?.httpMethod == "POST")
    let corpo = try #require(salva.richiesta?.httpBody)
    let inviato = try JSONSerialization.jsonObject(with: corpo) as? [String: Double]
    #expect(inviato == ["kcal": 2000, "protein": 130, "carbs": 210, "fat": 62.5])
    #expect(nuovo.fat == 62.5)
  }
}
