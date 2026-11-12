import Foundation

/// Gli orari dei promemoria (NUT-027), nelle preferenze condivise: il
/// backend li salva e basta, le notifiche le programma il telefono.
public struct Promemoria: Codable, Equatable, Sendable {
  /// Da slot a orario: `lunch` → `13:00`.
  public var meals: [String: String]
  /// Gli avvisi dell'acqua, in ordine.
  public var water: [String]
  /// Di quanti minuti `Rimanda` sposta il promemoria di un pasto.
  public var snooze: Int

  public static let predefiniti = Promemoria(
    meals: [
      "breakfast": "07:30", "morning_snack": "10:30", "lunch": "13:00", "afternoon_snack": "16:30",
      "dinner": "20:00",
    ],
    water: ["10:00", "13:00", "16:00", "19:00"], snooze: 15)

  public static let massimoAcqua = 12
  /// Il rinvio va da 5 minuti a 2 ore.
  public static let rinvii = 5...120

  public init(meals: [String: String], water: [String], snooze: Int = 15) {
    self.meals = meals
    self.water = water
    self.snooze = snooze
  }

  enum CodingKeys: String, CodingKey { case meals, water, snooze }

  /// Un orario che manca o non si capisce vale il predefinito.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let base = Promemoria.predefiniti
    let letti = c.leggi([String: String].self, .meals) ?? [:]
    meals = base.meals.merging(letti.filter { Promemoria.minuti($0.value) != nil }) { _, letto in letto }
    water = (c.leggi([String].self, .water) ?? base.water).filter { Promemoria.minuti($0) != nil }
    snooze = c.leggi(Int.self, .snooze).flatMap { Promemoria.rinvii.contains($0) ? $0 : nil } ?? base.snooze
  }

  /// L'orario di uno slot.
  public func orario(_ slot: String) -> String {
    meals[slot] ?? Promemoria.predefiniti.meals[slot] ?? "12:00"
  }

  /// I minuti dalla mezzanotte di `07:30`, o nil se non è un orario.
  public static func minuti(_ testo: String) -> Int? {
    let parti = testo.split(separator: ":")
    guard parti.count == 2, parti[0].count == 2, parti[1].count == 2,
      let ore = Int(parti[0]), let minuti = Int(parti[1]), (0..<24).contains(ore), (0..<60).contains(minuti)
    else { return nil }
    return ore * 60 + minuti
  }

  /// `07:30` da ore e minuti.
  public static func testo(ore: Int, minuti: Int) -> String {
    "\(ore < 10 ? "0" : "")\(ore):\(minuti < 10 ? "0" : "")\(minuti)"
  }

  /// Gli avvisi dell'acqua in ordine, senza doppioni, al massimo 12.
  public static func ordina(_ orari: [String]) -> [String] {
    let validi = Set(orari.filter { minuti($0) != nil })
    return Array(validi.sorted { (minuti($0) ?? 0) < (minuti($1) ?? 0) }.prefix(massimoAcqua))
  }
}

extension APIClient {
  /// `PATCH /preferences` con i soli orari dei promemoria.
  public func salvaPromemoria(_ promemoria: Promemoria) async throws(APIError) -> Preferenze {
    struct Corpo: Encodable, Sendable { let reminders: Promemoria }
    return try await invia("PATCH", "preferences", corpo: Corpo(reminders: promemoria))
  }
}
