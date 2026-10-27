import Foundation

/// Un documento con campi, scadenza e allegati (DOC-004).
public struct Documento: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let typeId: String?
  public let type: Tipo?
  public let title: String
  public let holder: String
  public let expiresOn: String?
  public let expiry: DocumentoBreve.Scadenza?
  public let warnings: [Int]
  public let tags: [String]
  public let pinnedAt: String?
  public let fields: [String: String]
  public let extra: [CampoLibero]
  public let notes: String
  public let files: [Allegato]

  public init(
    id: String, typeId: String? = nil, type: Tipo? = nil, title: String, holder: String = "Io",
    expiresOn: String? = nil, expiry: DocumentoBreve.Scadenza? = nil, warnings: [Int] = [90, 30, 7],
    tags: [String] = [], pinnedAt: String? = nil, fields: [String: String] = [:], extra: [CampoLibero] = [],
    notes: String = "", files: [Allegato] = []
  ) {
    self.id = id
    self.typeId = typeId
    self.type = type
    self.title = title
    self.holder = holder
    self.expiresOn = expiresOn
    self.expiry = expiry
    self.warnings = warnings
    self.tags = tags
    self.pinnedAt = pinnedAt
    self.fields = fields
    self.extra = extra
    self.notes = notes
    self.files = files
  }

  public struct Tipo: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public let fields: [CampoTipo]

    public init(id: String, name: String, icon: String = "file", fields: [CampoTipo] = []) {
      self.id = id
      self.name = name
      self.icon = icon
      self.fields = fields
    }
  }

  /// Un campo libero: etichetta e valore.
  public struct CampoLibero: Codable, Equatable, Hashable, Sendable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
      self.label = label
      self.value = value
    }
  }

  /// Un allegato cifrato sul server (DOC-011).
  public struct Allegato: Decodable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let mime: String
    public let size: Int
    /// `fronte`, `retro`, `pagina` o `altro`.
    public let label: String
    public let position: Int
    public let hasThumb: Bool

    public init(
      id: String, name: String, mime: String, size: Int = 0, label: String = "altro", position: Int = 0,
      hasThumb: Bool = false
    ) {
      self.id = id
      self.name = name
      self.mime = mime
      self.size = size
      self.label = label
      self.position = position
      self.hasThumb = hasThumb
    }

    public var immagine: Bool { mime.hasPrefix("image/") }
    public var pdf: Bool { mime == "application/pdf" }

    /// "Fronte", "Retro"…
    public var etichetta: String { label.prefix(1).uppercased() + label.dropFirst() }
  }

  /// Un campo da mostrare: etichetta piccola, valore in mono.
  public struct Campo: Equatable, Identifiable, Sendable {
    public let id: String
    public let etichetta: String
    public let valore: String
    /// Un tocco lo copia (DOC-012).
    public let copiabile: Bool
  }

  /// I campi del tipo nell'ordine del tipo, solo quelli con un valore; le
  /// date come gg/mm/aaaa. Poi i campi liberi.
  public var campi: [Campo] {
    let delTipo = (type?.fields ?? []).compactMap { campo -> Campo? in
      guard let chiave = campo.key, let valore = fields[chiave], !valore.isEmpty else { return nil }
      let testo = campo.kind == "date" ? Documento.data(valore) : valore
      return Campo(id: chiave, etichetta: campo.label, valore: testo, copiabile: campo.copyable)
    }
    let liberi = extra.enumerated().map { indice, campo in
      Campo(id: "extra-\(indice)", etichetta: campo.label, valore: campo.value, copiabile: true)
    }
    return delTipo + liberi
  }

  /// "2030-01-31" → "31/01/2030".
  public static func data(_ giorno: String) -> String {
    let parti = giorno.split(separator: "-")
    guard parti.count == 3 else { return giorno }
    return "\(parti[2])/\(parti[1])/\(parti[0])"
  }

  public var fissato: Bool { pinnedAt != nil }

  /// "Passaporto · Anna · scade tra 30 giorni".
  public var sottotitolo: String {
    [type?.name, holder == "Io" ? nil : holder, expiry.map { $0.testo.lowercased() }]
      .compactMap { $0 }
      .joined(separator: " · ")
  }

  /// `Copia tutto`: titolo, titolare, scadenza e campi, una riga ciascuno.
  public var testoCompleto: String {
    var righe = [title, "Titolare: \(holder)"]
    if let expiresOn { righe.append("Scadenza: \(Documento.data(expiresOn))") }
    righe += campi.map { "\($0.etichetta): \($0.valore)" }
    if !notes.isEmpty { righe.append("Note: \(notes)") }
    return righe.joined(separator: "\n")
  }
}

extension APIClient {
  /// `GET /documents/documents/{id}`: con i valori dei campi.
  public func documento(_ id: String) async throws(APIError) -> Documento {
    try await get("documents/documents/\(id)")
  }

  /// `PATCH` con `pinned`: in evidenza o no (DOC-008).
  public func fissaDocumento(_ id: String, fissato: Bool) async throws(APIError) -> Documento {
    struct Corpo: Encodable, Sendable { let pinned: Bool }
    return try await invia("PATCH", "documents/documents/\(id)", corpo: Corpo(pinned: fissato))
  }

  /// `DELETE`: il documento e i suoi allegati, in modo definitivo.
  public func eliminaDocumento(_ id: String) async throws(APIError) {
    _ = try await dati("documents/documents/\(id)", metodo: "DELETE")
  }

  /// Il contenuto di un allegato, in chiaro.
  public func allegato(_ id: String, file: String) async throws(APIError) -> Data {
    try await dati("documents/documents/\(id)/files/\(file)")
  }

  /// Il PDF di riepilogo (DOC-013), generato al volo. È in chiaro.
  public func pdfRiepilogo(_ id: String) async throws(APIError) -> Data {
    try await dati("documents/documents/\(id)/summary.pdf")
  }
}
