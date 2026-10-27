import Foundation

/// Il catalogo dei widget, da `GET /dashboard/catalog` (DASH-001,
/// DASH-010): per ogni id le misure ammesse su iPhone, le varianti e le
/// opzioni. È la fonte delle regole, come per il sito.
public struct Catalogo: Decodable, Equatable, Sendable {
  public let widgets: [VoceCatalogo]

  public init(widgets: [VoceCatalogo]) {
    self.widgets = widgets
  }

  public func voce(_ id: String) -> VoceCatalogo? { widgets.first { $0.id == id } }

  /// I widget che si possono mettere sull'iPhone, per modulo acceso.
  public func perIPhone(spenti: [String] = []) -> [VoceCatalogo] {
    widgets.filter { !($0.iphone ?? []).isEmpty && !spenti.contains($0.module) }
  }
}

public struct VoceCatalogo: Decodable, Equatable, Sendable {
  public let id: String
  public let module: String
  /// La prima è la predefinita; vuoto se il widget ha un solo aspetto.
  public let variants: [String]
  public let options: [OpzioneCatalogo]?
  /// Misure ammesse su iPhone, la predefinita per prima.
  public let iphone: [Misura]?

  public init(
    id: String, module: String, variants: [String] = [], options: [OpzioneCatalogo]? = nil,
    iphone: [Misura]? = nil
  ) {
    self.id = id
    self.module = module
    self.variants = variants
    self.options = options
    self.iphone = iphone
  }

  /// Il nome del widget nel catalogo dell'app.
  public var titolo: String {
    VoceCatalogo.titoli[id] ?? id
  }

  static let titoli = [
    "nutrition.summary": "Dieta", "nutrition.calories": "Calorie", "nutrition.next-meal": "Prossimo pasto",
    "nutrition.supplements": "Integratori", "workout.summary": "Palestra", "documents.summary": "Documenti",
    "downloads.summary": "Torrent", "downloads.speed": "Velocità download", "server.summary": "Server",
    "server.metric": "Risorsa del server",
  ]
}

/// Un'opzione di un widget (DASH-005).
public struct OpzioneCatalogo: Decodable, Equatable, Sendable {
  public struct Scelta: Decodable, Equatable, Sendable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
      self.value = value
      self.label = label
    }
  }

  public let key: String
  public let label: String
  /// `choice`, `multi` o `count`.
  public let type: String
  public let choices: [Scelta]?
  public let min: Int?
  public let max: Int?
  public let `default`: ValoreOpzione

  public init(
    key: String, label: String, type: String, choices: [Scelta]? = nil, min: Int? = nil, max: Int? = nil,
    default predefinito: ValoreOpzione
  ) {
    self.key = key
    self.label = label
    self.type = type
    self.choices = choices
    self.min = min
    self.max = max
    self.default = predefinito
  }

  /// Il valore va bene per questa opzione: come la validazione del backend.
  public func ammette(_ valore: ValoreOpzione) -> Bool {
    let valori = (choices ?? []).map(\.value)
    switch (type, valore) {
    case ("choice", .testo(let testo)): return valori.contains(testo)
    case ("multi", .elenco(let elenco)):
      return elenco.allSatisfy(valori.contains) && Set(elenco).count == elenco.count
    case ("count", .numero(let numero)): return numero >= (min ?? 0) && numero <= (max ?? Int.max)
    default: return false
    }
  }
}

extension LayoutHome {
  /// Sposta il widget in posizione `da` (nell'ordine di lettura) in `a` e
  /// rimette tutti nella griglia: gli altri fanno posto.
  public mutating func sposta(da: Int, a: Int) {
    var ordine = ordinati
    guard ordine.indices.contains(da) else { return }
    let elemento = ordine.remove(at: da)
    ordine.insert(elemento, at: Swift.max(0, Swift.min(a, ordine.count)))
    items = LayoutHome.dispone(ordine)
  }

