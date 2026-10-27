import Foundation

/// Un alimento, valori per 100 g (NUT-004). `id` è nil per un risultato
/// esterno non ancora nel catalogo: entra quando lo si usa.
public struct Alimento: Decodable, Equatable, Hashable, Identifiable, Sendable {
  public let id: String?
  /// `custom`, `openfoodfacts`, `usda` o `yazio`.
  public let source: String
  public let externalId: String?
  public let name: String
  public let brand: String?
  public let barcode: String?
  public let servingSizeG: Double?
  public let kcal: Double
  public let protein: Double
  public let carbs: Double
  public let fat: Double
  public let caffeineMg: Double?
  public let yazioProductId: String?

  public init(
    id: String? = nil, source: String = "custom", externalId: String? = nil, name: String,
    brand: String? = nil, barcode: String? = nil, servingSizeG: Double? = nil, kcal: Double,
    protein: Double = 0, carbs: Double = 0, fat: Double = 0, caffeineMg: Double? = nil,
    yazioProductId: String? = nil
  ) {
    self.id = id
    self.source = source
    self.externalId = externalId
    self.name = name
    self.brand = brand
    self.barcode = barcode
    self.servingSizeG = servingSizeG
    self.kcal = kcal
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.caffeineMg = caffeineMg
    self.yazioProductId = yazioProductId
  }

  /// La fonte come la vede l'utente: `mio`, `OFF`, `USDA`, `YAZIO`.
  public var fonte: String {
    switch source {
    case "custom": "mio"
    case "openfoodfacts": "OFF"
    case "usda": "USDA"
    case "yazio": "YAZIO"
    default: source.uppercased()
    }
  }

  /// "Fage · 73 kcal / 100 g", con la marca se c'è.
  public func sottotitolo(_ formati: Formati = Formati()) -> String {
    let energia = "\(formati.energia(kcal)) / 100 g"
    guard let brand, !brand.isEmpty else { return energia }
    return "\(brand) · \(energia)"
  }

  /// La chiave per l'elenco: l'id del catalogo, se no fonte e id esterno.
  public var chiave: String { id ?? "\(source):\(externalId ?? name)" }
}

/// I risultati della ricerca e le fonti che non hanno risposto.
public struct RisultatiRicerca: Decodable, Equatable, Sendable {
  public let results: [Alimento]
  public let unavailable: [String]

  public init(results: [Alimento], unavailable: [String] = []) {
    self.results = results
    self.unavailable = unavailable
  }

  /// "OpenFoodFacts non risponde", o nil se hanno risposto tutte.
  public var avviso: String? {
    guard !unavailable.isEmpty else { return nil }
    let nomi = unavailable.map { fonte in
      switch fonte {
      case "openfoodfacts": "OpenFoodFacts"
      case "usda": "USDA"
      case "yazio": "YAZIO"
      default: fonte
      }
    }
    return "\(nomi.joined(separator: " · ")) non risponde"
  }
}

/// Una riga da registrare: l'alimento e i grammi scritti (NUT-003). Kcal e
/// macro si ricalcolano mentre si scrive.
public struct Bozza: Equatable, Identifiable, Sendable {
  public let id: UUID
  public let alimento: Alimento
  /// I grammi come li scrive l'utente, anche a metà ("12").
  public var testoGrammi: String

  public init(_ alimento: Alimento, testoGrammi: String? = nil) {
    id = UUID()
    self.alimento = alimento
    self.testoGrammi = testoGrammi ?? Bozza.proposta(alimento)
  }

  /// I grammi proposti: la porzione dell'alimento, se no 100 g.
  public static func proposta(_ alimento: Alimento) -> String {
    guard let porzione = alimento.servingSizeG, porzione > 0 else { return "100" }
    return Formato.numero(porzione)
  }

  /// I grammi validi, o nil se il campo non è un numero maggiore di zero.
  public var grammi: Double? {
    let pulito = testoGrammi.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
    guard let valore = Double(pulito), valore > 0, valore <= 5_000 else { return nil }
    return valore
  }

  public var valida: Bool { grammi != nil }

  /// Kcal e macro per i grammi scritti.
  public var macro: Macro {
    let fattore = (grammi ?? 0) / 100
    return Macro(
      kcal: alimento.kcal * fattore, protein: alimento.protein * fattore,
      carbs: alimento.carbs * fattore, fat: alimento.fat * fattore)
  }
}

extension Array where Element == Bozza {
  /// Il totale delle righe valide: quello che si vede mentre si scrive.
  public var totale: Macro {
    reduce(Macro(kcal: 0, protein: 0, carbs: 0, fat: 0)) { somma, bozza in
      let parte = bozza.macro
      return Macro(
        kcal: somma.kcal + parte.kcal, protein: somma.protein + parte.protein,
        carbs: somma.carbs + parte.carbs, fat: somma.fat + parte.fat)
    }
  }

  /// Si salva solo con almeno una riga e tutte valide.
  public var salvabile: Bool { !isEmpty && allSatisfy(\.valida) }
}

