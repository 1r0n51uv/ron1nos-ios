#if canImport(SwiftUI)
  import PhotosUI
  import Ron1nKit
  import SwiftUI
  import UniformTypeIdentifiers
  import VisionKit

  /// Un file scelto per un documento nuovo, con il suo stato di caricamento.
  struct FileDaCaricare: Identifiable, Equatable {
    enum Stato: Equatable {
      case inCoda, inCorso, caricato
      case errore(String)
    }

    let id = UUID()
    let nome: String
    let dati: Data
    let tipo: String
    var etichetta: String
    var stato = Stato.inCoda

    var anteprima: UIImage? { tipo.hasPrefix("image/") ? UIImage(data: dati) : nil }

    /// Un file da File, con il suo MIME dall'estensione.
    static func leggi(_ url: URL) -> FileDaCaricare? {
      let accesso = url.startAccessingSecurityScopedResource()
      defer { if accesso { url.stopAccessingSecurityScopedResource() } }
      guard let dati = try? Data(contentsOf: url) else { return nil }
      let tipo = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
      return FileDaCaricare(nome: url.lastPathComponent, dati: dati, tipo: tipo, etichetta: "altro")
    }

    /// Una foto o una pagina scansionata, in JPEG.
    static func immagine(_ immagine: UIImage, nome: String, etichetta: String) -> FileDaCaricare? {
      guard let jpeg = immagine.jpegData(compressionQuality: 0.85) else { return nil }
      return FileDaCaricare(nome: nome, dati: jpeg, tipo: "image/jpeg", etichetta: etichetta)
    }
  }

  /// Nuovo documento (IOS-062, DOC-005): si parte dal file (Scansiona, Foto,
  /// File o Senza file), poi si sceglie cosa è, poi il form. Al salvataggio
  /// i file si caricano uno per uno: un errore su un file non ferma gli
  /// altri.
  struct NuovoDocumentoView: View {
    enum Passo { case sorgente, genere, form, caricamento }

    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var passo = Passo.sorgente
    @State private var file: [FileDaCaricare] = []
    @State private var tipi: [TipoDocumento] = []
    @State private var titolari: [String] = []
    @State private var modulo = ModuloDocumento(genere: .libero)
    @State private var errori: [String: String] = [:]
    @State private var scanner = false
    @State private var sceltaFile = false
    @State private var foto: [PhotosPickerItem] = []
    @State private var inCorso = false
    @State private var creato: Documento?

    var body: some View {
      NavigationStack {
        Group {
          switch passo {
          case .sorgente: sorgenti
          case .genere: generi
          case .form: form
          case .caricamento: caricamento
          }
        }
        .scrollContentBackground(.hidden)
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Nuovo documento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            if passo != .caricamento {
              Button("Annulla") { chiudi() }
            }
          }
          if passo == .form {
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .confirmationAction) {
              Button("Salva") { Task { await salva() } }
                .disabled(inCorso || !modulo.valido)
            }
          }
          if passo == .caricamento, !file.contains(where: { $0.stato == .inCoda || $0.stato == .inCorso }) {
            ToolbarItem(placement: .confirmationAction) {
              Button("Fine") { chiudi() }
            }
          }
        }
        .fullScreenCover(isPresented: $scanner) {
          Scanner { pagine in
            file += pagine.enumerated().compactMap { indice, pagina in
              FileDaCaricare.immagine(
                pagina, nome: "scansione-\(indice + 1).jpg", etichetta: indice == 0 ? "fronte" : "pagina")
            }
            if !pagine.isEmpty { passo = .genere }
          }
          .ignoresSafeArea()
        }
        .fileImporter(
          isPresented: $sceltaFile, allowedContentTypes: [.item], allowsMultipleSelection: true,
          onCompletion: scelti
        )
        .onChange(of: foto) { _, scelte in
          guard !scelte.isEmpty else { return }
          Task { await caricaFoto(scelte) }
        }
        .task {
          let client = sessione.client
          tipi = (try? await client.tipiDocumento()) ?? []
          titolari = (try? await client.titolari()) ?? []
        }
      }
    }

    private var sorgenti: some View {
      List {
        Section {
          if VNDocumentCameraViewController.isSupported {
            Button {
              scanner = true
            } label: {
              VoceSorgente("Scansiona", "Ritaglio e raddrizzamento automatici, più pagine", "doc.viewfinder")
            }
          }
          PhotosPicker(selection: $foto, maxSelectionCount: 10, matching: .images) {
            VoceSorgente("Foto", "Dalla libreria", "photo.on.rectangle")
          }
          Button {
            sceltaFile = true
          } label: {
            VoceSorgente("File", "Un PDF o un altro file da File", "folder")
          }
          Button {
            passo = .genere
          } label: {
            VoceSorgente("Senza file", "Solo i dati, gli allegati si aggiungono dopo", "square.and.pencil")
          }
        } header: {
          Text("Da dove parti")
        }
        .listRowBackground(Color.white.opacity(0.06))
      }
    }

    private var generi: some View {
      List {
        if !file.isEmpty {
          Section("File") {
            ForEach($file) { $voce in
              RigaFile(file: voce, etichetta: $voce.etichetta)
            }
            .onDelete { file.remove(atOffsets: $0) }
          }
          .listRowBackground(Color.white.opacity(0.06))
        }
        Section("Cos'è") {
          ForEach(ModuloDocumento.Genere.allCases, id: \.self) { genere in
            if genere == .documento {
              Menu {
                ForEach(tipi) { tipo in
                  Button(tipo.name) { scegli(.documento, tipo: tipo) }
                }
              } label: {
                VoceSorgente(genere.titolo, genere.descrizione, "person.text.rectangle")
              }
              .disabled(tipi.isEmpty)
            } else {
              Button {
                scegli(genere, tipo: nil)
              } label: {
                VoceSorgente(genere.titolo, genere.descrizione, genere == .conInfo ? "doc.text" : "doc")
              }
            }
          }
        }
        .listRowBackground(Color.white.opacity(0.06))
      }
    }

    private func scegli(_ genere: ModuloDocumento.Genere, tipo: TipoDocumento?) {
      modulo = ModuloDocumento(genere: genere, tipo: tipo, nomeFile: file.first?.nome)
      errori = [:]
      passo = .form
    }

    private var form: some View {
      Form {
        if let errore = errori["_"] {
          Text(errore).font(.footnote).foregroundStyle(Stile.brandTesto)
        }
        CampiDocumento(modulo: $modulo, titolari: titolari, errori: errori)
        if !file.isEmpty {
          Section("File · \(file.count)") {
            ForEach(file) { voce in
              Text(voce.nome).font(.footnote).foregroundStyle(Stile.testoTenue)
            }
          }
        }
      }
    }

    private var caricamento: some View {
      List {
        Section {
          ForEach(file) { voce in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(voce.nome).font(.subheadline).foregroundStyle(Stile.testo).lineLimit(1)
                Spacer()
                stato(voce.stato)
              }
              if voce.stato == .inCorso {
                ProgressView().progressViewStyle(.linear).tint(Stile.brand)
              }
              if case .errore(let messaggio) = voce.stato {
                Text(messaggio).font(.footnote).foregroundStyle(Stile.brandTesto)
              }
            }
          }
        } header: {
          Text(creato.map { "\($0.title) · salvato" } ?? "Salvataggio")
        }
        .listRowBackground(Color.white.opacity(0.06))
      }
    }

    @ViewBuilder
    private func stato(_ stato: FileDaCaricare.Stato) -> some View {
      switch stato {
      case .inCoda: Text("in coda").font(.footnote).foregroundStyle(Stile.testoTenue)
      case .inCorso: Text("in corso").font(.footnote).foregroundStyle(Stile.testoTenue)
      case .caricato: Image(systemName: "checkmark").foregroundStyle(Stile.testo)
      case .errore: Image(systemName: "exclamationmark.triangle").foregroundStyle(Stile.brandTesto)
      }
    }

    private func scelti(_ esito: Result<[URL], Error>) {
      guard case .success(let urls) = esito else { return }
      file += urls.compactMap(FileDaCaricare.leggi)
      if !urls.isEmpty { passo = .genere }
    }

    private func caricaFoto(_ scelte: [PhotosPickerItem]) async {
      var nuovi: [FileDaCaricare] = []
      for (indice, scelta) in scelte.enumerated() {
        guard let dati = try? await scelta.loadTransferable(type: Data.self),
          let immagine = UIImage(data: dati),
          let voce = FileDaCaricare.immagine(immagine, nome: "foto-\(indice + 1).jpg", etichetta: "altro")
        else { continue }
        nuovi.append(voce)
      }
      foto = []
      file += nuovi
      if !nuovi.isEmpty { passo = .genere }
    }

    private func salva() async {
      inCorso = true
      defer { inCorso = false }
      do {
        switch try await sessione.client.creaDocumento(modulo) {
        case .rifiutato(let messaggio):
          errori = [modulo.campo(di: messaggio) ?? "_": messaggio]
        case .fatto(let documento):
          creato = documento
          sessione.documentiCambiati += 1
          if file.isEmpty {
            chiudi()
          } else {
            passo = .caricamento
            await caricaFile(in: documento.id)
          }
        }
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }

    /// Un file alla volta; un errore resta su quel file.
    private func caricaFile(in id: String) async {
      for indice in file.indices {
        file[indice].stato = .inCorso
        let voce = file[indice]
        do {
          let esito = try await sessione.client.caricaAllegato(
            id, file: voce.dati, nome: voce.nome, tipo: voce.tipo, etichetta: voce.etichetta)
          switch esito {
          case .fatto: file[indice].stato = .caricato
          case .rifiutato(let messaggio): file[indice].stato = .errore(messaggio)
          }
        } catch {
          file[indice].stato = .errore(error.localizedDescription)
        }
      }
      sessione.documentiCambiati += 1
    }
  }

  /// Un file scelto: anteprima, nome ed etichetta (fronte, retro…).
  struct RigaFile: View {
    let file: FileDaCaricare
    @Binding var etichetta: String

    var body: some View {
      HStack(spacing: 12) {
        Group {
          if let anteprima = file.anteprima {
            Image(uiImage: anteprima).resizable().scaledToFill()
          } else {
            Image(systemName: "doc").foregroundStyle(Stile.testoTenue)
          }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        Text(file.nome).font(.subheadline).foregroundStyle(Stile.testo).lineLimit(1)
        Spacer()
        Picker("Etichetta", selection: $etichetta) {
          ForEach(["fronte", "retro", "pagina", "altro"], id: \.self) { voce in
            Text(voce.prefix(1).uppercased() + voce.dropFirst()).tag(voce)
          }
        }
        .labelsHidden()
      }
    }
  }

  /// Una sorgente del primo passo: icona, nome e una riga di spiegazione.
  struct VoceSorgente: View {
    let titolo: String
    let testo: String
    let icona: String

    init(_ titolo: String, _ testo: String, _ icona: String) {
      self.titolo = titolo
      self.testo = testo
      self.icona = icona
    }

    var body: some View {
      HStack(spacing: 14) {
        Image(systemName: icona)
          .font(.title3)
          .foregroundStyle(Stile.testo)
          .frame(width: 32)
        VStack(alignment: .leading, spacing: 2) {
          Text(titolo).foregroundStyle(Stile.testo)
          Text(testo).font(.footnote).foregroundStyle(Stile.testoTenue)
        }
      }
      .padding(.vertical, 4)
    }
  }

  /// Lo scanner di VisionKit: ritaglia e raddrizza da solo, più pagine.
  struct Scanner: UIViewControllerRepresentable {
    let fatto: ([UIImage]) -> Void
    @Environment(\.dismiss) private var chiudi

    func makeCoordinator() -> Coordinatore { Coordinatore(self) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
      let controller = VNDocumentCameraViewController()
      controller.delegate = context.coordinator
      return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    // VisionKit chiama il delegate sul main thread.
    @MainActor
    final class Coordinatore: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
      let scanner: Scanner

      init(_ scanner: Scanner) { self.scanner = scanner }

      func documentCameraViewController(
        _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
      ) {
        let pagine = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
        scanner.fatto(pagine)
        scanner.chiudi()
      }

      func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        scanner.chiudi()
      }

      func documentCameraViewController(
        _ controller: VNDocumentCameraViewController, didFailWithError error: Error
      ) {
        scanner.chiudi()
      }
    }
  }
#endif
