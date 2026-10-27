/// Il giorno del diario, da `GET /api/v1/nutrition/day` (NUT-001 di
/// ron1nOS). L'app ne usa solo i totali e l'obiettivo.
public struct GiornoDieta: Decodable, Equatable, Sendable {
  public let date: String
  public let totals: Macro
  public let goal: Macro?
  /// Le kcal del giorno: obiettivo più l'attività letta da YAZIO. null
  /// senza obiettivo.
  public let quota: Quota?
  /// Il prossimo slot ancora da mangiare oggi, se c'è: `dinner`.
  public let nextSlot: String?
  /// I 5 slot del giorno, nell'ordine.
  public let slots: [SlotGiorno]?
  /// Gli integratori attivi, con lo stato di oggi (NUT-014).
  public let supplements: [IntegratoreGiorno]?
  /// Le kcal pianificate e non ancora mangiate.
  public let plannedKcal: Double?
  /// Lo slot dell'ora corrente, solo per oggi.
  public let suggestedSlot: String?
  /// L'acqua bevuta nel giorno in ml (NUT-012).
  public let waterMl: Int?
  /// La caffeina del giorno (NUT-013).
  public let caffeine: Caffeina?

  public init(
    date: String, totals: Macro, goal: Macro? = nil, quota: Quota? = nil, nextSlot: String? = nil,
    slots: [SlotGiorno]? = nil, supplements: [IntegratoreGiorno]? = nil, plannedKcal: Double? = nil,
    suggestedSlot: String? = nil, waterMl: Int? = nil, caffeine: Caffeina? = nil
  ) {
    self.date = date
    self.totals = totals
    self.goal = goal
    self.quota = quota
    self.nextSlot = nextSlot
    self.slots = slots
    self.supplements = supplements
    self.plannedKcal = plannedKcal
    self.suggestedSlot = suggestedSlot
    self.waterMl = waterMl
    self.caffeine = caffeine
  }

  /// Gli slot nell'ordine del sito, anche se la risposta non li ha.
  public var slotInOrdine: [SlotGiorno] {
    let letti = slots ?? []
    return GiornoDieta.ordineSlot.map { nome in
      letti.first { $0.slot == nome } ?? SlotGiorno(slot: nome, state: "empty")
    }
  }

  public static let ordineSlot = ["breakfast", "morning_snack", "lunch", "afternoon_snack", "dinner"]

  public struct Caffeina: Decodable, Equatable, Sendable {
    public let totalMg: Int
    public let mealsMg: Int

    public init(totalMg: Int, mealsMg: Int) {
      self.totalMg = totalMg
      self.mealsMg = mealsMg
    }
  }

  /// I nomi degli slot, come sul sito.
  public static let nomiSlot = [
    "breakfast": "Colazione", "morning_snack": "Spuntino", "lunch": "Pranzo",
    "afternoon_snack": "Merenda", "dinner": "Cena",
  ]

  /// Il widget `nutrition.next-meal`: "Cena", o "Pasti completati".
  public var titoloProssimoPasto: String {
    nextSlot.flatMap { GiornoDieta.nomiSlot[$0] } ?? "Pasti completati"
  }

  /// Cosa c'è di pianificato per il prossimo pasto: "Pasta al pomodoro · 620 kcal".
  public func pianificato(_ formati: Formati) -> String? {
    guard let prossimo = nextSlot else { return nil }
    guard let slot = slots?.first(where: { $0.slot == prossimo }), slot.state == "planned",
      let piano = slot.planned
    else { return "Niente pianificato" }
    let cosa = piano.recipeName ?? piano.items.map(\.name).joined(separator: ", ")
    return "\(cosa) · \(formati.energia(piano.kcal))"
  }

  /// Il widget `nutrition.supplements`: "2 di 3 integratori".
  public var testoIntegratori: String {
    let lista = supplements ?? []
    guard !lista.isEmpty else { return "Nessun integratore attivo." }
    return "\(lista.filter(\.taken).count) di \(lista.count) integratori"
  }

