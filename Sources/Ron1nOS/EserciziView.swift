#if canImport(SwiftUI)
  import Charts
  import Ron1nKit
  import SwiftUI

  /// Gli esercizi (IOS-053, GYM-009): griglia a due colonne con foto, nome
  /// e gruppo; ricerca e filtro `Da completare`.
  struct EserciziView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<[EsercizioPalestra]> = .inCorso
    @State private var cerca = ""
    @State private var daCompletare = false

    private let colonne = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Toggle("Da completare", isOn: $daCompletare)
            .tint(Stile.brand)
            .foregroundStyle(Stile.testo)
            .glassPanel()
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
          case .pronto(let esercizi) where esercizi.isEmpty:
            Text(daCompletare ? "Niente da completare." : "Nessun esercizio.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .pronto(let esercizi):
            LazyVGrid(columns: colonne, spacing: 16) {
              ForEach(esercizi) { esercizio in
                NavigationLink(value: Pagina.esercizio(nome: esercizio.name)) {
                  TesseraEsercizio(esercizio: esercizio)
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Esercizi")
      .searchable(text: $cerca, prompt: "Cerca un esercizio")
      .refreshable { await carica() }
      .task(id: "\(cerca)-\(daCompletare)-\(sessione.palestraCambiata)") {
        // Una pausa breve mentre si scrive, poi una sola richiesta.
        if !cerca.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
        guard !Task.isCancelled else { return }
        await carica()
      }
    }

    private func carica() async {
      let client = sessione.client
      let (testo, solo) = (cerca, daCompletare)
      stato = await Carico.da { try await client.eserciziPalestra(cerca: testo, daCompletare: solo) }
    }
  }

  /// Una tessera della griglia: foto quadrata, nome e gruppo.
  struct TesseraEsercizio: View {
    let esercizio: EsercizioPalestra

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        FotoEsercizio(immagine: esercizio.image)
          .aspectRatio(1, contentMode: .fit)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        Text(esercizio.name)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
          .lineLimit(1)
        Text(esercizio.nomeGruppo)
          .font(.footnote)
          .foregroundStyle(esercizio.group == nil ? Stile.brandTesto : Stile.testoTenue)
      }
      .accessibilityElement(children: .combine)
    }
  }

  /// La pagina di un esercizio (IOS-053, GYM-008): foto grande, tre numeri,
  /// un grafico per volta, le ultime 3 volte e i record.
  struct DettaglioEsercizioView: View {
    let nome: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<DettaglioEsercizio> = .inCorso
    @State private var grafico = DettaglioEsercizio.Grafico.migliore
    @State private var periodo = PeriodoEsercizio.sei
    @State private var sceltaImmagine = false

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
          case .pronto(let esercizio):
            testata(esercizio)
            completa(esercizio)
            numeri(esercizio)
            andamento(esercizio)
            if !esercizio.recent.isEmpty {
              ultimeVolte(esercizio)
            }
            if !esercizio.records.isEmpty {
              record(esercizio)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(nome)
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $sceltaImmagine) {
        SceltaImmagineView(nome: nome).environmentObject(sessione)
      }
      .refreshable { await carica() }
      .task(id: "\(periodo.rawValue)-\(sessione.palestraCambiata)") { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      let (nome, periodo) = (nome, periodo)
      let nuovo = await Carico.da { try await client.esercizioPalestra(nome, periodo: periodo) }
      // Cambiando periodo resta la pagina di prima finché non arriva la nuova.
      if case .fallito = nuovo, stato.valore != nil { return }
      stato = nuovo
    }

    private func etichetta(_ testo: String) -> some View {
      Text(testo)
        .font(.system(.caption, design: .monospaced))
        .tracking(1.6)
        .foregroundStyle(Stile.testoTenue)
    }

    private func testata(_ esercizio: DettaglioEsercizio) -> some View {
      ZStack(alignment: .bottomLeading) {
        FotoEsercizio(immagine: esercizio.image, scurita: 0.5)
          .frame(maxWidth: .infinity)
          .frame(height: 240)
        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 4) {
          Text(esercizio.name)
            .font(.system(.title, design: .default).weight(.bold))
            .foregroundStyle(Stile.testo)
          Text(esercizio.nomeGruppo)
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        .padding(16)
      }
      .clipShape(RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous))
      .accessibilityElement(children: .combine)
    }

    /// Gruppo muscolare e immagine (IOS-054): valgono per tutto lo storico.
    private func completa(_ esercizio: DettaglioEsercizio) -> some View {
      HStack(spacing: 12) {
        Menu {
          Picker("Gruppo", selection: gruppo(esercizio)) {
            ForEach(Palestra.gruppi, id: \.self) { voce in
              Text(Palestra.nomeGruppo(voce)).tag(String?.some(voce))
            }
            Text("Da assegnare").tag(String?.none)
          }
        } label: {
          Label(esercizio.nomeGruppo, systemImage: "figure.strengthtraining.traditional")
            .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("Gruppo · \(esercizio.nomeGruppo)")
        Button("Scegli immagine", systemImage: "photo") { sceltaImmagine = true }
          .frame(maxWidth: .infinity)
      }
      .font(.subheadline)
      .tint(Stile.testo)
      .buttonStyle(.bordered)
    }

    private func gruppo(_ esercizio: DettaglioEsercizio) -> Binding<String?> {
      Binding(
        get: { esercizio.group },
        set: { nuovo in Task { await salvaGruppo(nuovo) } })
    }

    private func salvaGruppo(_ gruppo: String?) async {
      do {
        _ = try await sessione.client.gruppoEsercizio(nome, gruppo: gruppo)
        sessione.palestraCambiata += 1
      } catch {
        sessione.mostra(.nonSalvato) { Task { await salvaGruppo(gruppo) } }
      }
    }

    private func numeri(_ esercizio: DettaglioEsercizio) -> some View {
      HStack(alignment: .top, spacing: 12) {
        ForEach(esercizio.numeri(formati), id: \.titolo) { numero in
          VStack(alignment: .leading, spacing: 2) {
            Text(numero.valore)
              .font(.system(.title3, design: .monospaced).weight(.semibold))
              .foregroundStyle(Stile.testo)
              .minimumScaleFactor(0.7)
              .lineLimit(1)
            etichetta(numero.titolo)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityElement(children: .combine)
        }
      }
      .glassPanel()
    }

    private func andamento(_ esercizio: DettaglioEsercizio) -> some View {
      let valori = esercizio.valori(grafico)
      return VStack(alignment: .leading, spacing: 12) {
        Picker("Grafico", selection: $grafico) {
          ForEach(DettaglioEsercizio.Grafico.allCases, id: \.self) { voce in
            Text(voce.titolo(aTempo: esercizio.timed)).tag(voce)
          }
        }
        .pickerStyle(.segmented)
        if valori.count < 2 {
          Text("Servono almeno due sessioni nel periodo.")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
          Chart {
            ForEach(Array(valori.enumerated()), id: \.offset) { indice, valore in
              LineMark(x: .value("Giorno", esercizio.points[indice].day), y: .value("Valore", valore))
                .foregroundStyle(Stile.testo)
                .interpolationMethod(.monotone)
            }
          }
          .chartXAxis(.hidden)
          .chartYAxis {
            AxisMarks(position: .leading) { _ in
              AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
              AxisValueLabel().font(.system(.caption2, design: .monospaced))
            }
          }
          .frame(height: 160)
          .accessibilityLabel(grafico.titolo(aTempo: esercizio.timed))
        }
        Picker("Periodo", selection: $periodo) {
          ForEach(PeriodoEsercizio.allCases, id: \.self) { voce in
            Text(voce.titolo).tag(voce)
          }
        }
        .pickerStyle(.segmented)
      }
      .glassPanel()
    }

    private func ultimeVolte(_ esercizio: DettaglioEsercizio) -> some View {
      let oggi = Striscia(fuso: formati.fuso).oggi
      return VStack(alignment: .leading, spacing: 12) {
        etichetta("ULTIME VOLTE")
        ForEach(esercizio.recent) { volta in
          NavigationLink(value: Pagina.sessione(id: volta.sessionId)) {
            VStack(alignment: .leading, spacing: 4) {
              Text(Giorni.relativo(volta.day, oggi: oggi))
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
              Text(volta.sets.map { $0.testo(formati) }.joined(separator: " · "))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
                .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
          .buttonStyle(.plain)
        }
      }
      .glassPanel()
    }

    private func record(_ esercizio: DettaglioEsercizio) -> some View {
      let oggi = Striscia(fuso: formati.fuso).oggi
      return VStack(alignment: .leading, spacing: 10) {
        etichetta("RECORD")
        ForEach(esercizio.records) { voce in
          HStack {
            Text(voce.testo(formati))
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testo)
            Spacer()
            Text(Giorni.relativo(voce.day, oggi: oggi))
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
          }
          .accessibilityElement(children: .combine)
        }
      }
      .glassPanel()
    }
  }

  /// `Scegli immagine` (IOS-054, GYM-014): ricerca nel catalogo e griglia
  /// di foto. La scelta vale per tutto lo storico.
  struct SceltaImmagineView: View {
    let nome: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var cerca = ""
    @State private var stato: Carico<[EsercizioCatalogo]> = .inCorso
    @State private var inCorso = false

    private let colonne = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            switch stato {
            case .inCorso:
              Scheletro(righe: 4).glassPanel()
            case .spento:
              ModuloSpento()
            case .fallito(let errore):
              SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
            case .pronto(let catalogo) where catalogo.isEmpty:
              Text("Nessuna foto per questa ricerca.")
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
            case .pronto(let catalogo):
              LazyVGrid(columns: colonne, spacing: 10) {
                ForEach(catalogo) { voce in
                  Button {
                    Task { await scegli(voce.id) }
                  } label: {
                    VStack(alignment: .leading, spacing: 4) {
                      FotoEsercizio(immagine: voce.immagine, scurita: 0.2)
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                      Text(voce.name)
                        .font(.caption)
                        .foregroundStyle(Stile.testo)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    }
                  }
                  .buttonStyle(.plain)
                  .disabled(inCorso)
                }
              }
            }
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Scegli immagine")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $cerca, prompt: "Cerca in inglese, es. bench press")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .primaryAction) {
            Button("Automatica") { Task { await scegli(nil) } }
              .disabled(inCorso)
          }
        }
        .task(id: cerca) {
          if !cerca.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
          guard !Task.isCancelled else { return }
          let client = sessione.client
          let testo = cerca
          stato = await Carico.da { try await client.catalogoEsercizi(cerca: testo) }
        }
      }
    }

    /// nil torna all'abbinamento automatico.
    private func scegli(_ id: String?) async {
      inCorso = true
      defer { inCorso = false }
      do {
        _ = try await sessione.client.immagineEsercizio(nome, catalogId: id)
        sessione.palestraCambiata += 1
        chiudi()
      } catch {
        sessione.mostra(.nonSalvato) { Task { await scegli(id) } }
      }
    }
  }
#endif
