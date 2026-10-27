import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

extension Integrazione.Stato {
  /// "collegato", "errore", "non configurato".
  public var testo: String {
    switch self {
    case .connected: "collegato"
    case .error: "errore"
    case .notConfigured: "non configurato"
    }
  }
}

/// Versione e avvio del backend (SET-012), da `GET /about`.
public struct Informazioni: Decodable, Equatable, Sendable {
  public struct Versione: Decodable, Equatable, Sendable {
    /// null fuori da un'immagine della pipeline.
    public let commit: String?
    public let builtAt: String?

    public init(commit: String? = nil, builtAt: String? = nil) {
      self.commit = commit
      self.builtAt = builtAt
    }
  }

  public let version: Versione
  public let startedAt: String
  public let uptimeSeconds: Int

  public init(version: Versione, startedAt: String, uptimeSeconds: Int) {
    self.version = version
    self.startedAt = startedAt
    self.uptimeSeconds = uptimeSeconds
  }

  public static let repository = "https://github.com/1r0n51uv/ron1nOS"
  public static let repositoryApp = "https://github.com/1r0n51uv/ron1nos-ios"

  /// "a1b2c3d" o "build locale".
  public var commitBreve: String { version.commit.map { String($0.prefix(7)) } ?? "build locale" }

  /// Il commit sul repository, se c'è.
  public var indirizzoCommit: URL? {
    version.commit.flatMap { URL(string: "\(Informazioni.repository)/commit/\($0)") }
  }
}

/// Cosa cambierebbe un backup importato (SET-011), da
/// `POST /preferences/import`.
public struct EsitoBackup: Decodable, Equatable, Sendable {
  public let changes: [String]
  public let notes: [String]
  public let applied: Bool

  public init(changes: [String], notes: [String] = [], applied: Bool = false) {
    self.changes = changes
    self.notes = notes
    self.applied = applied
  }

  public var nienteDaCambiare: Bool { changes.isEmpty }

  /// Il nome del file del backup: "ron1nos-configurazione-2026-10-27.json".
  public static func nomeFile(
    adesso: Date = Date(), fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    return "ron1nos-configurazione-\(Striscia.testo(adesso, calendario: calendario)).json"
  }
}

extension APIClient {
  /// `POST /integrations/{id}/check`: il servizio appena controllato.
  public func verificaIntegrazione(_ id: String) async throws(APIError) -> Integrazione {
    try await invia("POST", "integrations/\(APIClient.segmento(id))/check")
  }

  /// `GET /about`.
  public func informazioni() async throws(APIError) -> Informazioni {
    try await get("about")
  }

  /// `GET /preferences/export`: il file così com'è, da condividere.
  public func esportaConfigurazione() async throws(APIError) -> Data {
    try await dati("preferences/export")
  }

  /// `POST /preferences/import`: senza conferma dice solo cosa cambierebbe.
  /// Un file non valido torna con il messaggio del server.
  public func importaConfigurazione(
    _ file: Data, conferma: Bool
  ) async throws(APIError) -> Esito<EsitoBackup> {
    let query = conferma ? [URLQueryItem(name: "confirm", value: "1")] : []
    let (data, http) = try await risposta("preferences/import", query: query, metodo: "POST", corpo: file)
    return try APIClient.esito(data, http, conMessaggio: [400, 422])
  }
}
