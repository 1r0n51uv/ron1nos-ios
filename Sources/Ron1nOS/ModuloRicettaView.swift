#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Creare o correggere una ricetta (IOS-034): nome, note e gli alimenti
  /// coi grammi. Gli alimenti si scelgono col foglio di ricerca.
  struct ModuloRicettaView: View {
    /// nil per una ricetta nuova.
    let ricetta: Ricetta?
    let salvato: () async -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var modulo = ModuloRicetta()
    @State private var scelta = false
    @State private var errore: String?
    @State private var salvando = false

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
              TextField("Nome", text: $modulo.nome)
                .foregroundStyle(Stile.testo)
                .glassChip()
              TextField("Note", text: $modulo.note, axis: .vertical)
                .foregroundStyle(Stile.testo)
                .lineLimit(1...4)
                .glassChip()
            }
            righe
            Button {
              scelta = true
            } label: {
              Label("Aggiungi un alimento", systemImage: "plus")
            }
            .glassChip()
            if let errore {
              Text(errore)
                .font(.subheadline)
                .foregroundStyle(Stile.brandTesto)
            }
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle(ricetta == nil ? "Nuova ricetta" : "Ricetta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Salva") { Task { await salva() } }
              .fontWeight(.semibold)
              .disabled(salvando)
          }
        }
      }
      .tint(Stile.brand)
      .sheet(isPresented: $scelta) {
        SceltaAlimentoView { alimento in
          modulo.righe.append(Bozza(alimento))
          scelta = false
        }
      }
      .onAppear {
        if let ricetta { modulo = ModuloRicetta(ricetta) }
      }
    }

    @ViewBuilder
    private var righe: some View {
      if !modulo.righe.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          ForEach($modulo.righe) { $riga in
            RigaBozza(riga: $riga) {
              modulo.righe.removeAll { $0.id == riga.id }
            }
          }
          Divider().overlay(Color.white.opacity(0.12))
          HStack {
            Text("Totale")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
            Spacer()
            Text(formati.energia(modulo.totale.kcal))
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(Stile.testo)
          }
        }
        .glassPanel()
      }
    }

    private func salva() async {
      if let problema = modulo.problema {
        errore = problema
        return
      }
      salvando = true
      defer { salvando = false }
      do {
        if let id = ricetta?.id {
          _ = try await sessione.client.correggiRicetta(id, modulo)
        } else {
          _ = try await sessione.client.creaRicetta(modulo)
        }
        await salvato()
        sessione.mostra(.salvato)
        chiudi()
      } catch {
        errore = error.titolo
      }
    }
  }

  /// Il foglio per scegliere un alimento: ricerca da due caratteri e,
  /// col campo vuoto, gli alimenti recenti (NUT-004, NUT-028).
  struct SceltaAlimentoView: View {
    let scegli: (Alimento) -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var testo = ""
    @State private var soloItalia = true
    @State private var risultati: RisultatiRicerca?
    @State private var recenti: [Alimento] = []
    @State private var cercando = false

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
              Image(systemName: "magnifyingglass")
                .foregroundStyle(Stile.testoTenue)
              TextField("Cerca un alimento", text: $testo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Stile.testo)
              if cercando { ProgressView().controlSize(.small) }
            }
            .glassChip()
            Toggle("Solo Italia", isOn: $soloItalia)
              .font(.subheadline)
              .tint(Stile.brand)
            if let avviso = risultati?.avviso {
              Text(avviso)
                .font(.footnote)
                .foregroundStyle(Stile.testoTenue)
            }
            elenco
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Alimento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
      }
      .tint(Stile.brand)
      .task(id: Chiave(testo: testo, italia: soloItalia)) { await cerca() }
      .task { recenti = (try? await sessione.client.alimentiRecenti()) ?? [] }
    }

    private struct Chiave: Equatable {
      let testo: String
      let italia: Bool
    }

    @ViewBuilder
    private var elenco: some View {
      let cercato = testo.trimmingCharacters(in: .whitespaces).count >= 2
      let mostrati = cercato ? (risultati?.results ?? []) : recenti
      VStack(alignment: .leading, spacing: 10) {
        Text(cercato ? "RISULTATI" : "RECENTI")
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
        if mostrati.isEmpty {
          Text(cercando ? "Cerco." : "Nessun alimento.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        ForEach(mostrati, id: \.chiave) { alimento in
          Button {
            scegli(alimento)
          } label: {
            VoceAlimento(alimento: alimento)
          }
          .buttonStyle(.plain)
        }
      }
      .glassPanel()
    }

    private func cerca() async {
      let q = testo.trimmingCharacters(in: .whitespaces)
      guard q.count >= 2 else {
        risultati = nil
        return
      }
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      cercando = true
      defer { cercando = false }
      risultati = try? await sessione.client.cercaAlimenti(q, soloItalia: soloItalia)
    }
  }
#endif
