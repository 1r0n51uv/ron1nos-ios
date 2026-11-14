#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Download, mezza larghezza nella Home: la velocità totale e quanti
  /// torrent scaricano. Si apre la pagina Torrent.
  struct CardTorrent: View {
    let carico: Carico<Download>

    var body: some View {
      Card(titolo: "Download", modulo: .torrent, carico: carico, freccia: true) { download in
        VStack(alignment: .leading, spacing: 4) {
          Text(Formato.velocita(download.downloadSpeed))
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .foregroundStyle(Stile.testo)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          Text(sottotitolo(download))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
            .lineLimit(2)
        }
        .frame(maxHeight: .infinity, alignment: .top)
      }
    }

    private func sottotitolo(_ download: Download) -> String {
      switch download.attivi.count {
      case 0: download.torrents.isEmpty ? "Niente in coda" : "Fermo · \(download.torrents.count) torrent"
      case 1: "1 in download"
      case let n: "\(n) in download"
      }
    }
  }

  /// I torrent che scaricano, a tutta larghezza sotto le due card: nome,
  /// barra e tempo rimanente, più il riepilogo di coda e seed.
  struct CardInDownload: View {
    let download: Download

    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        ForEach(download.inVista, id: \.hash) { torrent in
          VStack(alignment: .leading, spacing: 6) {
            Text(torrent.name)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
              .lineLimit(1)
              .truncationMode(.middle)
            Barra(valore: torrent.progress, tinta: Modulo.torrent.colore)
            Text(torrent.dettaglio)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
              .contentTransition(.numericText())
          }
          .accessibilityElement(children: .combine)
        }
        if !download.riepilogo.isEmpty {
          Text(download.riepilogo)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .glassPanel()
    }
  }
#endif
