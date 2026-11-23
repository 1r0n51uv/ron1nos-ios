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

/// Una categoria di ricetta (NUT-037): il momento o la temperatura.
public enum CategoriaRicetta: String, CaseIterable, Identifiable, Sendable {
  case lunch, dinner, snack, cold, hot

  public var id: String { rawValue }

  public var nome: String {
    switch self {
    case .lunch: "Pranzo"
    case .dinner: "Cena"
    case .snack: "Spuntino"
    case .cold: "Freddo"
    case .hot: "Caldo"
    }
  }

  /// Il simbolo SF che la rappresenta su card e dettaglio.
  public var simbolo: String {
    switch self {
    case .lunch: "sun.max.fill"
    case .dinner: "moon.stars.fill"
    case .snack: "carrot.fill"
    case .cold: "snowflake"
    case .hot: "flame.fill"
    }
  }
}

/// Il ruolo di una parte in una ricetta composta (NUT-037).
public enum RuoloParte: String, CaseIterable, Identifiable, Codable, Sendable {
  case course, side, bread

  public var id: String { rawValue }

  public var nome: String {
    switch self {
    case .course: "Portata"
    case .side: "Contorno"
    case .bread: "Pane o crackers"
    }
  }

  public var simbolo: String {
    switch self {
    case .course: "fork.knife"
    case .side: "leaf.fill"
    case .bread: "takeoutbag.and.cup.and.straw.fill"
    }
  }
}

/// Una ricetta dentro una composta (NUT-037), per `factor` porzioni.
public struct ParteRicetta: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let role: RuoloParte
  public let recipeId: String
  public let name: String
  public let imageUrl: String?
  public let factor: Double
  public let kcal: Double

  public init(
    id: String, role: RuoloParte, recipeId: String, name: String, imageUrl: String? = nil,
    factor: Double = 1, kcal: Double = 0
  ) {
    self.id = id
    self.role = role
    self.recipeId = recipeId
    self.name = name
    self.imageUrl = imageUrl
    self.factor = factor
    self.kcal = kcal
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
  /// Le categorie come le manda il server (NUT-037).
  public let categories: [String]
  /// Le ricette che la compongono, se è composta (NUT-037).
  public let parts: [ParteRicetta]
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
    id: String, name: String, notes: String? = nil, categories: [String] = [],
    parts: [ParteRicetta] = [], steps: [String] = [], imageUrl: String? = nil,
    photo: FotoInPreparazione? = nil, actions: [AzioneRicetta] = [], grams: Double, kcal: Double,
    protein: Double = 0, carbs: Double = 0,
    fat: Double = 0,
    items: [RigaRicetta] = []
  ) {
    self.id = id
    self.name = name
    self.notes = notes
    self.categories = categories
    self.parts = parts
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
    case id, name, notes, categories, parts, steps, imageUrl, photo, actions, grams, kcal, protein, carbs, fat
    case items
  }

  /// Un backend senza procedimento (prima di NUT-030) vale nessun passo.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    notes = try c.decodeIfPresent(String.self, forKey: .notes)
    categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
    parts = try c.decodeIfPresent([ParteRicetta].self, forKey: .parts) ?? []
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

  /// Le categorie che l'app conosce, nell'ordine fisso (pranzo, cena, spuntino, freddo, caldo).
  public var categorie: [CategoriaRicetta] {
    CategoriaRicetta.allCases.filter { categories.contains($0.rawValue) }
  }

  /// È fatta di altre ricette (NUT-037).
  public var composta: Bool { !parts.isEmpty }

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

/// Una parte in bozza di una ricetta composta (NUT-037).
public struct BozzaParte: Equatable, Identifiable, Sendable {
  public let id: UUID
  public var ruolo: RuoloParte
  public var ricettaId: String
  public var nome: String
  /// kcal di una porzione, per il totale mentre si scrive.
  public var kcal: Double
  public var porzioni: Double

  public static let porzioniPossibili = 0.5...10.0

  public init(
    id: UUID = UUID(), ruolo: RuoloParte, ricettaId: String, nome: String, kcal: Double = 0,
    porzioni: Double = 1
  ) {
    self.id = id
    self.ruolo = ruolo
    self.ricettaId = ricettaId
    self.nome = nome
    self.kcal = kcal
    self.porzioni = porzioni
  }

  /// La ricetta scelta per un ruolo, a una porzione.
  public init(ruolo: RuoloParte, _ ricetta: Ricetta) {
    self.init(ruolo: ruolo, ricettaId: ricetta.id, nome: ricetta.name, kcal: ricetta.kcal)
  }

  public var kcalTotali: Double { kcal * porzioni }
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
  /// Le categorie scelte (NUT-037).
  public var categorie: Set<CategoriaRicetta>
  /// Fatta di altre ricette: allora valgono `parti` e non `righe` (NUT-037).
  public var composta: Bool
  public var parti: [BozzaParte]

  public init(
    nome: String = "", note: String = "", passi: [String] = [], azioni: [AzioneRicetta] = [],
    righe: [Bozza] = [], categorie: Set<CategoriaRicetta> = [], composta: Bool = false,
    parti: [BozzaParte] = []
  ) {
    self.nome = nome
    self.note = note
    self.passi = passi
    self.azioni = azioni
    self.righe = righe
    self.categorie = categorie
    self.composta = composta
    self.parti = parti
  }

