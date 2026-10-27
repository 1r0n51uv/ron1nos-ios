#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Torrent (IOS-007): velocità totale, i primi tre attivi con barra e
  /// tempo rimanente, poi il riepilogo di coda e seed.
  struct CardTorrent: View {
    let carico: Carico<Download>
    var misura: Misura?

    /// Quanti torrent si vedono: nessuno nel piccolo, uno nel medio.
    private var quanti: Int {
      switch misura {
      case .small: 0
      case .medium: 1
      default: Download.visibili
      }
    }

    var body: some View {
      Card(titolo: "Torrent", carico: carico, riempi: misura != nil) { download in
        VStack(alignment: .leading, spacing: 12) {
          Text(Formato.velocita(download.downloadSpeed))
            .font(.system(.title2, design: .monospaced).weight(.semibold))
            .foregroundStyle(Stile.testo)
          if download.inVista.isEmpty, misura != .small {
            Text("Niente in download")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          }
          ForEach(download.inVista.prefix(quanti), id: \.hash) { torrent in
            VStack(alignment: .leading, spacing: 6) {
              Text(torrent.name)
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
                .lineLimit(1)
                .truncationMode(.middle)
              Barra(valore: torrent.progress)
              Text(torrent.dettaglio)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
            }
          }
          if !download.riepilogo.isEmpty, misura == nil || misura == .large {
            Text(download.riepilogo)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
    }
  }
#endif
