import Foundation

/// Una riga dello storico (GYM-004): i primi tre esercizi con la foto.
public struct SessionePalestra: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let day: String
  public let routine: String
  public let startedAt: String
  public let durationSeconds: Int?
  public let exercises: [RifEsercizio]

  public init(
    id: String, day: String, routine: String, startedAt: String = "", durationSeconds: Int? = nil,
    exercises: [RifEsercizio] = []
  ) {
    self.id = id
    self.day = day
    self.routine = routine
    self.startedAt = startedAt
    self.durationSeconds = durationSeconds
    self.exercises = exercises
  }

  /// "Push", o "Allenamento" senza routine.
  public var titolo: String { Palestra.titolo(routine) }

  /// "ieri · 1 h 05 min".
  public func sottotitolo(oggi: String) -> String {
    Palestra.quando(day, durata: durationSeconds, oggi: oggi)
  }
}

/// Una pagina dello storico.
public struct PaginaSessioni: Decodable, Equatable, Sendable {
  public let sessions: [SessionePalestra]
  public let nextCursor: String?

  public init(sessions: [SessionePalestra], nextCursor: String? = nil) {
    self.sessions = sessions
    self.nextCursor = nextCursor
  }
}

/// Lo storico caricato finora, a pagine da 20 (GYM-004).
public struct StoricoPalestra: Equatable, Sendable {
  public private(set) var sessioni: [SessionePalestra] = []
  /// Il `nextCursor` da chiedere; nil quando è finito.
  public private(set) var cursore: String?
  public private(set) var finito = false

  public init() {}

  /// Aggiunge una pagina in fondo, senza doppioni.
  public mutating func aggiungi(_ pagina: PaginaSessioni) {
    let presenti = Set(sessioni.map(\.id))
    sessioni += pagina.sessions.filter { !presenti.contains($0.id) }
    cursore = pagina.nextCursor
    finito = pagina.nextCursor == nil
  }

  /// Toglie una sessione eliminata.
  public mutating func togli(_ id: String) {
    sessioni.removeAll { $0.id == id }
  }

  /// La riga che, quando appare, chiede la pagina dopo.
  public func chiedeAltre(_ sessione: SessionePalestra) -> Bool {
    !finito && sessione.id == sessioni.last?.id
  }
}

/// Il dettaglio di una sessione (GYM-005).
public struct DettaglioSessione: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let day: String
  public let routine: String
  public let startedAt: String
  public let durationSeconds: Int?
  /// Senza riscaldamento.
  public let volumeKg: Double
  public let exercises: [Esercizio]

  public init(
    id: String, day: String, routine: String, startedAt: String = "", durationSeconds: Int? = nil,
    volumeKg: Double = 0, exercises: [Esercizio] = []
  ) {
    self.id = id
    self.day = day
    self.routine = routine
    self.startedAt = startedAt
    self.durationSeconds = durationSeconds
    self.volumeKg = volumeKg
    self.exercises = exercises
  }

  public struct Esercizio: Decodable, Equatable, Identifiable, Sendable {
    public let name: String
    public let key: String
    public let image: ImmagineEsercizio?
    public let timed: Bool
    public let volumeKg: Double
    /// Miglior 1RM stimato rispetto alle sessioni prima (GYM-010).
    public let record: Bool
    public let sets: [Serie]
    public var id: String { key }

    public init(
      name: String, key: String, image: ImmagineEsercizio? = nil, timed: Bool = false, volumeKg: Double = 0,
      record: Bool = false, sets: [Serie] = []
    ) {
      self.name = name
      self.key = key
      self.image = image
      self.timed = timed
      self.volumeKg = volumeKg
      self.record = record
      self.sets = sets
    }
  }

  public struct Serie: Decodable, Equatable, Identifiable, Sendable {
    public let index: Int
    public let warmup: Bool
    public let weightKg: Double
    public let reps: Int?
    public let durationSeconds: Int?
    public var id: Int { index }

    public init(
      index: Int, warmup: Bool = false, weightKg: Double, reps: Int? = nil, durationSeconds: Int? = nil
    ) {
      self.index = index
      self.warmup = warmup
      self.weightKg = weightKg
      self.reps = reps
      self.durationSeconds = durationSeconds
    }

    /// "80 kg × 8", "1:30", "20 kg · 1:30" o "× 12" a corpo libero.
    public func testo(_ formati: Formati = Formati()) -> String {
      let peso = weightKg > 0 ? formati.peso(weightKg) : nil
      if let durata = durationSeconds, reps == nil {
        return [peso, Palestra.tempo(durata)].compactMap { $0 }.joined(separator: " · ")
      }
      let ripetizioni = reps.map { "× \($0)" }
      return [peso, ripetizioni].compactMap { $0 }.joined(separator: " ")
    }
  }

  public var titolo: String { Palestra.titolo(routine) }

  public func sottotitolo(oggi: String) -> String {
    Palestra.quando(day, durata: durationSeconds, oggi: oggi)
  }

  /// Gli esercizi con volume, per le barre: il più pesante va in rosso.
  public var barre: [Esercizio] { exercises.filter { $0.volumeKg > 0 } }

  /// L'esercizio con più volume.
  public var piuPesante: String? { barre.max { $0.volumeKg < $1.volumeKg }?.key }

  /// La lunghezza della barra, da 0 a 1.
  public func quota(_ esercizio: Esercizio) -> Double {
    let massimo = barre.map(\.volumeKg).max() ?? 0
    return massimo > 0 ? esercizio.volumeKg / massimo : 0
  }
}

extension Palestra {
  static func titolo(_ routine: String) -> String {
    routine.isEmpty ? "Allenamento" : routine
  }

  static func quando(_ giorno: String, durata: Int?, oggi: String) -> String {
    [Giorni.relativo(giorno, oggi: oggi), durata.map { Formato.durata($0) }]
      .compactMap { $0 }
      .joined(separator: " · ")
  }
}

extension APIClient {
  /// `GET /workout/sessions`: una pagina dello storico, dalla più recente.
  public func sessioniPalestra(
    routine: String? = nil, cursore: String? = nil
  ) async throws(APIError) -> PaginaSessioni {
    var query: [URLQueryItem] = []
    if let routine { query.append(URLQueryItem(name: "routine", value: routine)) }
    if let cursore { query.append(URLQueryItem(name: "cursor", value: cursore)) }
    return try await get("workout/sessions", query: query)
  }

  /// `GET /workout/routines`: i nomi per il filtro.
  public func routinePalestra() async throws(APIError) -> [String] {
    struct Risposta: Decodable { let routines: [String] }
    let risposta: Risposta = try await get("workout/routines")
    return risposta.routines
  }

  /// `GET /workout/sessions/{id}`.
  public func sessionePalestra(_ id: String) async throws(APIError) -> DettaglioSessione {
    try await get("workout/sessions/\(id)")
  }

  /// `DELETE /workout/sessions/{id}` (GYM-006): un nuovo import non la riporta.
  public func eliminaSessione(_ id: String) async throws(APIError) {
    _ = try await dati("workout/sessions/\(id)", metodo: "DELETE")
  }
}
