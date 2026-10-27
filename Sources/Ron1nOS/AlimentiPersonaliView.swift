#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Gli alimenti personali (IOS-033, NUT-006): elenco, creazione,
  /// modifica ed eliminazione. Sta in Impostazioni › Moduli › Dieta, come
  /// sul sito.
  struct AlimentiPersonaliView: View {
    /// Un codice a barre da precompilare, quando si arriva dalla
    /// fotocamera (IOS-032).
    var codice: String?
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<[Alimento]> = .inCorso
    @State private var modulo: ModuloAlimento?

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 3).listRowBackground(Color.clear)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let errore):
          SezioneErrore(errore: errore).listRowBackground(Color.clear)
        case .pronto(let alimenti):
          if alimenti.isEmpty {
            Text("Nessun alimento personale.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(Color.clear)
          }
          ForEach(alimenti) { alimento in
            Button {
              modulo = ModuloAlimento(alimento)
            } label: {
              VoceAlimento(alimento: alimento)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
              Button("Elimina", role: .destructive) { Task { await elimina(alimento) } }
            }
            .accessibilityAction(named: "Elimina") { Task { await elimina(alimento) } }
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Alimenti")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            modulo = ModuloAlimento(codice: codice)
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Nuovo alimento")
        }
      }
      .sheet(item: $modulo) { aperto in
        ModuloAlimentoView(modulo: aperto) { await carica() }
      }
      .refreshable { await carica() }
      .task {
        await carica()
        // Dalla fotocamera con un codice sconosciuto si apre già il modulo.
        if let codice, !codice.isEmpty, modulo == nil { modulo = ModuloAlimento(codice: codice) }
      }
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.alimentiPersonali() }
    }

    private func elimina(_ alimento: Alimento) async {
      guard let id = alimento.id else { return }
      do {
        try await sessione.client.eliminaAlimento(id)
        await carica()
      } catch {
        sessione.mostra(.nonSalvato) { Task { await elimina(alimento) } }
      }
    }
  }

  /// Il modulo aperto: un alimento da correggere o uno nuovo.
  struct ModuloAlimento: Identifiable, Equatable {
    let id: String
    let alimento: Alimento?
    let campi: AlimentoPersonale

    init(_ alimento: Alimento) {
      id = alimento.id ?? alimento.name
      self.alimento = alimento
      campi = AlimentoPersonale(alimento)
    }

    init(codice: String?) {
      id = "nuovo"
      alimento = nil
      campi = AlimentoPersonale(codice: codice ?? "")
    }
  }

  /// Nome, kcal e macro per 100 g, più marca, porzione e codice a barre.
  struct ModuloAlimentoView: View {
    let modulo: ModuloAlimento
    let salvato: () async -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var campi = AlimentoPersonale()
    @State private var errore: String?
    @State private var salvando = false

    var body: some View {
      NavigationStack {
        Form {
          Section("Alimento") {
            TextField("Nome", text: $campi.nome)
            TextField("Marca", text: $campi.marca)
          }
          Section("Per 100 g") {
            numerico("kcal", $campi.kcal)
            numerico("Proteine", $campi.proteine)
            numerico("Carboidrati", $campi.carboidrati)
            numerico("Grassi", $campi.grassi)
            numerico("Caffeina in mg", $campi.caffeina)
          }
          Section("Facoltativi") {
            numerico("Porzione in g", $campi.porzione)
            TextField("Codice a barre", text: $campi.codice)
              .keyboardType(.numberPad)
          }
          if let errore {
            Text(errore)
              .font(.subheadline)
              .foregroundStyle(Stile.brand)
          }
        }
        .scrollContentBackground(.hidden)
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle(modulo.alimento == nil ? "Nuovo alimento" : "Alimento")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Salva") { Task { await salva() } }
              .fontWeight(.semibold)
              .disabled(salvando)
          }
        }
      }
      .tint(Stile.brand)
      .onAppear { campi = modulo.campi }
    }

    private func numerico(_ titolo: String, _ valore: Binding<String>) -> some View {
      HStack {
        Text(titolo)
        Spacer()
        TextField("0", text: valore)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .font(.system(.body, design: .monospaced))
          .frame(width: 90)
      }
    }

    private func salva() async {
      if let problema = campi.problema {
        errore = problema
        return
      }
      salvando = true
      defer { salvando = false }
      do {
        if let id = modulo.alimento?.id {
          _ = try await sessione.client.correggiAlimento(id, campi)
        } else {
          _ = try await sessione.client.creaAlimento(campi)
        }
        await salvato()
        sessione.mostra(.salvato)
        chiudi()
      } catch {
        errore = error == .stato(409) ? "Questo codice a barre è già di un altro alimento." : error.titolo
      }
    }
  }
#endif
