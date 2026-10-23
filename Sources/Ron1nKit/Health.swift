/// Risposta di `GET /api/v1/health` (api/openapi.yaml di ron1nOS).
public struct Health: Decodable, Equatable, Sendable {
  public let ok: Bool
  public let database: DatabaseState

  public init(ok: Bool, database: DatabaseState) {
    self.ok = ok
    self.database = database
  }
}

/// Stato del Postgres del backend. Un valore che l'app non conosce ancora
/// non è un errore: diventa `sconosciuto`.
public enum DatabaseState: Equatable, Sendable {
  case disabled
  case starting
  case ok
  case unavailable
  case sconosciuto(String)

  /// Come appare nella schermata.
  public var testo: String {
    switch self {
    case .ok: "pronto"
    case .starting: "in avvio"
    case .disabled: "spento"
    case .unavailable: "non risponde"
    case .sconosciuto(let valore): "stato \(valore)"
    }
  }

  /// Da segnalare in rosso: il database c'è ma non risponde.
  public var problema: Bool {
    self == .unavailable
  }
}

extension DatabaseState: Decodable {
  public init(from decoder: Decoder) throws {
    let valore = try decoder.singleValueContainer().decode(String.self)
    switch valore {
    case "disabled": self = .disabled
    case "starting": self = .starting
    case "ok": self = .ok
    case "unavailable": self = .unavailable
    default: self = .sconosciuto(valore)
    }
  }
}
