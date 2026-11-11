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
}

/// Le righe di una ricetta: una riga è un alimento del catalogo (`foodId`)
/// o un candidato esterno (`food`).
enum CorpoPasto {
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
