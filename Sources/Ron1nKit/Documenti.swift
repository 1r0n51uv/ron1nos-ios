import Foundation

/// Un campo di un tipo di documento (DOC-003).
public struct CampoTipo: Codable, Equatable, Hashable, Sendable {
  public var key: String?
  public var label: String
  /// `text`, `date` o `code`.
  public var kind: String
  public var copyable: Bool

  public init(key: String? = nil, label: String, kind: String = "text", copyable: Bool = true) {
    self.key = key
    self.label = label
    self.kind = kind
    self.copyable = copyable
  }
}

/// Un tipo di documento: già pronto o creato (DOC-003, DOC-016).
public struct TipoDocumento: Decodable, Equatable, Identifiable, Hashable, Sendable {
  public let id: String
  public let key: String?
  public let name: String
  public let icon: String
  public let preset: Bool
  public let fields: [CampoTipo]
  /// Quanti documenti lo usano.
  public let documents: Int

  public init(
    id: String, key: String? = nil, name: String, icon: String = "file", preset: Bool = false,
    fields: [CampoTipo] = [], documents: Int = 0
  ) {
    self.id = id
    self.key = key
    self.name = name
    self.icon = icon
    self.preset = preset
    self.fields = fields
    self.documents = documents
  }
}

/// I filtri dell'elenco (DOC-008): ricerca nel titolo e nei tag, tipo e
/// titolare.
public struct FiltroDocumenti: Equatable, Hashable, Sendable {
  public var cerca = ""
  /// Id di un tipo, o `none` per i file senza tipo.
  public var tipo: String?
  public var titolare: String?

  public init(cerca: String = "", tipo: String? = nil, titolare: String? = nil) {
    self.cerca = cerca
    self.tipo = tipo
    self.titolare = titolare
  }

  public static let senzaTipo = "none"

  public var attivo: Bool { tipo != nil || titolare != nil }

  var query: [URLQueryItem] {
    var query: [URLQueryItem] = []
    let parole = cerca.trimmingCharacters(in: .whitespaces)
    if !parole.isEmpty { query.append(URLQueryItem(name: "q", value: parole)) }
    if let tipo { query.append(URLQueryItem(name: "type", value: tipo)) }
    if let titolare { query.append(URLQueryItem(name: "holder", value: titolare)) }
    return query
  }
}

/// L'elenco dei Documenti (IOS-060): in cima i fissati, poi quelli in
/// scadenza o scaduti, poi gli altri per tipo. Ogni documento compare una
/// volta sola.
public struct ElencoDocumenti: Equatable, Sendable {
  public let fissati: [DocumentoBreve]
  public let inScadenza: [DocumentoBreve]
  public let perTipo: [Gruppo]

  public struct Gruppo: Equatable, Identifiable, Sendable {
    public let tipo: String
    public let documenti: [DocumentoBreve]
    public var id: String { tipo }
  }

  public init(_ documenti: [DocumentoBreve]) {
    fissati = documenti.filter { $0.pinnedAt != nil }
    let resto = documenti.filter { $0.pinnedAt == nil }
    inScadenza = resto.filter { ($0.expiry?.status ?? "ok") != "ok" }.sorted {
      ($0.expiry?.daysLeft ?? 0) < ($1.expiry?.daysLeft ?? 0)
    }
    let altri = resto.filter { ($0.expiry?.status ?? "ok") == "ok" }
    var ordine: [String] = []
    var gruppi: [String: [DocumentoBreve]] = [:]
    for documento in altri {
      let tipo = documento.typeName ?? "File"
      if gruppi[tipo] == nil { ordine.append(tipo) }
      gruppi[tipo, default: []].append(documento)
    }
    perTipo = ordine.sorted { $0.localizedCompare($1) == .orderedAscending }.map {
      Gruppo(tipo: $0, documenti: gruppi[$0] ?? [])
    }
  }

  public var vuoto: Bool { fissati.isEmpty && inScadenza.isEmpty && perTipo.isEmpty }
}

extension DocumentoBreve {
  /// "Passaporto · Anna · scade tra 30 giorni": quello che serve sotto il
  /// titolo, senza dati del documento.
  public var sottotitolo: String {
    [typeName, holder == "Io" ? nil : holder, expiry.map { $0.testo.lowercased() }]
      .compactMap { $0 }
      .joined(separator: " · ")
  }
}

extension APIClient {
  /// `GET /documents/documents` con i filtri. Solo dati in chiaro.
  public func elencoDocumenti(_ filtro: FiltroDocumenti) async throws(APIError) -> [DocumentoBreve] {
    try await get("documents/documents", query: filtro.query)
  }

  /// `GET /documents/types`: prima i già pronti, poi i creati.
  public func tipiDocumento() async throws(APIError) -> [TipoDocumento] {
    try await get("documents/types")
  }

  /// `GET /documents/holders`: i titolari già usati, i più frequenti prima.
  public func titolari() async throws(APIError) -> [String] {
    try await get("documents/holders")
  }

  /// La miniatura JPEG di un allegato, lato lungo 400 px.
  public func miniaturaDocumento(_ id: String, file: String) async throws(APIError) -> Data {
    try await dati(
      "documents/documents/\(id)/files/\(file)", query: [URLQueryItem(name: "variant", value: "thumb")])
  }
}
