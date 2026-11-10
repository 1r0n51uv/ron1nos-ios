import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Pausa, ripresa ed eliminazione dei torrent (IOS-072, DL-010).
public enum AzioneTorrent: String, Sendable {
  case pause, resume, delete
}

extension Torrent {
  /// Fermo: si può riprendere.
  public var inPausa: Bool { state == .stopped }

  /// Non fermo: si può mettere in pausa.
  public var sospendibile: Bool { state != .stopped }
}

/// Un gruppo dell'elenco: i torrent con lo stesso stato.
public struct SezioneTorrent: Equatable, Identifiable, Sendable {
  public let id: String
  public let titolo: String
  public let torrents: [Torrent]
  /// In seed si apre a mano: di solito sono tanti e non servono.
  public let chiusaDiDefault: Bool
}

extension Download {
  /// L'elenco della pagina Torrent: In download, In coda, In seed, Fermi,
  /// Errori, ognuno solo se non è vuoto. Dentro, l'ordine del server.
  public var sezioni: [SezioneTorrent] {
    func sezione(_ id: String, _ titolo: String, chiusa: Bool = false, _ filtro: (StatoTorrent) -> Bool)
      -> SezioneTorrent
    {
      SezioneTorrent(
        id: id, titolo: titolo, torrents: torrents.filter { filtro($0.state) }, chiusaDiDefault: chiusa)
    }
    return [
      sezione("download", "In download") { $0 == .downloading },
      sezione("coda", "In coda") { $0 == .queued },
      sezione("seed", "In seed", chiusa: true) { $0 == .seeding },
      sezione("fermi", "Fermi") { $0 == .stopped },
      sezione("errori", "Errori") { stato in
        switch stato {
        case .error, .sconosciuto: true
        default: false
        }
      },
    ].filter { !$0.torrents.isEmpty }
  }
}

/// I torrent scelti per un'azione di gruppo.
public struct SelezioneTorrent: Equatable, Sendable {
  public private(set) var hashes: Set<String> = []

  public init() {}

  public var vuota: Bool { hashes.isEmpty }

  public func contiene(_ torrent: Torrent) -> Bool { hashes.contains(torrent.hash) }

  /// Sceglie o toglie un torrent.
  public mutating func alterna(_ torrent: Torrent) {
    if hashes.contains(torrent.hash) {
      hashes.remove(torrent.hash)
    } else {
      hashes.insert(torrent.hash)
    }
  }

  /// Sceglie tutta la sezione, o la toglie se era già tutta scelta.
  public mutating func alterna(_ sezione: SezioneTorrent) {
    let loro = Set(sezione.torrents.map(\.hash))
    if loro.isSubset(of: hashes) {
      hashes.subtract(loro)
    } else {
      hashes.formUnion(loro)
    }
  }

  /// Dopo un aggiornamento restano solo i torrent che ci sono ancora.
  public mutating func tieni(_ torrents: [Torrent]) {
    hashes.formIntersection(torrents.map(\.hash))
  }

  public mutating func svuota() { hashes = [] }

  /// Tra i scelti ce n'è uno da mettere in pausa.
  public func puoPausa(in torrents: [Torrent]) -> Bool {
    torrents.contains { hashes.contains($0.hash) && $0.sospendibile }
  }

  /// Tra i scelti ce n'è uno da riprendere.
  public func puoRiprendere(in torrents: [Torrent]) -> Bool {
    torrents.contains { hashes.contains($0.hash) && $0.inPausa }
  }

  /// "3 scelti", "1 scelto", "Scegli".
  public var titolo: String {
    switch hashes.count {
    case 0: "Scegli"
    case 1: "1 scelto"
    case let n: "\(n) scelti"
    }
  }
}

/// Un file di un torrent, da `GET /downloads/{hash}`.
public struct FileTorrent: Decodable, Equatable, Sendable {
  public let index: Int
  public let name: String
  public let size: Double
  public let progress: Double
  /// false se escluso dal download.
  public let selected: Bool
}

/// Il torrent con i dati in più e i suoi file (DL-011).
public struct DettaglioTorrent: Decodable, Equatable, Sendable {
  public let hash: String
  public let name: String
  public let progress: Double
  public let state: StatoTorrent
  public let etaSeconds: Int?
  public let downloadSpeed: Double
  public let size: Double
  public let downloaded: Double
  public let uploadSpeed: Double
  public let ratio: Double
  public let savePath: String
  public let addedAt: String
  public let files: [FileTorrent]

  /// Quando è stato aggiunto, se la data è leggibile.
  public var aggiunto: Date? {
    let formato = ISO8601DateFormatter()
    formato.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formato.date(from: addedAt) ?? ISO8601DateFormatter().date(from: addedAt)
  }

  /// Fermo: si può riprendere.
  public var inPausa: Bool { state == .stopped }

  /// "In download", "In seed", "Fermo"…
  public var statoTesto: String {
    Torrent(hash: hash, name: name, progress: progress, state: state).statoTesto
  }

  /// Le righe del dettaglio: nome e valore, come le mostra la pagina.
  public var righe: [(nome: String, valore: String)] {
    [
      ("Dimensione", Formato.dimensione(size)),
      ("Scaricato", Formato.dimensione(downloaded)),
      ("Rapporto", Formato.numero(ratio, decimali: 2)),
      ("Download", Formato.velocita(downloadSpeed)),
      ("Upload", Formato.velocita(uploadSpeed)),
      ("Cartella", savePath),
    ]
  }
}

extension APIClient {
  /// `POST /downloads/actions`. `eliminaFile` conta solo per `delete`.
  public func azione(_ azione: AzioneTorrent, hashes: [String], eliminaFile: Bool = false)
    async throws(APIError)
  {
    struct Corpo: Encodable, Sendable {
      let action: String
      let hashes: [String]
      let deleteFiles: Bool
    }
    let corpo: Data
    do {
      corpo = try JSONEncoder().encode(
        Corpo(action: azione.rawValue, hashes: hashes, deleteFiles: eliminaFile))
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
    _ = try await dati("downloads/actions", metodo: "POST", corpo: corpo)
  }

  /// `GET /downloads/{hash}`.
  public func dettaglio(torrent hash: String) async throws(APIError) -> DettaglioTorrent {
    try await get("downloads/\(hash)")
  }
}

extension AggiungiTorrent {
  /// Un link `magnet:` dentro un testo, per proporre di aggiungerlo quando
  /// è negli appunti. nil se il testo non è un magnet valido.
  public static func magnet(in testo: String?) -> String? {
    guard let testo else { return nil }
    let pulito = testo.trimmingCharacters(in: .whitespacesAndNewlines)
    guard case .magnet? = Link(pulito) else { return nil }
    return pulito
  }
}
