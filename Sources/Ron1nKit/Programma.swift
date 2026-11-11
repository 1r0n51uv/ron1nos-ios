import Foundation

/// La settimana programmata, da `GET /api/v1/nutrition/week` (NUT-032):
/// sette giorni da lunedì con i pasti, il loro stato e le kcal.
public struct SettimanaNutrizione: Decodable, Equatable, Sendable {
  public let from: String
  public let days: [GiornoSettimana]

  public init(from: String, days: [GiornoSettimana]) {
    self.from = from
    self.days = days
  }
}

public struct GiornoSettimana: Decodable, Equatable, Identifiable, Sendable {
  public let date: String
  public let plannedKcal: Double
  public let slots: [PastoSettimana]

  public var id: String { date }

  public init(date: String, plannedKcal: Double = 0, slots: [PastoSettimana] = []) {
    self.date = date
    self.plannedKcal = plannedKcal
    self.slots = slots
  }

  /// Le kcal del giorno: quelle dei pasti mangiati e di quelli previsti.
  public var kcal: Double { slots.reduce(0) { $0 + $1.kcal } }
}

public struct PastoSettimana: Decodable, Equatable, Identifiable, Sendable {
  public let slot: String
  /// `empty`, `planned`, `eaten` o `skipped`.
  public let state: String
  public let kcal: Double
  public let plan: Programmato?

  public var id: String { slot }

  public init(slot: String, state: String, kcal: Double = 0, plan: Programmato? = nil) {
    self.slot = slot
    self.state = state
    self.kcal = kcal
    self.plan = plan
  }

  /// Il nome dello slot: "Colazione".
  public var titolo: String { GiornoDieta.nomiSlot[slot] ?? slot }

  /// Il pasto programmato: id del piano, ricetta e nome.
  public struct Programmato: Decodable, Equatable, Sendable {
    public let id: String
    public let status: String
    public let recipeId: String?
    public let name: String
    /// La foto della ricetta, se ce n'è una (NUT-034).
    public let imageUrl: String?

    public init(
      id: String, status: String = "planned", recipeId: String? = nil, name: String,
      imageUrl: String? = nil
    ) {
      self.id = id
      self.status = status
      self.recipeId = recipeId
      self.name = name
      self.imageUrl = imageUrl
    }
  }
}

/// Come si presenta un pasto programmato: lo stato non è tutto quello che
/// dice il server, perché un pasto che non hai spuntato e che è nel passato
/// è saltato, e uno nel futuro è ancora in programma.
public enum VistaPasto: Equatable, Sendable {
  case vuoto, pianificato, mangiato, saltato

  /// Da stato del server e da dove cade il giorno rispetto a oggi.
  /// `giorno` e `oggi` sono `YYYY-MM-DD`: si confrontano come testo.
  public static func da(stato: String, giorno: String, oggi: String) -> VistaPasto {
    switch stato {
    case "eaten": .mangiato
    case "skipped": .saltato
    case "planned": giorno < oggi ? .saltato : .pianificato
    default: .vuoto
    }
  }

  public var testo: String {
    switch self {
    case .vuoto: "Niente in programma"
    case .pianificato: "In programma"
    case .mangiato: "Mangiato"
    case .saltato: "Saltato"
    }
  }
}

extension PastoSettimana {
  public func vista(giorno: String, oggi: String) -> VistaPasto {
    VistaPasto.da(stato: state, giorno: giorno, oggi: oggi)
  }
}

extension SlotGiorno {
  public func vista(giorno: String, oggi: String) -> VistaPasto {
    VistaPasto.da(stato: state, giorno: giorno, oggi: oggi)
  }
}

extension Promemoria {
  /// Lo slot che corrisponde all'ora: l'ultimo il cui orario è già passato;
  /// prima della colazione, la colazione.
  public func slotCorrente(minuti: Int) -> String {
    let ordine = GiornoDieta.ordineSlot
    let iniziati = ordine.filter { (Promemoria.minuti(orario($0)) ?? 0) <= minuti }
    return iniziati.last ?? ordine[0]
  }

