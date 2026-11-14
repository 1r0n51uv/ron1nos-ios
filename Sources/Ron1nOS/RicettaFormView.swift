#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Creare o correggere una ricetta (IOS-034): nome, ingredienti dal
  /// catalogo YAZIO coi grammi, procedimento e note.
  struct RicettaFormView: View {
    /// nil per una ricetta nuova.
    let ricetta: Ricetta?
    let salvato: () async -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var modulo = ModuloRicetta()
    /// I passi in modifica, ognuno con un id: togliere un passo non sposta gli altri.
    @State private var voci: [PassoInModifica] = []
    @State private var scelta = false
    @State private var errore: String?
    @State private var salvando = false

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: Stile.traCard) {
            TextField("Nome", text: $modulo.nome)
              .foregroundStyle(Stile.testo)
              .glassChip()
            ingredienti
            passi
            azioni
            TextField("Note", text: $modulo.note, axis: .vertical)
              .foregroundStyle(Stile.testo)
              .lineLimit(2...6)
              .glassPanel()
            if let errore {
              Text(errore)
                .font(.subheadline)
                .foregroundStyle(Stile.brandTesto)
            }
          }
          .padding(16)
        }
        .sfondoPagina()
        .navigationTitle(ricetta == nil ? "Nuova ricetta" : "Modifica ricetta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
        .azioniInBasso {
          AzioneBarra(titolo: "Salva la ricetta", simbolo: "checkmark", principale: true, inCorso: salvando) {
            Task { await salva() }
          }
        }
      }
      .tint(Modulo.nutrizione.colore)
      .sheet(isPresented: $scelta) {
        SceltaAlimentoView { alimento in
          modulo.righe.append(Bozza(alimento))
          scelta = false
        }
        .environmentObject(sessione)
        .environment(\.formati, formati)
      }
      .onAppear {
        if let ricetta {
          modulo = ModuloRicetta(ricetta)
          voci = modulo.passi.map { PassoInModifica(testo: $0) }
        }
      }
    }

    private var ingredienti: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Ingredienti")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        ForEach($modulo.righe) { $riga in
          RigaBozza(riga: $riga) {
            modulo.righe.removeAll { $0.id == riga.id }
          }
        }
        Button {
          scelta = true
        } label: {
          Label("Aggiungi da YAZIO", systemImage: "plus")
        }
        .glassChip()
        if !modulo.righe.isEmpty {
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
      }
      .glassPanel()
    }

    private var passi: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Procedimento")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        ForEach($voci) { $voce in
          HStack(alignment: .top, spacing: 10) {
            Text("\((voci.firstIndex { $0.id == voce.id } ?? 0) + 1)")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
              .frame(width: 20, alignment: .trailing)
              .padding(.top, 4)
            TextField("Passo", text: $voce.testo, axis: .vertical)
              .foregroundStyle(Stile.testo)
            Button {
              voci.removeAll { $0.id == voce.id }
            } label: {
              Image(systemName: "minus.circle")
                .foregroundStyle(Stile.testoTenue)
                .frame(width: 44, height: 44)
            }
            .buttonStyle(StilePremuto())
            .accessibilityLabel("Togli questo passo")
          }
        }
        Button {
          voci.append(PassoInModifica(testo: ""))
        } label: {
          Label("Aggiungi un passo", systemImage: "plus")
        }
        .glassChip()
      }
      .glassPanel()
    }

    /// Le azioni collegate (NUT-035): un promemoria prima del pasto, per
    /// esempio scongelare il pesce la sera prima. Ognuna si può spegnere.
    private var azioni: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Azioni")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text("Ti avvisano prima del pasto, quando la ricetta è in programma.")
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
        ForEach($modulo.azioni) { $azione in
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              TextField("Per esempio: scongela il pesce", text: $azione.title)
                .foregroundStyle(Stile.testo)
              Button {
                modulo.azioni.removeAll { $0.id == azione.id }
              } label: {
                Image(systemName: "minus.circle")
                  .foregroundStyle(Stile.testoTenue)
                  .frame(width: 44, height: 44)
              }
              .buttonStyle(StilePremuto())
              .accessibilityLabel("Togli questa azione")
            }
            Stepper(value: $azione.daysBefore, in: AzioneRicetta.giorniPrima) {
              Text(giorniPrima(azione.daysBefore))
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
            }
            DatePicker("Alle", selection: orario($azione), displayedComponents: .hourAndMinute)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
            Toggle("Attiva", isOn: $azione.enabled)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
          }
          .padding(.vertical, 6)
        }
        Button {
          modulo.azioni.append(AzioneRicetta())
        } label: {
          Label("Aggiungi un'azione", systemImage: "plus")
        }
        .glassChip()
      }
      .glassPanel()
    }

    private func giorniPrima(_ n: Int) -> String {
      switch n {
      case 0: "Lo stesso giorno"
      case 1: "Il giorno prima"
      default: "\(n) giorni prima"
      }
    }

    /// L'orario di un'azione come data di oggi, per il selettore.
    private func orario(_ azione: Binding<AzioneRicetta>) -> Binding<Date> {
      Binding(
        get: {
          let minuti = Promemoria.minuti(azione.wrappedValue.time) ?? 21 * 60
          var calendario = Calendar(identifier: .gregorian)
          calendario.timeZone = sessione.formati.fuso
          let inizio = calendario.startOfDay(for: Date())
          return calendario.date(byAdding: .minute, value: minuti, to: inizio) ?? inizio
        },
        set: { data in
          let minuti = Promemoria.minutiDi(data, fuso: sessione.formati.fuso)
          azione.wrappedValue.time = Promemoria.testo(ore: minuti / 60, minuti: minuti % 60)
        })
    }

    private func salva() async {
      modulo.passi = voci.map(\.testo)
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
        sessione.cambiato()
        await sessione.ricalcolaPromemoria()
        sessione.mostra(.salvato)
        chiudi()
      } catch let problema as APIError {
        errore = problema.titolo
      } catch {
        errore = "Non salvata."
      }
    }
  }

  /// Un passo del procedimento mentre si scrive.
  struct PassoInModifica: Identifiable {
    let id = UUID()
    var testo: String
  }

  /// Il foglio per scegliere un ingrediente: solo il catalogo YAZIO, da due
  /// caratteri.
  struct SceltaAlimentoView: View {
    let scegli: (Alimento) -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var testo = ""
    @State private var risultati: [Alimento] = []
    @State private var cercando = false
    @State private var errore: String?

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
              Image(systemName: "magnifyingglass")
                .foregroundStyle(Stile.testoTenue)
              TextField("Cerca su YAZIO", text: $testo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Stile.testo)
              if cercando { ProgressView().controlSize(.small) }
            }
            .glassChip()
            if let errore {
              Text(errore)
                .font(.footnote)
                .foregroundStyle(Stile.brandTesto)
            }
            elenco
          }
          .padding(16)
        }
        .sfondoPagina()
        .navigationTitle("Ingrediente")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
      }
      .tint(Modulo.nutrizione.colore)
      .task(id: testo) { await cerca() }
    }

    @ViewBuilder
    private var elenco: some View {
      let cercato = testo.trimmingCharacters(in: .whitespaces).count >= 2
      VStack(alignment: .leading, spacing: 10) {
        if !cercato {
          Text("Scrivi almeno due lettere.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        } else if risultati.isEmpty {
          Text(cercando ? "Cerco." : "Nessun alimento su YAZIO.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        ForEach(risultati, id: \.chiave) { alimento in
          Button {
            scegli(alimento)
          } label: {
            VoceAlimento(alimento: alimento)
          }
          .buttonStyle(StilePremuto())
        }
      }
      .glassPanel()
    }

    private func cerca() async {
      let q = testo.trimmingCharacters(in: .whitespaces)
      guard q.count >= 2 else {
        risultati = []
        errore = nil
        return
      }
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      cercando = true
      defer { cercando = false }
      do {
        let trovati = try await sessione.client.cercaAlimenti(q, soloItalia: true)
        risultati = trovati.results.filter { $0.source == "yazio" }
        errore = trovati.unavailable.contains("yazio") ? "YAZIO non risponde" : nil
      } catch let problema as APIError {
        errore = problema.titolo
      } catch {
        errore = "Ricerca non riuscita"
      }
    }
  }

  /// Una riga dell'elenco: nome, marca e kcal per 100 g.
  struct VoceAlimento: View {
    let alimento: Alimento
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(alimento.name)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
          .lineLimit(2)
          .multilineTextAlignment(.leading)
        Text(alimento.sottotitolo(formati))
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
      }
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
    }
  }

  /// Un ingrediente con i grammi: il tastierino numerico e le kcal che si
  /// aggiornano mentre si scrive.
  struct RigaBozza: View {
    @Binding var riga: Bozza
    let togli: () -> Void
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(riga.alimento.name)
            .font(.subheadline)
            .foregroundStyle(Stile.testo)
            .lineLimit(1)
          Spacer()
          Button {
            togli()
          } label: {
            Image(systemName: "minus.circle")
              .foregroundStyle(Stile.testoTenue)
              .frame(width: 44, height: 44)
          }
          .buttonStyle(StilePremuto())
          .accessibilityLabel("Togli \(riga.alimento.name)")
        }
        HStack(spacing: 10) {
          TextField("0", text: $riga.testoGrammi)
            .keyboardType(.decimalPad)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(riga.valida ? Stile.testo : Stile.brandTesto)
            .frame(width: 80)
            .glassChip()
            .accessibilityLabel("Grammi di \(riga.alimento.name)")
          Text("g")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Text(formati.energia(riga.macro.kcal))
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
      }
    }
  }
#endif
