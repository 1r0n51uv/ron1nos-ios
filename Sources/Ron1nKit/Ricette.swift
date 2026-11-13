import Foundation

/// Un'azione collegata a una ricetta (NUT-035): un promemoria `daysBefore`
/// giorni prima del pasto, all'ora `time`, per esempio scongelare il pesce
/// la sera prima. Si può disattivare senza toglierla.
public struct AzioneRicetta: Codable, Equatable, Identifiable, Sendable {
  public var id: String
  public var title: String
  public var daysBefore: Int
  public var time: String
  public var enabled: Bool

  public init(
    id: String = UUID().uuidString, title: String = "", daysBefore: Int = 1, time: String = "21:00",
    enabled: Bool = true
  ) {
    self.id = id
    self.title = title
    self.daysBefore = daysBefore
    self.time = time
    self.enabled = enabled
  }

  public static let giorniPrima = 0...14

  /// "Il giorno prima · 21:00".
  public var quando: String {
    let giorni =
      switch daysBefore {
      case 0: "Lo stesso giorno"
      case 1: "Il giorno prima"
      default: "\(daysBefore) giorni prima"
      }
    return "\(giorni) · \(time)"
  }

  /// Titolo e orario sono a posto per il server.
  public var valida: Bool {
    !title.trimmingCharacters(in: .whitespaces).isEmpty && title.count <= 100
      && Promemoria.minuti(time) != nil && AzioneRicetta.giorniPrima.contains(daysBefore)
  }
}

/// La foto generata di una ricetta, finché non è pronta (NUT-036).
public struct FotoInPreparazione: Decodable, Equatable, Sendable {
  /// `generating` o `failed`.
  public let state: String
  public let error: String?

  public init(state: String, error: String? = nil) {
    self.state = state
    self.error = error
  }

  public var inCorso: Bool { state == "generating" }
}

/// Una ricetta (NUT-008): kcal e macro dagli alimenti di oggi.
public struct Ricetta: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let notes: String?
  /// Il procedimento, un passo per elemento (NUT-030).
  public let steps: [String]
  /// La foto, per le ricette di YAZIO che ne hanno una (NUT-034).
  public let imageUrl: String?
  /// La foto in preparazione o non riuscita (NUT-036); nil altrimenti.
  public let photo: FotoInPreparazione?
  /// Le azioni collegate (NUT-035).
  public let actions: [AzioneRicetta]
  /// Il peso totale degli alimenti.
  public let grams: Double
  public let kcal: Double
  public let protein: Double
  public let carbs: Double
  public let fat: Double
  public let items: [RigaRicetta]

  public init(
    id: String, name: String, notes: String? = nil, steps: [String] = [], imageUrl: String? = nil,
    photo: FotoInPreparazione? = nil, actions: [AzioneRicetta] = [], grams: Double, kcal: Double,
    protein: Double = 0, carbs: Double = 0,
    fat: Double = 0,
    items: [RigaRicetta] = []
  ) {
    self.id = id
    self.name = name
    self.notes = notes
    self.steps = steps
    self.imageUrl = imageUrl
    self.photo = photo
    self.actions = actions
    self.grams = grams
    self.kcal = kcal
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.items = items
  }

  enum CodingKeys: String, CodingKey {
    case id, name, notes, steps, imageUrl, photo, actions, grams, kcal, protein, carbs, fat, items
  }

  /// Un backend senza procedimento (prima di NUT-030) vale nessun passo.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    notes = try c.decodeIfPresent(String.self, forKey: .notes)
    steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
    imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
    photo = try c.decodeIfPresent(FotoInPreparazione.self, forKey: .photo)
    actions = try c.decodeIfPresent([AzioneRicetta].self, forKey: .actions) ?? []
    grams = try c.decode(Double.self, forKey: .grams)
    kcal = try c.decode(Double.self, forKey: .kcal)
    protein = try c.decode(Double.self, forKey: .protein)
    carbs = try c.decode(Double.self, forKey: .carbs)
    fat = try c.decode(Double.self, forKey: .fat)
    items = try c.decode([RigaRicetta].self, forKey: .items)
  }

  /// "620 kcal · 420 g".
  public func sottotitolo(_ formati: Formati = Formati()) -> String {
    "\(formati.energia(kcal)) · \(Formato.numero(grams)) g"
  }

  /// Qualche alimento è stato eliminato: i totali non contano quelle righe.
  public var incompleta: Bool { items.contains { $0.missing } }
}

/// Una riga di una ricetta.
public struct RigaRicetta: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let foodId: String?
  public let name: String
  public let grams: Double
  public let kcal: Double
  public let protein: Double
  public let carbs: Double
  public let fat: Double
  /// L'alimento è stato eliminato: la riga non conta.
  public let missing: Bool

  public init(
    id: String, foodId: String? = nil, name: String, grams: Double, kcal: Double, protein: Double = 0,
    carbs: Double = 0, fat: Double = 0, missing: Bool = false
  ) {
    self.id = id
    self.foodId = foodId
    self.name = name
    self.grams = grams
    self.kcal = kcal
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.missing = missing
  }
}

/// Una ricetta da creare o correggere: il nome e le righe in bozza.
public struct ModuloRicetta: Equatable, Sendable {
  public var nome: String
  public var note: String
  /// Il procedimento: un passo per elemento, anche vuoto mentre si scrive.
  public var passi: [String]
  /// Le azioni collegate (NUT-035), anche disattivate.
  public var azioni: [AzioneRicetta]
  public var righe: [Bozza]

  public init(
    nome: String = "", note: String = "", passi: [String] = [], azioni: [AzioneRicetta] = [],
    righe: [Bozza] = []
  ) {
    self.nome = nome
    self.note = note
    self.passi = passi
    self.azioni = azioni
    self.righe = righe
  }

