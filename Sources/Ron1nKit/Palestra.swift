import Foundation

/// La foto di un esercizio dal catalogo (GYM-014), servita dal backend.
public struct ImmagineEsercizio: Decodable, Equatable, Hashable, Sendable {
  public let catalogId: String
  /// `manual`, `dictionary` o `catalog`.
  public let source: String
  /// `/api/v1/workout/catalog/images/…/0.jpg`.
  public let url: String

  public init(catalogId: String, source: String = "catalog", url: String) {
    self.catalogId = catalogId
    self.source = source
    self.url = url
  }

  /// Il percorso da chiedere all'APIClient, che parte già da `/api/v1`.
  public var percorso: String { ImmagineEsercizio.percorso(url) }

  static func percorso(_ url: String) -> String {
    var resto = url
    if let fine = resto.range(of: "/api/v1/") { resto = String(resto[fine.upperBound...]) }
    while resto.hasPrefix("/") { resto.removeFirst() }
    return resto
  }
}

/// Un esercizio citato altrove: nome e foto.
public struct RifEsercizio: Decodable, Equatable, Sendable {
  public let name: String
  public let image: ImmagineEsercizio?

  public init(name: String, image: ImmagineEsercizio? = nil) {
    self.name = name
    self.image = image
  }
}

/// Un esercizio dell'elenco (GYM-007, GYM-009).
public struct EsercizioPalestra: Decodable, Equatable, Identifiable, Sendable {
  public let name: String
  /// Il nome normalizzato: è l'id dell'esercizio.
  public let key: String
  public let image: ImmagineEsercizio?
  public let group: String?
  public let timed: Bool
  public let sets: Int
  public let sessions: Int
  public let lastDay: String
  public let best1RMKg: Double?
  public let bestDurationSeconds: Int?
  public let trend: [Double]
  public var id: String { key }

  public init(
    name: String, key: String, image: ImmagineEsercizio? = nil, group: String? = nil, timed: Bool = false,
    sets: Int = 0, sessions: Int = 0, lastDay: String, best1RMKg: Double? = nil,
    bestDurationSeconds: Int? = nil, trend: [Double] = []
  ) {
    self.name = name
    self.key = key
    self.image = image
    self.group = group
    self.timed = timed
    self.sets = sets
    self.sessions = sessions
    self.lastDay = lastDay
    self.best1RMKg = best1RMKg
    self.bestDurationSeconds = bestDurationSeconds
    self.trend = trend
  }

  /// Il numero sotto la foto: "1RM 102,5 kg" o "1:30" per quelli a tempo.
  public func migliore(_ formati: Formati = Formati()) -> String? {
    if timed { return bestDurationSeconds.map { Palestra.tempo($0) } }
    return best1RMKg.map { "1RM \(formati.peso($0))" }
  }

  /// "Petto", o "Da assegnare".
  public var nomeGruppo: String { Palestra.nomeGruppo(group) }
}

/// Un record battuto (GYM-010).
public struct RecordPalestra: Decodable, Equatable, Identifiable, Sendable {
  /// `e1rm`, `weight`, `reps`, `volume` o `duration`.
  public let kind: String
  public let value: Double
  public let weightKg: Double?
  public let day: String
  public let sessionId: String
  /// Solo nell'elenco degli ultimi giorni.
  public let exercise: Esercizio?

  public var id: String { "\(sessionId)-\(exercise?.key ?? "")-\(kind)-\(weightKg ?? 0)" }

  public init(
    kind: String, value: Double, weightKg: Double? = nil, day: String, sessionId: String,
    exercise: Esercizio? = nil
  ) {
    self.kind = kind
    self.value = value
    self.weightKg = weightKg
    self.day = day
    self.sessionId = sessionId
    self.exercise = exercise
  }

  public struct Esercizio: Decodable, Equatable, Sendable {
    public let name: String
    public let key: String
    public let image: ImmagineEsercizio?

