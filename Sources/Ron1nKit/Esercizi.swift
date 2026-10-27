import Foundation

/// La pagina di un esercizio (GYM-008): tre numeri, i punti dei grafici,
/// le ultime 3 volte e i record.
public struct DettaglioEsercizio: Decodable, Equatable, Sendable {
  public let name: String
  public let key: String
  public let image: ImmagineEsercizio?
  public let group: String?
  public let timed: Bool
  public let best1RMKg: Double?
  public let heaviestKg: Double?
  public let bestDurationSeconds: Int?
  public let sessions: Int
  public let range: String
  public let points: [Punto]
  public let records: [RecordPalestra]
  public let recent: [Volta]

  public init(
    name: String, key: String, image: ImmagineEsercizio? = nil, group: String? = nil, timed: Bool = false,
    best1RMKg: Double? = nil, heaviestKg: Double? = nil, bestDurationSeconds: Int? = nil, sessions: Int = 0,
    range: String = "6m", points: [Punto] = [], records: [RecordPalestra] = [], recent: [Volta] = []
  ) {
    self.name = name
    self.key = key
    self.image = image
    self.group = group
    self.timed = timed
    self.best1RMKg = best1RMKg
    self.heaviestKg = heaviestKg
    self.bestDurationSeconds = bestDurationSeconds
    self.sessions = sessions
    self.range = range
    self.points = points
    self.records = records
    self.recent = recent
  }

  /// Una sessione nel periodo, dalla meno recente.
  public struct Punto: Decodable, Equatable, Identifiable, Sendable {
    public let sessionId: String
    public let day: String
    public let best1RMKg: Double
    public let volumeKg: Double
    public let bestDurationSeconds: Int
    public let totalDurationSeconds: Int
    public var id: String { sessionId }

    public init(
      sessionId: String, day: String, best1RMKg: Double = 0, volumeKg: Double = 0,
      bestDurationSeconds: Int = 0, totalDurationSeconds: Int = 0
    ) {
      self.sessionId = sessionId
      self.day = day
      self.best1RMKg = best1RMKg
      self.volumeKg = volumeKg
      self.bestDurationSeconds = bestDurationSeconds
      self.totalDurationSeconds = totalDurationSeconds
    }
  }

  /// Una delle ultime 3 volte.
  public struct Volta: Decodable, Equatable, Identifiable, Sendable {
    public let sessionId: String
    public let day: String
    public let best1RMKg: Double?
    public let sets: [Serie]
    public var id: String { sessionId }

    public init(sessionId: String, day: String, best1RMKg: Double? = nil, sets: [Serie] = []) {
      self.sessionId = sessionId
      self.day = day
      self.best1RMKg = best1RMKg
      self.sets = sets
    }
  }

  public struct Serie: Decodable, Equatable, Sendable {
    public let warmup: Bool
    public let weightKg: Double
    public let reps: Int?
    public let durationSeconds: Int?

    public init(warmup: Bool = false, weightKg: Double, reps: Int? = nil, durationSeconds: Int? = nil) {
      self.warmup = warmup
      self.weightKg = weightKg
      self.reps = reps
      self.durationSeconds = durationSeconds
    }

    public func testo(_ formati: Formati = Formati()) -> String {
      Palestra.serie(peso: weightKg, reps: reps, durata: durationSeconds, formati: formati)
    }
  }

  /// Uno dei tre numeri della testata.
  public struct Numero: Equatable, Sendable {
    public let valore: String
    public let titolo: String
  }

  /// I tre numeri: 1RM stimato, peso più alto e sessioni; per gli esercizi
  /// a tempo la durata migliore al posto dei primi due.
  public func numeri(_ formati: Formati = Formati()) -> [Numero] {
    let sessioni = Numero(valore: "\(sessions)", titolo: "SESSIONI")
    if timed {
      let durata = bestDurationSeconds.map { Palestra.tempo($0) } ?? "—"
      return [Numero(valore: durata, titolo: "DURATA MIGLIORE"), sessioni]
    }
    return [
      Numero(valore: best1RMKg.map { formati.peso($0) } ?? "—", titolo: "1RM STIMATO"),
      Numero(valore: heaviestKg.map { formati.peso($0) } ?? "—", titolo: "PESO PIÙ ALTO"),
      sessioni,
    ]
  }

  /// Il grafico scelto: il migliore della sessione o il totale.
  public enum Grafico: String, CaseIterable, Sendable {
    case migliore, totale

    public func titolo(aTempo: Bool) -> String {
      switch self {
      case .migliore: aTempo ? "Durata migliore" : "1RM stimato"
      case .totale: aTempo ? "Durata totale" : "Volume"
      }
    }
  }

  /// I valori del grafico: kg, o secondi per gli esercizi a tempo.
  public func valori(_ grafico: Grafico) -> [Double] {
    points.map { punto in
      switch (grafico, timed) {
      case (.migliore, false): punto.best1RMKg
      case (.totale, false): punto.volumeKg
      case (.migliore, true): Double(punto.bestDurationSeconds)
      case (.totale, true): Double(punto.totalDurationSeconds)
      }
    }
  }

  public var nomeGruppo: String { Palestra.nomeGruppo(group) }
}

/// Il periodo del grafico (GYM-008).
public enum PeriodoEsercizio: String, CaseIterable, Sendable {
  case tre = "3m"
  case sei = "6m"
  case anno = "1y"
  case tutto = "all"

  public var titolo: String {
    switch self {
    case .tre: "3 mesi"
    case .sei: "6 mesi"
    case .anno: "1 anno"
    case .tutto: "Tutto"
    }
  }
}

extension EsercizioPalestra {
  /// Senza gruppo o senza foto: va completato (GYM-009).
  public var daCompletare: Bool { group == nil || image == nil }
}

extension APIClient {
  /// `GET /workout/exercises/{name}`: la pagina di un esercizio.
  public func esercizioPalestra(
    _ nome: String, periodo: PeriodoEsercizio = .sei
  ) async throws(APIError) -> DettaglioEsercizio {
    try await get(
      "workout/exercises/\(APIClient.segmento(nome))",
      query: [URLQueryItem(name: "range", value: periodo.rawValue)])
  }
}
