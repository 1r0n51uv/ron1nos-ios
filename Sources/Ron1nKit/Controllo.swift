import Foundation

/// L'ultimo controllo del server, come lo mostra la schermata.
public enum Controllo: Equatable, Sendable {
  case inCorso
  case riuscito(Health, quando: Date)
  case fallito(APIError, quando: Date)

  /// Esegue un controllo con `client`. `adesso` si passa nei test.
  public static func esegui(
    con client: APIClient, adesso: @Sendable () -> Date = Date.init
  ) async -> Controllo {
    do {
      let health = try await client.health()
      return .riuscito(health, quando: adesso())
    } catch {
      return .fallito(error, quando: adesso())
    }
  }

  /// Stato del backend in una parola.
  public var backend: String {
    switch self {
    case .inCorso: "controllo…"
    case .riuscito: "raggiungibile"
    case .fallito(.nonRaggiungibile, _), .fallito(.certificato, _): "non raggiungibile"
    case .fallito: "risponde con errori"
    }
  }

  public var quando: Date? {
    switch self {
    case .inCorso: nil
    case .riuscito(_, let quando), .fallito(_, let quando): quando
    }
  }

  /// "Ultimo controllo · 16:05", nel fuso dato.
  public func testoOra(fuso: TimeZone = .current) -> String? {
    guard let quando else { return nil }
    let formato = DateFormatter()
    formato.locale = Locale(identifier: "it_IT")
    formato.timeZone = fuso
    formato.dateFormat = "HH:mm:ss"
    return "Ultimo controllo · \(formato.string(from: quando))"
  }
}
