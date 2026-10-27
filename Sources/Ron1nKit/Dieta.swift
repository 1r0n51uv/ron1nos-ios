/// Il giorno del diario, da `GET /api/v1/nutrition/day` (NUT-001 di
/// ron1nOS). L'app ne usa solo i totali e l'obiettivo.
public struct GiornoDieta: Decodable, Equatable, Sendable {
  public let date: String
  public let totals: Macro
  public let goal: Macro?
  /// Le kcal del giorno: obiettivo più l'attività letta da YAZIO. null
  /// senza obiettivo.
  public let quota: Quota?

  public init(date: String, totals: Macro, goal: Macro? = nil, quota: Quota? = nil) {
    self.date = date
    self.totals = totals
    self.goal = goal
    self.quota = quota
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
    let righe: [(String, Double, Double?)] = [
      ("Proteine", totals.protein, goal?.protein),
      ("Carboidrati", totals.carbs, goal?.carbs),
      ("Grassi", totals.fat, goal?.fat),
    ]
    return righe.map { nome, valore, obiettivo in
      let testo = obiettivo.map { "\(Formato.numero(valore)) / \(Formato.numero($0)) g" }
      return RigaMacro(nome: nome, testo: testo ?? "\(Formato.numero(valore)) g")
    }
  }
}

/// Una riga della card: "Proteine" e "82 / 140 g".
public struct RigaMacro: Equatable, Sendable {
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
