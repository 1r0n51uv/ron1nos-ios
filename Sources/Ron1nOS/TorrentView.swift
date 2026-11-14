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
    /// Cresce a ogni azione riuscita: dà la vibrazione di conferma.
    @State private var riuscite = 0
    @State private var magnet: String?
    @State private var magnetIgnorato: String?

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel().transition(.blurReplace)
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
              .comparsa(0)
            if download.torrents.isEmpty { vuoto }
            ForEach(Array(download.sezioni.enumerated()), id: \.element.id) { indice, sezione in
              self.sezione(sezione)
                .comparsa(indice + 1)
            }
          }
        }
        .padding(.horizontal, Stile.margine)
        .padding(.bottom, 24)
        .animation(Stile.molla, value: stato.valore?.sezioni.map(\.id))
      }
      .sfondoPagina()
      .navigationTitle("Torrent")
      // Aggiungi, Scegli e le azioni sulla selezione stanno in basso (IOS-044).
      .azioniInBasso {
        if selezionando {
          azioniSelezione
        } else if stato.valore != nil, !offline {
          AzioneBarra(titolo: "Aggiungi", simbolo: "plus", principale: true) {
            sessione.torrentInArrivo = .nuovo
          }
          if stato.valore?.torrents.isEmpty == false {
            AzioneBarra(titolo: "Scegli", simbolo: "checkmark.circle") { alternaSelezione() }
          }
        }
      }
      .animation(Stile.molla, value: selezionando)
      .sensoryFeedback(.success, trigger: riuscite)
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

    /// La velocità totale in grande, con quanti scaricano, in coda e in seed.
    private func velocita(_ download: Download) -> some View {
      let ambra = Modulo.torrent.colore
      return HStack(spacing: 14) {
        Tessera(simbolo: "arrow.down", tinta: ambra, lato: 44)
          .symbolEffect(.pulse, isActive: download.downloadSpeed > 0)
        VStack(alignment: .leading, spacing: 2) {
          Text(Formato.velocita(download.downloadSpeed))
            .font(.system(.title, design: .monospaced).weight(.bold))
            .foregroundStyle(Stile.testo)
            .contentTransition(.numericText())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          Text(conteggio(download))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .glassPanel(tinta: ambra)
      .accessibilityElement(children: .combine)
    }

    private func conteggio(_ download: Download) -> String {
      let attivi = download.attivi.count
      let primo = attivi == 1 ? "1 in download" : "\(attivi) in download"
      return download.riepilogo.isEmpty || attivi > Download.visibili
        ? primo : "\(primo) · \(download.riepilogo)"
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
            HStack(spacing: 8) {
              Image(systemName: sezione.simbolo)
                .font(.caption.weight(.bold))
                .foregroundStyle(coloreSezione(sezione))
              Text("\(sezione.titolo) · \(sezione.torrents.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Stile.testo)
              Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Stile.testoTenue)
                .rotationEffect(.degrees(aperta ? 90 : 0))
            }
            .frame(minHeight: 32)
            .contentShape(Rectangle())
          }
          .buttonStyle(StilePremuto())
          .disabled(selezionando)
          Spacer()
          if selezionando {
            Button("Tutti") { selezione.alterna(sezione) }
              .font(.footnote)
              .tint(Stile.testo)
          }
        }
        if aperta {
          VStack(alignment: .leading, spacing: 14) {
            ForEach(sezione.torrents, id: \.hash) { torrent in
              riga(torrent)
            }
          }
          .glassPanel()
          .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
        }
      }
      .animation(Stile.molla, value: aperta)
    }

    private func coloreSezione(_ sezione: SezioneTorrent) -> Color {
      switch sezione.id {
      case "download": Modulo.torrent.colore
      case "errori": Stile.brandTesto
      default: Stile.testoTenue
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
              .font(.title3)
              .foregroundStyle(selezione.contiene(torrent) ? Modulo.torrent.colore : Stile.testoTenue)
              .contentTransition(.symbolEffect(.replace))
            RigaTorrent(torrent: torrent)
          }
        }
        .buttonStyle(StilePremuto())
      } else {
        NavigationLink {
          TorrentDettaglioView(hash: torrent.hash)
        } label: {
          RigaTorrent(torrent: torrent)
        }
        .buttonStyle(StilePremuto())
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

    // MARK: - Aggiungere

    /// Lo stato vuoto non è un vicolo cieco: dice cosa fare.
    private var vuoto: some View {
      StatoVuoto(
        simbolo: "tray.fill", titolo: "Nessun torrent",
        testo: "Aggiungi un file .torrent o un link magnet, oppure aprine uno da Safari o da File.",
        tinta: Modulo.torrent.colore)
    }

    // MARK: - Selezione e azioni

    /// Con la selezione aperta: Pausa, Riprendi, Elimina e Fine, tutti in
    /// basso; quanti sono scelti lo dice il titolo di Fine.
    @ViewBuilder
    private var azioniSelezione: some View {
      let torrents = stato.valore?.torrents ?? []
      AzioneBarra(titolo: "Pausa", simbolo: "pause.fill", inCorso: inCorso, compatta: true) {
        esegui(.pause, Array(selezione.hashes))
      }
      .disabled(!selezione.puoPausa(in: torrents))
      AzioneBarra(titolo: "Riprendi", simbolo: "play.fill", compatta: true) {
        esegui(.resume, Array(selezione.hashes))
      }
      .disabled(!selezione.puoRiprendere(in: torrents) || inCorso)
      AzioneBarra(titolo: "Elimina", simbolo: "trash", distruttiva: true, compatta: true) {
        chiediEliminazione(Array(selezione.hashes))
      }
      .disabled(selezione.vuota || inCorso)
      AzioneBarra(
        titolo: selezione.vuota ? "Fine" : "Fine · \(selezione.titolo)", simbolo: "checkmark",
        principale: true
      ) {
        alternaSelezione()
      }
    }

    private func alternaSelezione() {
      withAnimation(Stile.molla) { selezionando.toggle() }
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
          riuscite += 1
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
        withAnimation(Stile.molla) {
          stato = nuovo
          offline = false
        }
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
        IntestazioneCard(titolo: "Magnet negli appunti", simbolo: "link", tinta: Modulo.torrent.colore)
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
          .pulsantePieno(Modulo.torrent.colore)
          Button("Ignora") {
            magnetIgnorato = link
            magnet = nil
          }
          .glassChip()
        }
      }
      .glassPanel(tinta: Modulo.torrent.colore)
      .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  /// Un torrent nell'elenco: l'anello dell'avanzamento con il simbolo dello
  /// stato, il nome e la riga di stato.
  struct RigaTorrent: View {
    let torrent: Torrent

    var body: some View {
      let errore = torrent.state == .error
      HStack(spacing: 12) {
        Anello(valore: torrent.progress, tinta: colore, spessore: 4, segnale: errore) {
          Image(systemName: torrent.simbolo)
            .font(.caption.weight(.bold))
            .foregroundStyle(errore ? Stile.brandTesto : colore)
        }
        .frame(width: 38, height: 38)
        VStack(alignment: .leading, spacing: 4) {
          Text(torrent.name)
            .font(.subheadline)
            .foregroundStyle(Stile.testo)
            .lineLimit(2)
            .truncationMode(.middle)
          Text(torrent.state == .downloading ? torrent.dettaglio : torrent.rigaBreve)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(errore ? Stile.brandTesto : Stile.testoTenue)
            .contentTransition(.numericText())
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
    }

    /// L'ambra per chi scarica, il bianco tenue per gli altri.
    private var colore: Color {
      torrent.state == .downloading ? Modulo.torrent.colore : Stile.testoTenue
    }
  }
#endif