  /// "Mancano Vitamina D · Omega 3", o "Tutti presi.".
  public var mancanoIntegratori: String? {
    let lista = supplements ?? []
    guard !lista.isEmpty else { return nil }
    let mancano = lista.filter { !$0.taken }.map(\.name)
    return mancano.isEmpty ? "Tutti presi." : "Mancano \(mancano.joined(separator: " · "))"
  }

  public struct Quota: Decodable, Equatable, Sendable {
    public let kcal: Double
    public init(kcal: Double) { self.kcal = kcal }
  }

  /// Le kcal da raggiungere: la quota del giorno, se no l'obiettivo.
  public var kcalObiettivo: Double? { quota?.kcal ?? goal?.kcal }

  /// "1.450 / 2.200 kcal", o solo le mangiate senza obiettivo.
  public var testoKcal: String { testoEnergia(Formati()) }

  /// Come `testoKcal`, nell'unità scelta (SET-010): "6.067 / 9.205 kJ".
  public func testoEnergia(_ formati: Formati) -> String {
    let mangiate = Formato.numero(formati.valoreEnergia(totals.kcal))
    let unita = formati.energyUnit.rawValue
    guard let obiettivo = kcalObiettivo else { return "\(mangiate) \(unita)" }
    return "\(mangiate) / \(Formato.numero(formati.valoreEnergia(obiettivo))) \(unita)"
  }

  /// Quanto manca, o di quanto si è oltre: "750 kcal rimanenti".
  public var testoRimanenti: String? { testoRimanenti(Formati()) }

  public func testoRimanenti(_ formati: Formati) -> String? {
    guard let obiettivo = kcalObiettivo else { return nil }
    let differenza = obiettivo - totals.kcal
    return differenza >= 0
      ? "\(formati.energia(differenza)) rimanenti" : "\(formati.energia(-differenza)) oltre"
  }

  /// Da 0 a 1, per la barra; nil senza obiettivo.
  public var avanzamento: Double? {
    guard let obiettivo = kcalObiettivo, obiettivo > 0 else { return nil }
    return min(1, totals.kcal / obiettivo)
  }

  /// Oltre la quota: la barra diventa rossa.
  public var oltre: Bool { kcalObiettivo.map { totals.kcal > $0 } ?? false }

  /// Le tre righe dei macro: nome e "82 / 140 g".
  public var macro: [RigaMacro] {
    let righe: [(String, String, Double, Double?)] = [
      ("protein", "Proteine", totals.protein, goal?.protein),
      ("carbs", "Carboidrati", totals.carbs, goal?.carbs),
      ("fat", "Grassi", totals.fat, goal?.fat),
    ]
    return righe.map { chiave, nome, valore, obiettivo in
      let testo = obiettivo.map { "\(Formato.numero(valore)) / \(Formato.numero($0)) g" }
      return RigaMacro(chiave: chiave, nome: nome, testo: testo ?? "\(Formato.numero(valore)) g")
    }
  }
}

/// Uno slot del giorno: vuoto, pianificato, mangiato o saltato.
public struct SlotGiorno: Decodable, Equatable, Identifiable, Sendable {
  public let slot: String
  public let state: String
  public let planned: Pianificato?
  /// Il pasto registrato, con le righe (NUT-003).
  public let meal: Pasto?

  public var id: String { slot }

  public init(slot: String, state: String, planned: Pianificato? = nil, meal: Pasto? = nil) {
    self.slot = slot
    self.state = state
    self.planned = planned
    self.meal = meal
  }

  /// Il nome dello slot: "Colazione".
  public var titolo: String { GiornoDieta.nomiSlot[slot] ?? slot }

  public var mangiato: Bool { state == "eaten" }
  public var vuoto: Bool { state == "empty" }
  public var saltato: Bool { state == "skipped" }

  /// Le kcal da mostrare sulla card: quelle mangiate, se no le pianificate.
  public var kcal: Double? { meal?.kcal ?? planned?.kcal }

