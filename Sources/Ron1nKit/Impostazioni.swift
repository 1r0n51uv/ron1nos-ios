import Foundation

/// Le sezioni delle Impostazioni (IOS-090, SET-001), nei quattro gruppi
/// dell'app.
public enum VoceImpostazioni: String, CaseIterable, Hashable, Sendable {
  case accesso, notifiche
  case aspetto, dashboard, moduli, navigazione, formati
  case account, appIOS
  case integrazioni, backup, informazioni

  public var titolo: String {
    switch self {
    case .accesso: "Accesso"
    case .notifiche: "Notifiche e Salute"
    case .aspetto: "Aspetto"
    case .dashboard: "Dashboard"
    case .moduli: "Moduli"
    case .navigazione: "Navigazione"
    case .formati: "Formati"
    case .account: "Account"
    case .appIOS: "App iOS"
    case .integrazioni: "Integrazioni"
    case .backup: "Backup configurazione"
    case .informazioni: "Informazioni"
    }
  }

  /// Il simbolo SF della riga.
  public var icona: String {
    switch self {
    case .accesso: "key"
    case .notifiche: "bell"
    case .aspetto: "paintbrush"
    case .dashboard: "square.grid.2x2"
    case .moduli: "switch.2"
    case .navigazione: "list.bullet"
    case .formati: "textformat.123"
    case .account: "person.crop.circle"
    case .appIOS: "iphone"
    case .integrazioni: "point.3.connected.trianglepath.dotted"
    case .backup: "arrow.up.arrow.down.square"
    case .informazioni: "info.circle"
    }
  }

  public struct Gruppo: Sendable {
    public let titolo: String
    public let voci: [VoceImpostazioni]
  }

  public static let gruppi = [
    Gruppo(titolo: "Questo iPhone", voci: [.accesso, .notifiche]),
    Gruppo(titolo: "ron1nOS", voci: [.aspetto, .dashboard, .moduli, .navigazione, .formati]),
    Gruppo(titolo: "Account", voci: [.account, .appIOS]),
    Gruppo(titolo: "Sistema", voci: [.integrazioni, .backup, .informazioni]),
  ]
}

/// Quello che serve per lo stato in breve a destra di ogni riga. Una parte
/// che non si è potuta leggere resta nil e la riga non mostra nulla.
public struct StatoImpostazioni: Equatable, Sendable {
  public var preferenze: Preferenze
  public var credenziali: Bool
  public var login: StatoLogin?
  public var notificheAccese: Int
  public var widget: Int?
  public var sessioni: Int?
  public var token: Int?
  public var integrazioni: [Integrazione]?
  public var versioneApp: String?

  public init(
    preferenze: Preferenze, credenziali: Bool, login: StatoLogin? = nil, notificheAccese: Int = 0,
    widget: Int? = nil, sessioni: Int? = nil, token: Int? = nil, integrazioni: [Integrazione]? = nil,
    versioneApp: String? = nil
  ) {
    self.preferenze = preferenze
    self.credenziali = credenziali
    self.login = login
    self.notificheAccese = notificheAccese
    self.widget = widget
    self.sessioni = sessioni
    self.token = token
    self.integrazioni = integrazioni
    self.versioneApp = versioneApp
  }

  /// I moduli che si possono spegnere (SET-005), come sul sito.
  public static let moduli = [
    "nutrition", "workout", "weight", "home", "server", "containers", "downloads", "notes", "documents",
  ]

