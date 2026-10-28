#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il dettaglio di un pasto mangiato (IOS-031, NUT-007): si cambia la
  /// quantità di una riga, si toglie una riga scorrendo a sinistra e si
  /// aggiunge un alimento extra. Ogni riga mostra lo stato di YAZIO.
  struct DettaglioPastoView: View {
    let giorno: String
    let slot: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<GiornoDieta> = .inCorso
    @State private var aggiunta = false
    /// I grammi in modifica: id della riga e testo scritto.
    @State private var inModifica: String?
    @State private var testoGrammi = ""

    private var pasto: SlotGiorno? {
      stato.valore?.slotInOrdine.first { $0.slot == slot }
    }

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 3).listRowBackground(Color.clear)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let errore):
          SezioneErrore(errore: errore).listRowBackground(Color.clear)
        case .pronto:
          righe
          totale
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(GiornoDieta.nomiSlot[slot] ?? slot)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            aggiunta = true
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Aggiungi un alimento")
        }
      }
      .sheet(isPresented: $aggiunta) {
        RegistraPastoView(giorno: giorno, slot: slot) { nuovo in
          stato = .pronto(nuovo)
        }
      }
      .refreshable { await carica() }
      .task { await carica() }
    }

    @ViewBuilder
    private var righe: some View {
      ForEach(pasto?.meal?.items ?? []) { riga in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(riga.name)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
            Spacer()
            Text(formati.energia(riga.kcal))
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(Stile.testo)
          }
          if inModifica == riga.id {
            HStack(spacing: 10) {
              TextField("0", text: $testoGrammi)
                .keyboardType(.decimalPad)
                .font(.system(.body, design: .monospaced))
                .frame(width: 80)
                .accessibilityLabel("Grammi di \(riga.name)")
              Text("g")
                .font(.footnote)
                .foregroundStyle(Stile.testoTenue)
              Spacer()
              Button("Salva") { Task { await salvaGrammi(riga.id) } }
                .fontWeight(.semibold)
              Button("Annulla") { inModifica = nil }
                .foregroundStyle(Stile.testoTenue)
            }
            .font(.subheadline)
          } else {
            HStack(spacing: 8) {
              Text("\(Formato.numero(riga.grams)) g")
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
              if let yazio = riga.statoYazio {
                Text("· \(yazio)")
                  .font(.footnote)
                  .foregroundStyle(riga.sync == "error" ? Stile.brandTesto : Stile.testoTenue)
              }
            }
          }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
          inModifica = riga.id
          testoGrammi = Formato.numero(riga.grams)
        }
        .swipeActions(edge: .trailing) {
          Button("Togli", role: .destructive) { Task { await togli(riga.id) } }
        }
        .accessibilityAction(named: "Cambia i grammi") {
          inModifica = riga.id
          testoGrammi = Formato.numero(riga.grams)
        }
        .accessibilityAction(named: "Togli") { Task { await togli(riga.id) } }
      }
    }

    @ViewBuilder
    private var totale: some View {
      if let meal = pasto?.meal {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Totale")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
            Spacer()
            Text(formati.energia(meal.kcal))
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(Stile.testo)
          }
          Text(
            RegistraPastoView.testoMacro(
              Macro(kcal: meal.kcal, protein: meal.protein, carbs: meal.carbs, fat: meal.fat)
            )
          )
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
      }
    }

    private func carica() async {
      let client = sessione.client
      let giorno = giorno
      stato = await Carico.da { try await client.dieta(giorno) }
    }

    private func salvaGrammi(_ riga: String) async {
      let pulito = testoGrammi.replacingOccurrences(of: ",", with: ".")
      guard let grammi = Double(pulito), grammi > 0 else { return }
      do {
        stato = .pronto(try await sessione.client.cambiaGrammi(riga, grammi))
        inModifica = nil
        sessione.mostra(.salvato)
      } catch {
        sessione.mostra(.nonSalvato) { Task { await salvaGrammi(riga) } }
      }
    }

    private func togli(_ riga: String) async {
      do {
        stato = .pronto(try await sessione.client.togliRiga(riga))
      } catch {
        sessione.mostra(.nonSalvato) { Task { await togli(riga) } }
      }
    }
  }
#endif
