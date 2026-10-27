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

  public init(
    date: String, totals: Macro, goal: Macro? = nil, quota: Quota? = nil, nextSlot: String? = nil,
    slots: [SlotGiorno]? = nil, supplements: [IntegratoreGiorno]? = nil
  ) {
    self.date = date
    self.totals = totals
    self.goal = goal
    self.quota = quota
    self.nextSlot = nextSlot
    self.slots = slots
    self.supplements = supplements
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
public struct SlotGiorno: Decodable, Equatable, Sendable {
  public let slot: String
  public let state: String
  public let planned: Pianificato?

  public init(slot: String, state: String, planned: Pianificato? = nil) {
    self.slot = slot
    self.state = state
    self.planned = planned
  }

  public struct Pianificato: Decodable, Equatable, Sendable {
    public let kcal: Double
    public let recipeName: String?
    public let items: [Voce]

    public init(kcal: Double, recipeName: String? = nil, items: [Voce] = []) {
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

extension APIClient {
  /// `GET /nutrition/day` di oggi.
  public func dieta() async throws(APIError) -> GiornoDieta {
    try await get("nutrition/day")
  }
}
