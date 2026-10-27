import Foundation

/// Lo stato del collegamento a YAZIO (NUT-020). Le credenziali stanno solo
/// nel `.env` del server: l'app non le vede mai.
public struct CollegamentoYazio: Decodable, Equatable, Sendable {
  /// False se mancano le variabili `YAZIO_*` sul server.
  public let configured: Bool
  /// `connected`, `disconnected` o `error`.
  public let state: String
  /// Il motivo dell'errore, già in italiano.
  public let error: String?
  public let lastSyncAt: String?
  public let syncEnabled: Bool
  /// Righe e cancellazioni in coda verso YAZIO.
  public let queue: Int
  /// Alimenti senza equivalente YAZIO.
  public let unmatched: Int

  public init(
    configured: Bool, state: String, error: String? = nil, lastSyncAt: String? = nil, syncEnabled: Bool,
    queue: Int = 0, unmatched: Int = 0
  ) {
    self.configured = configured
    self.state = state
    self.error = error
    self.lastSyncAt = lastSyncAt
    self.syncEnabled = syncEnabled
    self.queue = queue
    self.unmatched = unmatched
  }

  /// "Collegato", "Non collegato", "Errore" o "Non configurato".
  public var testoStato: String {
    guard configured else { return "Non configurato" }
    switch state {
    case "connected": return syncEnabled ? "Collegato" : "Collegato · in pausa"
    case "error": return "Errore"
    default: return "Non collegato"
    }
  }

  public var inErrore: Bool { configured && state == "error" }

  /// "Mai", "ora", "12 min fa", "oggi alle 14:05" o "26/10 alle 14:05".
  public func testoUltimaSincronizzazione(
    adesso: Date = Date(), fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String {
    guard let lastSyncAt, let data = CollegamentoYazio.istante(lastSyncAt) else { return "Mai" }
    let minuti = Int(adesso.timeIntervalSince(data) / 60)
    if minuti < 1 { return "ora" }
    if minuti < 60 { return "\(minuti) min fa" }
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let parti = calendario.dateComponents([.day, .month, .hour, .minute], from: data)
    let ora = "\(parti.hour ?? 0):\((parti.minute ?? 0) < 10 ? "0" : "")\(parti.minute ?? 0)"
    if calendario.isDate(data, inSameDayAs: adesso) { return "oggi alle \(ora)" }
    let giorno = "\((parti.day ?? 1) < 10 ? "0" : "")\(parti.day ?? 1)"
    let mese = "\((parti.month ?? 1) < 10 ? "0" : "")\(parti.month ?? 1)"
    return "\(giorno)/\(mese) alle \(ora)"
  }

  /// Un istante ISO 8601, con o senza millisecondi.
  static func istante(_ testo: String) -> Date? {
    let conMillisecondi = ISO8601DateFormatter()
    conMillisecondi.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return conMillisecondi.date(from: testo) ?? ISO8601DateFormatter().date(from: testo)
  }
}

/// Un obiettivo nutrizionale (NUT-015), valido da un giorno in poi.
public struct ObiettivoDieta: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  /// `manual` o `yazio`.
  public let source: String
  public let kcal: Double
  public let protein: Double
  public let carbs: Double
  public let fat: Double
  public let waterMl: Double?
  public let effectiveFrom: String

  public init(
    id: String, source: String = "manual", kcal: Double, protein: Double, carbs: Double, fat: Double,
    waterMl: Double? = nil, effectiveFrom: String
  ) {
    self.id = id
    self.source = source
    self.kcal = kcal
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.waterMl = waterMl
    self.effectiveFrom = effectiveFrom
  }
}

/// L'obiettivo di un giorno e lo storico. Con YAZIO collegato non si
/// cambia dall'app.
public struct ObiettiviDieta: Decodable, Equatable, Sendable {
  public let current: ObiettivoDieta?
  public let history: [ObiettivoDieta]
  public let editable: Bool

  public init(current: ObiettivoDieta?, history: [ObiettivoDieta] = [], editable: Bool) {
    self.current = current
    self.history = history
    self.editable = editable
  }
}

/// Un obiettivo nuovo, scritto a mano: valido da oggi.
public struct ModuloObiettivo: Equatable, Sendable {
  public var kcal: String
  public var proteine: String
  public var carboidrati: String
  public var grassi: String
  /// In ml, facoltativa.
  public var acqua: String

  public init(
    kcal: String = "", proteine: String = "", carboidrati: String = "", grassi: String = "",
    acqua: String = ""
  ) {
    self.kcal = kcal
    self.proteine = proteine
    self.carboidrati = carboidrati
    self.grassi = grassi
    self.acqua = acqua
  }

  /// I campi riempiti dall'obiettivo in corso.
  public init(_ obiettivo: ObiettivoDieta) {
    self.init(
      kcal: Formato.numero(obiettivo.kcal), proteine: Formato.numero(obiettivo.protein),
      carboidrati: Formato.numero(obiettivo.carbs), grassi: Formato.numero(obiettivo.fat),
      acqua: obiettivo.waterMl.map { Formato.numero($0) } ?? "")
  }