extension APIClient {
  /// `GET /nutrition/foods/search`: da 2 caratteri, con il filtro Solo
  /// Italia acceso (NUT-004).
  public func cercaAlimenti(_ q: String, soloItalia: Bool = true) async throws(APIError) -> RisultatiRicerca {
    let testo = q.trimmingCharacters(in: .whitespaces)
    guard testo.count >= 2 else { return RisultatiRicerca(results: []) }
    var query = [URLQueryItem(name: "q", value: testo)]
    if !soloItalia { query.append(URLQueryItem(name: "italy", value: "0")) }
    return try await get("nutrition/foods/search", query: query)
  }

  /// `GET /nutrition/foods/recent` (NUT-028): in cima al foglio di ricerca.
  public func alimentiRecenti(slot: String? = nil) async throws(APIError) -> [Alimento] {
    struct Risposta: Decodable { let results: [Alimento] }
    let query = slot.map { [URLQueryItem(name: "slot", value: $0)] } ?? []
    let risposta: Risposta = try await get("nutrition/foods/recent", query: query)
    return risposta.results
  }

  /// `GET /nutrition/foods/barcode/{code}` (NUT-005): nil se sconosciuto.
  public func alimentoDaCodice(_ codice: String) async throws(APIError) -> Alimento? {
    do {
      let alimento: Alimento = try await get("nutrition/foods/barcode/\(codice)")
      return alimento
    } catch {
      if error == .stato(404) { return nil }
      throw error
    }
  }

  /// `POST /nutrition/meals` (NUT-003): le righe entrano in coda allo slot
  /// e torna il giorno aggiornato.
  public func registraPasto(
    giorno: String, slot: String, righe: [Bozza]
  ) async throws(APIError) -> GiornoDieta {
    try await invia("POST", "nutrition/meals", corpo: CorpoPasto(date: giorno, slot: slot, righe: righe))
  }

  /// `PATCH /nutrition/meals/items/{id}` (NUT-007): cambia i grammi di una
  /// riga già registrata.
  public func cambiaGrammi(_ riga: String, _ grammi: Double) async throws(APIError) -> GiornoDieta {
    struct Corpo: Encodable, Sendable { let grams: Double }
    return try await invia("PATCH", "nutrition/meals/items/\(riga)", corpo: Corpo(grams: grammi))
  }

  /// `DELETE /nutrition/meals/items/{id}` (NUT-007): toglie una riga.
  public func togliRiga(_ riga: String) async throws(APIError) -> GiornoDieta {
    try await invia("DELETE", "nutrition/meals/items/\(riga)")
  }
}

/// Il corpo del `POST /nutrition/meals`: una riga è un alimento del
/// catalogo (`foodId`) o un candidato esterno (`food`).
struct CorpoPasto: Encodable, Sendable {
  let date: String
  let slot: String
  let items: [Riga]

  init(date: String, slot: String, righe: [Bozza]) {
    self.date = date
    self.slot = slot
    items = righe.compactMap { bozza in
      guard let grammi = bozza.grammi else { return nil }
      return Riga(bozza.alimento, grams: grammi)
    }
  }

  struct Riga: Encodable, Sendable {
    let foodId: String?
    let food: Candidato?
    let grams: Double

    init(_ alimento: Alimento, grams: Double) {
      self.grams = grams
      if let id = alimento.id {
        foodId = id
        food = nil
      } else {
        foodId = nil
        food = Candidato(alimento)
      }
    }
  }

  /// Un risultato esterno, come lo vuole l'API.
  struct Candidato: Encodable, Sendable {
    let source: String
    let externalId: String
    let name: String
    let brand: String?
    let barcode: String?
    let servingSizeG: Double?
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let caffeineMg: Double?
    let yazioProductId: String?

    init(_ alimento: Alimento) {
      source = alimento.source
      externalId = alimento.externalId ?? alimento.name
      name = alimento.name
      brand = alimento.brand
      barcode = alimento.barcode
      servingSizeG = alimento.servingSizeG
      kcal = alimento.kcal
      protein = alimento.protein
      carbs = alimento.carbs
      fat = alimento.fat
      caffeineMg = alimento.caffeineMg
      yazioProductId = alimento.yazioProductId
    }
  }
}

/// Un alimento personale da creare o correggere (NUT-006): valori per
/// 100 g. Il testo lo scrive l'utente, quindi la validazione sta qui.
public struct AlimentoPersonale: Equatable, Sendable {
  public var nome: String
  public var marca: String
  public var codice: String
  public var porzione: String
  public var kcal: String
  public var proteine: String
  public var carboidrati: String
  public var grassi: String
  public var caffeina: String

  public init(
    nome: String = "", marca: String = "", codice: String = "", porzione: String = "", kcal: String = "",
    proteine: String = "", carboidrati: String = "", grassi: String = "", caffeina: String = ""
  ) {
    self.nome = nome
    self.marca = marca
    self.codice = codice
    self.porzione = porzione
    self.kcal = kcal
    self.proteine = proteine
    self.carboidrati = carboidrati
    self.grassi = grassi
    self.caffeina = caffeina
  }

