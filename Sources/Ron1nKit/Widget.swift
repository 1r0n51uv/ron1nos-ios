import Foundation

extension ElementoLayout {
  /// Un'opzione di testo con il suo predefinito: la risorsa di
  /// `server.metric` vale `cpu` se non è salvata.
  public func opzione(_ chiave: String, predefinita: String) -> String {
    if case .testo(let valore) = options?[chiave] { return valore }
    return predefinita
  }

  public func opzione(_ chiave: String, predefinita: [String]) -> [String] {
    if case .elenco(let valore) = options?[chiave] { return valore }
    return predefinita
  }

  public func opzione(_ chiave: String, predefinita: Int) -> Int {
    if case .numero(let valore) = options?[chiave] { return valore }
    return predefinita
  }

  /// La variante scelta, o la prima del widget.
  public var compatto: Bool { variant == "compact" }
}

/// Una risorsa del server per `server.metric` (DASH-002).
public enum RisorsaServer: String, CaseIterable, Sendable {
  case cpu, ram, disk, net

  public var titolo: String {
    switch self {
    case .cpu: "CPU"
    case .ram: "RAM"
    case .disk: "Disco"
    case .net: "Rete"
    }
  }
}

extension StatoServer {
  /// Il valore di una risorsa in percentuale; nil per la rete.
  public func percentuale(_ risorsa: RisorsaServer) -> Double? {
    switch risorsa {
    case .cpu: cpu
    case .ram: ram
    case .disk: disk
    case .net: nil
    }
  }
}

/// L'allenamento per il widget, da `GET /workout/summary` (GYM-001).
public struct RiepilogoAllenamento: Decodable, Equatable, Sendable {
  public let today: String
  public let last: Ultimo?
  public let thisWeek: Int
  public let streakDays: Int
  public let weeks: [Settimana]

  public init(today: String, last: Ultimo?, thisWeek: Int, streakDays: Int, weeks: [Settimana]) {
    self.today = today
    self.last = last
    self.thisWeek = thisWeek
    self.streakDays = streakDays
    self.weeks = weeks
  }

  public struct Ultimo: Decodable, Equatable, Sendable {
    public let day: String
    public let routine: String
    public let durationSeconds: Int?
    /// La sessione, per aprirne il dettaglio (IOS-052).
    public let id: String?
    /// Il primo esercizio, con la foto (IOS-050).
    public let exercise: RifEsercizio?

    public init(
      day: String, routine: String, durationSeconds: Int?, id: String? = nil, exercise: RifEsercizio? = nil
    ) {
      self.day = day
      self.routine = routine
      self.durationSeconds = durationSeconds
      self.id = id
      self.exercise = exercise
    }
  }

  public struct Settimana: Decodable, Equatable, Sendable {
    public let monday: String
    public let count: Int

    public init(monday: String, count: Int) {
      self.monday = monday
      self.count = count
    }
  }

  /// "Push · ieri · 1 h 05 min"
  public var testoUltimo: String? {
    guard let last else { return nil }
    let parti = [
      last.routine.isEmpty ? "Allenamento" : last.routine,
      Giorni.relativo(last.day, oggi: today),
      last.durationSeconds.map(Formato.durata),
    ]
    return parti.compactMap { $0 }.joined(separator: " · ")
  }
}

/// Un documento nell'elenco, da `GET /documents/documents` (DOC-001): solo
/// tipo, titolo, titolare e scadenza, mai i valori dei campi.
public struct DocumentoBreve: Decodable, Equatable, Sendable {
  public let id: String
  public let typeName: String?
  public let title: String
  public let holder: String
  public let expiry: Scadenza?
  public let pinnedAt: String?
  /// Per l'elenco dei Documenti (IOS-060).
  public let typeId: String?
  public let typeIcon: String?
  public let expiresOn: String?
  public let tags: [String]?
  public let thumbFileId: String?
  /// I preavvisi attivi, per gli avvisi locali (IOS-065).
  public let warnings: [Int]?

