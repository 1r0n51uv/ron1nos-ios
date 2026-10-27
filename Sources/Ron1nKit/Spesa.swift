import Foundation

/// Una voce della lista della spesa (NUT-011): dal piano, con i grammi, o
/// scritta a mano, con una quantità libera.
public struct VoceSpesa: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let foodId: String?
  public let name: String
  public let grams: Double?
  public let text: String?
  public let checked: Bool
  /// `generated` o `manual`.
  public let source: String

  public init(
    id: String, foodId: String? = nil, name: String, grams: Double? = nil, text: String? = nil,
    checked: Bool = false, source: String = "manual"
  ) {
    self.id = id
    self.foodId = foodId
    self.name = name
    self.grams = grams
    self.text = text
    self.checked = checked
    self.source = source
  }

  /// "320 g", "1 pacco" o niente.
  public var quantita: String? {
    if let grams { return "\(Formato.numero(grams)) g" }
    guard let text, !text.isEmpty else { return nil }
    return text
  }

  public var dalPiano: Bool { source == "generated" }
}

/// La lista: prima le voci dal piano, poi quelle a mano, come la manda il
/// server.
public struct ListaSpesa: Decodable, Equatable, Sendable {
  public let items: [VoceSpesa]
  /// Solo dopo `Genera`.
  public let added: Int?
  /// Solo dopo `Togli le spuntate`.
  public let removed: Int?

  public init(items: [VoceSpesa], added: Int? = nil, removed: Int? = nil) {
    self.items = items
    self.added = added
    self.removed = removed
  }

  public var spuntate: Int { items.filter(\.checked).count }

  /// "4 da prendere · 2 prese".
  public var riepilogo: String {
    let prese = spuntate
    let mancano = items.count - prese
    return "\(mancano) da prendere · \(prese) \(prese == 1 ? "presa" : "prese")"
  }

  /// La stessa lista con una voce cambiata.
  public func sostituendo(_ voce: VoceSpesa) -> ListaSpesa {
    ListaSpesa(items: items.map { $0.id == voce.id ? voce : $0 })
  }

  /// La stessa lista senza una voce.
  public func senza(_ id: String) -> ListaSpesa {
    ListaSpesa(items: items.filter { $0.id != id })
  }
}

/// I giorni da cui `Genera` prende i pasti pianificati: al massimo 31.
public struct IntervalloSpesa: Equatable, Sendable {
  public var da: Date
  public var a: Date
  public let fuso: TimeZone

  public static let massimo = 31

  public init(da: Date, a: Date, fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt) {
    self.da = da
    self.a = a
    self.fuso = fuso
  }

  /// Da oggi per `giorni` giorni, oggi compreso.
  public static func prossimi(
    _ giorni: Int, da oggi: Date = Date(), fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> IntervalloSpesa {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let fine = calendario.date(byAdding: .day, value: giorni - 1, to: oggi) ?? oggi
    return IntervalloSpesa(da: oggi, a: fine, fuso: fuso)
  }

  private var calendario: Calendar {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    return calendario
  }

  public var inizio: String { Striscia.testo(da, calendario: calendario) }
  public var fine: String { Striscia.testo(a, calendario: calendario) }

  /// Quanti giorni, estremi compresi.
  public var giorni: Int {
    let primo = calendario.startOfDay(for: da)
    let ultimo = calendario.startOfDay(for: a)
    return (calendario.dateComponents([.day], from: primo, to: ultimo).day ?? 0) + 1
  }

  public var problema: String? {
    if giorni < 1 { return "La fine viene prima dell'inizio." }
    if giorni > IntervalloSpesa.massimo { return "Al massimo \(IntervalloSpesa.massimo) giorni." }
    return nil
  }
}

extension APIClient {
  /// `GET /nutrition/shopping`.
  public func spesa() async throws(APIError) -> ListaSpesa {
    try await get("nutrition/shopping")
  }

  /// `POST /nutrition/shopping`: una voce a mano.
  public func aggiungiSpesa(nome: String, quantita: String = "") async throws(APIError) -> VoceSpesa {
    struct Corpo: Encodable, Sendable {
      let name: String
      let text: String?
    }
    let testo = quantita.trimmingCharacters(in: .whitespaces)
    return try await invia(
      "POST", "nutrition/shopping",
      corpo: Corpo(name: nome.trimmingCharacters(in: .whitespaces), text: testo.isEmpty ? nil : testo))
  }

  /// `POST /nutrition/shopping/generate`: aggiunge ciò che manca dai pasti
  /// pianificati.
  public func generaSpesa(_ intervallo: IntervalloSpesa) async throws(APIError) -> ListaSpesa {
    struct Corpo: Encodable, Sendable {
      let from: String
      let to: String
    }
    return try await invia(
      "POST", "nutrition/shopping/generate", corpo: Corpo(from: intervallo.inizio, to: intervallo.fine))
  }

  /// `DELETE /nutrition/shopping/checked`.
  public func togliSpuntate() async throws(APIError) -> ListaSpesa {
    try await invia("DELETE", "nutrition/shopping/checked")
  }

  /// `PATCH /nutrition/shopping/{id}`: spunta o toglie la spunta.
  public func spunta(_ id: String, _ presa: Bool) async throws(APIError) -> VoceSpesa {
    struct Corpo: Encodable, Sendable { let checked: Bool }
    return try await invia("PATCH", "nutrition/shopping/\(id)", corpo: Corpo(checked: presa))
  }

  /// `DELETE /nutrition/shopping/{id}`.
  public func eliminaVoceSpesa(_ id: String) async throws(APIError) {
    _ = try await dati("nutrition/shopping/\(id)", metodo: "DELETE")
  }
}
