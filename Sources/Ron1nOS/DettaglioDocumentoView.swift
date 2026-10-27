#if canImport(SwiftUI)
  import QuickLook
  import Ron1nKit
  import SwiftUI
  import UniformTypeIdentifiers

  /// Il dettaglio di un documento (IOS-061, DOC-004): allegati in alto, poi i
  /// campi; un tocco su un campo lo copia. Menu `⋯` con le azioni.
  struct DettaglioDocumentoView: View {
    let id: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var stato: Carico<Documento> = .inCorso
    @State private var anteprima: URL?
    @State private var daCondividere: FileDaCondividere?
    @State private var avvisoPdf = false
    @State private var conferma = false
    @State private var modifica = false
    private let temporanei = FileTemporanei()

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
          case .pronto(let documento):
            testata(documento)
            if !documento.files.isEmpty {
              allegati(documento)
            }
            if !documento.campi.isEmpty {
              campi(documento)
            }
            if !documento.notes.isEmpty {
              note(documento.notes)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(stato.valore?.title ?? "Documento")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if let documento = stato.valore {
          ToolbarItem(placement: .topBarTrailing) { menu(documento) }
        }
      }
      .quickLookPreview($anteprima)
      .sheet(isPresented: $modifica) {
        if let documento = stato.valore {
          ModificaDocumentoView(documento: documento) { stato = .pronto($0) }
            .environmentObject(sessione)
        }
      }
      .sheet(item: $daCondividere) { file in
        CondividiFile(url: file.url).presentationDetents([.medium, .large])
      }
      .alert("Il PDF è in chiaro", isPresented: $avvisoPdf) {
        Button("Annulla", role: .cancel) {}
        Button("Condividi") { Task { await pdf() } }
      } message: {
        Text("Chi lo riceve legge tutti i campi. Condividilo solo dove serve.")
      }
      .confirmationDialog(
        "Eliminare il documento e i suoi allegati? Non si può annullare.", isPresented: $conferma,
        titleVisibility: .visible
      ) {
        Button("Elimina", role: .destructive) { Task { await elimina() } }
      }
      .refreshable { await carica() }
      .task { await carica() }
      .onDisappear { temporanei.svuota() }
      .protezioneDocumenti()
    }

    private func carica() async {
      let client = sessione.client
      let id = id
      stato = await Carico.da { try await client.documento(id) }
    }

    private func etichetta(_ testo: String) -> some View {
      Text(testo)
        .font(.system(.caption, design: .monospaced))
        .tracking(1.6)
        .foregroundStyle(Stile.testoTenue)
    }

    private func testata(_ documento: Documento) -> some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(documento.title)
          .font(.system(.title2, design: .default).weight(.bold))
          .foregroundStyle(Stile.testo)
        if !documento.sottotitolo.isEmpty {
          Text(documento.sottotitolo)
            .font(.subheadline)
            .foregroundStyle(documento.expiry?.scaduto == true ? Stile.brand : Stile.testoTenue)
        }
      }
      .accessibilityElement(children: .combine)
    }

    private func allegati(_ documento: Documento) -> some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(documento.files) { file in
            Button {
              Task { await apri(file, documento: documento) }
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                AnteprimaAllegato(documento: documento.id, file: file)
                  .frame(width: 160, height: 110)
                  .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(file.etichetta)
                  .font(.caption)
                  .foregroundStyle(Stile.testoTenue)
              }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Apri \(file.etichetta) · \(file.name)")
            .contextMenu {
              if file.immagine {
                Button("Copia immagine", systemImage: "doc.on.doc") {
                  Task { await copiaImmagine(file, documento: documento) }
                }
              }
              Button("Condividi", systemImage: "square.and.arrow.up") {
                Task { await condividi(file, documento: documento) }
              }
            }
          }
        }
      }
    }

    private func campi(_ documento: Documento) -> some View {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(documento.campi.enumerated()), id: \.element.id) { indice, campo in
          if indice > 0 { Divider().overlay(Color.white.opacity(0.08)) }
          Button {
            guard campo.copiabile else { return }
            Appunti.copia(campo.valore)
            sessione.mostra(Avviso("Copiato"))
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                etichetta(campo.etichetta.uppercased())
                Text(campo.valore)
                  .font(.system(.body, design: .monospaced))
                  .foregroundStyle(Stile.testo)
                  .multilineTextAlignment(.leading)
              }
              Spacer()
              if campo.copiabile {
                Image(systemName: "doc.on.doc")
                  .font(.footnote)
                  .foregroundStyle(Stile.testoTenue)
              }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityHint(campo.copiabile ? "Tocca per copiare" : "")
        }
      }
      .glassPanel()
    }

    private func note(_ testo: String) -> some View {
      VStack(alignment: .leading, spacing: 6) {
        etichetta("NOTE")
        Text(testo)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassPanel()
    }

    private func menu(_ documento: Documento) -> some View {
      Menu {
        Button("Modifica", systemImage: "pencil") { modifica = true }
        Button(
          documento.fissato ? "Togli dall'evidenza" : "Fissa",
          systemImage: documento.fissato ? "pin.slash" : "pin"
        ) {
          Task { await fissa(documento) }
        }
        Button("Copia tutto", systemImage: "doc.on.clipboard") {
          Appunti.copia(documento.testoCompleto)
          sessione.mostra(Avviso("Copiato"))
        }
        Button("PDF di riepilogo", systemImage: "doc.richtext") { avvisoPdf = true }
        Divider()
        Button("Elimina", systemImage: "trash", role: .destructive) { conferma = true }
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .accessibilityLabel("Altre azioni")
    }

    private func scarica(_ file: Documento.Allegato, documento: Documento) async -> URL? {
      do {
        let dati = try await sessione.client.allegato(documento.id, file: file.id)
        return try temporanei.scrivi(dati, nome: file.name)
      } catch {
        sessione.mostra(Avviso("File non disponibile"))
        return nil
      }
    }

    private func apri(_ file: Documento.Allegato, documento: Documento) async {
      anteprima = await scarica(file, documento: documento)
    }

    private func condividi(_ file: Documento.Allegato, documento: Documento) async {
      guard let url = await scarica(file, documento: documento) else { return }
      daCondividere = FileDaCondividere(url: url)
    }

    private func copiaImmagine(_ file: Documento.Allegato, documento: Documento) async {
      guard let dati = try? await sessione.client.allegato(documento.id, file: file.id),
        let immagine = UIImage(data: dati)
      else {
        sessione.mostra(Avviso("File non disponibile"))
        return
      }
      Appunti.copia(immagine)
      sessione.mostra(Avviso("Copiato"))
    }

    private func pdf() async {
      guard let documento = stato.valore else { return }
      do {
        let dati = try await sessione.client.pdfRiepilogo(documento.id)
        let url = try temporanei.scrivi(dati, nome: "\(documento.title).pdf")
        daCondividere = FileDaCondividere(url: url)
      } catch {
        sessione.mostra(Avviso("PDF non disponibile"))
      }
    }

    private func fissa(_ documento: Documento) async {
      do {
        stato = .pronto(try await sessione.client.fissaDocumento(documento.id, fissato: !documento.fissato))
        sessione.documentiCambiati += 1
      } catch {
        sessione.mostra(.nonSalvato) { Task { await fissa(documento) } }
      }
    }

    private func elimina() async {
      do {
        try await sessione.client.eliminaDocumento(id)
        sessione.documentiCambiati += 1
        sessione.mostra(Avviso("Documento eliminato"))
        chiudi()
      } catch {
        sessione.mostra(.nonSalvato) { Task { await elimina() } }
      }
    }
  }

  /// Un file pronto per il foglio di condivisione.
  struct FileDaCondividere: Identifiable {
    let url: URL
    var id: URL { url }
  }

  /// Il foglio di condivisione di iOS.
  struct CondividiFile: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
      UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
  }

  /// Gli appunti dei Documenti (DOC-012): scadono dopo 2 minuti e restano su
  /// questo telefono. Ogni copia dà un feedback aptico.
  @MainActor enum Appunti {
    static let durata: TimeInterval = 120

    static var opzioni: [UIPasteboard.OptionsKey: Any] {
      [.expirationDate: Date().addingTimeInterval(durata), .localOnly: true]
    }

    static func copia(_ testo: String) {
      UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: testo]], options: opzioni)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func copia(_ immagine: UIImage) {
      guard let png = immagine.pngData() else { return }
      UIPasteboard.general.setItems([[UTType.png.identifier: png]], options: opzioni)
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
  }

  /// L'anteprima di un allegato: la miniatura se c'è, se no l'icona del
  /// tipo di file.
  struct AnteprimaAllegato: View {
    let documento: String
    let file: Documento.Allegato
    @EnvironmentObject private var sessione: Sessione
    @State private var immagine: UIImage?

    var body: some View {
      ZStack {
        Color.white.opacity(0.06)
        if let immagine {
          Image(uiImage: immagine)
            .resizable()
            .scaledToFill()
        } else {
          Image(systemName: file.pdf ? "doc.richtext" : file.immagine ? "photo" : "doc")
            .font(.title2)
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .clipped()
      .accessibilityHidden(true)
      .task(id: file.id) {
        guard file.hasThumb else { return }
        let dati = try? await sessione.client.miniaturaDocumento(documento, file: file.id)
        immagine = dati.flatMap { UIImage(data: $0) }
      }
    }
  }
#endif