  /// Sposta un widget prima o dopo il vicino (VoiceOver: `Sposta su`).
  public mutating func sposta(_ id: String, di passo: Int) {
    guard let indice = ordinati.firstIndex(where: { $0.id == id }) else { return }
    sposta(da: indice, a: indice + passo)
  }

  public mutating func rimuovi(_ id: String) {
    items = LayoutHome.dispone(ordinati.filter { $0.id != id })
  }

  /// Il widget scelto dal catalogo entra in cima, alla sua misura
  /// predefinita. Un widget già presente non si ripete.
  public mutating func aggiungi(_ voce: VoceCatalogo, misura: Misura? = nil) {
    guard !items.contains(where: { $0.id == voce.id }), let ammesse = voce.iphone, let prima = ammesse.first
    else { return }
    let scelta = misura.flatMap { ammesse.contains($0) ? $0 : nil } ?? prima
    items = LayoutHome.dispone([ElementoLayout(id: voce.id, misura: scelta)] + ordinati)
  }

  /// Cambia misura, variante o opzioni di un widget.
  public mutating func modifica(_ id: String, _ cambio: (inout ElementoLayout) -> Void) {
    var ordine = ordinati
    guard let indice = ordine.firstIndex(where: { $0.id == id }) else { return }
    cambio(&ordine[indice])
    items = LayoutHome.dispone(ordine)
  }

  /// Il primo problema del layout prima dell'invio, o nil: le stesse regole
  /// del backend (DASH-010), così un 422 non arriva.
  public func problema(_ catalogo: Catalogo) -> String? {
    var visti = Set<String>()
    for elemento in items {
      guard let voce = catalogo.voce(elemento.id) else { return "Widget sconosciuto: \(elemento.id)" }
      guard visti.insert(elemento.id).inserted else { return "Widget ripetuto: \(elemento.id)" }
      guard let ammesse = voce.iphone else { return "Widget non disponibile su iPhone: \(elemento.id)" }
      guard let misura = Misura(w: elemento.w, h: elemento.h), ammesse.contains(misura) else {
        return "Misura non ammessa: \(elemento.id)"
      }
      if elemento.x + elemento.w > 4 { return "Fuori dalla griglia: \(elemento.id)" }
      if let variante = elemento.variant, !voce.variants.contains(variante) {
        return "Variante non disponibile: \(elemento.id)"
      }
      for (chiave, valore) in elemento.options ?? [:] {
        guard let opzione = voce.options?.first(where: { $0.key == chiave }), opzione.ammette(valore) else {
          return "Opzioni non valide: \(elemento.id)"
        }
      }
    }
    for (i, a) in items.enumerated() {
      for b in items[(i + 1)...] where a.copre(b) {
        return "Widget sovrapposti: \(a.id), \(b.id)"
      }
    }
    return nil
  }

  /// Il corpo del `PUT`: solo testata e widget.
  struct Corpo: Encodable, Sendable {
    let header: Testata
    let items: [ElementoLayout]
  }

  var corpo: Corpo { Corpo(header: header, items: items) }
}

extension ElementoLayout {
  /// I due widget occupano almeno una cella in comune.
  func copre(_ altro: ElementoLayout) -> Bool {
    x < altro.x + altro.w && altro.x < x + w && y < altro.y + altro.h && altro.y < y + h
  }
}

extension APIClient {
  /// `GET /dashboard/catalog`.
  public func catalogo() async throws(APIError) -> Catalogo {
    try await get("dashboard/catalog")
  }

  /// `PUT /dashboard/layouts/iphone` (DASH-007).
  public func salvaLayoutHome(_ layout: LayoutHome) async throws(APIError) -> LayoutHome {
    try await invia("PUT", "dashboard/layouts/iphone", corpo: layout.corpo)
  }

  /// `DELETE /dashboard/layouts/iphone`: torna il predefinito (DASH-008).
  public func ripristinaLayoutHome() async throws(APIError) -> LayoutHome {
    try await invia("DELETE", "dashboard/layouts/iphone")
  }
}