  public init(
    id: String, typeName: String? = nil, title: String, holder: String = "Io", expiry: Scadenza? = nil,
    pinnedAt: String? = nil, typeId: String? = nil, typeIcon: String? = nil, expiresOn: String? = nil,
    tags: [String]? = nil, thumbFileId: String? = nil, warnings: [Int]? = nil
  ) {
    self.id = id
    self.typeName = typeName
    self.title = title
    self.holder = holder
    self.expiry = expiry
    self.pinnedAt = pinnedAt
    self.typeId = typeId
    self.typeIcon = typeIcon
    self.expiresOn = expiresOn
    self.tags = tags
    self.thumbFileId = thumbFileId
    self.warnings = warnings
  }

  public struct Scadenza: Decodable, Equatable, Sendable {
    /// `ok`, `expiring` o `expired`.
    public let status: String
    public let daysLeft: Int

    public init(status: String, daysLeft: Int) {
      self.status = status
      self.daysLeft = daysLeft
    }

    public var scaduto: Bool { status == "expired" }

    /// "Scade tra 30 giorni", "Scade domani", "Scaduto".
    public var testo: String {
      if scaduto { return "Scaduto" }
      if daysLeft == 0 { return "Scade oggi" }
      return daysLeft == 1 ? "Scade domani" : "Scade tra \(daysLeft) giorni"
    }
  }

  /// "Passaporto · Anna": il tipo al posto del titolo, il titolare se non
  /// sono io.
  public var etichetta: String {
    (typeName ?? title) + (holder == "Io" ? "" : " · \(holder)")
  }
}

/// Il widget Documenti (DOC-001): fissati e in scadenza entro 90 giorni.
public struct VistaDocumenti: Equatable, Sendable {
  public static let fissati = 4
  public static let orizzonte = 90

  public let fissati: [DocumentoBreve]
  public let inScadenza: [DocumentoBreve]
  /// Fra quanti giorni scade il prossimo oltre l'orizzonte.
  public let prossimo: Int?

  public init(_ documenti: [DocumentoBreve]) {
    fissati = Array(documenti.filter { $0.pinnedAt != nil }.prefix(VistaDocumenti.fissati))
    let datati = documenti.filter { $0.expiry != nil }.sorted {
      ($0.expiry?.daysLeft ?? 0) < ($1.expiry?.daysLeft ?? 0)
    }
    inScadenza = datati.filter { ($0.expiry?.daysLeft ?? 0) <= VistaDocumenti.orizzonte }
    prossimo = datati.first { ($0.expiry?.daysLeft ?? 0) > VistaDocumenti.orizzonte }?.expiry?.daysLeft
  }
}

/// Giorni `YYYY-MM-DD` come li dice il sito.
public enum Giorni {
  static let giorni = ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]

  static func data(_ giorno: String) -> Date? {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = TimeZone(identifier: "UTC")!
    let parti = giorno.split(separator: "-").compactMap { Int($0) }
    guard parti.count == 3 else { return nil }
    return calendario.date(from: DateComponents(year: parti[0], month: parti[1], day: parti[2], hour: 12))
  }

  /// "oggi", "ieri", o "lunedì 26 ottobre".
  public static func relativo(_ giorno: String, oggi: String) -> String {
    guard let quando = data(giorno), let adesso = data(oggi) else { return giorno }
    let diff = Int((adesso.timeIntervalSince(quando) / 86_400).rounded())
    if diff == 0 { return "oggi" }
    if diff == 1 { return "ieri" }
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = TimeZone(identifier: "UTC")!
    let p = calendario.dateComponents([.weekday, .day, .month], from: quando)
    return "\(giorni[(p.weekday ?? 1) - 1]) \(p.day ?? 1) \(Testata.mesi[(p.month ?? 1) - 1])"
  }
}

extension Formato {
  /// Durata di un allenamento: "45 min", "1 h 05 min".
  public static func durata(_ secondi: Int) -> String {
    let minuti = Int((Double(secondi) / 60).rounded())
    if minuti < 60 { return "\(minuti) min" }
    let resto = minuti % 60
    return "\(minuti / 60) h \(resto < 10 ? "0" : "")\(resto) min"
  }
}

extension APIClient {
  /// `GET /workout/summary`.
  public func allenamento() async throws(APIError) -> RiepilogoAllenamento {
    try await get("workout/summary")
  }

  /// `GET /documents/documents`: l'elenco, senza i valori dei campi.
  public func documenti() async throws(APIError) -> [DocumentoBreve] {
    try await get("documents/documents")
  }
}
