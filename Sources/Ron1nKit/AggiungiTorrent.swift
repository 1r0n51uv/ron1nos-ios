import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Il wizard `Aggiungi` (IOS-071, DL-003…DL-008): gli stessi passi e le
/// stesse regole del sito.
public enum AggiungiTorrent {
  public static let massimoFile = 10 * 1024 * 1024
  public static let passi = 4

  /// "AGGIUNGI TORRENT · 2 DI 4".
  public static func titolo(passo: Int) -> String { "AGGIUNGI TORRENT · \(passo) DI \(passi)" }

  /// Un link valido: magnet v1 o v2, o un URL http(s).
  public enum Link: Equatable, Sendable {
    case magnet(versione: String)
    case url

    public init?(_ testo: String) {
      let t = testo.trimmingCharacters(in: .whitespacesAndNewlines)
      let minuscolo = t.lowercased()
      if minuscolo.hasPrefix("magnet:?") {
        if minuscolo.contains("xt=urn:btih:") {
          self = .magnet(versione: "v1")
        } else if minuscolo.contains("xt=urn:btmh:") {
          self = .magnet(versione: "v2")
        } else {
          return nil
        }
        return
      }
      guard let url = URL(string: t), let schema = url.scheme?.lowercased(),
        schema == "http" || schema == "https", let host = url.host(), !host.isEmpty
      else { return nil }
      self = .url
    }

    /// "magnet · v1" o "URL di un file .torrent".
    public var etichetta: String {
      switch self {
      case .magnet(let versione): "magnet · \(versione)"
      case .url: "URL di un file .torrent"
      }
    }
  }

  /// Un file `.torrent` accettabile: estensione giusta, non vuoto, fino a
  /// 10 MB.
  public static func fileValido(nome: String, dimensione: Int) -> Bool {
    nome.lowercased().hasSuffix(".torrent") && dimensione > 0 && dimensione <= massimoFile
  }

  /// L'attesa dei metadati come sul sito: "0:18".
  public static func orologio(_ secondi: Int) -> String {
    let s = max(0, secondi)
    return "\(s / 60):\(s % 60 < 10 ? "0" : "")\(s % 60)"
  }

  /// "in download", "in seed"… per il torrent già presente.
  public static func stato(_ stato: String) -> String {
    switch stato {
    case "downloading": "in download"
    case "queued": "in coda"
    case "seeding": "in seed"
    case "stopped": "fermo"
    case "error": "in errore"
    default: stato
    }
  }
}

/// Una bozza del wizard: il torrent letto ma non ancora in qBittorrent.
public struct BozzaTorrent: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  /// `file`, `url` o `magnet`.
  public let source: String
  /// `ready`, `metadata` (magnet in attesa) o `timeout`.
  public let status: String
  public let infoHash: String
  public let name: String
  public let size: Double
  public let files: [FileBozza]
  public let metadata: Attesa?

  public init(
    id: String, source: String = "file", status: String = "ready", infoHash: String = "", name: String,
    size: Double = 0, files: [FileBozza] = [], metadata: Attesa? = nil
  ) {
    self.id = id
    self.source = source
    self.status = status
    self.infoHash = infoHash
    self.name = name
    self.size = size
    self.files = files
    self.metadata = metadata
  }

  public struct Attesa: Decodable, Equatable, Sendable {
    public let peers: Int
    public let waitedSeconds: Int
    public let limitSeconds: Int

    public init(peers: Int, waitedSeconds: Int, limitSeconds: Int) {
      self.peers = peers
      self.waitedSeconds = waitedSeconds
      self.limitSeconds = limitSeconds
    }

    /// "3 peer · 0:18 su 1:00", come sul sito.
    public var testo: String {
      let attesa = AggiungiTorrent.orologio(waitedSeconds)
      return "\(peers) peer · \(attesa) su \(AggiungiTorrent.orologio(limitSeconds))"
    }
  }

  public var pronta: Bool { status == "ready" }
  public var scaduta: Bool { status == "timeout" }

  /// "12 file · 3,9 GB".
  public var riepilogo: String {
    "\(files.count) file · \(Formato.dimensione(size))"
  }
}

public struct FileBozza: Decodable, Equatable, Sendable {
  public let index: Int
  /// Con la cartella del torrent, separato da `/`.
  public let path: String
  public let size: Double

  public init(index: Int, path: String, size: Double) {
    self.index = index
    self.path = path
    self.size = size
  }
}

/// Il passo 3 (DL-006): i file come albero di cartelle, con la scelta fatta
/// per indice di file.
public struct NodoFile: Equatable, Identifiable, Sendable {
  public let nome: String
  public let percorso: String
  public var dimensione: Double
  /// Gli indici dei file sotto questo nodo.
  public var indici: [Int]
  /// Solo per i file.
  public let indice: Int?
  public var figli: [NodoFile]

