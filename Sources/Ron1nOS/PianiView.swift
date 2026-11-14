#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// I piani (IOS-031): le settimane tipo. Un piano si programma da oggi
  /// fino a una data, o per la sola settimana; si crea e si corregge qui.
  struct PianiView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato = Carico<[TemplateSettimana]>.inCorso
    @State private var nuovo = false
    @State private var daModificare: TemplateSettimana?
    @State private var daProgrammare: TemplateSettimana?
    @State private var daEliminare: TemplateSettimana?

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 4).glassPanel().transition(.blurReplace)
          case .spento:
            Text("Il modulo Nutrizione è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel()
          case .pronto(let piani):
            if piani.isEmpty { vuoto }
            ForEach(Array(piani.enumerated()), id: \.element.id) { indice, piano in
              scheda(piano)
                .comparsa(indice)
            }
          }
        }
        .padding(.horizontal, Stile.margine)
        .padding(.bottom, 24)
      }
      .sfondoPagina()
      .navigationTitle("Piani")
      .azioniInAlto {
        AzioneBarra(titolo: "Nuovo piano", simbolo: "plus", principale: true) { nuovo = true }
      }
      .sheet(isPresented: $nuovo) {
        PianoFormView(piano: nil) { await carica() }
          .environmentObject(sessione)
      }
      .sheet(item: $daModificare) { piano in
        PianoFormView(piano: piano) { await carica() }
          .environmentObject(sessione)
      }
      .sheet(item: $daProgrammare) { piano in
        ProgrammaView(piano: piano)
          .environmentObject(sessione)
      }
      .confirmationDialog(
        "Eliminare il piano?", isPresented: eliminando, titleVisibility: .visible, presenting: daEliminare
      ) { piano in
        Button("Elimina", role: .destructive) { Task { await elimina(piano) } }
        Button("Annulla", role: .cancel) {}
      } message: { _ in
        Text("I pasti già programmati restano.")
      }
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    private var eliminando: Binding<Bool> {
      Binding(get: { daEliminare != nil }, set: { if !$0 { daEliminare = nil } })
    }

    private var vuoto: some View {
      StatoVuoto(
        simbolo: "calendar.badge.plus", titolo: "Nessun piano",
        testo: "Un piano è una settimana tipo: per ogni giorno scegli la ricetta di ogni pasto.",
        tinta: Modulo.nutrizione.colore)
    }

    private func scheda(_ piano: TemplateSettimana) -> some View {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 12) {
          Tessera(simbolo: "calendar", tinta: Modulo.nutrizione.colore, lato: 40)
          VStack(alignment: .leading, spacing: 2) {
            Text(piano.name)
              .font(.headline)
              .foregroundStyle(Stile.testo)
            Text(piano.sottotitolo)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
        HStack(spacing: 8) {
          Button {
            daProgrammare = piano
          } label: {
            Label("Programma", systemImage: "calendar.badge.clock")
          }
          .pulsantePieno(Modulo.nutrizione.colore)
          Button("Modifica") { daModificare = piano }
            .glassChip()
          Spacer()
          Button {
            daEliminare = piano
          } label: {
            Image(systemName: "trash")
              .foregroundStyle(Stile.testoTenue)
              .frame(width: 44, height: 44)
          }
          .buttonStyle(StilePremuto())
          .accessibilityLabel("Elimina \(piano.name)")
        }
        .buttonStyle(StilePremuto())
      }
      .glassPanel()
    }

    private func carica() async {
      let client = sessione.client
      let nuovo = await Carico.da { try await client.template() }
      withAnimation(Stile.molla) { stato = nuovo }
    }

    private func elimina(_ piano: TemplateSettimana) async {
      do {
        try await sessione.client.eliminaTemplate(piano.id)
        await carica()
        sessione.mostra(Avviso("Eliminato"))
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non riuscito"))
      }
    }
  }

  /// Il pasto di cui si sceglie la ricetta, per aprire il foglio.
  struct SlotScelto: Identifiable {
    let id: String
  }

  /// Creare o correggere un piano (IOS-031): il nome e, giorno per giorno, la
  /// ricetta di ogni pasto.
  struct PianoFormView: View {
    /// nil per un piano nuovo.
    let piano: TemplateSettimana?
    let salvato: () async -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var modulo = ModuloPiano()
    @State private var giorno = 1
    @State private var ricette: [Ricetta] = []
    @State private var sceltaSlot: SlotScelto?
    @State private var errore: String?
    @State private var salvando = false
    @Namespace private var selezione
    private let verde = Modulo.nutrizione.colore

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            TextField("Nome del piano", text: $modulo.nome)
              .foregroundStyle(Stile.testo)
              .glassChip()
            giorni
            VStack(alignment: .leading, spacing: 16) {
              ForEach(GiornoDieta.ordineSlot, id: \.self) { slot in
                casella(slot)
              }
            }
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
        .navigationTitle(piano == nil ? "Nuovo piano" : "Modifica piano")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
        .azioniInBasso {
          AzioneBarra(titolo: "Salva il piano", simbolo: "checkmark", principale: true, inCorso: salvando) {
            Task { await salva() }
          }
        }
      }
      .tint(Modulo.nutrizione.colore)
      .sheet(item: $sceltaSlot) { scelto in
        SceltaRicettaView(ricette: ricette) { id in
          modulo.ricette[.init(giorno: giorno, slot: scelto.id)] = id
          sceltaSlot = nil
        }
        .environmentObject(sessione)
        .environment(\.formati, sessione.formati)
      }
      .onAppear {
        if let piano { modulo = ModuloPiano(piano) }
      }
      .task { ricette = (try? await sessione.client.ricette()) ?? [] }
    }

    /// Le sette lettere dei giorni, con un puntino dove il giorno ha pasti.
    private var giorni: some View {
      HStack(spacing: 8) {
        ForEach(1...7, id: \.self) { numero in
          Button {
            giorno = numero
          } label: {
            VStack(spacing: 4) {
              Text(TemplateSettimana.lettere[numero - 1])
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
              Circle()
                .fill(haPasti(numero) ? (giorno == numero ? Stile.inchiostro : verde) : Color.clear)
                .frame(width: 4, height: 4)
            }
            .foregroundStyle(giorno == numero ? Stile.inchiostro : Stile.testo)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
              if giorno == numero {
                RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous)
                  .fill(verde)
                  .matchedGeometryEffect(id: "giorno", in: selezione)
              } else {
                RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous)
                  .fill(Stile.velo)
              }
            }
          }
          .buttonStyle(StilePremuto())
          .animation(Stile.molla, value: giorno)
          .accessibilityLabel(nomeGiorno(numero))
          .accessibilityAddTraits(giorno == numero ? .isSelected : [])
        }
      }
    }

    private func haPasti(_ numero: Int) -> Bool {
      modulo.ricette.keys.contains { $0.giorno == numero }
    }

    private func nomeGiorno(_ numero: Int) -> String {
      ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"][numero - 1]
    }

    private func casella(_ slot: String) -> some View {
      let chiave = ModuloPiano.Casella(giorno: giorno, slot: slot)
      let scelta = modulo.ricette[chiave].flatMap { id in ricette.first { $0.id == id } }
      return HStack(spacing: 12) {
        Tessera(
          simbolo: GiornoDieta.simboliSlot[slot] ?? "fork.knife",
          tinta: modulo.ricette[chiave] == nil ? Stile.testoTenue : verde, lato: 32)
        VStack(alignment: .leading, spacing: 2) {
          Text(GiornoDieta.nomiSlot[slot] ?? slot)
            .font(.caption)
            .foregroundStyle(Stile.testoTenue)
          Button {
            sceltaSlot = SlotScelto(id: slot)
          } label: {
            Text(scelta?.name ?? (modulo.ricette[chiave] == nil ? "Scegli una ricetta" : "Ricetta"))
              .font(.subheadline)
              .foregroundStyle(modulo.ricette[chiave] == nil ? Stile.testoTenue : Stile.testo)
              .multilineTextAlignment(.leading)
              .frame(minHeight: 44, alignment: .leading)
          }
          .buttonStyle(StilePremuto())
        }
        Spacer()
        if modulo.ricette[chiave] != nil {
          Button {
            modulo.ricette[chiave] = nil
          } label: {
            Image(systemName: "minus.circle")
              .foregroundStyle(Stile.testoTenue)
              .frame(width: 44, height: 44)
          }
          .buttonStyle(StilePremuto())
          .accessibilityLabel("Togli la ricetta")
        }
      }
    }

    private func salva() async {
      if let problema = modulo.problema {
        errore = problema
        return
      }
      salvando = true
      defer { salvando = false }
      do {
        if let id = piano?.id {
          _ = try await sessione.client.correggiPiano(id, modulo)
        } else {
          _ = try await sessione.client.creaPiano(modulo)
        }
        await salvato()
        sessione.mostra(.salvato)
        chiudi()
      } catch let problema as APIError {
        errore = problema.titolo
      } catch {
        errore = "Non salvato."
      }
    }
  }

  /// Il foglio per scegliere la ricetta di un pasto.
  struct SceltaRicettaView: View {
    let ricette: [Ricetta]
    let scegli: (String) -> Void
    @Environment(\.dismiss) private var chiudi
    @Environment(\.formati) private var formati

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            if ricette.isEmpty {
              Text("Nessuna ricetta: importa i preferiti di YAZIO o creane una dalla pagina Ricette.")
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
                .glassPanel()
            }
            ForEach(ricette) { ricetta in
              Button {
                scegli(ricetta.id)
              } label: {
                HStack(spacing: 14) {
                  FotoRicetta(indirizzo: ricetta.imageUrl)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(ricetta.name)
                      .font(.subheadline)
                      .foregroundStyle(Stile.testo)
                      .multilineTextAlignment(.leading)
                    Text(ricetta.sottotitolo(formati))
                      .font(.system(.footnote, design: .monospaced))
                      .foregroundStyle(Stile.testoTenue)
                  }
                  Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel()
              }
              .buttonStyle(StilePremuto())
            }
          }
          .padding(16)
        }
        .sfondoPagina()
        .navigationTitle("Ricetta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
      }
      .tint(Modulo.nutrizione.colore)
    }
  }

  /// `Programma` (IOS-031): da che giorno e fino a quando ripetere la
  /// settimana tipo.
  struct ProgrammaView: View {
    let piano: TemplateSettimana
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var da = Date()
    @State private var finoAUnaData = false
    @State private var fino = Date().addingTimeInterval(27 * 86_400)
    @State private var inCorso = false
    @State private var errore: String?

    var body: some View {
      NavigationStack {
        Form {
          Section {
            DatePicker("Da", selection: $da, displayedComponents: .date)
            Toggle("Fino a una data", isOn: $finoAUnaData)
              .tint(Modulo.nutrizione.colore)
            if finoAUnaData {
              DatePicker("Fino al", selection: $fino, in: da..., displayedComponents: .date)
            }
          } footer: {
            Text(
              finoAUnaData
                ? "La settimana tipo si ripete ogni settimana fino a quel giorno, al massimo un anno."
                : "Vale fino a domenica della settimana scelta."
            )
          }
          .listRowBackground(Color.white.opacity(0.06))
          Section {
            Text(
              "I pasti ancora in programma di quei giorni si rifanno con questo piano. Quelli mangiati e saltati restano."
            )
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
          }
          .listRowBackground(Color.clear)
          if let errore {
            Section {
              Text(errore)
                .font(.footnote)
                .foregroundStyle(Stile.brandTesto)
            }
            .listRowBackground(Color.clear)
          }
        }
        .environment(\.timeZone, formati.fuso)
        .scrollContentBackground(.hidden)
        .sfondoPagina()
        .navigationTitle(piano.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
        .azioniInBasso {
          AzioneBarra(
            titolo: "Programma", simbolo: "calendar.badge.clock", principale: true, inCorso: inCorso
          ) {
            Task { await programma() }
          }
        }
      }
      .tint(Modulo.nutrizione.colore)
    }

    private func programma() async {
      inCorso = true
      defer { inCorso = false }
      let inizio = Settimana.testo(da, fuso: formati.fuso)
      let fine = finoAUnaData ? Settimana.testo(fino, fuso: formati.fuso) : nil
      do {
        let esito = try await sessione.client.programma(piano.id, da: inizio, fino: fine)
        sessione.cambiato()
        sessione.mostra(Avviso(esito.testo))
        chiudi()
      } catch let problema as APIError {
        errore = problema.titolo
      } catch {
        errore = "Non programmato."
      }
    }
  }
#endif