    public init(name: String, key: String, image: ImmagineEsercizio? = nil) {
      self.name = name
      self.key = key
      self.image = image
    }
  }

  /// "1RM stimato · 102,5 kg", "8 ripetizioni a 80 kg", "Durata · 1:30".
  public func testo(_ formati: Formati = Formati()) -> String {
    switch kind {
    case "e1rm": return "1RM stimato · \(formati.peso(value))"
    case "weight": return "Peso più alto · \(formati.peso(value))"
    case "volume": return "Volume · \(formati.peso(value))"
    case "duration": return "Durata · \(Palestra.tempo(Int(value)))"
    case "reps":
      let peso = weightKg.map { " a \(formati.peso($0))" } ?? ""
      return "\(Formato.numero(value)) ripetizioni\(peso)"
    default: return Formato.numero(value)
    }
  }
}

/// Testi comuni della Palestra.
public enum Palestra {
  /// I gruppi muscolari dell'elenco fisso (GYM-011), nell'ordine del sito.
  public static let gruppi = [
    "petto", "schiena", "spalle", "bicipiti", "tricipiti", "gambe", "glutei", "addome", "altro",
  ]

  public static func nomeGruppo(_ gruppo: String?) -> String {
    guard let gruppo, !gruppo.isEmpty else { return "Da assegnare" }
    return gruppo.prefix(1).uppercased() + gruppo.dropFirst()
  }

  /// Una durata breve: "45 s", "1:30", "12:05".
  public static func tempo(_ secondi: Int) -> String {
    if secondi < 60 { return "\(secondi) s" }
    let resto = secondi % 60
    return "\(secondi / 60):\(resto < 10 ? "0" : "")\(resto)"
  }
}

extension RiepilogoAllenamento {
  /// Le ultime 12 settimane per il grafico, l'ultima è quella corrente.
  public var ultime12: [Settimana] { Array(weeks.suffix(12)) }

  /// Niente allenamenti: si mostra solo l'invito a importare il CSV.
  public var vuoto: Bool { last == nil && weeks.allSatisfy { $0.count == 0 } }
}

extension APIClient {
  /// `GET /workout/exercises`: dai più allenati con `piuAllenati`, se no
  /// dall'ultima volta.
  public func eserciziPalestra(
    cerca testo: String = "", piuAllenati: Bool = false, limite: Int? = nil, daCompletare: Bool = false
  ) async throws(APIError) -> [EsercizioPalestra] {
    struct Risposta: Decodable { let exercises: [EsercizioPalestra] }
    var query: [URLQueryItem] = []
    let parole = testo.trimmingCharacters(in: .whitespaces)
    if !parole.isEmpty { query.append(URLQueryItem(name: "q", value: parole)) }
    if piuAllenati { query.append(URLQueryItem(name: "sort", value: "sets")) }
    if let limite { query.append(URLQueryItem(name: "limit", value: String(limite))) }
    if daCompletare { query.append(URLQueryItem(name: "incomplete", value: "true")) }
    let risposta: Risposta = try await get("workout/exercises", query: query)
    return risposta.exercises
  }

  /// `GET /workout/records`: i record degli ultimi giorni.
  public func recordPalestra(giorni: Int = 30, limite: Int = 3) async throws(APIError) -> [RecordPalestra] {
    struct Risposta: Decodable { let records: [RecordPalestra] }
    let query = [
      URLQueryItem(name: "days", value: String(giorni)), URLQueryItem(name: "limit", value: String(limite)),
    ]
    let risposta: Risposta = try await get("workout/records", query: query)
    return risposta.records
  }

  /// Una foto del catalogo degli esercizi, con le stesse credenziali
  /// delle altre richieste.
  public func fotoEsercizio(_ immagine: ImmagineEsercizio) async throws(APIError) -> Data {
    try await dati(immagine.percorso)
  }
}
