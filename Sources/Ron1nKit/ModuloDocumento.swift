import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Il form di un documento, nuovo o da modificare (DOC-005), come quello
/// del sito.
public struct ModuloDocumento: Equatable, Sendable {
  /// Cosa si sta caricando: un documento con il suo tipo, un file con info
  /// (titolo e campi liberi) o un file libero (solo titolo).
  public enum Genere: String, CaseIterable, Sendable {
    case documento, conInfo, libero

    public var titolo: String {
      switch self {
      case .documento: "Documento"
      case .conInfo: "File con info"
      case .libero: "File libero"
      }
    }

    public var descrizione: String {
      switch self {
      case .documento: "Ha un tipo, compili il suo form. Carta d'identità, passaporto…"
      case .conInfo: "Un titolo e i campi che vuoi copiare al volo. Un PDF, un contratto."
      case .libero: "Solo un titolo. Lo tieni per quando ti serve."
      }
    }
  }

  public static let preavvisi = [90, 30, 7]

  public var genere: Genere
  public var tipo: TipoDocumento?
  public var titolo: String
  public var titolare: String
  public var valori: [String: String]
  public var liberi: [Documento.CampoLibero]
  /// `YYYY-MM-DD`, o vuota.
  public var scadenza: String
  public var avvisi: [Int]
  /// Separati da virgola, come sul sito.
  public var tag: String
  public var fissato: Bool
  public var note: String

  /// Un form vuoto; il titolo parte dal tipo o dal nome del file.
  public init(genere: Genere, tipo: TipoDocumento? = nil, nomeFile: String? = nil) {
    self.genere = genere
    self.tipo = genere == .documento ? tipo : nil
    if genere == .documento {
      titolo = tipo?.name ?? ""
    } else {
      titolo = nomeFile.map(ModuloDocumento.senzaEstensione) ?? ""
    }
    titolare = "Io"
    valori = [:]
    liberi = genere == .conInfo ? [Documento.CampoLibero(label: "", value: "")] : []
    scadenza = ""
    avvisi = ModuloDocumento.preavvisi
    tag = ""
    fissato = false
    note = ""
  }

  /// Il form di un documento che c'è già.
  public init(documento: Documento, tipo: TipoDocumento?) {
    genere = documento.typeId != nil ? .documento : documento.extra.isEmpty ? .libero : .conInfo
    self.tipo = tipo
    titolo = documento.title
    titolare = documento.holder
    valori = documento.fields
    liberi = documento.extra
    scadenza = documento.expiresOn ?? ""
    avvisi = documento.warnings
    tag = documento.tags.joined(separator: ", ")
    fissato = documento.fissato
    note = documento.notes
  }

  /// "passaporto.pdf" → "passaporto".
  static func senzaEstensione(_ nome: String) -> String {
    guard let punto = nome.lastIndex(of: "."), punto != nome.startIndex else { return nome }
    return String(nome[..<punto])
  }

  public var tags: [String] {
    tag.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
  }

  /// I problemi da segnare sul campo prima di inviare, per etichetta: il
  /// titolo è `Titolo`. Gli stessi limiti del backend.
  public var problemi: [String: String] {
    var problemi: [String: String] = [:]
    let titolo = titolo.trimmingCharacters(in: .whitespaces)
    if titolo.isEmpty { problemi["Titolo"] = "Serve un titolo." }
    if titolo.count > 120 { problemi["Titolo"] = "Al massimo 120 caratteri." }
    if titolare.trimmingCharacters(in: .whitespaces).count > 60 {
      problemi["Titolare"] = "Al massimo 60 caratteri."
    }
    if genere == .documento, !scadenza.isEmpty, !ModuloDocumento.giornoValido(scadenza) {
      problemi["Scadenza"] = "Data non valida."
    }
    for campo in tipo?.fields ?? [] where campo.kind == "date" {
      let valore = valori[campo.key ?? ""]?.trimmingCharacters(in: .whitespaces) ?? ""
      if !valore.isEmpty, !ModuloDocumento.giornoValido(valore) { problemi[campo.label] = "Data non valida." }
    }
    if tags.count > 20 { problemi["Tag"] = "Al massimo 20 tag." }
    if tags.contains(where: { $0.count > 40 }) { problemi["Tag"] = "Ogni tag al massimo 40 caratteri." }
    if liberiDaInviare.count > 30 { problemi["Campi liberi"] = "Al massimo 30 campi liberi." }
    let incompleti = liberiDaInviare.filter {
      $0.label.trimmingCharacters(in: .whitespaces).isEmpty
        || $0.value.trimmingCharacters(in: .whitespaces).isEmpty
    }
    if !incompleti.isEmpty { problemi["Campi liberi"] = "Ogni campo libero vuole etichetta e valore." }
    if note.count > 5000 { problemi["Note"] = "Al massimo 5000 caratteri." }
    return problemi
  }

  public var valido: Bool { problemi.isEmpty }

  /// Un messaggio del server come "Data di rilascio: data non valida" va
  /// sotto il suo campo; gli altri restano in cima al form.
  public func campo(di messaggio: String) -> String? {
    let etichette = ["Titolo", "Titolare", "Scadenza", "Tag", "Note"] + (tipo?.fields.map(\.label) ?? [])
    return etichette.first { messaggio.hasPrefix("\($0):") }
  }

