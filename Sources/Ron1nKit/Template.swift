import Foundation

/// Un template settimanale (NUT-010): una griglia di giorni e slot, ognuno
/// con una ricetta o un alimento.
public struct TemplateSettimana: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let cells: [Cella]
  /// Le kcal di ogni giorno, da lunedì a domenica.
  public let dayKcal: [Double]

  public init(id: String, name: String, cells: [Cella] = [], dayKcal: [Double] = []) {
    self.id = id
    self.name = name
    self.cells = cells
    self.dayKcal = dayKcal
  }

  /// Una casella della griglia.
  public struct Cella: Decodable, Equatable, Sendable {
    /// 1 è lunedì, 7 domenica.
    public let weekday: Int
    public let slot: String
    public let recipeId: String?
    public let foodId: String?
    public let grams: Double?
    public let name: String
    public let kcal: Double

    public init(
      weekday: Int, slot: String, recipeId: String? = nil, foodId: String? = nil, grams: Double? = nil,
      name: String, kcal: Double
    ) {
      self.weekday = weekday
      self.slot = slot
      self.recipeId = recipeId
      self.foodId = foodId
      self.grams = grams
      self.name = name
      self.kcal = kcal
    }

    /// "Ricetta" o "120 g".
    public var dettaglio: String {
      if recipeId != nil { return "Ricetta" }
      return grams.map { "\(Formato.numero($0)) g" } ?? "Alimento"
    }
  }

  /// I cinque slot di un giorno nell'ordine della Dieta: `nil` dove il
  /// template non ha niente.
  public func slot(giorno: Int) -> [Casella] {
    GiornoDieta.ordineSlot.map { nome in
      Casella(slot: nome, cella: cells.first { $0.weekday == giorno && $0.slot == nome })
    }
  }

  /// Uno slot del giorno scelto, pieno o vuoto.
  public struct Casella: Equatable, Identifiable, Sendable {
    public let slot: String
    public let cella: Cella?
    public var id: String { slot }
    public var titolo: String { GiornoDieta.nomiSlot[slot] ?? slot }
  }

  /// Le kcal di un giorno, da 1 a 7.
  public func kcal(giorno: Int) -> Double {
    dayKcal.indices.contains(giorno - 1) ? dayKcal[giorno - 1] : 0
  }

  /// "5 giorni · 18 pasti".
  public var sottotitolo: String {
    let giorni = Set(cells.map(\.weekday)).count
    let pasti = cells.count
    return "\(giorni) \(giorni == 1 ? "giorno" : "giorni") · \(pasti) \(pasti == 1 ? "pasto" : "pasti")"
  }

  /// Le iniziali da lunedì a domenica, per la fila dei giorni.
  public static let lettere = ["L", "M", "M", "G", "V", "S", "D"]
}

/// Cosa ha fatto `Applica` (NUT-010).
public struct EsitoTemplate: Decodable, Equatable, Sendable {
  public let created: Int
  public let replaced: Int
  public let kept: Int

  public init(created: Int, replaced: Int, kept: Int) {
    self.created = created
    self.replaced = replaced
    self.kept = kept
  }

  /// "4 pasti creati · 2 sostituiti · 1 lasciato com'era".
  public var testo: String {
    var parti = ["\(created) \(created == 1 ? "pasto creato" : "pasti creati")"]
    parti.append("\(replaced) \(replaced == 1 ? "sostituito" : "sostituiti")")
    if kept > 0 { parti.append("\(kept) \(kept == 1 ? "lasciato com'era" : "lasciati com'erano")") }
    return parti.joined(separator: " · ")
  }
}

/// Le settimane a cui si applica un template: sempre da lunedì.
public enum Settimana {
  /// Il lunedì della settimana di `data`, come lo vuole l'API.
  public static func lunedi(
    di data: Date, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let inizio = calendario.startOfDay(for: data)
    // weekday: 1 è domenica, 2 lunedì.
    let giorno = calendario.component(.weekday, from: inizio)
    let indietro = (giorno + 5) % 7
    let lunedi = calendario.date(byAdding: .day, value: -indietro, to: inizio) ?? inizio
    return Striscia.testo(lunedi, calendario: calendario)
  }

  /// Il lunedì `settimane` dopo quello di `data`.
  public static func lunedi(
    di data: Date, piu settimane: Int, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let spostata = calendario.date(byAdding: .day, value: 7 * settimane, to: data) ?? data
    return lunedi(di: spostata, fuso: fuso)
  }

  /// Il giorno della settimana di `data`, da 1 (lunedì) a 7.
  public static func giorno(
    di data: Date, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> Int {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    return (calendario.component(.weekday, from: data) + 5) % 7 + 1
  }
}

extension APIClient {
  /// `GET /nutrition/templates`.
  public func template() async throws(APIError) -> [TemplateSettimana] {
    struct Risposta: Decodable { let templates: [TemplateSettimana] }
    let risposta: Risposta = try await get("nutrition/templates")
    return risposta.templates
  }

  /// `DELETE /nutrition/templates/{id}`: i pasti già pianificati restano.
  public func eliminaTemplate(_ id: String) async throws(APIError) {
    _ = try await dati("nutrition/templates/\(id)", metodo: "DELETE")
  }

  /// `POST /nutrition/templates/{id}/apply` sulla settimana che inizia `lunedi`.
  public func applicaTemplate(_ id: String, lunedi: String) async throws(APIError) -> EsitoTemplate {
    struct Corpo: Encodable, Sendable { let monday: String }
    return try await invia("POST", "nutrition/templates/\(id)/apply", corpo: Corpo(monday: lunedi))
  }
}
