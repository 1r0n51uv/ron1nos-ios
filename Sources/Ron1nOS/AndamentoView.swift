#if canImport(SwiftUI)
  import Charts
  import Ron1nKit
  import SwiftUI

  /// L'andamento della Dieta (IOS-038, NUT-017): kcal al giorno con
  /// l'obiettivo, media, tendenza, aderenza, macro medi e peso. Tutto
  /// calcolato dal backend.
  struct AndamentoView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var giorni = 30
    @State private var stato: Carico<AndamentoDieta> = .inCorso

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Picker("Periodo", selection: $giorni) {
            ForEach(AndamentoDieta.periodi, id: \.self) { Text("\($0) g").tag($0) }
          }
          .pickerStyle(.segmented)
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
          case .pronto(let andamento):
            energia(andamento)
            numeri(andamento)
            macro(andamento)
            peso(andamento)
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Andamento")
      .refreshable { await carica() }
      .task(id: giorni) { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      let giorni = giorni
      stato = await Carico.da { try await client.andamentoDieta(giorni: giorni) }
    }

    private func etichetta(_ testo: String) -> some View {
      Text(testo)
        .font(.system(.caption, design: .monospaced))
        .tracking(1.6)
        .foregroundStyle(Stile.testoTenue)
    }

    @ViewBuilder
    private func energia(_ andamento: AndamentoDieta) -> some View {
      let fuso = formati.fuso
      VStack(alignment: .leading, spacing: 10) {
        etichetta("KCAL AL GIORNO")
        if andamento.registrati.isEmpty {
          Text("Nessun giorno registrato nel periodo.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        } else {
          Chart {
            ForEach(andamento.registrati) { giorno in
              if let data = AndamentoDieta.data(giorno.date, fuso: fuso) {
                BarMark(
                  x: .value("Giorno", data, unit: .day), y: .value("kcal", formati.valoreEnergia(giorno.kcal))
                )
                .foregroundStyle(Color.white.opacity(0.35))
              }
            }
            ForEach(andamento.series) { giorno in
              if let data = AndamentoDieta.data(giorno.date, fuso: fuso), let obiettivo = giorno.goalKcal {
                LineMark(
                  x: .value("Giorno", data, unit: .day),
                  y: .value("Obiettivo", formati.valoreEnergia(obiettivo))
                )
                .foregroundStyle(Stile.brand)
                .interpolationMethod(.stepCenter)
              }
            }
            if let media = andamento.averageKcal {
              RuleMark(y: .value("Media", formati.valoreEnergia(media)))
                .foregroundStyle(Stile.testoTenue)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
          }
          .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: giorni == 30 ? 7 : 21)) { _ in
              AxisGridLine().foregroundStyle(Stile.bordo)
              AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .foregroundStyle(Stile.testoTenue)
            }
          }
          .chartYAxis {
            AxisMarks(position: .trailing) { _ in
              AxisGridLine().foregroundStyle(Stile.bordo)
              AxisValueLabel().foregroundStyle(Stile.testoTenue)
            }
          }
          .environment(\.timeZone, fuso)
          .frame(height: 200)
          .accessibilityLabel("Kcal al giorno, con l'obiettivo in rosso e la media tratteggiata")
        }
      }
      .glassPanel()
    }

    @ViewBuilder
    private func numeri(_ andamento: AndamentoDieta) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        riga("MEDIA", andamento.averageKcal.map { formati.energia($0) } ?? "—")
        riga("TENDENZA", andamento.testoTendenza(formati))
        riga("ADERENZA", andamento.testoAderenza)
      }
      .glassPanel()
    }

    private func riga(_ titolo: String, _ valore: String) -> some View {
      HStack(alignment: .firstTextBaseline) {
        etichetta(titolo)
        Spacer()
        Text(valore)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(Stile.testo)
      }
      .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func macro(_ andamento: AndamentoDieta) -> some View {
      if let medie = andamento.macros {
        VStack(alignment: .leading, spacing: 12) {
          etichetta("MACRO MEDI")
          rigaMacro("Proteine", medie.protein, andamento.goal?.protein)
          rigaMacro("Carboidrati", medie.carbs, andamento.goal?.carbs)
          rigaMacro("Grassi", medie.fat, andamento.goal?.fat)
        }
        .glassPanel()
      }
    }

    private func rigaMacro(_ nome: String, _ valore: Double, _ obiettivo: Double?) -> some View {
      let testo = obiettivo.map { "\(Formato.numero(valore)) / \(Formato.numero($0)) g" }
      return HStack(alignment: .firstTextBaseline) {
        Text(nome)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
        Spacer()
        Text(testo ?? "\(Formato.numero(valore)) g")
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
      }
      .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func peso(_ andamento: AndamentoDieta) -> some View {
      let fuso = formati.fuso
      let pesate = andamento.weight.points
      if !pesate.isEmpty, let inizio = AndamentoDieta.data(andamento.from, fuso: fuso),
        let fine = AndamentoDieta.data(andamento.to, fuso: fuso)
      {
        VStack(alignment: .leading, spacing: 10) {
          HStack(alignment: .firstTextBaseline) {
            etichetta("PESO")
            Spacer()
            Text(andamento.testoPeso(formati))
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testo)
          }
          // Stesso asse del grafico delle kcal: dal primo all'ultimo giorno del periodo.
          Chart(pesate) { pesata in
            if let data = AndamentoDieta.data(pesata.date, fuso: fuso) {
              LineMark(x: .value("Giorno", data, unit: .day), y: .value("Peso", pesata.kg))
                .foregroundStyle(Stile.testo)
              PointMark(x: .value("Giorno", data, unit: .day), y: .value("Peso", pesata.kg))
                .foregroundStyle(Stile.testo)
                .symbolSize(18)
            }
          }
          .chartXScale(domain: inizio...fine)
          .chartYScale(domain: .automatic(includesZero: false))
          .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: giorni == 30 ? 7 : 21)) { _ in
              AxisGridLine().foregroundStyle(Stile.bordo)
              AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                .foregroundStyle(Stile.testoTenue)
            }
          }
          .chartYAxis {
            AxisMarks(position: .trailing) { _ in
              AxisGridLine().foregroundStyle(Stile.bordo)
              AxisValueLabel().foregroundStyle(Stile.testoTenue)
            }
          }
          .environment(\.timeZone, fuso)
          .frame(height: 140)
          .accessibilityLabel("Peso nel periodo · \(andamento.testoPeso(formati))")
        }
        .glassPanel()
      }
    }
  }
#endif
