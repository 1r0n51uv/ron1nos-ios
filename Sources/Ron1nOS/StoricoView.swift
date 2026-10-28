#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Lo storico delle sessioni (IOS-052, GYM-004): dalla più recente, a
  /// pagine da 20 scorrendo, con il filtro per routine.
  struct StoricoView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<StoricoPalestra> = .inCorso
    @State private var routine: [String] = []
    @State private var filtro: String?
    @State private var altreInCorso = false

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 5).listRowBackground(Color.clear)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let errore):
          SezioneErrore(errore: errore).listRowBackground(Color.clear)
        case .pronto(let storico):
          if storico.sessioni.isEmpty {
            Text("Nessuna sessione.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(Color.clear)
          }
          ForEach(storico.sessioni) { voce in
            NavigationLink(value: Pagina.sessione(id: voce.id)) {
              RigaSessione(sessione: voce, oggi: oggi)
            }
            .listRowBackground(Color.clear)
            .onAppear {
              if storico.chiedeAltre(voce) { Task { await altre() } }
            }
          }
          if altreInCorso {
            ProgressView().frame(maxWidth: .infinity).listRowBackground(Color.clear)
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(filtro ?? "Storico")
      .toolbar {
        if !routine.isEmpty {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Picker("Routine", selection: $filtro) {
                Text("Tutte").tag(String?.none)
                ForEach(routine, id: \.self) { nome in
                  Text(nome).tag(String?.some(nome))
                }
              }
            } label: {
              Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filtra per routine")
          }
        }
      }
      .refreshable { await carica() }
      .task(id: "\(filtro ?? "")-\(sessione.palestraCambiata)") { await carica() }
      .task { routine = (try? await sessione.client.routinePalestra()) ?? [] }
    }

    private var oggi: String { Striscia(fuso: formati.fuso).oggi }

    private func carica() async {
      let client = sessione.client
      let filtro = filtro
      stato = await Carico.da {
        var storico = StoricoPalestra()
        storico.aggiungi(try await client.sessioniPalestra(routine: filtro))
        return storico
      }
    }

    /// La pagina dopo; se non arriva, la riga resta e si riprova scorrendo.
    private func altre() async {
      guard !altreInCorso, case .pronto(var storico) = stato, let cursore = storico.cursore else { return }
      altreInCorso = true
      defer { altreInCorso = false }
      guard let pagina = try? await sessione.client.sessioniPalestra(routine: filtro, cursore: cursore) else {
        return
      }
      storico.aggiungi(pagina)
      stato = .pronto(storico)
    }
  }

  /// Una riga dello storico: le miniature dei primi tre esercizi, routine,
  /// giorno e durata.
  struct RigaSessione: View {
    let sessione: SessionePalestra
    let oggi: String

    var body: some View {
      HStack(spacing: 12) {
        HStack(spacing: -14) {
          ForEach(Array(sessione.exercises.prefix(3).enumerated()), id: \.offset) { _, esercizio in
            FotoEsercizio(immagine: esercizio.image)
              .frame(width: 40, height: 40)
              .clipShape(Circle())
              .overlay(Circle().stroke(Color.black, lineWidth: 2))
          }
          if sessione.exercises.isEmpty {
            FotoEsercizio(immagine: nil)
              .frame(width: 40, height: 40)
              .clipShape(Circle())
          }
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(sessione.titolo)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Stile.testo)
          Text(sessione.sottotitolo(oggi: oggi))
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .padding(.vertical, 4)
      .accessibilityElement(children: .combine)
    }
  }

  /// Il dettaglio di una sessione (IOS-052, GYM-005): testata, volume per
  /// esercizio e una card per esercizio. `Elimina sessione` nel menu.
  struct DettaglioSessioneView: View {
    let id: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var stato: Carico<DettaglioSessione> = .inCorso
    @State private var conferma = false

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
          case .pronto(let dettaglio):
            testata(dettaglio)
            if !dettaglio.barre.isEmpty {
              volume(dettaglio)
            }
            ForEach(dettaglio.exercises) { esercizio in
              CardEsercizio(esercizio: esercizio)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(stato.valore?.titolo ?? "Sessione")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("Elimina sessione", systemImage: "trash", role: .destructive) { conferma = true }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .accessibilityLabel("Altre azioni")
        }
      }
      .confirmationDialog(
        "Eliminare la sessione? Un nuovo import del CSV non la riporta.", isPresented: $conferma,
        titleVisibility: .visible
      ) {
        Button("Elimina sessione", role: .destructive) { Task { await elimina() } }
      }
      .refreshable { await carica() }
      .task { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      let id = id
      stato = await Carico.da { try await client.sessionePalestra(id) }
    }

    private func elimina() async {
      do {
        try await sessione.client.eliminaSessione(id)
        sessione.palestraCambiata += 1
        sessione.mostra(Avviso("Sessione eliminata"))
        chiudi()
      } catch {
        sessione.mostra(.nonSalvato) { Task { await elimina() } }
      }
    }

    private func testata(_ dettaglio: DettaglioSessione) -> some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(dettaglio.titolo)
          .font(.system(.title, design: .default).weight(.bold))
          .foregroundStyle(Stile.testo)
        Text(dettaglio.sottotitolo(oggi: Striscia(fuso: formati.fuso).oggi))
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
        Text(formati.peso(dettaglio.volumeKg))
          .font(.system(size: 34, weight: .semibold, design: .monospaced))
          .foregroundStyle(Stile.testo)
          .padding(.top, 6)
        Text("VOLUME")
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassPanel()
      .accessibilityElement(children: .combine)
    }

    private func volume(_ dettaglio: DettaglioSessione) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("VOLUME PER ESERCIZIO")
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
        ForEach(dettaglio.barre) { esercizio in
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(esercizio.name)
                .font(.footnote)
                .foregroundStyle(Stile.testo)
                .lineLimit(1)
              Spacer()
              Text(formati.peso(esercizio.volumeKg))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
            }
            GeometryReader { spazio in
              Capsule()
                .fill(esercizio.key == dettaglio.piuPesante ? Stile.brand : Color.white.opacity(0.3))
                .frame(width: max(4, spazio.size.width * dettaglio.quota(esercizio)))
            }
            .frame(height: 6)
          }
          .accessibilityElement(children: .combine)
        }
      }
      .glassPanel()
    }
  }

  /// Un esercizio della sessione: foto, nome, record e le serie.
  struct CardEsercizio: View {
    let esercizio: DettaglioSessione.Esercizio
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          FotoEsercizio(immagine: esercizio.image)
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          VStack(alignment: .leading, spacing: 2) {
            Text(esercizio.name)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Stile.testo)
            if esercizio.record {
              Text("RECORD")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(Stile.testo)
            }
          }
        }
        GrigliaSerie(serie: esercizio.sets, formati: formati)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassPanel()
      .accessibilityElement(children: .combine)
    }
  }

  /// Le serie come chip: il riscaldamento tratteggiato.
  struct GrigliaSerie: View {
    let serie: [DettaglioSessione.Serie]
    let formati: Formati

    var body: some View {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(serie) { voce in
          Text(voce.testo(formati))
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(voce.warmup ? Stile.testoTenue : Stile.testo)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .overlay {
              RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                  Color.white.opacity(voce.warmup ? 0.35 : 0.15),
                  style: StrokeStyle(lineWidth: 1, dash: voce.warmup ? [4, 3] : []))
            }
            .accessibilityLabel(voce.warmup ? "Riscaldamento \(voce.testo(formati))" : voce.testo(formati))
        }
      }
    }
  }
#endif
