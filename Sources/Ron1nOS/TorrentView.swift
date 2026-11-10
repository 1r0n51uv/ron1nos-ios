#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// La pagina Torrent (IOS-070, IOS-072, IOS-073): la velocità totale e i
  /// torrent in sezioni per stato. Un tocco apre il dettaglio; `Scegli` apre
  /// la selezione per mettere in pausa, riprendere o eliminare più torrent
  /// insieme. Si aggiorna ogni 5 secondi.
  struct TorrentView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.scenePhase) private var fase
    @State private var stato = Carico<Download>.inCorso
    @State private var offline = false
    @State private var aperte: Set<String> = []
    @State private var selezione = SelezioneTorrent()
    @State private var selezionando = false
    @State private var daEliminare: [String] = []
    @State private var eliminando = false
    @State private var inCorso = false
    @State private var magnet: String?
    @State private var magnetIgnorato: String?

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel()
          case .spento:
            Text("Il modulo Download è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            Pillola(testo: "offline", tono: .offline)
            SezioneErrore(errore: errore).glassPanel()
          case .pronto(let download):
            if offline { Pillola(testo: "offline", tono: .offline) }
            if let magnet { propostaMagnet(magnet) }
            velocita(download)
            if download.torrents.isEmpty {
              Text("Nessun torrent")
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
            }
            ForEach(download.sezioni) { sezione in
              self.sezione(sezione)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Torrent")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          if stato.valore?.torrents.isEmpty == false {
            Button(selezionando ? "Fine" : "Scegli") { alternaSelezione() }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          // Senza qBittorrent il wizard non può leggere nulla (IOS-071).
          Button("Aggiungi", systemImage: "plus") { sessione.torrentInArrivo = .nuovo }
            .disabled(offline || stato.valore == nil || selezionando)
        }
      }
      .safeAreaInset(edge: .bottom) {
        if selezionando { barraAzioni }
      }
      .confirmationDialog(
        daEliminare.count == 1 ? "Eliminare il torrent?" : "Eliminare \(daEliminare.count) torrent?",
        isPresented: $eliminando, titleVisibility: .visible
      ) {
        Button("Elimina e tieni i file", role: .destructive) { eliminaIScelti(conFile: false) }
        Button("Elimina anche i file", role: .destructive) { eliminaIScelti(conFile: true) }
        Button("Annulla", role: .cancel) {}
      }
      .refreshable { await carica() }
      .task(id: sessione.versione) {
        await carica()
        controllaAppunti()
      }
      .aggiornaOgni(5) { await carica() }
      .onChange(of: fase) { _, nuova in
        if nuova == .active { controllaAppunti() }
      }
    }

    // MARK: - Sezioni

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

    private func sezione(_ sezione: SezioneTorrent) -> some View {
      // In seed è chiusa finché non la si apre; durante la selezione si
      // vedono tutte, per poter scegliere.
      let aperta =
        selezionando || (sezione.chiusaDiDefault ? aperte.contains(sezione.id) : !aperte.contains(sezione.id))
      return VStack(alignment: .leading, spacing: 12) {
        HStack {
          Button {
            if aperte.contains(sezione.id) { aperte.remove(sezione.id) } else { aperte.insert(sezione.id) }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: aperta ? "chevron.down" : "chevron.right")
                .font(.caption.weight(.semibold))
              Text("\(sezione.titolo) · \(sezione.torrents.count)")
                .font(.footnote.weight(.medium))
            }
            .foregroundStyle(Stile.testoTenue)
          }
          .disabled(selezionando)
          Spacer()
          if selezionando {
            Button("Tutti") { selezione.alterna(sezione) }
              .font(.footnote)
              .tint(Stile.testo)
          }
        }
        if aperta {
          VStack(alignment: .leading, spacing: 16) {
            ForEach(sezione.torrents, id: \.hash) { torrent in
              riga(torrent)
            }
          }
          .glassPanel()
        }
      }
    }

    @ViewBuilder
    private func riga(_ torrent: Torrent) -> some View {
      if selezionando {
        Button {
          selezione.alterna(torrent)
        } label: {
          HStack(spacing: 12) {
            Image(systemName: selezione.contiene(torrent) ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(selezione.contiene(torrent) ? Stile.brand : Stile.testoTenue)
            RigaTorrent(torrent: torrent)
          }
        }
        .buttonStyle(.plain)
      } else {
        NavigationLink {
          TorrentDettaglioView(hash: torrent.hash)
        } label: {
          RigaTorrent(torrent: torrent)
        }
        .buttonStyle(.plain)
        .contextMenu {
          if torrent.inPausa {
            Button("Riprendi", systemImage: "play") { esegui(.resume, [torrent.hash]) }
          } else {
            Button("Pausa", systemImage: "pause") { esegui(.pause, [torrent.hash]) }
          }
          Button("Elimina…", systemImage: "trash", role: .destructive) { chiediEliminazione([torrent.hash]) }
        }
      }
    }

    // MARK: - Selezione e azioni

    private var barraAzioni: some View {
      let torrents = stato.valore?.torrents ?? []
      return HStack(spacing: 12) {
        Text(selezione.titolo)
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
        Spacer()
        Button("Pausa") { esegui(.pause, Array(selezione.hashes)) }
          .glassChip()
          .disabled(!selezione.puoPausa(in: torrents) || inCorso)
        Button("Riprendi") { esegui(.resume, Array(selezione.hashes)) }
          .glassChip()
          .disabled(!selezione.puoRiprendere(in: torrents) || inCorso)
        Button("Elimina") { chiediEliminazione(Array(selezione.hashes)) }
          .glassChip()
          .foregroundStyle(Stile.brandTesto)
          .disabled(selezione.vuota || inCorso)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(.black.opacity(0.7))
    }

    private func alternaSelezione() {
      selezionando.toggle()
      selezione.svuota()
    }

    private func chiediEliminazione(_ hashes: [String]) {
      daEliminare = hashes
      eliminando = true
    }

    private func eliminaIScelti(conFile: Bool) {
      esegui(.delete, daEliminare, eliminaFile: conFile)
    }

    private func esegui(_ azione: AzioneTorrent, _ hashes: [String], eliminaFile: Bool = false) {
      guard !hashes.isEmpty else { return }
      Task {
        inCorso = true
        defer { inCorso = false }
        do {
          try await sessione.client.azione(azione, hashes: hashes, eliminaFile: eliminaFile)
          selezione.svuota()
          selezionando = false
          switch azione {
          case .pause: sessione.mostra(Avviso("Messo in pausa"))
          case .resume: sessione.mostra(Avviso("Ripreso"))
          case .delete: sessione.mostra(Avviso("Eliminato"))
          }
          await carica()
        } catch let errore as APIError {
          sessione.mostra(Avviso(errore.titolo))
        } catch {
          sessione.mostra(Avviso("Non riuscito"))
        }
      }
    }

    // MARK: - Dati

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
      if let download = nuovo.valore {
        selezione.tieni(download.torrents)
        if download.torrents.isEmpty { selezionando = false }
        sessione.letti(download, chiediPermesso: true)
      }
    }

    // MARK: - Magnet negli appunti

    private func controllaAppunti() {
      guard UIPasteboard.general.hasStrings,
        let testo = AggiungiTorrent.magnet(in: UIPasteboard.general.string), testo != magnetIgnorato
      else {
        magnet = nil
        return
      }
      magnet = testo
    }

    private func propostaMagnet(_ link: String) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Magnet negli appunti")
          .font(.headline)
          .foregroundStyle(Stile.testo)
        Text(link)
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
          .lineLimit(2)
          .truncationMode(.middle)
        HStack(spacing: 12) {
          Button("Aggiungi") {
            magnetIgnorato = link
            magnet = nil
            sessione.torrentInArrivo = .link(link)
          }
          .glassChip()
          Button("Ignora") {
            magnetIgnorato = link
            magnet = nil
          }
          .glassChip()
        }
      }
      .glassPanel()
    }
  }

  /// Un torrent nell'elenco: nome, barra e riga di stato.
  struct RigaTorrent: View {
    let torrent: Torrent

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(torrent.name)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
          .lineLimit(2)
          .truncationMode(.middle)
        if torrent.state != .seeding { Barra(valore: torrent.progress) }
        Text(torrent.state == .downloading ? torrent.dettaglio : torrent.rigaBreve)
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(torrent.state == .error ? Stile.brandTesto : Stile.testoTenue)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .combine)
    }
  }
#endif
