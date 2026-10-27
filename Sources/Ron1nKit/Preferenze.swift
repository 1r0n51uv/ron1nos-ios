/// Le preferenze di ron1nOS, da `GET /api/v1/preferences` (SET-002 del
/// sito): una per tutti i dispositivi. I campi che mancano valgono il
/// predefinito, così una versione nuova del backend non rompe l'app.
public struct Preferenze: Codable, Equatable, Sendable {
  /// Moduli spenti nelle Impostazioni (SET-005): `nutrition`, `workout`…
  public var disabledModules: [String]
  /// Ordine delle voci della barra del sito (SET-006): `pasti`,
  /// `allenamenti`, `documenti`, `note`, `casa`, `server`.
  public var navOrder: [String]

  public static let predefinite = Preferenze(
    disabledModules: [], navOrder: ["pasti", "allenamenti", "documenti", "note", "casa", "server"])

  public init(disabledModules: [String], navOrder: [String]) {
    self.disabledModules = disabledModules
    self.navOrder = navOrder
  }

  enum CodingKeys: String, CodingKey {
    case disabledModules, navOrder
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let base = Preferenze.predefinite
    disabledModules = c.leggi([String].self, .disabledModules) ?? base.disabledModules
    navOrder = c.leggi([String].self, .navOrder) ?? base.navOrder
  }
}

extension KeyedDecodingContainer {
  /// Il valore se c'è ed è valido, se no nil: un campo rotto non fa
  /// fallire tutto il resto.
  func leggi<T: Decodable>(_ tipo: T.Type, _ chiave: Key) -> T? {
    (try? decodeIfPresent(tipo, forKey: chiave)) ?? nil
  }
}

extension APIClient {
  /// `GET /preferences`.
  public func preferenze() async throws(APIError) -> Preferenze {
    try await get("preferences")
  }
}
