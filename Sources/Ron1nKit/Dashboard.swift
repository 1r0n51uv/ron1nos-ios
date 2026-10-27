import Foundation

/// Le tre misure dei widget sull'iPhone (DASH-010 di ron1nOS): celle della
/// griglia di 4 colonne.
public enum Misura: String, Codable, CaseIterable, Sendable {
  case small, medium, large

  public var w: Int { self == .small ? 2 : 4 }
  public var h: Int { self == .large ? 4 : 2 }

  public var titolo: String {
    switch self {
    case .small: "Piccolo"
    case .medium: "Medio"
    case .large: "Grande"
    }
  }

  public init?(w: Int, h: Int) {
    guard let trovata = Misura.allCases.first(where: { $0.w == w && $0.h == h }) else { return nil }
    self = trovata
  }
}

/// Il valore di un'opzione di un widget (DASH-005): una scelta, più valori
/// o un numero.
public enum ValoreOpzione: Codable, Equatable, Hashable, Sendable {
  case testo(String)
  case elenco([String])
  case numero(Int)

  public init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if let numero = try? c.decode(Int.self) {
      self = .numero(numero)
    } else if let elenco = try? c.decode([String].self) {
      self = .elenco(elenco)
    } else {
      self = .testo(try c.decode(String.self))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .testo(let testo): try c.encode(testo)
    case .elenco(let elenco): try c.encode(elenco)
    case .numero(let numero): try c.encode(numero)
    }
  }
}

/// Un widget nel layout: id del catalogo, posto e dimensione in celle,
/// variante e opzioni.
public struct ElementoLayout: Codable, Equatable, Hashable, Identifiable, Sendable {
  public var id: String
  public var x: Int
  public var y: Int
  public var w: Int
  public var h: Int
  public var variant: String?
  public var options: [String: ValoreOpzione]?

  public init(
    id: String, x: Int = 0, y: Int = 0, misura: Misura, variant: String? = nil,
    options: [String: ValoreOpzione]? = nil
  ) {
    self.id = id
    self.x = x
    self.y = y
    w = misura.w
    h = misura.h
    self.variant = variant
    self.options = options
  }

  /// La misura iPhone; un layout fuori regola vale `medium`.
  public var misura: Misura { Misura(w: w, h: h) ?? .medium }

  /// Il modulo del widget: `nutrition` per `nutrition.summary`.
  public var modulo: String { String(id.prefix { $0 != "." }) }
}

/// Il layout della Home (DASH-007): forma della testata e widget.
public struct LayoutHome: Codable, Equatable, Sendable {
  public enum Testata: String, Codable, CaseIterable, Sendable {
    case full, line, hidden

    public var titolo: String {
      switch self {
      case .full: "Completa"
      case .line: "Una riga"
      case .hidden: "Nascosta"
      }
    }
  }

  public var header: Testata
  public var items: [ElementoLayout]
  /// false senza database: le modifiche non si salvano.
  public var stored: Bool

  public init(header: Testata = .full, items: [ElementoLayout], stored: Bool = true) {
    self.header = header
    self.items = items
    self.stored = stored
  }