  /// `2030-01-31`, una data vera.
  static func giornoValido(_ giorno: String) -> Bool {
    let parti = giorno.split(separator: "-", omittingEmptySubsequences: false)
    guard parti.count == 3, parti[0].count == 4, parti[1].count == 2, parti[2].count == 2,
      let anno = Int(parti[0]), let mese = Int(parti[1]), let giorno = Int(parti[2])
    else { return false }
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = TimeZone(identifier: "UTC")!
    let componenti = DateComponents(year: anno, month: mese, day: giorno)
    guard let data = calendario.date(from: componenti) else { return false }
    let indietro = calendario.dateComponents([.year, .month, .day], from: data)
    return indietro.year == anno && indietro.month == mese && indietro.day == giorno
  }

  /// Righe dei campi liberi vuote tolte, come sul sito.
  var liberiDaInviare: [Documento.CampoLibero] {
    guard genere != .libero else { return [] }
    return liberi.filter {
      !$0.label.trimmingCharacters(in: .whitespaces).isEmpty
        || !$0.value.trimmingCharacters(in: .whitespaces).isEmpty
    }
  }

  /// Il corpo per il backend: il resto lo valida il server.
  var corpo: Corpo {
    let documento = genere == .documento
    let titolare = titolare.trimmingCharacters(in: .whitespaces)
    return Corpo(
      typeId: documento ? tipo?.id : nil,
      title: titolo.trimmingCharacters(in: .whitespaces),
      holder: titolare.isEmpty ? "Io" : titolare,
      fields: documento ? valori.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty } : [:],
      extra: liberiDaInviare.map {
        Documento.CampoLibero(
          label: $0.label.trimmingCharacters(in: .whitespaces),
          value: $0.value.trimmingCharacters(in: .whitespaces))
      },
      expiresOn: documento && !scadenza.isEmpty ? scadenza : nil,
      warnings: avvisi, tags: tags, pinned: fissato, notes: note)
  }

  struct Corpo: Encodable, Equatable, Sendable {
    let typeId: String?
    let title: String
    let holder: String
    let fields: [String: String]
    let extra: [Documento.CampoLibero]
    let expiresOn: String?
    let warnings: [Int]
    let tags: [String]
    let pinned: Bool
    let notes: String

    enum CodingKeys: String, CodingKey {
      case typeId, title, holder, fields, extra, expiresOn, warnings, tags, pinned, notes
    }

    /// `typeId` e `expiresOn` viaggiano anche null: in modifica li tolgono.
    func encode(to encoder: Encoder) throws {
      var c = encoder.container(keyedBy: CodingKeys.self)
      try c.encode(typeId, forKey: .typeId)
      try c.encode(title, forKey: .title)
      try c.encode(holder, forKey: .holder)
      try c.encode(fields, forKey: .fields)
      try c.encode(extra, forKey: .extra)
      try c.encode(expiresOn, forKey: .expiresOn)
      try c.encode(warnings, forKey: .warnings)
      try c.encode(tags, forKey: .tags)
      try c.encode(pinned, forKey: .pinned)
      try c.encode(notes, forKey: .notes)
    }
  }
}

/// Com'è andato un invio che il server può rifiutare con un messaggio.
public enum Esito<Valore: Equatable & Sendable>: Equatable, Sendable {
  case fatto(Valore)
  case rifiutato(String)
}

extension APIClient {
  /// `POST /documents/documents`.
  public func creaDocumento(_ modulo: ModuloDocumento) async throws(APIError) -> Esito<Documento> {
    try await inviaConMessaggio("POST", "documents/documents", corpo: modulo.corpo)
  }

  /// `PATCH /documents/documents/{id}` con tutto il form.
  public func modificaDocumento(
    _ id: String, _ modulo: ModuloDocumento
  ) async throws(APIError) -> Esito<Documento> {
    try await inviaConMessaggio("PATCH", "documents/documents/\(id)", corpo: modulo.corpo)
  }

  /// `POST /documents/documents/{id}/files`: un file per richiesta, fino a
  /// 20 MB. Oltre il limite il server risponde con un messaggio.
  public func caricaAllegato(
    _ id: String, file: Data, nome: String, tipo: String, etichetta: String
  ) async throws(APIError) -> Esito<Documento.Allegato> {
    let confine = "ron1nOS-\(UUID().uuidString)"
    let corpo = APIClient.multipart(
      file, nome: nome, confine: confine, tipo: tipo, campi: [("label", etichetta)])
    let (data, http) = try await risposta(
      "documents/documents/\(id)/files", metodo: "POST", corpo: corpo,
      tipo: "multipart/form-data; boundary=\(confine)")
    return try APIClient.esito(data, http)
  }

  func inviaConMessaggio<Valore: Decodable & Equatable & Sendable>(
    _ metodo: String, _ path: String, corpo: some Encodable & Sendable
  ) async throws(APIError) -> Esito<Valore> {
    let json: Data
    do {
      json = try JSONEncoder().encode(corpo)
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
    let (data, http) = try await risposta(path, metodo: metodo, corpo: json)
    return try APIClient.esito(data, http)
  }

  /// 400, 409 e 413 portano un messaggio da mostrare; gli altri errori no.
  static func esito<Valore: Decodable & Equatable & Sendable>(
    _ data: Data, _ http: HTTPURLResponse, conMessaggio: Set<Int> = [400, 409, 413]
  ) throws(APIError) -> Esito<Valore> {
    if conMessaggio.contains(http.statusCode) {
      let errore = try? JSONDecoder().decode(MessaggioErrore.self, from: data)
      return .rifiutato(errore?.message ?? "Richiesta non valida.")
    }
    guard (200..<300).contains(http.statusCode) else { throw .stato(http.statusCode) }
    do {
      return .fatto(try JSONDecoder().decode(Valore.self, from: data))
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
  }
}

/// Il messaggio di un errore del server, da mostrare.
struct MessaggioErrore: Decodable {
  let message: String
}
