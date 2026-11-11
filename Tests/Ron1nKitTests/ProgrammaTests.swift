import Foundation
import Testing

@testable import Ron1nKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite struct ProgrammaTests {
  static let settimana = """
    {"from":"2026-10-26","days":[
      {"date":"2026-10-26","quota":{"kcal":2100},"totals":{"kcal":500,"protein":30,"carbs":60,"fat":10},
       "plannedKcal":620,"slots":[
        {"slot":"breakfast","state":"eaten","kcal":480,"plan":{"id":"p0","status":"eaten","recipeId":"r0","name":"Yogurt"}},
        {"slot":"morning_snack","state":"empty","kcal":0,"plan":null},
        {"slot":"lunch","state":"planned","kcal":620,"plan":{"id":"p1","status":"planned","recipeId":"r1","name":"Pasta al pomodoro"}},
        {"slot":"afternoon_snack","state":"skipped","kcal":90,"plan":{"id":"p2","status":"skipped","recipeId":null,"name":"Mela"}},
        {"slot":"dinner","state":"empty","kcal":0,"plan":null}]}]}
    """

  /// Il corpo JSON di una richiesta.
  func corpo(_ richiesta: URLRequest?) throws -> [String: Any] {
    let dati = try #require(richiesta?.httpBody)
    return try #require(try JSONSerialization.jsonObject(with: dati) as? [String: Any])
  }

  // MARK: - settimana

  @Test func leggeLaSettimana() async throws {
    let transport = TransportFinto(.risposta(200, ProgrammaTests.settimana))
    let settimana = try await APIClient(transport: transport).settimana(da: "2026-10-26")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/week")
    #expect(transport.richiesta?.url?.query == "from=2026-10-26")
    #expect(settimana.days.count == 1)
    let giorno = settimana.days[0]
    #expect(giorno.slots.map(\.slot) == GiornoDieta.ordineSlot)
    #expect(giorno.slots[2].plan == .init(id: "p1", recipeId: "r1", name: "Pasta al pomodoro"))
    #expect(giorno.slots[1].plan == nil)
    #expect(giorno.kcal == 480 + 620 + 90)
    #expect(giorno.slots[0].titolo == "Colazione")
  }

  @Test func settimanaCorrenteSenzaData() async throws {
    let transport = TransportFinto(.risposta(200, ProgrammaTests.settimana))
    _ = try await APIClient(transport: transport).settimana()
    #expect(transport.richiesta?.url?.query == nil)
  }

  // MARK: - stato di un pasto

  static let viste: [(String, String, VistaPasto)] = [
    ("eaten", "2026-10-20", VistaPasto.mangiato),
    ("eaten", "2026-11-20", VistaPasto.mangiato),
    ("skipped", "2026-11-20", VistaPasto.saltato),
    ("planned", "2026-10-26", VistaPasto.saltato),
    ("planned", "2026-10-27", VistaPasto.pianificato),
    ("planned", "2026-12-01", VistaPasto.pianificato),
    ("empty", "2026-10-26", VistaPasto.vuoto),
  ]

  @Test(arguments: ProgrammaTests.viste)
  func vistaDelPasto(stato: String, giorno: String, atteso: VistaPasto) {
    // Oggi è il 27 ottobre: il pasto non spuntato di ieri è saltato, quello di oggi e di domani no.
    #expect(VistaPasto.da(stato: stato, giorno: giorno, oggi: "2026-10-27") == atteso)
  }

  @Test func laVistaVaAncheSuiPastiESuiSlot() {
    let pasto = PastoSettimana(slot: "lunch", state: "planned")
    #expect(pasto.vista(giorno: "2026-10-26", oggi: "2026-10-27") == .saltato)
    let slot = SlotGiorno(slot: "lunch", state: "planned")
    #expect(slot.vista(giorno: "2026-10-27", oggi: "2026-10-27") == .pianificato)
    #expect(VistaPasto.saltato.testo == "Saltato")
  }

  // MARK: - slot corrente

  static let orari: [(Int, String)] = [
    (300, "breakfast"),
    (450, "breakfast"),
    (629, "breakfast"),
    (630, "morning_snack"),
    (780, "lunch"),
    (1_005, "afternoon_snack"),
    (1_200, "dinner"),
    (1_439, "dinner"),
  ]

  @Test(arguments: ProgrammaTests.orari)
  func slotCorrente(minuti: Int, atteso: String) {
    #expect(Promemoria.predefiniti.slotCorrente(minuti: minuti) == atteso)
  }

  @Test func slotCorrenteConOrariPersonali() {
    let orari = Promemoria(meals: ["breakfast": "09:00", "lunch": "14:00"], water: [])
    #expect(orari.slotCorrente(minuti: 8 * 60) == "breakfast")
    #expect(orari.slotCorrente(minuti: 14 * 60) == "lunch")
  }

  @Test func minutiNelFusoDiRoma() throws {
    // 10:30 UTC il 21 ottobre sono le 12:30 a Roma (ora legale).
    let adesso = Date(timeIntervalSince1970: 1_792_578_600)
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let parti = calendario.dateComponents([.hour, .minute], from: adesso)
    #expect(Promemoria.minutiDi(adesso, fuso: fuso) == (parti.hour ?? 0) * 60 + (parti.minute ?? 0))
  }

  // MARK: - promemoria dei pasti

  @Test func unAvvisoPerOgniPastoDaSpuntare() throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let settimana = try JSONDecoder().decode(
      SettimanaNutrizione.self, from: Data(ProgrammaTests.settimana.utf8))
    // Le 6:00 del 26 ottobre: solo il pranzo è ancora pianificato (colazione mangiata, merenda saltata).
    let adesso = try #require(
      calendario.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 6)))
    let avvisi = PromemoriaPasti.notifiche(
      settimane: [settimana], promemoria: .predefiniti, adesso: adesso, fuso: fuso)
    #expect(avvisi.map(\.id) == ["pasto-2026-10-26-lunch"])
    #expect(avvisi[0].titolo == "Pranzo?")
    #expect(avvisi[0].corpo == "In programma Pasta al pomodoro")
    #expect(avvisi[0].dati == ["giorno": "2026-10-26", "slot": "lunch", "piano": "p1"])
    let alle = calendario.dateComponents([.hour, .minute], from: avvisi[0].quando)
    #expect(alle.hour == 13 && alle.minute == 0)
  }

  @Test func nienteAvvisoSePassatoOSenzaPiano() throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let settimana = try JSONDecoder().decode(
      SettimanaNutrizione.self, from: Data(ProgrammaTests.settimana.utf8))
    let dopoPranzo = try #require(
      calendario.date(from: DateComponents(year: 2026, month: 10, day: 26, hour: 14)))
    #expect(
      PromemoriaPasti.notifiche(
        settimane: [settimana], promemoria: .predefiniti, adesso: dopoPranzo, fuso: fuso
      ).isEmpty)
  }

  @Test func alMassimoQuaranta() throws {
    let fuso = try #require(TimeZone(identifier: "Europe/Rome"))
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let giorni = (1...28).map { n -> GiornoSettimana in
      let data = String(format: "2026-11-%02d", n)
      let pasti = GiornoDieta.ordineSlot.map {
        PastoSettimana(
          slot: $0, state: "planned", kcal: 100, plan: .init(id: "\(data)-\($0)", name: "Pasto"))
      }
      return GiornoSettimana(date: data, slots: pasti)
    }
    let adesso = try #require(
      calendario.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12)))
    let avvisi = PromemoriaPasti.notifiche(
      settimane: [SettimanaNutrizione(from: "2026-11-01", days: giorni)], promemoria: .predefiniti,
      adesso: adesso, fuso: fuso)
    #expect(avvisi.count == PromemoriaPasti.massimo)
    #expect(avvisi.first?.id == "pasto-2026-11-01-breakfast")
    #expect(avvisi == avvisi.sorted { $0.quando < $1.quando })
  }

  // MARK: - piano

  @Test func ilPianoSiLeggeEDiventaUnModulo() throws {
    let json = """
      {"id":"t1","name":"Definizione","dayKcal":[0,0,0,0,0,0,0],"cells":[
        {"weekday":1,"slot":"lunch","recipeId":"r1","foodId":null,"grams":null,"name":"Pasta","kcal":620},
        {"weekday":2,"slot":"dinner","recipeId":null,"foodId":"f1","grams":150,"name":"Mela","kcal":80}]}
      """
    let piano = try JSONDecoder().decode(TemplateSettimana.self, from: Data(json.utf8))
    let modulo = ModuloPiano(piano)
    #expect(modulo.nome == "Definizione")
    // La casella con un alimento solo non si rifà nell'app: resta fuori.
    #expect(modulo.ricette == [.init(giorno: 1, slot: "lunch"): "r1"])
  }

  @Test(arguments: [
    ("", true, "Serve un nome."),
    ("  ", true, "Serve un nome."),
    (String(repeating: "x", count: 101), true, "Il nome è troppo lungo."),
    ("Piano", false, "Scegli almeno una ricetta."),
  ])
  func moduloPianoNonValido(nome: String, conRicetta: Bool, problema: String) {
    var modulo = ModuloPiano(nome: nome)
    if conRicetta { modulo.ricette[.init(giorno: 1, slot: "lunch")] = "r1" }
    #expect(modulo.problema == problema)
    #expect(!modulo.valido)
  }

  @Test func salvaIlPianoConLeCaselleInOrdine() async throws {
    var modulo = ModuloPiano(nome: " Definizione ")
    modulo.ricette[.init(giorno: 3, slot: "dinner")] = "r3"
    modulo.ricette[.init(giorno: 1, slot: "lunch")] = "r1"
    modulo.ricette[.init(giorno: 1, slot: "breakfast")] = "r0"
    #expect(modulo.valido)

    let risposta = #"{"id":"t1","name":"Definizione","dayKcal":[],"cells":[]}"#
    let post = TransportFinto(.risposta(201, risposta))
    _ = try await APIClient(transport: post).creaPiano(modulo)
    #expect(post.richiesta?.httpMethod == "POST")
    #expect(post.richiesta?.url?.path == "/api/v1/nutrition/templates")
    let json = try corpo(post.richiesta)
    #expect(json["name"] as? String == "Definizione")
    let celle = try #require(json["cells"] as? [[String: Any]])
    var chiavi: [String] = []
    for cella in celle {
      let giorno = cella["weekday"] as? Int ?? 0
      let slot = cella["slot"] as? String ?? ""
      chiavi.append("\(giorno)-\(slot)")
    }
    #expect(chiavi == ["1-breakfast", "1-lunch", "3-dinner"])
    #expect(celle.first?["recipeId"] as? String == "r0")

    let put = TransportFinto(.risposta(200, risposta))
    _ = try await APIClient(transport: put).correggiPiano("t1", modulo)
    #expect(put.richiesta?.httpMethod == "PUT")
    #expect(put.richiesta?.url?.path == "/api/v1/nutrition/templates/t1")
  }

  // MARK: - programmazione

  @Test func programmaFinoAUnaData() async throws {
    let risposta = #"{"created":12,"removed":3,"kept":1,"from":"2026-10-27","until":"2026-11-30"}"#
    let transport = TransportFinto(.risposta(200, risposta))
    let esito = try await APIClient(transport: transport).programma(
      "t1", da: "2026-10-27", fino: "2026-11-30")
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/templates/t1/schedule")
    let json = try corpo(transport.richiesta)
    #expect(json["from"] as? String == "2026-10-27")
    #expect(json["until"] as? String == "2026-11-30")
    #expect(
      esito == EsitoProgramma(created: 12, removed: 3, kept: 1, from: "2026-10-27", until: "2026-11-30"))
    #expect(esito.testo == "12 pasti programmati")
  }

  @Test func programmaLaSolaSettimana() async throws {
    let transport = TransportFinto(
      .risposta(200, #"{"created":1,"removed":0,"kept":0,"from":"2026-10-27","until":"2026-11-01"}"#))
    let esito = try await APIClient(transport: transport).programma("t1", da: "2026-10-27")
    let json = try corpo(transport.richiesta)
    #expect(json["until"] == nil || json["until"] is NSNull)
    #expect(esito.testo == "1 pasto programmato")
  }

  // MARK: - procedimento

  @Test func laRicettaLeggeIPassi() throws {
    let con = #"""
      {"id":"r1","name":"Pasta","notes":null,"steps":["Cuoci.","Condisci."],"grams":300,"kcal":620,
       "protein":20,"carbs":90,"fat":15,"items":[]}
      """#
    #expect(try JSONDecoder().decode(Ricetta.self, from: Data(con.utf8)).steps == ["Cuoci.", "Condisci."])
    let senza = #"""
      {"id":"r1","name":"Pasta","notes":null,"grams":300,"kcal":620,"protein":20,"carbs":90,"fat":15,"items":[]}
      """#
    #expect(try JSONDecoder().decode(Ricetta.self, from: Data(senza.utf8)).steps.isEmpty)
  }

  @Test func ilModuloMandaIPassiPuliti() async throws {
    var modulo = ModuloRicetta(
      nome: "Pasta", passi: ["  Cuoci. ", "", "   ", "Condisci."],
      righe: [Bozza(Alimento(id: "f1", name: "Pasta", kcal: 350), testoGrammi: "80")])
    #expect(modulo.passiPuliti == ["Cuoci.", "Condisci."])
    #expect(modulo.valido)
    let transport = TransportFinto(
      .risposta(
        201,
        #"{"id":"r1","name":"Pasta","notes":null,"steps":[],"grams":80,"kcal":280,"protein":0,"carbs":0,"fat":0,"items":[]}"#
      ))
    _ = try await APIClient(transport: transport).creaRicetta(modulo)
    let json = try corpo(transport.richiesta)
    #expect(json["steps"] as? [String] == ["Cuoci.", "Condisci."])

    modulo.passi = Array(repeating: "passo", count: 51)
    #expect(modulo.problema == "Al massimo 50 passi.")
    modulo.passi = [String(repeating: "x", count: 1_001)]
    #expect(modulo.problema == "Un passo è troppo lungo.")
  }
}

@Suite struct DateProgrammaTests {
  let fuso = TimeZone(identifier: "Europe/Rome") ?? .gmt

  @Test func dataETestoSiRispecchiano() throws {
    let data = try #require(Settimana.data("2026-10-27", fuso: fuso))
    #expect(Settimana.testo(data, fuso: fuso) == "2026-10-27")
    #expect(Settimana.data("ieri", fuso: fuso) == nil)
    #expect(Settimana.data("2026-10", fuso: fuso) == nil)
  }

  @Test func giorniDopoEPrima() {
    #expect(Settimana.piu(1, a: "2026-10-31", fuso: fuso) == "2026-11-01")
    #expect(Settimana.piu(7, a: "2026-12-28", fuso: fuso) == "2027-01-04")
    #expect(Settimana.piu(-1, a: "2026-03-01", fuso: fuso) == "2026-02-28")
    // Il cambio dell'ora (25 ottobre) non sposta il giorno.
    #expect(Settimana.piu(1, a: "2026-10-24", fuso: fuso) == "2026-10-25")
    #expect(Settimana.piu(1, a: "2026-10-25", fuso: fuso) == "2026-10-26")
    #expect(Settimana.piu(3, a: "ciao", fuso: fuso) == "ciao")
  }

  @Test func oggiNelFusoDiRoma() {
    // 23:30 UTC del 26 ottobre sono già le 00:30 del 27 a Roma.
    let tardi = Date(timeIntervalSince1970: 1_793_057_400)
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let atteso = Striscia.testo(tardi, calendario: calendario)
    #expect(Settimana.oggi(adesso: tardi, fuso: fuso) == atteso)
  }

  @Test func esitoImportRicette() async throws {
    let corpo = #"{"created":3,"updated":2,"skipped":["x"],"skippedItems":1,"removedUpstream":0}"#
    let transport = TransportFinto(.risposta(200, corpo))
    let esito = try await APIClient(transport: transport).importaRicetteYazio()
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/nutrition/recipes/yazio/import")
    #expect(esito.testo == "3 ricette nuove · 2 aggiornate · 1 ingrediente escluso")
    #expect(EsitoImportRicette(created: 1, updated: 0).testo == "1 ricetta nuova · 0 aggiornate")
  }
}