  /// I campi riempiti da una ricetta letta: una riga senza alimento non si
  /// può ricostruire e resta fuori.
  public init(_ ricetta: Ricetta) {
    nome = ricetta.name
    note = ricetta.notes ?? ""
    passi = ricetta.steps
    azioni = ricetta.actions
    categorie = Set(ricetta.categorie)
    composta = ricetta.composta
    parti = ricetta.parts.map { parte in
      BozzaParte(
        ruolo: parte.role, ricettaId: parte.recipeId, nome: parte.name,
        kcal: parte.factor > 0 ? parte.kcal / parte.factor : parte.kcal, porzioni: parte.factor)
    }
    // Una composta non ha alimenti suoi: `items` sono quelli delle parti.
    righe =
      ricetta.composta
      ? []
      : ricetta.items.compactMap { riga in
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
    if composta {
      if parti.isEmpty { return "Scegli almeno una ricetta." }
      if parti.count > 10 { return "Al massimo 10 parti." }
      if !parti.allSatisfy({ BozzaParte.porzioniPossibili.contains($0.porzioni) }) {
        return "Controlla le porzioni."
      }
    } else {
      if righe.isEmpty { return "Serve almeno un alimento." }
      if righe.count > 50 { return "Al massimo 50 alimenti." }
    }
    if passiPuliti.count > 50 { return "Al massimo 50 passi." }
    if passiPuliti.contains(where: { $0.count > 1_000 }) { return "Un passo è troppo lungo." }
    if azioni.count > 10 { return "Al massimo 10 azioni." }
    if !azioni.allSatisfy(\.valida) { return "Controlla le azioni: servono un titolo e un orario." }
    if !composta, !righe.salvabile { return "Controlla i grammi." }
    return nil
  }

  public var valido: Bool { problema == nil }

  /// I totali della ricetta mentre si scrive.
  public var totale: Macro { righe.totale }

  /// Le kcal della composta mentre si sceglie, parte per parte.
  public var kcalParti: Double { parti.reduce(0) { $0 + $1.kcalTotali } }

  /// I passi senza spazi ai bordi, saltando quelli vuoti.
  public var passiPuliti: [String] {
    passi.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
  }

  var corpo: Corpo {
    let note = note.trimmingCharacters(in: .whitespaces)
    return Corpo(
      name: nome.trimmingCharacters(in: .whitespaces), notes: note.isEmpty ? nil : note,
      steps: passiPuliti,
      categories: CategoriaRicetta.allCases.filter(categorie.contains).map(\.rawValue),
      parts: composta
        ? parti.map { Corpo.Parte(role: $0.ruolo, recipeId: $0.ricettaId, factor: $0.porzioni) } : nil,
      actions: azioni.map { azione in
        var pulita = azione
        pulita.title = azione.title.trimmingCharacters(in: .whitespaces)
        return pulita
      },
      items: composta
        ? nil
        : righe.compactMap { bozza in
          guard let grammi = bozza.grammi else { return nil }
          return CorpoPasto.Riga(bozza.alimento, grams: grammi)
        })
  }

  struct Corpo: Encodable, Sendable {
    let name: String
    let notes: String?
    let steps: [String]
    let categories: [String]
    let parts: [Parte]?
    let actions: [AzioneRicetta]
    let items: [CorpoPasto.Riga]?

    struct Parte: Encodable, Sendable {
      let role: RuoloParte
      let recipeId: String
      let factor: Double
    }

    enum CodingKeys: String, CodingKey { case name, notes, steps, categories, parts, actions, items }

    /// Note vuote viaggiano come null, così si cancellano anche sul server.
    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode(name, forKey: .name)
      try c.encode(notes, forKey: .notes)
      try c.encode(steps, forKey: .steps)
      try c.encode(categories, forKey: .categories)
      try c.encodeIfPresent(parts, forKey: .parts)
      try c.encode(actions, forKey: .actions)
      try c.encodeIfPresent(items, forKey: .items)
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

  /// `PATCH /nutrition/recipes/{id}`: le sole categorie (NUT-037).
  public func cambiaCategorie(_ id: String, _ categorie: [CategoriaRicetta]) async throws(APIError) -> Ricetta
  {
    struct Corpo: Encodable, Sendable { let categories: [String] }
    return try await invia(
      "PATCH", "nutrition/recipes/\(id)",
      corpo: Corpo(categories: categorie.map(\.rawValue)))
  }

  /// `PUT /nutrition/plans`: la ricetta, una porzione, in un giorno e uno slot.
  public func programmaRicetta(_ id: String, giorno: String, slot: String) async throws(APIError) {
    struct Voce: Encodable, Sendable {
      let recipeId: String
      let factor: Double
    }
    struct Corpo: Encodable, Sendable {
      let date: String
      let slot: String
      let items: [Voce]
    }
    let corpo = Corpo(date: giorno, slot: slot, items: [Voce(recipeId: id, factor: 1)])
    let json: Data
    do {
      json = try JSONEncoder().encode(corpo)
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
    _ = try await dati("nutrition/plans", metodo: "PUT", corpo: json)
  }

  /// Gli ingredienti della ricetta in fondo alla lista della spesa, uno per
  /// riga con i grammi; ne restituisce il numero.
  public func ricettaInSpesa(_ ricetta: Ricetta) async throws(APIError) -> Int {
    let righe = ricetta.items.filter { !$0.missing }
    for riga in righe {
      _ = try await aggiungiSpesa(nome: riga.name, quantita: "\(Formato.numero(riga.grams)) g")
    }
    return righe.count
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
