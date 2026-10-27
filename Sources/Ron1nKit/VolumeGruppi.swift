import Foundation

/// Volume e serie per gruppo muscolare, settimana per settimana (GYM-012).
public struct VolumeGruppi: Decodable, Equatable, Sendable {
  /// I gruppi presenti nell'ordine dell'elenco fisso; nil, Non assegnato,
  /// in fondo.
  public let groups: [String?]
  public let weeks: [Settimana]

  public init(groups: [String?], weeks: [Settimana]) {
    self.groups = groups
    self.weeks = weeks
  }

  public struct Settimana: Decodable, Equatable, Sendable {
    public let monday: String
    public let groups: [Voce]

    public init(monday: String, groups: [Voce]) {
      self.monday = monday
      self.groups = groups
    }
  }

  public struct Voce: Decodable, Equatable, Sendable {
    public let group: String?
    public let volumeKg: Double
    public let sets: Int

    public init(group: String?, volumeKg: Double, sets: Int) {
      self.group = group
      self.volumeKg = volumeKg
      self.sets = sets
    }
  }

  /// Cosa si conta: kg sollevati o serie.
  public enum Misura: String, CaseIterable, Sendable {
    case volume, serie

    public var titolo: String { self == .volume ? "Volume" : "Serie" }
  }

  /// Un pezzo di una barra impilata.
  public struct Pezzo: Equatable, Identifiable, Sendable {
    public let monday: String
    public let gruppo: String?
    public let valore: Double
    /// La posizione del gruppo nella legenda, per il tono di grigio.
    public let indice: Int
    public var id: String { "\(monday)-\(gruppo ?? "")" }
  }

  /// I pezzi delle barre nell'ordine della legenda, senza quelli a zero.
  public func pezzi(_ misura: Misura) -> [Pezzo] {
    weeks.flatMap { settimana in
      groups.enumerated().compactMap { indice, gruppo -> Pezzo? in
        guard let voce = settimana.groups.first(where: { $0.group == gruppo }) else { return nil }
        let valore = misura == .volume ? voce.volumeKg : Double(voce.sets)
        guard valore > 0 else { return nil }
        return Pezzo(monday: settimana.monday, gruppo: gruppo, valore: valore, indice: indice)
      }
    }
  }

  /// Niente da mostrare nelle settimane chieste.
  public var vuoto: Bool { pezzi(.serie).isEmpty }

  /// "Petto", o "Non assegnato" per gli esercizi senza gruppo.
  public static func nome(_ gruppo: String?) -> String {
    gruppo == nil ? "Non assegnato" : Palestra.nomeGruppo(gruppo)
  }

  /// Il tono di grigio di un gruppo: dal più chiaro al più scuro.
  public func opacita(_ indice: Int) -> Double {
    let pieni = max(groups.filter { $0 != nil }.count, 1)
    return 0.9 - 0.65 * Double(indice) / Double(max(pieni - 1, 1))
  }
}

extension APIClient {
  /// `GET /workout/muscle-groups`: le ultime settimane, dalla meno recente.
  public func volumeGruppi(settimane: Int = 12) async throws(APIError) -> VolumeGruppi {
    try await get("workout/muscle-groups", query: [URLQueryItem(name: "weeks", value: String(settimane))])
  }
}