  /// I campi riempiti da un alimento già nel catalogo.
  public init(_ alimento: Alimento) {
    self.init(
      nome: alimento.name, marca: alimento.brand ?? "", codice: alimento.barcode ?? "",
      porzione: alimento.servingSizeG.map { Formato.numero($0) } ?? "",
      kcal: Formato.numero(alimento.kcal), proteine: Formato.numero(alimento.protein),
      carboidrati: Formato.numero(alimento.carbs), grassi: Formato.numero(alimento.fat),
      caffeina: alimento.caffeineMg.map { Formato.numero($0) } ?? "")
  }

  static func numero(_ testo: String) -> Double? {
    let pulito = testo.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
    guard let valore = Double(pulito), valore >= 0 else { return nil }
    return valore
  }

  /// Il primo problema del modulo, o nil: le stesse regole del backend.
  public var problema: String? {
    let nomePulito = nome.trimmingCharacters(in: .whitespaces)
    if nomePulito.isEmpty { return "Serve un nome." }
    if nomePulito.count > 200 { return "Il nome è troppo lungo." }
    guard let energia = AlimentoPersonale.numero(kcal), energia <= 900 else {
      return "Le kcal per 100 g vanno da 0 a 900."
    }
    let macro = [("Le proteine", proteine), ("I carboidrati", carboidrati), ("I grassi", grassi)]
    for (nome, testo) in macro {
      guard let valore = AlimentoPersonale.numero(testo), valore <= 100 else {
        return "\(nome) per 100 g vanno da 0 a 100."
      }
    }
    if !porzione.isEmpty, AlimentoPersonale.numero(porzione) == nil { return "La porzione non è un numero." }
    if !caffeina.isEmpty, AlimentoPersonale.numero(caffeina) == nil { return "La caffeina non è un numero." }
    let codicePulito = codice.trimmingCharacters(in: .whitespaces)
    if !codicePulito.isEmpty, codicePulito.count < 8 || !codicePulito.allSatisfy(\.isNumber) {
      return "Il codice a barre è di almeno 8 cifre."
    }
    return nil
  }

  public var valido: Bool { problema == nil }

  /// Il corpo del `POST` e del `PATCH`, con i campi vuoti a null.
  var corpo: Corpo {
    func testo(_ valore: String) -> String? {
      let pulito = valore.trimmingCharacters(in: .whitespaces)
      return pulito.isEmpty ? nil : pulito
    }
    return Corpo(
      name: nome.trimmingCharacters(in: .whitespaces), brand: testo(marca), barcode: testo(codice),
      servingSizeG: testo(porzione).flatMap(AlimentoPersonale.numero),
      kcal: AlimentoPersonale.numero(kcal) ?? 0, protein: AlimentoPersonale.numero(proteine) ?? 0,
      carbs: AlimentoPersonale.numero(carboidrati) ?? 0, fat: AlimentoPersonale.numero(grassi) ?? 0,
      caffeineMg: testo(caffeina).flatMap(AlimentoPersonale.numero))
  }

  struct Corpo: Encodable, Sendable {
    let name: String
    let brand: String?
    let barcode: String?
    let servingSizeG: Double?
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let caffeineMg: Double?

    // I campi vuoti vanno scritti come null: in una correzione tolgono il
    // valore di prima.
    func encode(to encoder: Encoder) throws {
      var contenitore = encoder.container(keyedBy: CodingKeys.self)
      try contenitore.encode(name, forKey: .name)
      try contenitore.encode(brand, forKey: .brand)
      try contenitore.encode(barcode, forKey: .barcode)
      try contenitore.encode(servingSizeG, forKey: .servingSizeG)
      try contenitore.encode(kcal, forKey: .kcal)
      try contenitore.encode(protein, forKey: .protein)
      try contenitore.encode(carbs, forKey: .carbs)
      try contenitore.encode(fat, forKey: .fat)
      try contenitore.encode(caffeineMg, forKey: .caffeineMg)
    }

    enum CodingKeys: String, CodingKey {
      case name, brand, barcode, servingSizeG, kcal, protein, carbs, fat, caffeineMg
    }
  }
}

extension APIClient {
  /// `GET /nutrition/foods`: gli alimenti personali (NUT-006).
  public func alimentiPersonali() async throws(APIError) -> [Alimento] {
    struct Risposta: Decodable { let foods: [Alimento] }
    let risposta: Risposta = try await get("nutrition/foods")
    return risposta.foods
  }

  /// `POST /nutrition/foods`.
  public func creaAlimento(_ alimento: AlimentoPersonale) async throws(APIError) -> Alimento {
    try await invia("POST", "nutrition/foods", corpo: alimento.corpo)
  }

  /// `PATCH /nutrition/foods/{id}`.
  public func correggiAlimento(
    _ id: String, _ alimento: AlimentoPersonale
  ) async throws(APIError) -> Alimento {
    try await invia("PATCH", "nutrition/foods/\(id)", corpo: alimento.corpo)
  }

  /// `DELETE /nutrition/foods/{id}`.
  public func eliminaAlimento(_ id: String) async throws(APIError) {
    _ = try await dati("nutrition/foods/\(id)", metodo: "DELETE")
  }
}
