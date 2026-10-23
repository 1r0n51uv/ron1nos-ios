#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Torrent (IOS-007): velocità totale, i primi tre attivi con barra e
  /// tempo rimanente, poi il riepilogo di coda e seed.
  struct CardTorrent: View {
    let carico: Carico<Download>

    var body: some View {
      Card(titolo: "Torrent", carico: carico) { download in
        VStack(alignment: .leading, spacing: 12) {
          Text(Formato.velocita(download.downloadSpeed))
            .font(.system(.title2, design: .monospaced).weight(.semibold))
            .foregroundStyle(Stile.testo)
          if download.inVista.isEmpty {
            Text("Niente in download")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          }
          ForEach(download.inVista, id: \.hash) { torrent in
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
          if !download.riepilogo.isEmpty {
            Text(download.riepilogo)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
    }
  }
#endif
