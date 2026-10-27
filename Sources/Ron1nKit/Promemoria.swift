import Foundation

/// Gli orari dei promemoria (NUT-027), nelle preferenze condivise: il
/// backend li salva e basta, le notifiche le programma il telefono.
public struct Promemoria: Codable, Equatable, Sendable {
  /// Da slot a orario: `lunch` → `13:00`.
  public var meals: [String: String]
  /// Gli avvisi dell'acqua, in ordine.
  public var water: [String]

  public static let predefiniti = Promemoria(
    meals: [
      "breakfast": "07:30", "morning_snack": "10:30", "lunch": "13:00", "afternoon_snack": "16:30",
      "dinner": "20:00",
    ],
    water: ["10:00", "13:00", "16:00", "19:00"])

  public static let massimoAcqua = 12

  public init(meals: [String: String], water: [String]) {
    self.meals = meals
    self.water = water
  }

  enum CodingKeys: String, CodingKey { case meals, water }

  /// Un orario che manca o non si capisce vale il predefinito.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let base = Promemoria.predefiniti
    let letti = c.leggi([String: String].self, .meals) ?? [:]
    meals = base.meals.merging(letti.filter { Promemoria.minuti($0.value) != nil }) { _, letto in letto }
    water = (c.leggi([String].self, .water) ?? base.water).filter { Promemoria.minuti($0) != nil }
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

/// Le notifiche dei pasti e dell'acqua (IOS-041), da programmare con
/// quelle di IOS-011.
public enum PromemoriaDieta {
  /// La categoria con `Sì` e `Rimanda`.
  public static let categoriaPasto = "pasto"
  /// Quanto rimanda `Rimanda`.
  public static let rinvio: TimeInterval = 30 * 60
  /// L'acqua si conta fra le 7 e le 22: a metà giornata ne serve metà.
  static let inizioAcqua = 7 * 60
  static let fineAcqua = 22 * 60

  /// Un promemoria per ogni slot non mangiato né saltato dei giorni dati,
  /// e per oggi gli avvisi dell'acqua se si è sotto la quota dell'ora.
  public static func notifiche(
    giorni: [GiornoDieta], promemoria: Promemoria, oggi: String, adesso: Date,
    fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> [NotificaLocale] {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    var risultato: [NotificaLocale] = []
    for giorno in giorni {
      for slot in giorno.slotInOrdine where !slot.mangiato && !slot.saltato {
        let orario = promemoria.orario(slot.slot)
        guard let quando = istante(giorno.date, orario, calendario: calendario), quando > adesso else {
          continue
        }
        let piatto = slot.elenco ?? "un pasto"
        let corpo = slot.planned == nil ? "Niente di registrato per ora" : "In programma \(piatto)"
        var dati = ["giorno": giorno.date, "slot": slot.slot]
        if let piano = slot.planned?.id { dati["piano"] = piano }
        risultato.append(
          NotificaLocale(
            id: "pasto-\(giorno.date)-\(slot.slot)", gruppo: .pasti, titolo: "\(slot.titolo)?", corpo: corpo,
            quando: quando, categoria: dati["piano"] == nil ? nil : categoriaPasto, dati: dati))
      }
      guard giorno.date == oggi, let quota = giorno.goal?.waterMl, quota > 0 else { continue }
      let bevuta = Double(giorno.waterMl ?? 0)
      for orario in promemoria.water {
        guard let minuti = Promemoria.minuti(orario),
          let quando = istante(giorno.date, orario, calendario: calendario), quando > adesso,
          bevuta < quota * quotaAllOra(minuti)
        else { continue }
        risultato.append(
          NotificaLocale(
            id: "acqua-\(giorno.date)-\(orario)", gruppo: .acqua, titolo: "Acqua",
            corpo: "\(giorno.testoAcqua) · un bicchiere?", quando: quando, dati: ["giorno": giorno.date]))
      }
    }
    return risultato
  }

  /// La parte della quota che serve aver bevuto a quell'ora, da 0 a 1.
  public static func quotaAllOra(_ minuti: Int) -> Double {
    let parte = Double(minuti - inizioAcqua) / Double(fineAcqua - inizioAcqua)
    return min(1, max(0, parte))
  }

  static func istante(_ giorno: String, _ orario: String, calendario: Calendar) -> Date? {
    let parti = giorno.split(separator: "-").compactMap { Int($0) }
    guard parti.count == 3, let minuti = Promemoria.minuti(orario) else { return nil }
    let ora = DateComponents(
      year: parti[0], month: parti[1], day: parti[2], hour: minuti / 60, minute: minuti % 60)
    return calendario.date(from: ora)
  }
}

extension APIClient {
  /// `PATCH /preferences` con i soli orari dei promemoria.
  public func salvaPromemoria(_ promemoria: Promemoria) async throws(APIError) -> Preferenze {
    struct Corpo: Encodable, Sendable { let reminders: Promemoria }
    return try await invia("PATCH", "preferences", corpo: Corpo(reminders: promemoria))
  }
}
