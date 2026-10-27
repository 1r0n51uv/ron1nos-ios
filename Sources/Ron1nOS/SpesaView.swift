#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// La lista della spesa (IOS-036, NUT-011), pensata per il supermercato:
  /// righe alte, testo grande, un tocco per spuntare e lo schermo che non
  /// si spegne finché è aperta.
  struct SpesaView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<ListaSpesa> = .inCorso
    @State private var nuova = false
    @State private var nome = ""
    @State private var quantita = ""
    @State private var genera = false

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 4).listRowBackground(Color.clear)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let errore):
          SezioneErrore(errore: errore).listRowBackground(Color.clear)
        case .pronto(let lista):
          if lista.items.isEmpty {
            Text("La lista è vuota. Genera dai pasti pianificati o aggiungi una voce.")
              .font(.body)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(Color.clear)
          } else {
            Text(lista.riepilogo)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(Color.clear)
          }
          ForEach(lista.items) { voce in
            RigaSpesa(voce: voce) { Task { await spunta(voce) } }
              .listRowBackground(Color.clear)
              .swipeActions(edge: .trailing) {
                Button("Elimina", role: .destructive) { Task { await elimina(voce.id) } }
              }
              .accessibilityAction(named: "Elimina") { Task { await elimina(voce.id) } }
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Spesa")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            nome = ""
            quantita = ""
            nuova = true
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Aggiungi una voce")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("Genera dai pasti pianificati") { genera = true }
            Button("Togli le spuntate", role: .destructive) { Task { await togliSpuntate() } }
              .disabled((stato.valore?.spuntate ?? 0) == 0)
          } label: {
            Image(systemName: "ellipsis")
          }
          .accessibilityLabel("Altre azioni")
        }
      }
      .alert("Nuova voce", isPresented: $nuova) {
        TextField("Nome", text: $nome)
        TextField("Quantità, facoltativa", text: $quantita)
        Button("Annulla", role: .cancel) {}
        Button("Aggiungi") { Task { await aggiungi() } }
          .disabled(nome.trimmingCharacters(in: .whitespaces).isEmpty)
      }
      .sheet(isPresented: $genera) {
        GeneraSpesaView { intervallo in await generaLista(intervallo) }
      }
      .refreshable { await carica() }
      .task { await carica() }
      .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
      .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.spesa() }
    }

    private func spunta(_ voce: VoceSpesa) async {
      guard let lista = stato.valore else { return }
      // Subito sullo schermo, poi sul server: al supermercato la rete va e viene.
      let presa = VoceSpesa(
        id: voce.id, foodId: voce.foodId, name: voce.name, grams: voce.grams, text: voce.text,
        checked: !voce.checked, source: voce.source)
      stato = .pronto(lista.sostituendo(presa))
      UISelectionFeedbackGenerator().selectionChanged()
      do {
        let salvata = try await sessione.client.spunta(voce.id, presa.checked)
        if let attuale = stato.valore { stato = .pronto(attuale.sostituendo(salvata)) }
      } catch {
        if let attuale = stato.valore { stato = .pronto(attuale.sostituendo(voce)) }
        sessione.mostra(.nonSalvato) { Task { await spunta(voce) } }
      }
    }

    private func elimina(_ id: String) async {
      do {
        try await sessione.client.eliminaVoceSpesa(id)
        if let lista = stato.valore { stato = .pronto(lista.senza(id)) }
      } catch {
        sessione.mostra(.nonSalvato) { Task { await elimina(id) } }
      }
    }

    private func aggiungi() async {
      let nome = nome
      let quantita = quantita
      do {
        _ = try await sessione.client.aggiungiSpesa(nome: nome, quantita: quantita)
        await carica()
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }

    private func togliSpuntate() async {
      do {
        let lista = try await sessione.client.togliSpuntate()
        stato = .pronto(lista)
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }

    private func generaLista(_ intervallo: IntervalloSpesa) async {
      do {
        let lista = try await sessione.client.generaSpesa(intervallo)
        stato = .pronto(lista)
        let aggiunte = lista.added ?? 0
        sessione.mostra(Avviso(aggiunte == 1 ? "1 voce aggiunta" : "\(aggiunte) voci aggiunte"))
        genera = false
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }
  }

  /// Una voce: alta, col nome grande e la quantità in mono. Un tocco la
  /// spunta.
  struct RigaSpesa: View {
    let voce: VoceSpesa
    let tocca: () -> Void

    var body: some View {
      Button(action: tocca) {
        HStack(spacing: 14) {
          Image(systemName: voce.checked ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(voce.checked ? Stile.brand : Stile.testoTenue)
          Text(voce.name)
            .font(.title3)
            .strikethrough(voce.checked)
            .foregroundStyle(voce.checked ? Stile.testoTenue : Stile.testo)
          Spacer()
          if let quantita = voce.quantita {
            Text(quantita)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(voce.checked ? [.isButton, .isSelected] : .isButton)
    }
  }

  /// `Genera`: i giorni da cui prendere i pasti pianificati.
  struct GeneraSpesaView: View {
    let conferma: (IntervalloSpesa) async -> Void
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var da = Date()
    @State private var a = Date().addingTimeInterval(6 * 86_400)
    @State private var inCorso = false

    var body: some View {
      NavigationStack {
        Form {
          Section {
            DatePicker("Dal", selection: $da, displayedComponents: .date)
            DatePicker("Al", selection: $a, displayedComponents: .date)
          } footer: {
            Text(intervallo.problema ?? "\(intervallo.giorni) giorni · i pasti saltati non contano")
              .foregroundStyle(intervallo.problema == nil ? Stile.testoTenue : Stile.brand)
          }
          .listRowBackground(Color.white.opacity(0.06))
          Section {
            Button("Prossimi 7 giorni") { scegli(7) }
            Button("Prossimi 14 giorni") { scegli(14) }
          }
          .listRowBackground(Color.white.opacity(0.06))
        }
        .environment(\.timeZone, formati.fuso)
        .scrollContentBackground(.hidden)
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Genera")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Genera") {
              inCorso = true
              Task {
                await conferma(intervallo)
                inCorso = false
              }
            }
            .fontWeight(.semibold)
            .disabled(intervallo.problema != nil || inCorso)
          }
        }
      }
      .tint(Stile.brand)
    }

    private var intervallo: IntervalloSpesa { IntervalloSpesa(da: da, a: a, fuso: formati.fuso) }

    private func scegli(_ giorni: Int) {
      let scelto = IntervalloSpesa.prossimi(giorni, fuso: formati.fuso)
      da = scelto.da
      a = scelto.a
    }
  }
#endif
