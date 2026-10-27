/// Velocità e torrent di qBittorrent, da `GET /api/v1/downloads` (modulo
/// Download di ron1nOS). I torrent arrivano già in ordine: prima quelli
/// che scaricano, dal più vicino alla fine.
public struct Download: Decodable, Equatable, Sendable {
  /// byte/s in download, in totale.
  public let downloadSpeed: Double
  public let torrents: [Torrent]

  public init(downloadSpeed: Double, torrents: [Torrent]) {
    self.downloadSpeed = downloadSpeed
    self.torrents = torrents
  }

  /// Quanti torrent attivi mostrare per intero, come nel widget web.
  public static let visibili = 3

  public var attivi: [Torrent] { torrents.filter { $0.state == .downloading } }

  /// I torrent da mostrare nella card.
  public var inVista: [Torrent] { Array(attivi.prefix(Download.visibili)) }

  /// "+2 attivi · 1 in coda · 4 in seed", vuoto se non c'è altro.
  public var riepilogo: String {
    let nascosti = max(0, attivi.count - Download.visibili)
    let inCoda = torrents.filter { $0.state == .queued }.count
    let inSeed = torrents.filter { $0.state == .seeding }.count
    return [
      nascosti > 0 ? "+\(nascosti) \(nascosti == 1 ? "attivo" : "attivi")" : nil,
      inCoda > 0 ? "\(inCoda) in coda" : nil,
      inSeed > 0 ? "\(inSeed) in seed" : nil,
    ].compactMap { $0 }.joined(separator: " · ")
  }
}

public struct Torrent: Decodable, Equatable, Sendable {
  public let hash: String
  public let name: String
  /// Da 0 a 1.
  public let progress: Double
  public let state: StatoTorrent
  public let etaSeconds: Int?
  public let downloadSpeed: Double

  public init(
    hash: String, name: String, progress: Double, state: StatoTorrent, etaSeconds: Int? = nil,
    downloadSpeed: Double = 0
  ) {
    self.hash = hash
    self.name = name
    self.progress = progress
    self.state = state
    self.etaSeconds = etaSeconds
    self.downloadSpeed = downloadSpeed
  }

  /// "42% · 2,4 MB/s · 10 min".
  public var dettaglio: String {
    [
      Formato.percento(progress * 100), Formato.velocita(downloadSpeed),
      Formato.rimanente(etaSeconds),
    ].joined(separator: " · ")
  }
}

/// Stato di un torrent. Un valore nuovo non è un errore.
public enum StatoTorrent: Equatable, Sendable, Decodable {
  case downloading, queued, seeding, stopped, error
  case sconosciuto(String)

  public init(from decoder: Decoder) throws {
    let valore = try decoder.singleValueContainer().decode(String.self)
    switch valore {
    case "downloading": self = .downloading
    case "queued": self = .queued
    case "seeding": self = .seeding
    case "stopped": self = .stopped
    case "error": self = .error
    default: self = .sconosciuto(valore)
    }
  }
}

extension APIClient {
  /// `GET /downloads`.
  public func download() async throws(APIError) -> Download {
    try await get("downloads")
  }
}

extension Download {
  /// La pagina Torrent (IOS-070): sotto i download, in righe più piccole,
  /// gli altri torrent; oltre 5 si vedono con `Mostra tutto`.
  public static let altriVisibili = 5

  /// In coda, in seed, fermi o in errore, nell'ordine del server.
  public var altri: [Torrent] { torrents.filter { $0.state != .downloading } }
}

extension Torrent {
  /// "In coda", "In seed", "Fermo", "Errore".
  public var statoTesto: String {
    switch state {
    case .downloading: "In download"
    case .queued: "In coda"
    case .seeding: "In seed"
    case .stopped: "Fermo"
    case .error: "Errore"
    case .sconosciuto(let valore): valore
    }
  }

  /// La riga piccola: "In coda · 42%".
  public var rigaBreve: String {
    state == .seeding ? statoTesto : "\(statoTesto) · \(Formato.percento(progress * 100))"
  }
}
