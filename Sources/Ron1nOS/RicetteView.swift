#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le ricette (IOS-034, NUT-008): elenco con kcal e macro totali, e da
  /// una ricetta `Registra` o `Pianifica`.
  struct RicetteView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<[Ricetta]> = .inCorso
    @State private var modulo: ModuloAperto?

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 3).listRowBackground(Color.clear)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let errore):
          SezioneErrore(errore: errore).listRowBackground(Color.clear)
        case .pronto(let ricette):
          if ricette.isEmpty {
            Text("Nessuna ricetta.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(Color.clear)
          }
          ForEach(ricette) { ricetta in
            NavigationLink(value: Pagina.ricetta(id: ricetta.id)) {
              VoceRicetta(ricetta: ricetta)
            }
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
              Button("Elimina", role: .destructive) { Task { await elimina(ricetta.id) } }
            }
            .accessibilityAction(named: "Elimina") { Task { await elimina(ricetta.id) } }
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Ricette")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            modulo = ModuloAperto(id: "nuova", ricetta: nil)
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Nuova ricetta")
        }
      }
      .sheet(item: $modulo) { aperto in
        ModuloRicettaView(ricetta: aperto.ricetta) { await carica() }
      }
      .refreshable { await carica() }
      .task { await carica() }
    }

    /// La ricetta aperta nel modulo, o una nuova.
    struct ModuloAperto: Identifiable, Equatable {
      let id: String
      let ricetta: Ricetta?
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.ricette() }
    }

    private func elimina(_ id: String) async {
      do {
        try await sessione.client.eliminaRicetta(id)
        await carica()
      } catch {
        sessione.mostra(.nonSalvato) { Task { await elimina(id) } }
      }
    }
  }

  /// Una riga dell'elenco: nome, kcal e peso, e i macro totali.
  struct VoceRicetta: View {
    let ricetta: Ricetta
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(ricetta.name)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
        Text(ricetta.sottotitolo(formati))
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
        if ricetta.incompleta {
          Text("Un alimento è stato eliminato.")
            .font(.footnote)
            .foregroundStyle(Stile.brand)
        }
      }
      .padding(.vertical, 4)
    }
  }

  /// Il dettaglio di una ricetta: gli alimenti coi grammi, i totali e i
  /// pulsanti `Registra` e `Pianifica`.
  struct DettaglioRicettaView: View {
    let id: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<Ricetta> = .inCorso
    @State private var modifica = false
    @State private var destinazione: Destinazione?

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 4).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
          case .pronto(let ricetta):
            totali(ricetta)
            alimenti(ricetta)
            if let note = ricetta.notes, !note.isEmpty {
              Text(note)
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
                .glassPanel()
            }
            pulsanti
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(stato.valore?.name ?? "Ricetta")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Modifica") { modifica = true }
            .disabled(stato.valore == nil)
        }
      }
      .sheet(isPresented: $modifica) {
        if let ricetta = stato.valore {
          ModuloRicettaView(ricetta: ricetta) { await carica() }
        }
      }
      .sheet(item: $destinazione) { scelta in
        SceltaGiornoSlotView(pianifica: scelta.pianifica) { giorno, slot, porzioni in
          await usa(giorno: giorno, slot: slot, porzioni: porzioni, pianifica: scelta.pianifica)
        }
      }
      .refreshable { await carica() }
      .task { await carica() }
    }

    /// `Registra` sta su oggi, `Pianifica` chiede giorno e slot.
    struct Destinazione: Identifiable, Equatable {
      let pianifica: Bool
      var id: Bool { pianifica }
    }

    @ViewBuilder
    private func totali(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(formati.energia(ricetta.kcal))
          .font(.system(.title2, design: .monospaced))
          .foregroundStyle(Stile.testo)
        Text(
          RegistraPastoView.testoMacro(
            Macro(
              kcal: ricetta.kcal, protein: ricetta.protein, carbs: ricetta.carbs, fat: ricetta.fat)
          )
        )
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(Stile.testoTenue)
        Text("\(Formato.numero(ricetta.grams)) g in tutto")
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
    }

    @ViewBuilder
    private func alimenti(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(ricetta.items) { riga in
          HStack {
            Text(riga.name)
              .font(.subheadline)
              .foregroundStyle(riga.missing ? Stile.testoTenue : Stile.testo)
            Spacer()
            Text("\(Formato.numero(riga.grams)) g")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
            Text(formati.energia(riga.kcal))
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testo)
          }
        }
      }
      .glassPanel()
    }

    @ViewBuilder
    private var pulsanti: some View {
      HStack(spacing: 12) {
        Button("Registra") { destinazione = Destinazione(pianifica: false) }
          .fontWeight(.semibold)
          .glassChip()
        Button("Pianifica") { destinazione = Destinazione(pianifica: true) }
          .glassChip()
      }
    }

    private func carica() async {
      let client = sessione.client
      let id = id
      stato = await Carico.da { try await client.ricetta(id) }
    }

    private func usa(giorno: String, slot: String, porzioni: Double, pianifica: Bool) async {
      do {
        if pianifica {
          _ = try await sessione.client.pianificaRicetta(
            giorno: giorno, slot: slot, ricetta: id, porzioni: porzioni)
        } else {
          _ = try await sessione.client.registraRicetta(
            giorno: giorno, slot: slot, ricetta: id, porzioni: porzioni)
        }
        sessione.mostra(.salvato)
        destinazione = nil
      } catch {
        let pieno = error == .stato(409)
        sessione.mostra(pieno ? Avviso("Quel pasto è già mangiato") : .nonSalvato)
      }
    }
  }

  /// Dove va la ricetta: `Registra` su oggi, `Pianifica` su un giorno
  /// qualsiasi, anche nel futuro.
  struct SceltaGiornoSlotView: View {
    let pianifica: Bool
    let conferma: (String, String, Double) async -> Void
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var striscia = Striscia()
    @State private var giorno = ""
    @State private var slot = "lunch"
    @State private var porzioni = 1.0

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            if pianifica {
              StrisciaGiorni(striscia: striscia, scelto: giorno) { giorno = $0 }
            }
            VStack(alignment: .leading, spacing: 10) {
              Text("PASTO")
                .font(.system(.caption, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Stile.testoTenue)
              Picker("Pasto", selection: $slot) {
                ForEach(GiornoDieta.ordineSlot, id: \.self) { nome in
                  Text(GiornoDieta.nomiSlot[nome] ?? nome).tag(nome)
                }
              }
              .pickerStyle(.inline)
              .labelsHidden()
            }
            Stepper(value: $porzioni, in: 0.5...10, step: 0.5) {
              Text("\(Formato.numero(porzioni)) porzioni")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Stile.testo)
            }
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle(pianifica ? "Pianifica" : "Registra")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Conferma") {
              Task {
                await conferma(giorno, slot, porzioni)
                chiudi()
              }
            }
            .fontWeight(.semibold)
          }
        }
      }
      .tint(Stile.brand)
      .onAppear {
        striscia = Striscia(fuso: formati.fuso)
        if giorno.isEmpty { giorno = striscia.oggi }
      }
    }
  }
#endif
