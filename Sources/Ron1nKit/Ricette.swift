import Foundation

/// Una ricetta (NUT-008): kcal e macro dagli alimenti di oggi.
public struct Ricetta: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let notes: String?
  /// Il peso totale degli alimenti.
  public let grams: Double
  public let kcal: Double
  public let protein: Double
  public let carbs: Double
  public let fat: Double
  public let items: [RigaRicetta]

  public init(
    id: String, name: String, notes: String? = nil, grams: Double, kcal: Double, protein: Double = 0,
    carbs: Double = 0, fat: Double = 0, items: [RigaRicetta] = []
  ) {
    self.id = id
    self.name = name
    self.notes = notes
    self.grams = grams
    self.kcal = kcal
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.items = items
  }

  /// "620 kcal · 420 g".
  public func sottotitolo(_ formati: Formati = Formati()) -> String {
    "\(formati.energia(kcal)) · \(Formato.numero(grams)) g"
  }

  /// Qualche alimento è stato eliminato: i totali non contano quelle righe.
  public var incompleta: Bool { items.contains(\.missing) }
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
  public var righe: [Bozza]

  public init(nome: String = "", note: String = "", righe: [Bozza] = []) {
    self.nome = nome
    self.note = note
    self.righe = righe
  }

  /// I campi riempiti da una ricetta letta: una riga senza alimento non si
  /// può ricostruire e resta fuori.
  public init(_ ricetta: Ricetta) {
    nome = ricetta.name
    note = ricetta.notes ?? ""
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
    if !righe.salvabile { return "Controlla i grammi." }
    return nil
  }

  public var valido: Bool { problema == nil }

  /// I totali della ricetta mentre si scrive.
  public var totale: Macro { righe.totale }

  var corpo: Corpo {
    let note = note.trimmingCharacters(in: .whitespaces)
    return Corpo(
      name: nome.trimmingCharacters(in: .whitespaces), notes: note.isEmpty ? nil : note,
      items: righe.compactMap { bozza in
        guard let grammi = bozza.grammi else { return nil }
        return CorpoPasto.Riga(bozza.alimento, grams: grammi)
      })
  }

  struct Corpo: Encodable, Sendable {
    let name: String
    let notes: String?
    let items: [CorpoPasto.Riga]
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

  /// `DELETE /nutrition/recipes/{id}`.
  public func eliminaRicetta(_ id: String) async throws(APIError) {
    _ = try await dati("nutrition/recipes/\(id)", metodo: "DELETE")
  }

  /// `POST /nutrition/meals` con una ricetta intera (NUT-008): `Registra`.
  public func registraRicetta(
    giorno: String, slot: String, ricetta: String, porzioni: Double = 1
  ) async throws(APIError) -> GiornoDieta {
    try await invia(
      "POST", "nutrition/meals",
      corpo: CorpoRicetta(date: giorno, slot: slot, recipeId: ricetta, factor: porzioni))
  }

  /// `PUT /nutrition/plans` con una ricetta (NUT-009): `Pianifica`.
  public func pianificaRicetta(
    giorno: String, slot: String, ricetta: String, porzioni: Double = 1
  ) async throws(APIError) -> GiornoDieta {
    try await invia(
      "PUT", "nutrition/plans",
      corpo: CorpoRicetta(date: giorno, slot: slot, recipeId: ricetta, factor: porzioni))
  }

  /// `PUT /nutrition/plans` con degli alimenti (NUT-009).
  public func pianificaPasto(
    giorno: String, slot: String, righe: [Bozza]
  ) async throws(APIError) -> GiornoDieta {
    try await invia("PUT", "nutrition/plans", corpo: CorpoPasto(date: giorno, slot: slot, righe: righe))
  }

  /// `DELETE /nutrition/plans/{id}`: toglie un piano non mangiato.
  public func eliminaPiano(_ id: String) async throws(APIError) -> GiornoDieta {
    try await invia("DELETE", "nutrition/plans/\(id)")
  }
}

/// Il corpo con una ricetta intera, per `factor` porzioni.
struct CorpoRicetta: Encodable, Sendable {
  let date: String
  let slot: String
  let items: [Riga]

  init(date: String, slot: String, recipeId: String, factor: Double) {
    self.date = date
    self.slot = slot
    items = [Riga(recipeId: recipeId, factor: factor)]
  }

  struct Riga: Encodable, Sendable {
    let recipeId: String
    let factor: Double
  }
}
