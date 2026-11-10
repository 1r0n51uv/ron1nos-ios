import Foundation

/// Una notifica locale per un download (IOS-075).
public struct NotificaTorrent: Equatable, Sendable {
  public let id: String
  public let titolo: String
  public let corpo: String
  /// Fra quanti secondi; `nil` per subito.
  public let tra: TimeInterval?
}

/// Cosa fare con le notifiche dopo aver letto i download. Con SideStore e un
/// Apple ID gratuito le push non ci sono: il telefono programma da sé una
/// notifica all'ora di fine prevista di ogni download e, quando ne vede uno
/// finito, ne manda una subito.
public struct PianoNotificheTorrent: Equatable, Sendable {
  /// Fine prevista dei download in corso, da programmare.
  public let programma: [NotificaTorrent]
  /// Download finiti dall'ultima lettura: da mandare subito.
  public let finiti: [NotificaTorrent]
  /// Notifiche programmate che non servono più.
  public let annulla: [String]
  /// I download in corso adesso: da ricordare per la prossima lettura.
  public let inDownload: Set<String>

  /// Il margine dopo l'ora prevista, perché le stime sono ottimistiche.
  public static let margine: TimeInterval = 60

  public static func idFine(_ hash: String) -> String { "torrent-fine-\(hash)" }
  public static func idFinito(_ hash: String) -> String { "torrent-finito-\(hash)" }

  /// `prima` sono i download in corso alla lettura precedente.
  public static func piano(download: Download, prima: Set<String>) -> PianoNotificheTorrent {
    let attivi = download.attivi
    let adesso = Set(attivi.map(\.hash))

    let programma = attivi.compactMap { torrent -> NotificaTorrent? in
      guard let eta = torrent.etaSeconds else { return nil }
      return NotificaTorrent(
        id: idFine(torrent.hash), titolo: "Download in arrivo a fine",
        corpo: "\(torrent.name) dovrebbe aver finito.", tra: max(5, Double(eta)) + margine)
    }

    // Era in download e adesso non più: se è completo è finito, se è
    // sparito o fermo a metà no.
    let finiti = download.torrents.filter {
      prima.contains($0.hash) && !adesso.contains($0.hash) && $0.progress >= 1
    }
    .map {
      NotificaTorrent(id: idFinito($0.hash), titolo: "Download finito", corpo: $0.name, tra: nil)
    }

    // Le programmate di chi non è più in corso, completo o no.
    let annulla = prima.subtracting(adesso).map(idFine)

    return PianoNotificheTorrent(
      programma: programma, finiti: finiti, annulla: annulla, inDownload: adesso)
  }
}
