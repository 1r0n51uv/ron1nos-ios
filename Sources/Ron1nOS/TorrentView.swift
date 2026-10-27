#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La pagina Torrent (IOS-070, DL-001, DL-002): velocità totale grande, i
  /// download con barra e tempo, sotto gli altri in righe piccole. In sola
  /// lettura come il widget; si aggiorna ogni 5 secondi.
  struct TorrentView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<Download> = .inCorso
    @State private var tutti = false
    @State private var offline = false

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito:
            Pillola(testo: "offline", tono: .offline)
            Text("qBittorrent non risponde. Riprovo da solo ogni 5 secondi.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .pronto(let download):
            if offline { Pillola(testo: "offline", tono: .offline) }
            velocita(download)
            if download.attivi.isEmpty {
              Text("Niente in download")
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
            } else {
              VStack(alignment: .leading, spacing: 16) {
                ForEach(download.attivi, id: \.hash) { torrent in
                  RigaDownload(torrent: torrent)
                }
              }
              .glassPanel()
            }
            if !download.altri.isEmpty {
              altri(download)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Torrent")
      .refreshable { await carica() }
      .task { await carica() }
      .aggiornaOgni(5) { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      let nuovo = await Carico.da { try await client.download() }
      // Un aggiornamento fallito dopo il primo non cancella i dati: lo
      // dice la pillola.
      if case .fallito = nuovo, stato.valore != nil {
        offline = true
      } else {
        stato = nuovo
        offline = false
      }
    }

    private func velocita(_ download: Download) -> some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(Formato.velocita(download.downloadSpeed))
          .font(.system(size: 44, weight: .semibold, design: .monospaced))
          .foregroundStyle(Stile.testo)
          .contentTransition(.numericText())
        Text("DOWNLOAD")
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
      }
      .accessibilityElement(children: .combine)
    }

    private func altri(_ download: Download) -> some View {
      let elenco = tutti ? download.altri : Array(download.altri.prefix(Download.altriVisibili))
      return VStack(alignment: .leading, spacing: 10) {
        ForEach(elenco, id: \.hash) { torrent in
          HStack {
            Text(torrent.name)
              .font(.footnote)
              .foregroundStyle(Stile.testo)
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
            Text(torrent.rigaBreve)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(torrent.state == .error ? Stile.brand : Stile.testoTenue)
          }
          .accessibilityElement(children: .combine)
        }
        if download.altri.count > Download.altriVisibili {
          Button(tutti ? "Mostra meno" : "Mostra tutto · \(download.altri.count)") { tutti.toggle() }
            .font(.footnote)
            .tint(Stile.testo)
        }
      }
      .glassPanel()
    }
  }

  /// Un torrent in download: nome, barra, percentuale, velocità e tempo.
  struct RigaDownload: View {
    let torrent: Torrent

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(torrent.name)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
          .lineLimit(2)
          .truncationMode(.middle)
        Barra(valore: torrent.progress)
        Text(torrent.dettaglio)
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
      }
      .accessibilityElement(children: .combine)
    }
  }
#endif