  /// "collegato", "medio", "5 accesi"…
  public func riepilogo(_ voce: VoceImpostazioni) -> String? {
    switch voce {
    case .accesso:
      guard credenziali else { return "da configurare" }
      guard let login, login.problema else { return "collegato" }
      return login.testo
    case .notifiche:
      return notificheAccese == 0 ? "spente" : "\(notificheAccese) accese"
    case .aspetto:
      return StatoImpostazioni.vetro(preferenze.appearance.glass)
    case .dashboard:
      return widget.map { $0 == 1 ? "1 widget" : "\($0) widget" }
    case .moduli:
      let spenti = StatoImpostazioni.moduli.filter { preferenze.disabledModules.contains($0) }.count
      let accesi = StatoImpostazioni.moduli.count - spenti
      return accesi == 1 ? "1 acceso" : "\(accesi) accesi"
    case .navigazione:
      let inBarra = Navigazione(preferenze).schede.filter { $0 != .home && $0 != .altro }
      return inBarra.first.map { "prima \($0.titolo)" }
    case .formati:
      let formati = preferenze.formats
      return "\(formati.weightUnit.rawValue) · \(formati.energyUnit.rawValue)"
    case .account:
      return sessioni.map { $0 == 1 ? "1 sessione" : "\($0) sessioni" }
    case .appIOS:
      return token.map { $0 == 1 ? "1 token" : "\($0) token" }
    case .integrazioni:
      guard let integrazioni else { return nil }
      let errori = integrazioni.filter { $0.state == .error }.count
      if errori > 0 { return errori == 1 ? "1 in errore" : "\(errori) in errore" }
      let collegate = integrazioni.filter { $0.state == .connected }.count
      return "\(collegate) di \(integrazioni.count) collegate"
    case .backup:
      return nil
    case .informazioni:
      return versioneApp
    }
  }

  /// Da segnare in rosso.
  public func segnale(_ voce: VoceImpostazioni) -> Bool {
    switch voce {
    case .accesso: !credenziali || login?.problema == true
    case .integrazioni: integrazioni?.contains { $0.state == .error } == true
    default: false
    }
  }

  public static func vetro(_ vetro: Aspetto.Vetro) -> String {
    switch vetro {
    case .light: "leggero"
    case .medium: "medio"
    case .strong: "forte"
    }
  }
}

/// Una sessione web del login (SET-007).
public struct SessioneWeb: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  /// "Safari su iPhone".
  public let device: String
  public let createdAt: String
  public let lastSeenAt: String
  /// La sessione di questa richiesta.
  public let current: Bool

  public init(id: String, device: String, createdAt: String, lastSeenAt: String, current: Bool = false) {
    self.id = id
    self.device = device
    self.createdAt = createdAt
    self.lastSeenAt = lastSeenAt
    self.current = current
  }
}

/// Un token dell'app iOS (AUTH-005, SET-008). Il segreto non torna mai.
public struct TokenApp: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let createdAt: String
  public let lastUsedAt: String?

  public init(id: String, name: String, createdAt: String, lastUsedAt: String? = nil) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
  }
}

/// Un servizio esterno (SET-009): Postgres, YAZIO, qBittorrent, Glances,
/// Home Assistant.
public struct Integrazione: Decodable, Equatable, Identifiable, Sendable {
  public enum Stato: String, Decodable, Sendable {
    case connected, error
    case notConfigured = "not_configured"
  }

  public let id: String
  public let name: String
  public let state: Stato
  /// Il motivo dell'errore, già in italiano.
  public let message: String?
  public let checkedAt: String
  /// Le variabili del `.env` da impostare, solo se non configurato.
  public let env: [String]

  public init(
    id: String, name: String, state: Stato, message: String? = nil, checkedAt: String, env: [String] = []
  ) {
    self.id = id
    self.name = name
    self.state = state
    self.message = message
    self.checkedAt = checkedAt
    self.env = env
  }
}

extension APIClient {
  /// `GET /auth/sessions`.
  public func sessioniWeb() async throws(APIError) -> [SessioneWeb] {
    struct Risposta: Decodable { let sessions: [SessioneWeb] }
    let risposta: Risposta = try await get("auth/sessions")
    return risposta.sessions
  }

  /// `GET /auth/tokens`.
  public func tokenApp() async throws(APIError) -> [TokenApp] {
    struct Risposta: Decodable { let tokens: [TokenApp] }
    let risposta: Risposta = try await get("auth/tokens")
    return risposta.tokens
  }

  /// `GET /integrations`.
  public func integrazioni() async throws(APIError) -> [Integrazione] {
    struct Risposta: Decodable { let integrations: [Integrazione] }
    let risposta: Risposta = try await get("integrations")
    return risposta.integrations
  }
}
