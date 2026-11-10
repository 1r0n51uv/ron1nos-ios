#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UniformTypeIdentifiers

  /// Da dove parte il wizard: dal pulsante `Aggiungi`, da un `.torrent`
  /// condiviso o da un link `magnet:` (IOS-071).
  enum TorrentInArrivo: Identifiable, Equatable {
    case nuovo
    case file(nome: String, dati: Data)
    case link(String)

    var id: String {
      switch self {
      case .nuovo: "nuovo"
      case .file(let nome, let dati): "file-\(nome)-\(dati.count)"
      case .link(let link): "link-\(link)"
      }
    }

    /// Legge un `.torrent`, anche fuori dalla sandbox dell'app.
    static func leggi(_ url: URL) -> TorrentInArrivo? {
      let accesso = url.startAccessingSecurityScopedResource()
      defer { if accesso { url.stopAccessingSecurityScopedResource() } }
      guard let dati = try? Data(contentsOf: url) else { return nil }
      return .file(nome: url.lastPathComponent, dati: dati)
    }
  }

  /// Il wizard `Aggiungi` in un foglio a tutta altezza, con i 4 passi del
  /// sito (DL-003…DL-008): sorgente, contenuti, file, avvio. Chiuderlo
  /// prima di `Avvia` annulla la bozza.
  struct AggiungiTorrentView: View {
    let partenza: TorrentInArrivo
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi

    enum Modo: String, CaseIterable { case file = "File", link = "Link" }

    @State private var passo = 1
    @State private var modo = Modo.file
    @State private var link = ""
    @State private var file: (nome: String, dati: Data)?
    @State private var sceltaFile = false
    @State private var problemaFile: ProblemaBozza?
    @State private var bozza: BozzaTorrent?
    @State private var problema: ProblemaBozza?
    @State private var scelti: Set<Int> = []
    @State private var spazio: Carico<Spazio> = .inCorso
    @State private var problemaAvvio: ProblemaBozza?
    @State private var avvio = false
    @State private var avviato = false
    @State private var iniziato = false

    var body: some View {
      NavigationStack {
        Group {
          switch passo {
          case 1: pagina { sorgente }
          case 2: pagina { contenuti }
          case 3: sceltaDeiFile
          default: pagina { riepilogo }
          }
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle(AggiungiTorrent.titolo(passo: passo))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
        .safeAreaInset(edge: .bottom) { piede }
      }
      .tint(Stile.brand)
      .presentationDetents([.large])
      .fileImporter(
        isPresented: $sceltaFile, allowedContentTypes: [AggiungiTorrentView.tipoTorrent]
      ) { esito in
        if case .success(let url) = esito, case .file(let nome, let dati)? = TorrentInArrivo.leggi(url) {
          scegli(nome: nome, dati: dati)
        }
      }
      .task {
        guard !iniziato else { return }
        iniziato = true
        switch partenza {
        case .nuovo: break
        case .file(let nome, let dati): scegli(nome: nome, dati: dati)
        case .link(let testo):
          modo = .link
          link = testo
          if AggiungiTorrent.Link(testo) != nil { await vai(a: 2) }
        }
      }
      .onDisappear {
        // Come `Annulla` sul sito: la bozza non resta in qBittorrent.
        guard !avviato, let id = bozza?.id else { return }
        let client = sessione.client
        Task { try? await client.annullaBozza(id) }
      }
    }

    static let tipoTorrent = UTType(filenameExtension: "torrent") ?? .data

    private func pagina(@ViewBuilder _ contenuto: () -> some View) -> some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) { contenuto() }
          .padding(16)
      }
    }

    // MARK: Passo 1 · sorgente

    @ViewBuilder
    private var sorgente: some View {
      Picker("Sorgente", selection: $modo) {
        ForEach(Modo.allCases, id: \.self) { Text($0.rawValue) }
      }
      .pickerStyle(.segmented)
      switch modo {
      case .file:
        Button {
          sceltaFile = true
        } label: {
          Label(file?.nome ?? "Scegli un file .torrent", systemImage: "doc")
            .frame(maxWidth: .infinity, alignment: .leading)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .foregroundStyle(Stile.testo)
        .glassPanel()
        if let problemaFile {
          Avvertenza(problema: problemaFile)
        }
      case .link:
        VStack(alignment: .leading, spacing: 10) {
          TextField("magnet:?xt=urn:btih:… o https://…", text: $link, axis: .vertical)
            .font(.system(.footnote, design: .monospaced))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .lineLimit(1...4)
          HStack {
            if let tipo = AggiungiTorrent.Link(link) {
              Text(tipo.etichetta)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
            } else if !link.isEmpty {
              Text("Serve un link magnet o l’URL http(s) di un file .torrent.")
                .font(.caption)
                .foregroundStyle(Stile.brandTesto)
            }
            Spacer()
            // Il pulsante di sistema: niente richiesta di permesso.
            PasteButton(payloadType: String.self) { testi in
              guard let testo = testi.first else { return }
              Task { @MainActor in link = testo.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .buttonBorderShape(.capsule)
            .labelStyle(.titleAndIcon)
          }
        }
        .glassPanel()
      }
    }

    private func scegli(nome: String, dati: Data) {
      modo = .file
      guard AggiungiTorrent.fileValido(nome: nome, dimensione: dati.count) else {
        file = nil
        problemaFile = ProblemaBozza(codice: "invalid_torrent")
        return
      }
      file = (nome, dati)
      problemaFile = nil
      Task { await vai(a: 2) }
    }

    // MARK: Passo 2 · contenuti

    @ViewBuilder
    private var contenuti: some View {
      if let problema {
        Avvertenza(problema: problema)
      } else if let bozza {
        if bozza.scaduta {
          let limite = bozza.metadata?.limitSeconds ?? 60
          VStack(alignment: .leading, spacing: 10) {
            Text("Nessun peer ha fornito i metadati.")
              .font(.headline)
              .foregroundStyle(Stile.testo)
            Text("Attesi \(limite) secondi. Puoi riprovare per altri \(limite).")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
            Button("Riprova") { Task { await riprova() } }
              .glassChip()
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .glassPanel(tinta: Stile.brand)
        } else if bozza.pronta {
          VStack(alignment: .leading, spacing: 4) {
            Text("Torrent")
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
            Text(bozza.name)
              .font(.headline)
              .foregroundStyle(Stile.testo)
              .lineLimit(2)
              .truncationMode(.middle)
            Text(bozza.riepilogo)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .glassPanel()
        } else {
          attesa("Recupero dei metadati…", dettaglio: bozza.metadata?.testo)
            .task(id: bozza.id) { await aspettaMetadati(bozza.id) }
        }
        if bozza.source == "magnet" {
          Text("magnet · \(bozza.infoHash)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      } else {
        attesa("Lettura del torrent…", dettaglio: nil)
      }
    }

    private func attesa(_ titolo: String, dettaglio: String?) -> some View {
      VStack(spacing: 14) {
        ProgressView().controlSize(.large)
        Text(titolo)
          .font(.headline)
          .foregroundStyle(Stile.testo)
        if let dettaglio {
          Text("I peer stanno inviando nome ed elenco dei file.")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
          Text(dettaglio)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 220)
      .glassPanel()
      .accessibilityElement(children: .combine)
    }

    private func leggi() async {
      let client = sessione.client
      bozza = nil
      problema = nil
      do {
        let esito: EsitoBozza<BozzaTorrent>
        if modo == .file, let file {
          esito = try await client.creaBozza(file: file.dati, nome: file.nome)
        } else {
          esito = try await client.creaBozza(link: link)
        }
        aggiorna(esito)
      } catch {
        problema = .rete
      }
    }

    private func aggiorna(_ esito: EsitoBozza<BozzaTorrent>) {
      switch esito {
      case .fatto(let nuova):
        if nuova.pronta, bozza?.pronta != true { scelti = Set(nuova.files.map(\.index)) }
        bozza = nuova
      case .problema(let nuovo):
        problema = nuovo
      }
    }

    /// Con un magnet si rilegge la bozza ogni secondo, come sul sito.
    private func aspettaMetadati(_ id: String) async {
      let client = sessione.client
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled, let esito = try? await client.bozza(id) else { continue }
        aggiorna(esito)
        if case .fatto(let letta) = esito, letta.status != "metadata" { return }
        if case .problema = esito { return }
      }
    }

    private func riprova() async {
      guard let id = bozza?.id else { return }
      do {
        aggiorna(try await sessione.client.riprovaBozza(id))
      } catch {
        problema = .rete
      }
    }

    // MARK: Passo 3 · file

    private var sceltaDeiFile: some View {
      List {
        Section {
          HStack(spacing: 10) {
            Button("Tutti") { scelti = Set((bozza?.files ?? []).map(\.index)) }
              .glassChip()
            Button("Nessuno") { scelti = [] }
              .glassChip()
          }
          .buttonStyle(.plain)
          .listRowBackground(Color.clear)
        }
        Section {
          OutlineGroup(NodoFile.albero(bozza?.files ?? []), children: \.figliOpzionali) { nodo in
            RigaNodo(nodo: nodo, spunta: nodo.spunta(scelti)) { scelti = nodo.alterna(scelti) }
          }
          .listRowBackground(Color.white.opacity(0.04))
        }
      }
      .scrollContentBackground(.hidden)
    }

    // MARK: Passo 4 · avvio

    @ViewBuilder
    private var riepilogo: some View {
      if let bozza {
        let servono = NodoFile.dimensione(bozza.files, scelti: scelti)
        VStack(alignment: .leading, spacing: 4) {
          Text("Torrent")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
          Text(bozza.name)
            .font(.headline)
            .foregroundStyle(Stile.testo)
            .lineLimit(2)
            .truncationMode(.middle)
        }
        HStack(spacing: 12) {
          Tessera(titolo: "Da scaricare", valore: Formato.dimensione(servono)) {
            "\(scelti.count) file su \(bozza.files.count)"
          }
          switch spazio {
          case .pronto(let libero):
            Tessera(titolo: "Spazio libero", valore: Formato.dimensione(libero.free)) {
              "dopo il download: \(Formato.dimensione(max(0, libero.free - servono)))"
            }
          case .inCorso:
            Tessera(titolo: "Spazio libero", valore: "—") { "lettura…" }
          default:
            Tessera(titolo: "Spazio libero", valore: "—") { "non disponibile" }
          }
        }
        HStack {
          Text("Cartella")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Text(spazio.valore?.path ?? "/downloads")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
        .glassPanel()
        if let avviso = spazio.valore?.avviso(servono: servono) {
          Avvertenza(titolo: "Spazio insufficiente.", testo: avviso)
        }
        if case .fallito = spazio {
          Avvertenza(
            titolo: "Spazio libero non disponibile.", testo: "qBittorrent non risponde. Riprova tra poco.")
        }
        if let problemaAvvio {
          Avvertenza(problema: problemaAvvio)
        }
      }
    }

    private func leggiSpazio() async {
      let client = sessione.client
      spazio = .inCorso
      spazio = await Carico.da { try await client.spazio() }
    }

    private func avvia() async {
      guard let id = bozza?.id else { return }
      avvio = true
      defer { avvio = false }
      problemaAvvio = nil
      do {
        switch try await sessione.client.avviaBozza(id, file: Array(scelti)) {
        case .fatto:
          avviato = true
          sessione.mostra(Avviso("Download avviato"))
          chiudi()
        case .problema(let problema):
          problemaAvvio = problema
        }
      } catch {
        problemaAvvio = ProblemaBozza(codice: "start_failed")
      }
    }

    // MARK: Piede

    /// I pulsanti in basso; al passo 3 sopra c'è il totale scelto.
    private var piede: some View {
      VStack(spacing: 10) {
        if passo == 3, let bozza {
          HStack {
            Text("SELEZIONATI")
              .foregroundStyle(Stile.testoTenue)
            Spacer()
            let scelto = Formato.dimensione(NodoFile.dimensione(bozza.files, scelti: scelti))
            Text("\(scelti.count) file · \(scelto) su \(Formato.dimensione(bozza.size))")
              .foregroundStyle(Stile.testo)
          }
          .font(.system(.footnote, design: .monospaced))
        }
        HStack {
          if passo > 1 {
            Button("Indietro") { Task { await vai(a: passo - 1) } }
              .tint(Stile.testo)
          }
          Spacer()
          Button(passo == AggiungiTorrent.passi ? "Avvia" : "Avanti") {
            Task {
              if passo == AggiungiTorrent.passi {
                await avvia()
              } else {
                await vai(a: passo + 1)
              }
            }
          }
          .buttonStyle(.borderedProminent)
          .fontWeight(.semibold)
          .disabled(!puoAvanzare)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(.ultraThinMaterial)
    }

    private var puoAvanzare: Bool {
      switch passo {
      case 1: modo == .file ? file != nil : AggiungiTorrent.Link(link) != nil
      case 2: bozza?.pronta == true && problema == nil
      case 3: !scelti.isEmpty
      default:
        !scelti.isEmpty && !avvio && spazio.valore?.avviso(servono: servonoOra) == nil
      }
    }

    private var servonoOra: Double {
      NodoFile.dimensione(bozza?.files ?? [], scelti: scelti)
    }

    /// Cambia passo. Tornare alla sorgente butta la bozza, come sul sito.
    private func vai(a nuovo: Int) async {
      let prima = passo
      passo = nuovo
      if nuovo == 1, let id = bozza?.id {
        bozza = nil
        problema = nil
        let client = sessione.client
        Task { try? await client.annullaBozza(id) }
      } else if nuovo == 2, prima == 1 {
        await leggi()
      } else if nuovo == 4 {
        problemaAvvio = nil
        await leggiSpazio()
      }
    }
  }

  /// Una riga dell'albero: casella, cartella, nome e dimensione.
  private struct RigaNodo: View {
    let nodo: NodoFile
    let spunta: NodoFile.Spunta
    let alterna: () -> Void

    var body: some View {
      Button(action: alterna) {
        HStack(spacing: 10) {
          Image(systemName: icona)
            .foregroundStyle(spunta == .niente ? Stile.testoTenue : Stile.testo)
          if nodo.cartella {
            Image(systemName: "folder")
              .foregroundStyle(Stile.testoTenue)
          }
          Text(nodo.nome)
            .font(nodo.cartella ? Font.subheadline.weight(.medium) : Font.subheadline)
            .foregroundStyle(Stile.testo)
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
          Text(Formato.dimensione(nodo.dimensione))
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(spunta == .tutto ? [.isButton, .isSelected] : .isButton)
    }

    private var icona: String {
      switch spunta {
      case .tutto: "checkmark.square.fill"
      case .parte: "minus.square.fill"
      case .niente: "square"
      }
    }
  }

  /// Una tessera del riepilogo: numero grande in mono e una nota.
  private struct Tessera: View {
    let titolo: String
    let valore: String
    let nota: () -> String

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(titolo)
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
        Text(valore)
          .font(.system(size: 24, weight: .semibold, design: .monospaced))
          .foregroundStyle(Stile.testo)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        Text(nota())
          .font(.caption)
          .foregroundStyle(Stile.testoTenue)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassPanel()
    }
  }

  /// Un avviso rosso con titolo e testo, come l'AlertRow del sito.
  private struct Avvertenza: View {
    let titolo: String
    let testo: String?

    init(titolo: String, testo: String?) {
      self.titolo = titolo
      self.testo = testo
    }

    init(problema: ProblemaBozza) {
      self.init(titolo: problema.titolo, testo: problema.testo)
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(titolo)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.brandTesto)
        if let testo {
          Text(testo)
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassPanel(tinta: Stile.brand)
      .accessibilityElement(children: .combine)
    }
  }
#endif