  public var id: String { indice.map { "f\($0)" } ?? "d\(percorso)" }
  public var cartella: Bool { indice == nil }
  /// nil per i file: serve a `OutlineGroup`.
  public var figliOpzionali: [NodoFile]? { cartella ? figli : nil }

  public enum Spunta: Sendable { case tutto, niente, parte }

  public func spunta(_ scelti: Set<Int>) -> Spunta {
    let quanti = indici.filter { scelti.contains($0) }.count
    return quanti == 0 ? .niente : quanti == indici.count ? .tutto : .parte
  }

  /// Scegliere una cartella sceglie tutto quello che contiene.
  public func alterna(_ scelti: Set<Int>) -> Set<Int> {
    spunta(scelti) == .tutto ? scelti.subtracting(indici) : scelti.union(indici)
  }

  public static func albero(_ file: [FileBozza]) -> [NodoFile] {
    var radice = NodoFile(nome: "", percorso: "", dimensione: 0, indici: [], indice: nil, figli: [])
    for voce in file {
      inserisci(voce, parti: voce.path.split(separator: "/").map(String.init), in: &radice, da: 0)
    }
    return radice.figli
  }

  private static func inserisci(
    _ voce: FileBozza, parti: [String], in nodo: inout NodoFile, da posizione: Int
  ) {
    nodo.dimensione += voce.size
    nodo.indici.append(voce.index)
    guard posizione < parti.count else { return }
    let percorso = parti[...posizione].joined(separator: "/")
    let foglia = posizione == parti.count - 1
    if foglia {
      nodo.figli.append(
        NodoFile(
          nome: parti[posizione], percorso: percorso, dimensione: voce.size, indici: [voce.index],
          indice: voce.index, figli: []))
      return
    }
    if let i = nodo.figli.firstIndex(where: { $0.percorso == percorso && $0.cartella }) {
      inserisci(voce, parti: parti, in: &nodo.figli[i], da: posizione + 1)
    } else {
      var nuova = NodoFile(
        nome: parti[posizione], percorso: percorso, dimensione: 0, indici: [], indice: nil, figli: [])
      inserisci(voce, parti: parti, in: &nuova, da: posizione + 1)
      nodo.figli.append(nuova)
    }
  }

  public static func dimensione(_ file: [FileBozza], scelti: Set<Int>) -> Double {
    file.filter { scelti.contains($0.index) }.reduce(0) { $0 + $1.size }
  }
}

/// Lo spazio libero nella cartella di qBittorrent.
public struct Spazio: Decodable, Equatable, Sendable {
  public let free: Double
  public let path: String

  public init(free: Double, path: String) {
    self.free = free
    self.path = path
  }

  /// "Servono 3,9 GB, liberi 2,1 GB. Togli qualche file al passo
  /// precedente.", o nil se basta.
  public func avviso(servono: Double) -> String? {
    guard servono > free else { return nil }
    return "Servono \(Formato.dimensione(servono)), liberi \(Formato.dimensione(free)). "
      + "Togli qualche file al passo precedente."
  }
}

/// Perché il wizard non va avanti: titolo e testo come sul sito, dal
/// codice d'errore del server.
public struct ProblemaBozza: Equatable, Sendable {
  public let codice: String
  public let titolo: String
  public let testo: String?

  public init(codice: String, messaggio: String = "", torrent: (nome: String, stato: String)? = nil) {
    self.codice = codice
    switch codice {
    case "invalid_torrent":
      titolo = "File torrent non valido."
      testo = "Il file non è un torrent o supera 10 MB."
    case "torrent_fetch_failed":
      titolo = "Impossibile scaricare il file torrent."
      testo = "L’indirizzo non risponde, non è permesso o il file non è un torrent."
    case "invalid_link":
      titolo = "Link non valido."
      testo = "Serve un link magnet o l’URL http(s) di un file .torrent."
    case "duplicate":
      titolo = "Questo torrent è già nei download."
      testo = torrent.map { "\($0.nome) · \(AggiungiTorrent.stato($0.stato))" }
    case "qbittorrent_unreachable", "network":
      titolo = "qBittorrent non raggiungibile."
      testo = "Riprova tra poco."
    case "draft_not_found":
      titolo = "Il torrent non c’è più."
      testo = "È stato tolto da qBittorrent. Ricomincia dal passo 1."
    case "insufficient_space":
      titolo = "Spazio insufficiente."
      testo = "Togli qualche file al passo precedente."
    case "start_failed":
      titolo = "Avvio non riuscito. Riprova."
      testo = "qBittorrent non ha accettato il torrent."
    default:
      titolo = "Lettura non riuscita."
      testo = messaggio.isEmpty ? nil : messaggio
    }
  }

