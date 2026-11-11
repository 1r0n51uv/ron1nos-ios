import Foundation

/// La striscia dei giorni della Dieta (IOS-030): dieci giorni indietro e
/// tredici avanti rispetto a oggi, con oggi in mezzo.
public struct Striscia: Equatable, Sendable {
  public struct Giorno: Equatable, Identifiable, Sendable {
    /// `2026-10-27`, come lo vuole l'API.
    public let id: String
    /// L'iniziale del giorno: `L`, `M`, `G`.
    public let lettera: String
    public let numero: Int
    public let oggi: Bool
    public let futuro: Bool
  }

  public let giorni: [Giorno]
  public let oggi: String

  public static let indietro = 10
  public static let avanti = 13

  public init(oggi adesso: Date = Date(), fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt) {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let inizio = calendario.startOfDay(for: adesso)
    oggi = Striscia.testo(inizio, calendario: calendario)
    giorni = (-Striscia.indietro...Striscia.avanti).compactMap { passo in
      guard let data = calendario.date(byAdding: .day, value: passo, to: inizio) else { return nil }
      let parti = calendario.dateComponents([.weekday, .day], from: data)
      let lettera = Striscia.lettere[((parti.weekday ?? 1) - 1) % 7]
      return Giorno(
        id: Striscia.testo(data, calendario: calendario), lettera: lettera, numero: parti.day ?? 1,
        oggi: passo == 0, futuro: passo > 0)
    }
  }

  /// Da domenica a sabato, come `weekday` di Calendar.
  static let lettere = ["D", "L", "M", "M", "G", "V", "S"]

  /// `2026-10-27`: la data come la vuole l'API, senza fuso di mezzo.
  public static func testo(_ data: Date, calendario: Calendar) -> String {
    let parti = calendario.dateComponents([.year, .month, .day], from: data)
    let mese = parti.month ?? 1
    let giorno = parti.day ?? 1
    return "\(parti.year ?? 2026)-\(mese < 10 ? "0" : "")\(mese)-\(giorno < 10 ? "0" : "")\(giorno)"
  }

  public func giorno(_ id: String) -> Giorno? { giorni.first { $0.id == id } }
}
