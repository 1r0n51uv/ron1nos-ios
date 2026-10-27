import Foundation

/// L'andamento della Dieta (NUT-017): tutto calcolato dal backend, qui
/// solo letto e messo in parole.
public struct AndamentoDieta: Decodable, Equatable, Sendable {
  public let days: Int
  public let from: String
  public let to: String
  public let series: [Giorno]
  public let averageKcal: Double?
  public let trendKcalPerWeek: Double?
  public let adherence: Aderenza
  public let macros: Medie?
  /// I macro dell'obiettivo di oggi.
  public let goal: Medie?
  public let weight: Peso

  public init(
    days: Int, from: String, to: String, series: [Giorno], averageKcal: Double?, trendKcalPerWeek: Double?,
    adherence: Aderenza, macros: Medie?, goal: Medie?, weight: Peso
  ) {
    self.days = days
    self.from = from
    self.to = to
    self.series = series
    self.averageKcal = averageKcal
    self.trendKcalPerWeek = trendKcalPerWeek
    self.adherence = adherence
    self.macros = macros
    self.goal = goal
    self.weight = weight
  }

  public struct Giorno: Decodable, Equatable, Identifiable, Sendable {
    public let date: String
    public let kcal: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    /// Almeno una riga quel giorno.
    public let logged: Bool
    /// La quota del giorno.
    public let goalKcal: Double?
    public var id: String { date }

    public init(
      date: String, kcal: Double, protein: Double, carbs: Double, fat: Double, logged: Bool, goalKcal: Double?
    ) {
      self.date = date
      self.kcal = kcal
      self.protein = protein
      self.carbs = carbs
      self.fat = fat
      self.logged = logged
      self.goalKcal = goalKcal
    }
  }

  public struct Aderenza: Decodable, Equatable, Sendable {
    public let inTarget: Int
    /// I giorni registrati con un obiettivo.
    public let total: Int
    public let pct: Int?

    public init(inTarget: Int, total: Int, pct: Int?) {
      self.inTarget = inTarget
      self.total = total
      self.pct = pct
    }
  }

  public struct Medie: Decodable, Equatable, Sendable {
    public let protein: Double
    public let carbs: Double
    public let fat: Double

    public init(protein: Double, carbs: Double, fat: Double) {
      self.protein = protein
      self.carbs = carbs
      self.fat = fat
    }
  }

  public struct Peso: Decodable, Equatable, Sendable {
    public let points: [Pesata]
    public let first: Double?
    public let last: Double?
    public let delta: Double?

    public init(points: [Pesata], first: Double?, last: Double?, delta: Double?) {
      self.points = points
      self.first = first
      self.last = last
      self.delta = delta
    }
  }

  public struct Pesata: Decodable, Equatable, Identifiable, Sendable {
    public let date: String
    public let kg: Double
    public var id: String { date }

    public init(date: String, kg: Double) {
      self.date = date
      self.kg = kg
    }
  }

  /// I giorni registrati, i soli che il grafico mostra come barre.
  public var registrati: [Giorno] { series.filter(\.logged) }

  /// "18 giorni su 22 · 82%", o un trattino senza giorni con obiettivo.
  public var testoAderenza: String {
    guard let pct = adherence.pct, adherence.total > 0 else { return "—" }
    return "\(adherence.inTarget) giorni su \(adherence.total) · \(pct)%"
  }

  /// "+120 kcal a settimana", "−80 kcal a settimana" o un trattino.
  public func testoTendenza(_ formati: Formati = Formati()) -> String {
    guard let tendenza = trendKcalPerWeek else { return "—" }
    let segno = tendenza > 0 ? "+" : (tendenza < 0 ? "−" : "")
    return "\(segno)\(formati.energia(abs(tendenza))) a settimana"
  }

  /// "−1,2 kg nel periodo" o un trattino.
  public func testoPeso(_ formati: Formati = Formati()) -> String {
    guard let delta = weight.delta else { return "—" }
    let segno = delta > 0 ? "+" : (delta < 0 ? "−" : "")
    return "\(segno)\(formati.peso(abs(delta))) nel periodo"
  }

  /// Una data dell'API come Date, a mezzogiorno nel fuso: per l'asse del
  /// grafico, senza che l'ora legale sposti il giorno.
  public static func data(
    _ testo: String, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> Date? {
    let parti = testo.split(separator: "-").compactMap { Int($0) }
    guard parti.count == 3 else { return nil }
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    return calendario.date(from: DateComponents(year: parti[0], month: parti[1], day: parti[2], hour: 12))
  }

  /// I periodi del selettore.
  public static let periodi = [30, 90]
}

extension APIClient {
  /// `GET /nutrition/report?days=30|90`.
  public func andamentoDieta(giorni: Int = 30) async throws(APIError) -> AndamentoDieta {
    try await get("nutrition/report", query: [URLQueryItem(name: "days", value: String(giorni))])
  }
}
