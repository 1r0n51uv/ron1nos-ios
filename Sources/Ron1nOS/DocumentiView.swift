#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// I Documenti (IOS-060, DOC-002): in cima i fissati in card grandi con la
  /// miniatura, poi quelli in scadenza o scaduti, poi gli altri per tipo.
  /// Ricerca nella barra, filtri per tipo e titolare in un menu.
  struct DocumentiView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<ElencoDocumenti> = .inCorso
    @State private var filtro = FiltroDocumenti()
    @State private var tipi: [TipoDocumento] = []
    @State private var titolari: [String] = []
    @State private var nuovo = false

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 5).listRowBackground(Color.clear)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let errore):
          SezioneErrore(errore: errore).listRowBackground(Color.clear)
        case .pronto(let elenco) where elenco.vuoto:
          Text(filtro == FiltroDocumenti() ? "Nessun documento." : "Nessun documento con questi filtri.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
            .listRowBackground(Color.clear)
        case .pronto(let elenco):
          if !elenco.fissati.isEmpty {
            Section {
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                  ForEach(elenco.fissati, id: \.id) { documento in
                    collegamento(documento) { CardDocumento(documento: documento) }
                  }
                }
              }
              .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
              .listRowBackground(Color.clear)
            } header: {
              intestazione("IN EVIDENZA")
            }
          }
          if !elenco.inScadenza.isEmpty {
            Section {
              ForEach(elenco.inScadenza, id: \.id) { documento in
                collegamento(documento) { RigaDocumento(documento: documento) }
                  .listRowBackground(Color.clear)
              }
            } header: {
              intestazione("IN SCADENZA")
            }
          }
          ForEach(elenco.perTipo) { gruppo in
            Section {
              ForEach(gruppo.documenti, id: \.id) { documento in
                collegamento(documento) { RigaDocumento(documento: documento) }
                  .listRowBackground(Color.clear)
              }
            } header: {
              intestazione(gruppo.tipo.uppercased())
            }
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Documenti")
      .searchable(text: $filtro.cerca, prompt: "Titolo o tag")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          menuFiltri
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            nuovo = true
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Nuovo documento")
        }
      }
      .sheet(isPresented: $nuovo) {
        NuovoDocumentoView().environmentObject(sessione)
      }
      .refreshable { await carica() }
      .task(id: Ricarica(filtro: filtro, versione: sessione.documentiCambiati)) {
        if !filtro.cerca.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
        guard !Task.isCancelled else { return }
        await carica()
      }
      .task {
        let client = sessione.client
        async let tipi = client.tipiDocumento()
        async let titolari = client.titolari()
        self.tipi = (try? await tipi) ?? []
        self.titolari = (try? await titolari) ?? []
      }
      .protezioneDocumenti()
    }

    /// Un documento che si apre nel dettaglio (IOS-061).
    private func collegamento<Contenuto: View>(
      _ documento: DocumentoBreve, @ViewBuilder contenuto: () -> Contenuto
    ) -> some View {
      NavigationLink(value: Pagina.documento(id: documento.id)) { contenuto() }
        .buttonStyle(.plain)
    }

    /// Quando ricaricare: filtri cambiati o un documento modificato.
    private struct Ricarica: Equatable {
      let filtro: FiltroDocumenti
      let versione: Int
    }

    private var menuFiltri: some View {
      Menu {
        Picker("Tipo", selection: $filtro.tipo) {
          Text("Tutti i tipi").tag(String?.none)
          ForEach(tipi) { tipo in
            Text(tipo.name).tag(String?.some(tipo.id))
          }
          Text("File senza tipo").tag(String?.some(FiltroDocumenti.senzaTipo))
        }
        Picker("Titolare", selection: $filtro.titolare) {
          Text("Tutti i titolari").tag(String?.none)
          ForEach(titolari, id: \.self) { nome in
            Text(nome).tag(String?.some(nome))
          }
        }
      } label: {
        Image(
          systemName: filtro.attivo
            ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
      }
      .accessibilityLabel(filtro.attivo ? "Filtri attivi" : "Filtri")
    }

    private func intestazione(_ testo: String) -> some View {
      Text(testo)
        .font(.system(.caption, design: .monospaced))
        .tracking(1.6)
        .foregroundStyle(Stile.testoTenue)
    }

    private func carica() async {
      let client = sessione.client
      let filtro = filtro
      stato = await Carico.da { ElencoDocumenti(try await client.elencoDocumenti(filtro)) }
    }
  }

  /// Il simbolo del tipo di documento, come le icone del sito.
  enum IconaDocumento {
    static func simbolo(_ icona: String?) -> String {
      switch icona {
      case "id-card": "person.text.rectangle"
      case "passport": "globe.europe.africa"
      case "car": "car"
      case "health": "cross.case"
      case "card": "creditcard"
      case "person": "person"
      default: "doc"
      }
    }
  }

  /// Una card grande dei fissati: la miniatura del primo allegato, tipo e
  /// titolo.
  struct CardDocumento: View {
    let documento: DocumentoBreve

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        MiniaturaDocumento(documento: documento)
          .frame(width: 200, height: 126)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        Text(documento.title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
          .lineLimit(1)
        Text(documento.sottotitolo)
          .font(.footnote)
          .foregroundStyle(documento.expiry?.scaduto == true ? Stile.brandTesto : Stile.testoTenue)
          .lineLimit(1)
      }
      .frame(width: 200, alignment: .leading)
      .accessibilityElement(children: .combine)
    }
  }

  /// Una riga semplice: icona del tipo, titolo e sottotitolo; lo scaduto
  /// in rosso.
  struct RigaDocumento: View {
    let documento: DocumentoBreve

    var body: some View {
      HStack(spacing: 12) {
        Image(systemName: IconaDocumento.simbolo(documento.typeIcon))
          .font(.body)
          .foregroundStyle(Stile.testoTenue)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 2) {
          Text(documento.title)
            .font(.subheadline)
            .foregroundStyle(Stile.testo)
          if !documento.sottotitolo.isEmpty {
            Text(documento.sottotitolo)
              .font(.footnote)
              .foregroundStyle(documento.expiry?.scaduto == true ? Stile.brandTesto : Stile.testoTenue)
          }
        }
      }
      .padding(.vertical, 2)
      .accessibilityElement(children: .combine)
    }
  }

  /// La miniatura del primo allegato se è un'immagine; se no l'icona del
  /// tipo su vetro.
  struct MiniaturaDocumento: View {
    let documento: DocumentoBreve
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
          Image(systemName: IconaDocumento.simbolo(documento.typeIcon))
            .font(.title)
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .clipped()
      .accessibilityHidden(true)
      .task(id: documento.thumbFileId) {
        guard let file = documento.thumbFileId else { return }
        let dati = try? await sessione.client.miniaturaDocumento(documento.id, file: file)
        immagine = dati.flatMap { UIImage(data: $0) }
      }
    }
  }
#endif
