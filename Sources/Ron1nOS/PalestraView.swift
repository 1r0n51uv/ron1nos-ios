#if canImport(SwiftUI)
  import Charts
  import Ron1nKit
  import SwiftUI
  import UniformTypeIdentifiers

  /// Quello che la pagina Palestra legge insieme.
  struct DatiPalestra: Equatable, Sendable {
    let riepilogo: RiepilogoAllenamento
    let esercizi: [EsercizioPalestra]
    let record: [RecordPalestra]
  }

  /// La pagina Palestra (IOS-050): l'ultimo allenamento a tutta larghezza,
  /// la settimana, i 6 esercizi più allenati e i record del mese. Fatta
  /// soprattutto di foto, con pochi numeri.
  struct PalestraView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<DatiPalestra> = .inCorso
    @State private var sceltaFile = false

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
          case .pronto(let dati) where dati.riepilogo.vuoto:
            invito
          case .pronto(let dati):
            if let ultimo = dati.riepilogo.last {
              if let id = ultimo.id {
                NavigationLink(value: Pagina.sessione(id: id)) {
                  UltimoAllenamento(ultimo: ultimo, oggi: dati.riepilogo.today)
                }
                .buttonStyle(.plain)
              } else {
                UltimoAllenamento(ultimo: ultimo, oggi: dati.riepilogo.today)
              }
            }
            settimana(dati.riepilogo)
            if !dati.esercizi.isEmpty {
              piuAllenati(dati.esercizi)
            }
            if !dati.record.isEmpty {
              record(dati.record)
            }
            collegamento("Storico delle sessioni", icona: "clock.arrow.circlepath", pagina: .storicoPalestra)
            collegamento("Esercizi", icona: "dumbbell", pagina: .esercizi)
            collegamento("Volume per gruppo", icona: "chart.bar", pagina: .volumeGruppi)
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Palestra")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Importa CSV", systemImage: "square.and.arrow.down") { sceltaFile = true }
        }
      }
      .fileImporter(isPresented: $sceltaFile, allowedContentTypes: [.commaSeparatedText]) { esito in
        // Il foglio di import si apre dalla radice, come per un file condiviso.
        if case .success(let url) = esito { sessione.csvInArrivo = FileCSV.leggi(url) }
      }
      .refreshable { await carica() }
      .task(id: "\(sessione.versione)-\(sessione.palestraCambiata)") { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da {
        async let riepilogo = client.allenamento()
        async let esercizi = client.eserciziPalestra(piuAllenati: true, limite: 6)
        async let record = client.recordPalestra(giorni: 30, limite: 3)
        return DatiPalestra(
          riepilogo: try await riepilogo, esercizi: try await esercizi, record: try await record)
      }
    }

    private func collegamento(_ titolo: String, icona: String, pagina: Pagina) -> some View {
      NavigationLink(value: pagina) {
        HStack {
          Label(titolo, systemImage: icona)
            .foregroundStyle(Stile.testo)
          Spacer()
          Image(systemName: "chevron.right")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
        .glassPanel()
      }
      .buttonStyle(.plain)
    }

    private func etichetta(_ testo: String) -> some View {
      Text(testo)
        .font(.system(.caption, design: .monospaced))
        .tracking(1.6)
        .foregroundStyle(Stile.testoTenue)
    }

    private var invito: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("Nessun allenamento")
          .font(.system(.title3, design: .default).weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text("Esporta il CSV da Liftin' e condividilo con ron1nOS: lo storico arriva qui.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        Button("Importa CSV", systemImage: "square.and.arrow.down") { sceltaFile = true }
          .buttonStyle(.borderedProminent)
          .tint(Stile.brand)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassPanel()
    }

    @ViewBuilder
    private func settimana(_ riepilogo: RiepilogoAllenamento) -> some View {
      let settimane = riepilogo.ultime12
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline, spacing: 28) {
          numero("\(riepilogo.thisWeek)", "QUESTA SETTIMANA")
          numero("\(riepilogo.streakDays)", "GIORNI DI FILA")
        }
        Chart {
          ForEach(Array(settimane.enumerated()), id: \.element.monday) { indice, settimana in
            BarMark(x: .value("Settimana", settimana.monday), y: .value("Allenamenti", settimana.count))
              .foregroundStyle(indice == settimane.count - 1 ? Stile.brand : Color.white.opacity(0.3))
              .cornerRadius(3)
          }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 64)
        .accessibilityLabel("Allenamenti delle ultime 12 settimane, la corrente in rosso")
      }
      .glassPanel()
    }

    private func numero(_ valore: String, _ titolo: String) -> some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(valore)
          .font(.system(size: 40, weight: .semibold, design: .monospaced))
          .foregroundStyle(Stile.testo)
        etichetta(titolo)
      }
      .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func piuAllenati(_ esercizi: [EsercizioPalestra]) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        etichetta("I PIÙ ALLENATI")
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(esercizi) { esercizio in
              NavigationLink(value: Pagina.esercizio(nome: esercizio.name)) {
                tessera(esercizio)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }

    private func tessera(_ esercizio: EsercizioPalestra) -> some View {
      VStack(alignment: .leading, spacing: 6) {
        FotoEsercizio(immagine: esercizio.image)
          .frame(width: 140, height: 140)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        Text(esercizio.name)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
          .lineLimit(1)
        if let migliore = esercizio.migliore(formati) {
          Text(migliore)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .frame(width: 140, alignment: .leading)
      .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func record(_ record: [RecordPalestra]) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        etichetta("RECORD DEL MESE")
        ForEach(record) { voce in
          HStack(spacing: 12) {
            FotoEsercizio(immagine: voce.exercise?.image)
              .frame(width: 44, height: 44)
              .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
              Text(voce.exercise?.name ?? "Esercizio")
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
              Text(voce.testo(formati))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Stile.brand)
            }
          }
          .accessibilityElement(children: .combine)
        }
      }
      .glassPanel()
    }
  }

  /// L'ultimo allenamento: la foto del primo esercizio a tutta larghezza,
  /// con routine, giorno e durata sopra.
  struct UltimoAllenamento: View {
    let ultimo: RiepilogoAllenamento.Ultimo
    let oggi: String

    var body: some View {
      ZStack(alignment: .bottomLeading) {
        FotoEsercizio(immagine: ultimo.exercise?.image, scurita: 0.5)
          .frame(maxWidth: .infinity)
          .frame(height: 220)
        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 4) {
          Text("ULTIMO ALLENAMENTO")
            .font(.system(.caption, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(Stile.testoTenue)
          Text(ultimo.routine.isEmpty ? "Allenamento" : ultimo.routine)
            .font(.system(.title, design: .default).weight(.bold))
            .foregroundStyle(Stile.testo)
          Text(dettaglio)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
        .padding(16)
      }
      .clipShape(RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous))
      .accessibilityElement(children: .combine)
    }

    private var dettaglio: String {
      let parti = [
        Giorni.relativo(ultimo.day, oggi: oggi), ultimo.durationSeconds.map { Formato.durata($0) },
      ]
      return parti.compactMap { $0 }.joined(separator: " · ")
    }
  }
#endif