  /// Gli alimenti da elencare sulla card: "Pane 80 g · Uova 120 g".
  public var elenco: String? {
    if let righe = meal?.items, !righe.isEmpty {
      return righe.map { "\($0.name) \(Formato.numero($0.grams)) g" }.joined(separator: " · ")
    }
    if let piano = planned {
      if let ricetta = piano.recipeName { return ricetta }
      if !piano.items.isEmpty { return piano.items.map(\.name).joined(separator: " · ") }
    }
    return nil
  }

  /// Il pasto registrato: kcal, macro e righe.
  public struct Pasto: Decodable, Equatable, Sendable {
    public let id: String
    public let kcal: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    public let items: [RigaPasto]

    public init(
      id: String, kcal: Double, protein: Double = 0, carbs: Double = 0, fat: Double = 0,
      items: [RigaPasto] = []
    ) {
      self.id = id
      self.kcal = kcal
      self.protein = protein
      self.carbs = carbs
      self.fat = fat
      self.items = items
    }
  }

  public struct Pianificato: Decodable, Equatable, Sendable {
    public let id: String?
    public let kcal: Double
    public let recipeName: String?
    public let items: [Voce]

    public init(id: String? = nil, kcal: Double, recipeName: String? = nil, items: [Voce] = []) {
      self.id = id
      self.kcal = kcal
      self.recipeName = recipeName
      self.items = items
    }
  }

  public struct Voce: Decodable, Equatable, Sendable {
    public let name: String
    public init(name: String) { self.name = name }
  }
}

/// Un integratore attivo e se è stato preso oggi.
public struct IntegratoreGiorno: Decodable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let taken: Bool

  public init(id: String, name: String, taken: Bool) {
    self.id = id
    self.name = name
    self.taken = taken
  }
}

/// Una riga della card: "Proteine" e "82 / 140 g".
public struct RigaMacro: Equatable, Sendable {
  /// `protein`, `carbs` o `fat`, come nelle opzioni del widget.
  public let chiave: String
  public let nome: String
  public let testo: String
}

/// Kcal e macro in grammi.
public struct Macro: Decodable, Equatable, Sendable {
  public let kcal: Double
  public let protein: Double
  public let carbs: Double
  public let fat: Double

  public init(kcal: Double, protein: Double, carbs: Double, fat: Double) {
    self.kcal = kcal
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
  }
}

/// Una riga del diario, con lo stato verso YAZIO (NUT-023).
public struct RigaPasto: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let foodId: String?
  public let name: String
  public let grams: Double
  public let kcal: Double
  public let protein: Double
  public let carbs: Double
  public let fat: Double
  /// `local`, `pending`, `synced`, `error` o `unmatched`.
  public let sync: String

  public init(
    id: String, foodId: String? = nil, name: String, grams: Double, kcal: Double, protein: Double = 0,
    carbs: Double = 0, fat: Double = 0, sync: String = "local"
  ) {
    self.id = id
    self.foodId = foodId
    self.name = name
    self.grams = grams
    self.kcal = kcal
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.sync = sync
  }

  /// Lo stato di YAZIO come lo legge l'utente, o nil se resta locale.
  public var statoYazio: String? {
    switch sync {
    case "pending": "In coda su YAZIO"
    case "synced": "Inviata a YAZIO"
    case "error": "YAZIO ha rifiutato la riga"
    case "unmatched": "Senza equivalente su YAZIO"
    default: nil
    }
  }
}

extension APIClient {
  /// `GET /nutrition/day` di oggi o di un giorno dato.
  public func dieta(_ giorno: String? = nil) async throws(APIError) -> GiornoDieta {
    guard let giorno else { return try await get("nutrition/day") }
    return try await get("nutrition/day", query: [URLQueryItem(name: "date", value: giorno)])
  }

  /// `PUT /nutrition/plans/{id}/status`: segna un pasto pianificato
  /// `eaten` o `skipped` (NUT-009).
  public func statoPiano(_ id: String, _ stato: String) async throws(APIError) {
    struct Corpo: Encodable, Sendable { let status: String }
    let json: Data
    do {
      json = try JSONEncoder().encode(Corpo(status: stato))
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
    _ = try await dati("nutrition/plans/\(id)/status", metodo: "PUT", corpo: json)
  }
}