  /// I minuti dalla mezzanotte di `adesso` nel fuso dato.
  public static func minutiDi(
    _ adesso: Date, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> Int {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let parti = calendario.dateComponents([.hour, .minute], from: adesso)
    return (parti.hour ?? 0) * 60 + (parti.minute ?? 0)
  }
}

/// Una notifica di un pasto da programmare con `UNUserNotificationCenter`.
public struct NotificaPasto: Equatable, Sendable {
  /// Stabile tra un ricalcolo e l'altro: `pasto-2026-10-27-lunch`.
  public let id: String
  public let titolo: String
  public let corpo: String
  public let quando: Date
  /// Giorno, slot e id del piano, per `Mangiato` e per aprire la pagina.
  public let dati: [String: String]
}

/// I promemoria dei pasti programmati (IOS-035): un avviso all'orario di
/// ogni pasto ancora da spuntare, con `Mangiato` e `Rimanda`.
public enum PromemoriaPasti {
  /// La categoria con `Mangiato` e `Rimanda`.
  public static let categoria = "pasto"
  /// Quanto rimanda `Rimanda`.
  public static let rinvio: TimeInterval = 30 * 60
  /// iOS tiene al massimo 64 notifiche programmate: queste sono le più
  /// vicine, e restano posto per quelle dei download.
  public static let massimo = 40

  /// Un avviso per ogni pasto programmato e non spuntato, con l'orario nel
  /// futuro, i più vicini per primi.
  public static func notifiche(
    settimane: [SettimanaNutrizione], promemoria: Promemoria, adesso: Date,
    fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> [NotificaPasto] {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    var risultato: [NotificaPasto] = []
    for giorno in settimane.flatMap(\.days) {
      for pasto in giorno.slots where pasto.state == "planned" {
        guard let piano = pasto.plan,
          let quando = istante(giorno.date, promemoria.orario(pasto.slot), calendario: calendario),
          quando > adesso
        else { continue }
        risultato.append(
          NotificaPasto(
            id: "pasto-\(giorno.date)-\(pasto.slot)", titolo: "\(pasto.titolo)?",
            corpo: "In programma \(piano.name)", quando: quando,
            dati: ["giorno": giorno.date, "slot": pasto.slot, "piano": piano.id]))
      }
    }
    return Array(risultato.sorted { $0.quando < $1.quando }.prefix(massimo))
  }

  static func istante(_ giorno: String, _ orario: String, calendario: Calendar) -> Date? {
    let parti = giorno.split(separator: "-").compactMap { Int($0) }
    guard parti.count == 3, let minuti = Promemoria.minuti(orario) else { return nil }
    let ora = DateComponents(
      year: parti[0], month: parti[1], day: parti[2], hour: minuti / 60, minute: minuti % 60)
    return calendario.date(from: ora)
  }
}

/// Un piano (la settimana tipo) da creare o correggere: nome e ricetta di
/// ogni giorno e pasto.
public struct ModuloPiano: Equatable, Sendable {
  public var nome: String
  /// Da `(giorno, slot)` a id della ricetta; giorno da 1 (lunedì) a 7.
  public var ricette: [Casella: String]

  public struct Casella: Hashable, Sendable {
    public let giorno: Int
    public let slot: String
    public init(giorno: Int, slot: String) {
      self.giorno = giorno
      self.slot = slot
    }
  }

  public init(nome: String = "", ricette: [Casella: String] = [:]) {
    self.nome = nome
    self.ricette = ricette
  }

  /// I campi riempiti da un piano letto; le caselle con un alimento solo
  /// (senza ricetta) non si possono rifare nell'app e restano fuori.
  public init(_ piano: TemplateSettimana) {
    nome = piano.name
    ricette = Dictionary(
      uniqueKeysWithValues: piano.cells.compactMap { cella in
        cella.recipeId.map { (Casella(giorno: cella.weekday, slot: cella.slot), $0) }
      })
  }

  public var problema: String? {
    let pulito = nome.trimmingCharacters(in: .whitespaces)
    if pulito.isEmpty { return "Serve un nome." }
    if pulito.count > 100 { return "Il nome è troppo lungo." }
    if ricette.isEmpty { return "Scegli almeno una ricetta." }
    return nil
  }

  public var valido: Bool { problema == nil }

  struct Corpo: Encodable, Sendable {
    let name: String
    let cells: [Cella]

    struct Cella: Encodable, Sendable {
      let weekday: Int
      let slot: String
      let recipeId: String
    }
  }

  var corpo: Corpo {
    let ordine = GiornoDieta.ordineSlot
    let celle = ricette.map { Corpo.Cella(weekday: $0.key.giorno, slot: $0.key.slot, recipeId: $0.value) }
      .sorted {
        ($0.weekday, ordine.firstIndex(of: $0.slot) ?? 0) < ($1.weekday, ordine.firstIndex(of: $1.slot) ?? 0)
      }
    return Corpo(name: nome.trimmingCharacters(in: .whitespaces), cells: celle)
  }
}

/// Cosa ha fatto `Programma` (NUT-031).
public struct EsitoProgramma: Decodable, Equatable, Sendable {
  public let created: Int
  public let removed: Int
  public let kept: Int
  public let from: String
  public let until: String