  /// Un numero scritto all'italiana: "1.800" o "92,5".
  static func numero(_ testo: String) -> Double? {
    let pulito = testo.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: ",", with: ".")
    guard !pulito.isEmpty else { return nil }
    return Double(pulito)
  }

  public var problema: String? {
    guard let kcal = ModuloObiettivo.numero(kcal) else { return "Servono le kcal." }
    if kcal < 800 || kcal > 8000 { return "Le kcal vanno da 800 a 8.000." }
    for campo in [proteine, carboidrati, grassi] {
      guard let valore = ModuloObiettivo.numero(campo), valore >= 0 else {
        return "Servono proteine, carboidrati e grassi."
      }
    }
    if !acqua.trimmingCharacters(in: .whitespaces).isEmpty {
      guard let ml = ModuloObiettivo.numero(acqua), ml >= 0 else { return "Controlla l'acqua." }
    }
    return nil
  }

  public var valido: Bool { problema == nil }

  var corpo: Corpo {
    Corpo(
      kcal: ModuloObiettivo.numero(kcal) ?? 0, protein: ModuloObiettivo.numero(proteine) ?? 0,
      carbs: ModuloObiettivo.numero(carboidrati) ?? 0, fat: ModuloObiettivo.numero(grassi) ?? 0,
      waterMl: ModuloObiettivo.numero(acqua))
  }

  struct Corpo: Encodable, Sendable {
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let waterMl: Double?
  }
}

/// Un alimento le cui righe non partono verso YAZIO perché manca un
/// prodotto equivalente (NUT-023).
public struct SenzaEquivalente: Decodable, Equatable, Identifiable, Sendable {
  public let food: Cibo
  public let rows: Int
  public let last: Ultima
  public var id: String { food.id }

  public init(food: Cibo, rows: Int, last: Ultima) {
    self.food = food
    self.rows = rows
    self.last = last
  }

  public struct Cibo: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let brand: String?
    public let source: String
    public let kcal: Double

    public init(id: String, name: String, brand: String? = nil, source: String = "custom", kcal: Double) {
      self.id = id
      self.name = name
      self.brand = brand
      self.source = source
      self.kcal = kcal
    }
  }

  public struct Ultima: Decodable, Equatable, Sendable {
    public let day: String
    public let slot: String
    public let grams: Double

    public init(day: String, slot: String, grams: Double) {
      self.day = day
      self.slot = slot
      self.grams = grams
    }
  }

  /// "3 righe · ultima a Pranzo, 120 g".
  public var sottotitolo: String {
    let pasto = GiornoDieta.nomiSlot[last.slot] ?? last.slot
    return "\(rows) \(rows == 1 ? "riga" : "righe") · ultima a \(pasto), \(Formato.numero(last.grams)) g"
  }
}

extension APIClient {
  /// `GET /nutrition/yazio`.
  public func collegamentoYazio() async throws(APIError) -> CollegamentoYazio {
    try await get("nutrition/yazio")
  }

  /// `PUT /nutrition/yazio/sync`: accende o spegne, senza cancellare niente.
  public func sincronizzazioneYazio(_ accesa: Bool) async throws(APIError) -> CollegamentoYazio {
    struct Corpo: Encodable, Sendable { let enabled: Bool }
    return try await invia("PUT", "nutrition/yazio/sync", corpo: Corpo(enabled: accesa))
  }

  /// `POST /nutrition/yazio/sync`: un giro subito. Un errore di YAZIO
  /// arriva nello stato, non come errore HTTP.
  public func sincronizzaYazio() async throws(APIError) -> CollegamentoYazio {
    try await invia("POST", "nutrition/yazio/sync")
  }

  /// `GET /nutrition/yazio/unmatched`.
  public func senzaEquivalente() async throws(APIError) -> [SenzaEquivalente] {
    struct Risposta: Decodable { let foods: [SenzaEquivalente] }
    let risposta: Risposta = try await get("nutrition/yazio/unmatched")
    return risposta.foods
  }

  /// `GET /nutrition/yazio/products?q=`: i prodotti YAZIO da abbinare.
  public func prodottiYazio(_ testo: String) async throws(APIError) -> [Alimento] {
    struct Risposta: Decodable { let products: [Alimento] }
    let risposta: Risposta = try await get(
      "nutrition/yazio/products", query: [URLQueryItem(name: "q", value: testo)])
    return risposta.products
  }

  /// `PUT /nutrition/foods/{id}/yazio`: abbina un prodotto, o con `nil`
  /// lascia l'alimento solo in ron1nOS. Torna l'elenco aggiornato.
  public func abbinaYazio(_ id: String, prodotto: String?) async throws(APIError) -> [SenzaEquivalente] {
    struct Corpo: Encodable, Sendable {
      let productId: String?
      // `null` va scritto: vuol dire "solo in ron1nOS".
      func encode(to encoder: Encoder) throws {
        var contenitore = encoder.container(keyedBy: Chiavi.self)
        try contenitore.encode(productId, forKey: .productId)
      }
      enum Chiavi: String, CodingKey { case productId }
    }
    struct Risposta: Decodable { let foods: [SenzaEquivalente] }
    let risposta: Risposta = try await invia(
      "PUT", "nutrition/foods/\(id)/yazio", corpo: Corpo(productId: prodotto))
    return risposta.foods
  }

  /// `GET /nutrition/goals`: l'obiettivo di oggi e lo storico.
  public func obiettiviDieta() async throws(APIError) -> ObiettiviDieta {
    try await get("nutrition/goals")
  }

  /// `POST /nutrition/goals`: un obiettivo nuovo da oggi, solo senza YAZIO.
  public func nuovoObiettivo(_ modulo: ModuloObiettivo) async throws(APIError) -> ObiettivoDieta {
    try await invia("POST", "nutrition/goals", corpo: modulo.corpo)
  }
}
