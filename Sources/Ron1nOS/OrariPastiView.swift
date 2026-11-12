#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Gli orari dei cinque pasti (IOS-037): decidono quale pasto compare
  /// nella Home e quando arriva il promemoria. Si salvano nelle preferenze di
  /// ron1nOS.
  struct OrariPastiView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var orari = Promemoria.predefiniti
    @State private var letti = false

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text("Orari dei pasti")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        ForEach(GiornoDieta.ordineSlot, id: \.self) { slot in
          DatePicker(
            GiornoDieta.nomiSlot[slot] ?? slot, selection: orario(slot), displayedComponents: .hourAndMinute
          )
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
          .frame(minHeight: 44)
        }
        Stepper(value: rinvio, in: Promemoria.rinvii, step: 5) {
          Text("Rimanda di \(orari.snooze) min")
            .font(.subheadline)
            .foregroundStyle(Stile.testo)
        }
        .frame(minHeight: 44)
        Text("Il promemoria arriva a quell'ora, con Mangiato e Rimanda.")
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
      .onAppear {
        if !letti { orari = sessione.promemoria }
      }
      .onChange(of: sessione.promemoria) { _, nuovi in
        orari = nuovi
        letti = true
      }
    }

    /// Di quanti minuti `Rimanda` sposta il promemoria; scrivendo si salva.
    private var rinvio: Binding<Int> {
      Binding(
        get: { orari.snooze },
        set: { minuti in
          orari.snooze = minuti
          let nuovi = orari
          Task {
            let salvato = await sessione.salvaOrari(nuovi)
            if !salvato { sessione.mostra(.nonSalvato) }
          }
        })
    }

    /// L'orario di uno slot come data di oggi, per il selettore; scrivendo si salva.
    private func orario(_ slot: String) -> Binding<Date> {
      Binding(
        get: {
          let minuti = Promemoria.minuti(orari.orario(slot)) ?? 12 * 60
          var calendario = Calendar(identifier: .gregorian)
          calendario.timeZone = sessione.formati.fuso
          let inizio = calendario.startOfDay(for: Date())
          return calendario.date(byAdding: .minute, value: minuti, to: inizio) ?? inizio
        },
        set: { data in
          let minuti = Promemoria.minutiDi(data, fuso: sessione.formati.fuso)
          orari.meals[slot] = Promemoria.testo(ore: minuti / 60, minuti: minuti % 60)
          let nuovi = orari
          Task {
            let salvato = await sessione.salvaOrari(nuovi)
            if !salvato { sessione.mostra(.nonSalvato) }
          }
        })
    }
  }
#endif
