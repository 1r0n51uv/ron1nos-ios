#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// I template settimanali (IOS-035, NUT-010): l'elenco, e in ogni
  /// template un giorno alla volta.
  struct TemplateView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<[TemplateSettimana]> = .inCorso

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 3).listRowBackground(Color.clear)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let errore):
          SezioneErrore(errore: errore).listRowBackground(Color.clear)
        case .pronto(let elenco):
          if elenco.isEmpty {
            Text("Nessun template. Si creano dal sito.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(Color.clear)
          }
          ForEach(elenco) { template in
            NavigationLink(value: Pagina.template(id: template.id)) {
              VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                  .font(.subheadline)
                  .foregroundStyle(Stile.testo)
                Text(template.sottotitolo)
                  .font(.system(.footnote, design: .monospaced))
                  .foregroundStyle(Stile.testoTenue)
              }
              .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
              Button("Elimina", role: .destructive) { Task { await elimina(template.id) } }
            }
            .accessibilityAction(named: "Elimina") { Task { await elimina(template.id) } }
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Template")
      .refreshable { await carica() }
      .task { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.template() }
    }

    private func elimina(_ id: String) async {
      do {
        try await sessione.client.eliminaTemplate(id)
        await carica()
      } catch {
        sessione.mostra(.nonSalvato) { Task { await elimina(id) } }
      }
    }
  }

  /// Un template: la fila dei sette giorni e sotto i cinque slot del
  /// giorno scelto. `Applica` lo copia su una settimana.
  struct DettaglioTemplateView: View {
    let id: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<TemplateSettimana> = .inCorso
    @State private var giorno = 1
    @State private var applica = false

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
          case .pronto(let template):
            giorni
            Text(formati.energia(template.kcal(giorno: giorno)))
              .font(.system(.title2, design: .monospaced))
              .foregroundStyle(Stile.testo)
            VStack(alignment: .leading, spacing: 14) {
              ForEach(template.slot(giorno: giorno)) { casella in
                riga(casella)
              }
            }
            .glassPanel()
            Button("Applica a una settimana") { applica = true }
              .fontWeight(.semibold)
              .glassChip()
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(stato.valore?.name ?? "Template")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $applica) {
        ApplicaTemplateView { lunedi in await usa(lunedi) }
      }
      .refreshable { await carica() }
      .task {
        giorno = Settimana.giorno(di: Date(), fuso: formati.fuso)
        await carica()
      }
    }

    private var giorni: some View {
      HStack(spacing: 6) {
        ForEach(1...7, id: \.self) { numero in
          Button {
            giorno = numero
          } label: {
            Text(TemplateSettimana.lettere[numero - 1])
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(Stile.testo)
              .frame(maxWidth: .infinity, minHeight: 44)
              .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .fill(numero == giorno ? Stile.brand.opacity(0.9) : Color.white.opacity(0.06))
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Self.nomi[numero - 1])
          .accessibilityAddTraits(numero == giorno ? [.isButton, .isSelected] : .isButton)
        }
      }
    }

    private static let nomi = [
      "Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica",
    ]

    @ViewBuilder
    private func riga(_ casella: TemplateSettimana.Casella) -> some View {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(casella.titolo.uppercased())
            .font(.system(.caption, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(Stile.testoTenue)
          Text(casella.cella?.name ?? "Niente")
            .font(.subheadline)
            .foregroundStyle(casella.cella == nil ? Stile.testoTenue : Stile.testo)
        }
        Spacer()
        if let cella = casella.cella {
          VStack(alignment: .trailing, spacing: 2) {
            Text(formati.energia(cella.kcal))
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testo)
            Text(cella.dettaglio)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
      .accessibilityElement(children: .combine)
    }

    private func carica() async {
      let client = sessione.client
      let id = id
      stato = await Carico.da {
        let elenco = try await client.template()
        guard let template = elenco.first(where: { $0.id == id }) else {
          throw APIError.rispostaInattesa(codice: 404)
        }
        return template
      }
    }

    private func usa(_ lunedi: String) async {
      do {
        let esito = try await sessione.client.applicaTemplate(id, lunedi: lunedi)
        sessione.mostra(Avviso(esito.testo))
        applica = false
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }
  }

  /// Su quale settimana va il template: questa, la prossima o quella di
  /// una data qualsiasi, sempre da lunedì.
  struct ApplicaTemplateView: View {
    let conferma: (String) async -> Void
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var scelta = Scelta.prossima
    @State private var data = Date()
    @State private var inCorso = false

    enum Scelta: String, CaseIterable, Identifiable {
      case corrente = "Questa"
      case prossima = "La prossima"
      case data = "Una data"
      var id: String { rawValue }
    }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            Picker("Settimana", selection: $scelta) {
              ForEach(Scelta.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            if scelta == .data {
              DatePicker("Giorno", selection: $data, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.timeZone, formati.fuso)
            }
            VStack(alignment: .leading, spacing: 4) {
              Text("DA LUNEDÌ")
                .font(.system(.caption, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(Stile.testoTenue)
              Text(lunedi)
                .font(.system(.title3, design: .monospaced))
                .foregroundStyle(Stile.testo)
              Text("I pasti già mangiati o saltati restano.")
                .font(.footnote)
                .foregroundStyle(Stile.testoTenue)
            }
            .glassPanel()
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Applica")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Applica") {
              inCorso = true
              Task {
                await conferma(lunedi)
                inCorso = false
                chiudi()
              }
            }
            .fontWeight(.semibold)
            .disabled(inCorso)
          }
        }
      }
      .tint(Stile.brand)
    }

    private var lunedi: String {
      switch scelta {
      case .corrente: Settimana.lunedi(di: Date(), fuso: formati.fuso)
      case .prossima: Settimana.lunedi(di: Date(), piu: 1, fuso: formati.fuso)
      case .data: Settimana.lunedi(di: data, fuso: formati.fuso)
      }
    }
  }
#endif