  public init(created: Int, removed: Int, kept: Int, from: String, until: String) {
    self.created = created
    self.removed = removed
    self.kept = kept
    self.from = from
    self.until = until
  }

  /// "12 pasti programmati".
  public var testo: String { "\(created) \(created == 1 ? "pasto programmato" : "pasti programmati")" }
}

extension APIClient {
  /// `GET /nutrition/week` dal lunedì dato, o da questa settimana.
  public func settimana(da lunedi: String? = nil) async throws(APIError) -> SettimanaNutrizione {
    guard let lunedi else { return try await get("nutrition/week") }
    return try await get("nutrition/week", query: [URLQueryItem(name: "from", value: lunedi)])
  }

  /// `POST /nutrition/templates`.
  public func creaPiano(_ modulo: ModuloPiano) async throws(APIError) -> TemplateSettimana {
    try await invia("POST", "nutrition/templates", corpo: modulo.corpo)
  }

  /// `PUT /nutrition/templates/{id}`.
  public func correggiPiano(_ id: String, _ modulo: ModuloPiano) async throws(APIError)
    -> TemplateSettimana
  {
    try await invia("PUT", "nutrition/templates/\(id)", corpo: modulo.corpo)
  }

  /// `POST /nutrition/templates/{id}/schedule`: dal giorno `da` fino a `fino`
  /// compreso, o fino a domenica della settimana di `da`.
  public func programma(_ piano: String, da: String, fino: String? = nil) async throws(APIError)
    -> EsitoProgramma
  {
    struct Corpo: Encodable, Sendable {
      let from: String
      let until: String?
    }
    return try await invia(
      "POST", "nutrition/templates/\(piano)/schedule", corpo: Corpo(from: da, until: fino))
  }
}

/// Le date come testo `YYYY-MM-DD`, quelle che parla l'API.
extension Settimana {
  private static func calendario(_ fuso: TimeZone) -> Calendar {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    return calendario
  }

  /// Oggi, nel fuso dato.
  public static func oggi(
    adesso: Date = Date(), fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String {
    testo(adesso, fuso: fuso)
  }

  /// Una data come la vuole l'API.
  public static func testo(
    _ data: Date, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String {
    Striscia.testo(data, calendario: calendario(fuso))
  }

  /// La data di un `YYYY-MM-DD`, a mezzanotte nel fuso dato; nil se il testo non è una data.
  public static func data(
    _ giorno: String, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> Date? {
    let parti = giorno.split(separator: "-").compactMap { Int($0) }
    guard parti.count == 3 else { return nil }
    return calendario(fuso).date(from: DateComponents(year: parti[0], month: parti[1], day: parti[2]))
  }

  /// Il giorno `n` giorni dopo (o prima, se negativo) di `giorno`.
  public static func piu(
    _ n: Int, a giorno: String, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String {
    guard let data = data(giorno, fuso: fuso),
      let spostata = calendario(fuso).date(byAdding: .day, value: n, to: data)
    else { return giorno }
    return testo(spostata, fuso: fuso)
  }
}

/// Cosa ha fatto l'import dei preferiti YAZIO (NUT-008).
public struct EsitoImportRicette: Decodable, Equatable, Sendable {
  public let created: Int
  public let updated: Int
  /// Ingredienti lasciati fuori perché non in grammi.
  public let skippedItems: Int

  public init(created: Int, updated: Int, skippedItems: Int = 0) {
    self.created = created
    self.updated = updated
    self.skippedItems = skippedItems
  }

  /// "3 ricette nuove · 2 aggiornate".
  public var testo: String {
    var parti = ["\(created) \(created == 1 ? "ricetta nuova" : "ricette nuove")"]
    parti.append("\(updated) \(updated == 1 ? "aggiornata" : "aggiornate")")
    if skippedItems > 0 {
      parti.append("\(skippedItems) \(skippedItems == 1 ? "ingrediente escluso" : "ingredienti esclusi")")
    }
    return parti.joined(separator: " · ")
  }
}

extension APIClient {
  /// `POST /nutrition/recipes/yazio/import`: i preferiti YAZIO tra le ricette.
  public func importaRicetteYazio() async throws(APIError) -> EsitoImportRicette {
    try await invia("POST", "nutrition/recipes/yazio/import")
  }
}
