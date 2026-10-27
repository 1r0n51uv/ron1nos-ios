import Foundation

/// Le preferenze di ron1nOS, da `GET /api/v1/preferences` (SET-002 del
/// sito): una per tutti i dispositivi. I campi che mancano o non si
/// capiscono valgono il predefinito, così una versione nuova del backend
/// non rompe l'app.
public struct Preferenze: Codable, Equatable, Sendable {
  public var appearance: Aspetto
  /// Moduli spenti nelle Impostazioni (SET-005): `nutrition`, `workout`…
  public var disabledModules: [String]
  /// Ordine delle voci della barra del sito (SET-006): `pasti`,
  /// `allenamenti`, `documenti`, `note`, `casa`, `server`.
  public var navOrder: [String]
  public var formats: Formati
  /// Quando è stata caricata l'immagine di sfondo, se c'è (SET-003).
  public var backgroundImage: String?

  public static let predefinite = Preferenze(
    disabledModules: [], navOrder: ["pasti", "allenamenti", "documenti", "note", "casa", "server"])

  public init(
    appearance: Aspetto = Aspetto(), disabledModules: [String], navOrder: [String],
    formats: Formati = Formati(), backgroundImage: String? = nil
  ) {
    self.appearance = appearance
    self.disabledModules = disabledModules
    self.navOrder = navOrder
    self.formats = formats
    self.backgroundImage = backgroundImage
  }

  enum CodingKeys: String, CodingKey {
    case appearance, disabledModules, navOrder, formats, backgroundImage
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let base = Preferenze.predefinite
    appearance = c.leggi(Aspetto.self, .appearance) ?? base.appearance
    disabledModules = c.leggi([String].self, .disabledModules) ?? base.disabledModules
    navOrder = c.leggi([String].self, .navOrder) ?? base.navOrder
    formats = c.leggi(Formati.self, .formats) ?? base.formats
    backgroundImage = c.leggi(String.self, .backgroundImage)
  }

  /// Lo sfondo da mostrare: `image` senza immagine caricata torna `brace`,
  /// come sul sito.
  public var sfondo: Aspetto.Sfondo {
    appearance.background == .image && backgroundImage == nil ? .brace : appearance.background
  }
}

/// Aspetto (SET-003): sfondo, vetro e densità.
public struct Aspetto: Codable, Equatable, Sendable {
  public enum Sfondo: String, Codable, Sendable { case brace, nebbia, grafite, nero, image }
  public enum Vetro: String, Codable, Sendable { case light, medium, strong }
  public enum Densita: String, Codable, Sendable { case comfortable, compact }

  public var background: Sfondo
  public var glass: Vetro
  public var density: Densita

  public init(background: Sfondo = .brace, glass: Vetro = .medium, density: Densita = .comfortable) {
    self.background = background
    self.glass = glass
    self.density = density
  }

  enum CodingKeys: String, CodingKey { case background, glass, density }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let base = Aspetto()
    background = c.leggi(Sfondo.self, .background) ?? base.background
    glass = c.leggi(Vetro.self, .glass) ?? base.glass
    density = c.leggi(Densita.self, .density) ?? base.density
  }

  /// Il velo bianco delle card (IOS-003): 4%, 6% o 10%.
  public var velo: Double {
    switch glass {
    case .light: 0.04
    case .medium: 0.06
    case .strong: 0.10
    }
  }

  /// Quanto è acceso il bordo di luce, rispetto al vetro medio.
  public var luce: Double {
    switch glass {
    case .light: 0.7
    case .medium: 1
    case .strong: 1.4
    }
  }

  /// Padding dentro le card, in punti.
  public var padding: Double { density == .compact ? 14 : 20 }

  /// Spazio fra le card, in punti.
  public var spazio: Double { density == .compact ? 10 : 14 }
}

/// Formati (SET-010): cambiano solo come si leggono i numeri, i dati
/// restano in kg e kcal.
public struct Formati: Codable, Equatable, Sendable {
  public enum Peso: String, Codable, Sendable { case kg, lb }
  public enum Energia: String, Codable, Sendable { case kcal, kJ }

  public static let kJPerKcal = 4.184
  public static let lbPerKg = 2.20462262

  public var timeZone: String
  public var weightUnit: Peso
  public var energyUnit: Energia

  public init(timeZone: String = "Europe/Rome", weightUnit: Peso = .kg, energyUnit: Energia = .kcal) {
    self.timeZone = timeZone
    self.weightUnit = weightUnit
    self.energyUnit = energyUnit
  }

  enum CodingKeys: String, CodingKey { case timeZone, weightUnit, energyUnit }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let base = Formati()
    timeZone = c.leggi(String.self, .timeZone) ?? base.timeZone
    weightUnit = c.leggi(Peso.self, .weightUnit) ?? base.weightUnit
    energyUnit = c.leggi(Energia.self, .energyUnit) ?? base.energyUnit
  }

  /// Il fuso scelto; se iOS non lo conosce, Roma.
  public var fuso: TimeZone { TimeZone(identifier: timeZone) ?? TimeZone(identifier: "Europe/Rome")! }

  /// Energia nell'unità scelta: "1.840 kcal" o "7.699 kJ".
  public func energia(_ kcal: Double) -> String {
    "\(Formato.numero(valoreEnergia(kcal))) \(energyUnit.rawValue)"
  }

  public func valoreEnergia(_ kcal: Double) -> Double {
    energyUnit == .kJ ? kcal * Formati.kJPerKcal : kcal
  }

  /// Peso nell'unità scelta, con i decimali solo se servono: "92,5 kg".
  public func peso(_ kg: Double) -> String {
    let valore = weightUnit == .lb ? kg * Formati.lbPerKg : kg
    let decimali = valore.rounded() == valore ? 0 : (weightUnit == .lb ? 1 : 2)
    var testo = Formato.numero(valore, decimali: decimali)
    while decimali > 0, testo.hasSuffix("0") { testo.removeLast() }
    if testo.hasSuffix(",") { testo.removeLast() }
    return "\(testo) \(weightUnit.rawValue)"
  }
}

extension KeyedDecodingContainer {
  /// Il valore se c'è ed è valido, se no nil: un campo rotto non fa
  /// fallire tutto il resto.
  func leggi<T: Decodable>(_ tipo: T.Type, _ chiave: Key) -> T? {
    (try? decodeIfPresent(tipo, forKey: chiave)) ?? nil
  }
}

/// Le ultime preferenze lette, sul telefono: all'avvio valgono queste
/// finché il backend non risponde, così niente sfarfallio (IOS-010).
public struct MemoriaPreferenze: @unchecked Sendable {
  let defaults: UserDefaults
  static let chiave = "ron1nos.preferenze"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func carica() -> Preferenze? {
    guard let dati = defaults.data(forKey: MemoriaPreferenze.chiave) else { return nil }
    return try? JSONDecoder().decode(Preferenze.self, from: dati)
  }

  public func salva(_ preferenze: Preferenze) {
    if let dati = try? JSONEncoder().encode(preferenze) {
      defaults.set(dati, forKey: MemoriaPreferenze.chiave)
    }
  }
}

extension APIClient {
  /// `GET /preferences`.
  public func preferenze() async throws(APIError) -> Preferenze {
    try await get("preferences")
  }

  /// `GET /preferences/background`: l'immagine di sfondo caricata.
  /// `versione` è `backgroundImage`, per non usare quella vecchia.
  public func immagineSfondo(versione: String) async throws(APIError) -> Data {
    try await dati("preferences/background", query: [URLQueryItem(name: "v", value: versione)])
  }
}