  /// I campi riempiti da una ricetta letta: una riga senza alimento non si
  /// può ricostruire e resta fuori.
  public init(_ ricetta: Ricetta) {
    nome = ricetta.name
    note = ricetta.notes ?? ""
    passi = ricetta.steps
    azioni = ricetta.actions
    righe = ricetta.items.compactMap { riga in
      guard !riga.missing, riga.grams > 0 else { return nil }
      let per100 = 100 / riga.grams
      let alimento = Alimento(
        id: riga.foodId, name: riga.name, kcal: riga.kcal * per100, protein: riga.protein * per100,
        carbs: riga.carbs * per100, fat: riga.fat * per100)
      return Bozza(alimento, testoGrammi: Formato.numero(riga.grams))
    }
  }

  public var problema: String? {
    let pulito = nome.trimmingCharacters(in: .whitespaces)
    if pulito.isEmpty { return "Serve un nome." }
    if pulito.count > 200 { return "Il nome è troppo lungo." }
    if righe.isEmpty { return "Serve almeno un alimento." }
    if righe.count > 50 { return "Al massimo 50 alimenti." }
    if passiPuliti.count > 50 { return "Al massimo 50 passi." }
    if passiPuliti.contains(where: { $0.count > 1_000 }) { return "Un passo è troppo lungo." }
    if azioni.count > 10 { return "Al massimo 10 azioni." }
    if !azioni.allSatisfy(\.valida) { return "Controlla le azioni: servono un titolo e un orario." }
    if !righe.salvabile { return "Controlla i grammi." }
    return nil
  }

  public var valido: Bool { problema == nil }

  /// I totali della ricetta mentre si scrive.
  public var totale: Macro { righe.totale }

  /// I passi senza spazi ai bordi, saltando quelli vuoti.
  public var passiPuliti: [String] {
    passi.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
  }

  var corpo: Corpo {
    let note = note.trimmingCharacters(in: .whitespaces)
    return Corpo(
      name: nome.trimmingCharacters(in: .whitespaces), notes: note.isEmpty ? nil : note,
      steps: passiPuliti,
      actions: azioni.map { azione in
        var pulita = azione
        pulita.title = azione.title.trimmingCharacters(in: .whitespaces)
        return pulita
      },
      items: righe.compactMap { bozza in
        guard let grammi = bozza.grammi else { return nil }
        return CorpoPasto.Riga(bozza.alimento, grams: grammi)
      })
  }

  struct Corpo: Encodable, Sendable {
    let name: String
    let notes: String?
    let steps: [String]
    let actions: [AzioneRicetta]
    let items: [CorpoPasto.Riga]

    enum CodingKeys: String, CodingKey { case name, notes, steps, actions, items }

    /// Note vuote viaggiano come null, così si cancellano anche sul server.
    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode(name, forKey: .name)
      try c.encode(notes, forKey: .notes)
      try c.encode(steps, forKey: .steps)
      try c.encode(actions, forKey: .actions)
      try c.encode(items, forKey: .items)
    }
  }
}

extension APIClient {
  /// `GET /nutrition/recipes`.
  public func ricette() async throws(APIError) -> [Ricetta] {
    struct Risposta: Decodable { let recipes: [Ricetta] }
    let risposta: Risposta = try await get("nutrition/recipes")
    return risposta.recipes
  }

  /// `GET /nutrition/recipes/{id}`: con le righe.
  public func ricetta(_ id: String) async throws(APIError) -> Ricetta {
    try await get("nutrition/recipes/\(id)")
  }

  /// `POST /nutrition/recipes`.
  public func creaRicetta(_ modulo: ModuloRicetta) async throws(APIError) -> Ricetta {
    try await invia("POST", "nutrition/recipes", corpo: modulo.corpo)
  }

  /// `PUT /nutrition/recipes/{id}`.
  public func correggiRicetta(_ id: String, _ modulo: ModuloRicetta) async throws(APIError) -> Ricetta {
    try await invia("PUT", "nutrition/recipes/\(id)", corpo: modulo.corpo)
  }

  /// `POST /nutrition/recipes/{id}/photo/generate`: avvia la foto con l'agente
  /// del dojo e torna subito; la ricetta dice `photo.state` (NUT-036).
  public func generaFoto(_ id: String) async throws(APIError) -> Ricetta {
    try await invia("POST", "nutrition/recipes/\(id)/photo/generate")
  }

  /// Una foto che sta sul server di ron1nOS, come `/api/v1/nutrition/recipes/{id}/photo?v=…`:
  /// ha bisogno dell'accesso, quindi non la si carica con un indirizzo qualunque.
  public func foto(_ indirizzo: String) async throws(APIError) -> Data {
    guard let (percorso, query) = APIClient.percorsoProprio(indirizzo) else {
      throw .rispostaInattesa(codice: nil)
    }
    return try await dati(percorso, query: query)
  }

  /// `DELETE /nutrition/recipes/{id}`.
  public func eliminaRicetta(_ id: String) async throws(APIError) {
    _ = try await dati("nutrition/recipes/\(id)", metodo: "DELETE")
  }
}

extension APIClient {
  /// L'indirizzo di una foto di ron1nOS (comincia con `/api/v1/`) diviso in
  /// percorso e query; nil per un indirizzo di un altro sito.
  public static func percorsoProprio(_ indirizzo: String) -> (String, [URLQueryItem])? {
    guard indirizzo.hasPrefix("/api/v1/"), let parti = URLComponents(string: indirizzo) else { return nil }
    return (String(parti.path.dropFirst("/api/v1/".count)), parti.queryItems ?? [])
  }
}