  /// Il backend non risponde.
  public static let rete = ProblemaBozza(codice: "network")
}

/// Com'è andato un passo del wizard.
public enum EsitoBozza<Valore: Equatable & Sendable>: Equatable, Sendable {
  case fatto(Valore)
  case problema(ProblemaBozza)
}

extension APIClient {
  /// `POST /downloads/drafts` con un file `.torrent`.
  public func creaBozza(file: Data, nome: String) async throws(APIError) -> EsitoBozza<BozzaTorrent> {
    let confine = "ron1nOS-\(UUID().uuidString)"
    let corpo = APIClient.multipart(file, nome: nome, confine: confine, tipo: "application/x-bittorrent")
    let (data, http) = try await risposta(
      "downloads/drafts", metodo: "POST", corpo: corpo, tipo: "multipart/form-data; boundary=\(confine)")
    return try APIClient.esitoBozza(data, http)
  }

  /// `POST /downloads/drafts` con un magnet o l'URL di un `.torrent`.
  public func creaBozza(link: String) async throws(APIError) -> EsitoBozza<BozzaTorrent> {
    struct Corpo: Encodable, Sendable { let link: String }
    let json = try APIClient.json(Corpo(link: link.trimmingCharacters(in: .whitespacesAndNewlines)))
    let (data, http) = try await risposta("downloads/drafts", metodo: "POST", corpo: json)
    return try APIClient.esitoBozza(data, http)
  }

  /// `GET /downloads/drafts/{id}`: con un magnet dice se i metadati sono
  /// arrivati.
  public func bozza(_ id: String) async throws(APIError) -> EsitoBozza<BozzaTorrent> {
    let (data, http) = try await risposta("downloads/drafts/\(id)")
    return try APIClient.esitoBozza(data, http)
  }

  /// Altri 60 secondi di attesa dei metadati.
  public func riprovaBozza(_ id: String) async throws(APIError) -> EsitoBozza<BozzaTorrent> {
    let (data, http) = try await risposta("downloads/drafts/\(id)/retry", metodo: "POST")
    return try APIClient.esitoBozza(data, http)
  }

  /// `POST /downloads/drafts/{id}/start` con gli indici dei file scelti:
  /// l'hash del torrent avviato.
  public func avviaBozza(_ id: String, file: [Int]) async throws(APIError) -> EsitoBozza<String> {
    struct Corpo: Encodable, Sendable { let files: [Int] }
    struct Avviato: Decodable, Equatable, Sendable { let hash: String }
    let json = try APIClient.json(Corpo(files: file.sorted()))
    let (data, http) = try await risposta("downloads/drafts/\(id)/start", metodo: "POST", corpo: json)
    let esito: EsitoBozza<Avviato> = try APIClient.esitoBozza(data, http)
    switch esito {
    case .fatto(let avviato): return .fatto(avviato.hash)
    case .problema(let problema): return .problema(problema)
    }
  }

  /// `DELETE /downloads/drafts/{id}`: annulla la bozza.
  public func annullaBozza(_ id: String) async throws(APIError) {
    _ = try await dati("downloads/drafts/\(id)", metodo: "DELETE")
  }

  /// `GET /downloads/space`.
  public func spazio() async throws(APIError) -> Spazio {
    try await get("downloads/space")
  }

  /// I codici con cui il server spiega perché il wizard si ferma.
  static let erroriBozza: Set<Int> = [400, 404, 409, 422, 502, 503]

  private static func json(_ corpo: some Encodable) throws(APIError) -> Data {
    do {
      return try JSONEncoder().encode(corpo)
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
  }

  /// Un errore con il suo codice diventa un problema da mostrare; gli
  /// altri restano errori.
  static func esitoBozza<Valore: Decodable & Equatable & Sendable>(
    _ data: Data, _ http: HTTPURLResponse
  ) throws(APIError) -> EsitoBozza<Valore> {
    guard (200..<300).contains(http.statusCode) else {
      guard APIClient.erroriBozza.contains(http.statusCode),
        let errore = try? JSONDecoder().decode(ErroreBozza.self, from: data)
      else {
        throw .stato(http.statusCode)
      }
      let torrent = errore.torrent.map { (nome: $0.name, stato: $0.state) }
      return .problema(ProblemaBozza(codice: errore.error, messaggio: errore.message ?? "", torrent: torrent))
    }
    do {
      return .fatto(try JSONDecoder().decode(Valore.self, from: data))
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
  }
}

/// Un errore del wizard come lo manda il server.
struct ErroreBozza: Decodable {
  struct Presente: Decodable {
    let name: String
    let state: String
  }
  let error: String
  let message: String?
  let torrent: Presente?
}
