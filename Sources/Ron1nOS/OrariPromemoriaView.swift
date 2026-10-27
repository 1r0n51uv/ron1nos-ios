#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Gli orari dei promemoria (IOS-041): uno per pasto e gli avvisi
  /// dell'acqua. Si salvano sul server, nelle preferenze condivise, un
  /// secondo dopo l'ultima modifica.
  struct OrariPromemoriaView: View {
    let pasti: Bool
    let acqua: Bool
    @EnvironmentObject private var sessione: Sessione
    @State private var bozza = Promemoria.predefiniti
    @State private var letta = false

    var body: some View {
      Group {
        if pasti {
          Section {
            ForEach(GiornoDieta.ordineSlot, id: \.self) { slot in
              let nome = GiornoDieta.nomiSlot[slot] ?? slot
              DatePicker(nome, selection: orario(slot), displayedComponents: .hourAndMinute)
                .foregroundStyle(Stile.testo)
                .listRowBackground(Color.white.opacity(0.06))
            }
          } header: {
            Text("Orari dei pasti")
          } footer: {
            Text("Il promemoria arriva solo se quel pasto non è ancora registrato.")
              .foregroundStyle(Stile.testoTenue)
          }
        }
        if acqua {
          Section {
            ForEach(Array(bozza.water.enumerated()), id: \.element) { indice, _ in
              DatePicker("Avviso", selection: avviso(indice), displayedComponents: .hourAndMinute)
                .foregroundStyle(Stile.testo)
                .listRowBackground(Color.white.opacity(0.06))
            }
            .onDelete { righe in
              bozza.water.remove(atOffsets: righe)
            }
            if bozza.water.count < Promemoria.massimoAcqua {
              Button("Aggiungi un avviso") { aggiungiAvviso() }
                .foregroundStyle(Stile.brand)
                .listRowBackground(Color.white.opacity(0.06))
            }
          } header: {
            Text("Avvisi dell'acqua")
          } footer: {
            Text("Arrivano solo se a quell'ora sei sotto la quota del giorno.")
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
      .onAppear {
        if !letta {
          bozza = sessione.preferenze.reminders
          letta = true
        }
      }
      .task(id: bozza) {
        guard letta, bozza != sessione.preferenze.reminders else { return }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        guard !Task.isCancelled else { return }
        if !(await sessione.salvaPromemoria(bozza)) { sessione.mostra(.nonSalvato) }
      }
    }

    private func data(_ testo: String) -> Date {
      let minuti = Promemoria.minuti(testo) ?? 12 * 60
      var calendario = Calendar.current
      calendario.timeZone = .current
      let oggi = calendario.startOfDay(for: Date())
      return calendario.date(byAdding: .minute, value: minuti, to: oggi) ?? oggi
    }

    private func testo(_ data: Date) -> String {
      let parti = Calendar.current.dateComponents([.hour, .minute], from: data)
      return Promemoria.testo(ore: parti.hour ?? 0, minuti: parti.minute ?? 0)
    }

    private func orario(_ slot: String) -> Binding<Date> {
      Binding(
        get: { data(bozza.orario(slot)) },
        set: { bozza.meals[slot] = testo($0) })
    }

    private func avviso(_ indice: Int) -> Binding<Date> {
      Binding(
        get: { data(bozza.water.indices.contains(indice) ? bozza.water[indice] : "12:00") },
        set: { nuovo in
          guard bozza.water.indices.contains(indice) else { return }
          var orari = bozza.water
          orari[indice] = testo(nuovo)
          bozza.water = Promemoria.ordina(orari)
        })
    }

    /// Un'ora dopo l'ultimo avviso, o le 12 se non ce ne sono.
    private func aggiungiAvviso() {
      let ultimo = bozza.water.last.flatMap(Promemoria.minuti) ?? 11 * 60
      let minuti = min(ultimo + 60, 23 * 60)
      bozza.water = Promemoria.ordina(bozza.water + [Promemoria.testo(ore: minuti / 60, minuti: minuti % 60)])
    }
  }
#endif