  enum CodingKeys: String, CodingKey { case header, items, stored }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    header = c.leggi(Testata.self, .header) ?? .full
    items = try c.decode([ElementoLayout].self, forKey: .items)
    stored = c.leggi(Bool.self, .stored) ?? true
  }

  /// Il predefinito dell'iPhone (DASH-010), uguale a quello del backend.
  public static let predefinito = LayoutHome(
    items: LayoutHome.dispone([
      ElementoLayout(id: "nutrition.summary", misura: .large),
      ElementoLayout(id: "workout.summary", misura: .medium),
      ElementoLayout(id: "server.metric", misura: .small),
      ElementoLayout(id: "downloads.speed", misura: .small),
      ElementoLayout(id: "documents.summary", misura: .medium),
    ]))

  /// I widget in ordine di lettura: riga per riga, da sinistra.
  public var ordinati: [ElementoLayout] {
    items.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
  }

  /// Rimette i widget nella griglia di 4 colonne nell'ordine dato, come la
  /// Home di iOS: un piccolo accanto all'altro, gli altri a capo.
  public static func dispone(_ elementi: [ElementoLayout]) -> [ElementoLayout] {
    var x = 0
    var y = 0
    var fondo = 0
    return elementi.map { elemento in
      var posto = elemento
      let misura = elemento.misura
      if x + misura.w > 4 {
        x = 0
        y = fondo
      }
      posto.x = x
      posto.y = y
      posto.w = misura.w
      posto.h = misura.h
      x += misura.w
      fondo = max(fondo, y + misura.h)
      return posto
    }
  }

  /// Le righe da disegnare: i widget visibili, uno o due per riga. I widget
  /// di un modulo spento non si vedono ma restano nel layout (DASH-007).
  public func righe(spenti: [String] = []) -> [[ElementoLayout]] {
    let visibili = LayoutHome.dispone(ordinati.filter { !spenti.contains($0.modulo) })
    var righe: [[ElementoLayout]] = []
    for elemento in visibili {
      if elemento.x > 0, var ultima = righe.popLast() {
        ultima.append(elemento)
        righe.append(ultima)
      } else {
        righe.append([elemento])
      }
    }
    return righe
  }
}

/// La testata della Home (DASH-006): data in maiuscolo, saluto e frase di
/// stato. Nomi di giorni e mesi scritti qui, uguali su iOS e su Linux.
public enum Testata {
  static let giorni = ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]
  static let mesi = [
    "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno", "luglio", "agosto", "settembre",
    "ottobre", "novembre", "dicembre",
  ]

  static func parti(_ data: Date, fuso: TimeZone) -> DateComponents {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    return calendario.dateComponents([.weekday, .day, .month, .hour, .minute], from: data)
  }

  /// "LUNEDÌ 27 OTTOBRE · 09:41"
  public static func data(_ data: Date, fuso: TimeZone) -> String {
    let p = parti(data, fuso: fuso)
    let giorno = giorni[(p.weekday ?? 1) - 1]
    let mese = mesi[(p.month ?? 1) - 1]
    return "\(giorno) \(p.day ?? 1) \(mese) · \(ora(p))".uppercased()
  }

  /// "LUN 27 OTT · 09:41", per la testata su una riga.
  public static func dataCorta(_ data: Date, fuso: TimeZone) -> String {
    let p = parti(data, fuso: fuso)
    let giorno = giorni[(p.weekday ?? 1) - 1].prefix(3)
    let mese = mesi[(p.month ?? 1) - 1].prefix(3)
    return "\(giorno) \(p.day ?? 1) \(mese) · \(ora(p))".uppercased()
  }

  static func ora(_ p: DateComponents) -> String {
    let due = { (n: Int) in n < 10 ? "0\(n)" : "\(n)" }
    return "\(due(p.hour ?? 0)):\(due(p.minute ?? 0))"
  }

  public static func saluto(_ data: Date, fuso: TimeZone) -> String {
    let ora = parti(data, fuso: fuso).hour ?? 12
    if ora < 5 { return "Buonanotte." }
    if ora < 13 { return "Buongiorno." }
    if ora < 18 { return "Buon pomeriggio." }
    return "Buonasera."
  }

  static let articoli = [
    "breakfast": "la colazione", "morning_snack": "lo spuntino", "lunch": "il pranzo",
    "afternoon_snack": "la merenda", "dinner": "la cena",
  ]

  /// La frase di stato: cosa resta da fare. "Ti manca la cena."
  public static func stato(prossimoPasto: String?) -> String {
    guard let pasto = prossimoPasto.flatMap({ articoli[$0] }) else { return "" }
    return "Ti manca \(pasto)."
  }
}

extension APIClient {
  /// `GET /dashboard/layouts/iphone`: il salvato o il predefinito.
  public func layoutHome() async throws(APIError) -> LayoutHome {
    try await get("dashboard/layouts/iphone")
  }
}
