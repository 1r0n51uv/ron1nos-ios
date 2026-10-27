#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Impostazioni › Moduli › Dieta (IOS-039): collegamento a YAZIO e
  /// obiettivo. Le credenziali YAZIO stanno solo sul server.
  struct ImpostazioniDietaView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var yazio: Carico<CollegamentoYazio> = .inCorso
    @State private var obiettivi: Carico<ObiettiviDieta> = .inCorso
    @State private var modulo = ModuloObiettivo()
    @State private var sincronizzo = false

    var body: some View {
      Form {
        sezioneYazio
        sezioneObiettivo
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Dieta")
      .refreshable { await carica() }
      .task { await carica() }
    }

    @ViewBuilder
    private var sezioneYazio: some View {
      Section {
        switch yazio {
        case .inCorso:
          Scheletro(righe: 2)
        case .spento:
          ModuloSpento()
        case .fallito(let errore):
          SezioneErrore(errore: errore)
        case .pronto(let collegamento):
          riga("Stato", collegamento.testoStato, rosso: collegamento.inErrore)
          if let errore = collegamento.error, collegamento.inErrore {
            Text(errore)
              .font(.footnote)
              .foregroundStyle(Stile.brand)
          }
          if collegamento.configured {
            riga(
              "Ultima sincronizzazione",
              collegamento.testoUltimaSincronizzazione(fuso: formati.fuso))
            if collegamento.queue > 0 {
              riga("In coda verso YAZIO", "\(collegamento.queue)")
            }
            Toggle(
              "Sincronizzazione",
              isOn: Binding(
                get: { collegamento.syncEnabled },
                set: { acceso in Task { await accendi(acceso) } }))
            Button(sincronizzo ? "Sincronizzo…" : "Sincronizza ora") {
              Task { await sincronizza() }
            }
            .disabled(sincronizzo || !collegamento.syncEnabled)
            NavigationLink(value: Pagina.senzaEquivalente) {
              HStack {
                Text("Senza equivalente YAZIO")
                Spacer()
                Text("\(collegamento.unmatched)")
                  .font(.system(.body, design: .monospaced))
                  .foregroundStyle(collegamento.unmatched > 0 ? Stile.brand : Stile.testoTenue)
              }
            }
          } else {
            Text("Le credenziali YAZIO si mettono nel file .env del server, mai nell'app.")
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
          }
        }
      } header: {
        Text("YAZIO")
      }
      .listRowBackground(Color.white.opacity(0.06))
    }

    @ViewBuilder
    private var sezioneObiettivo: some View {
      Section {
        switch obiettivi {
        case .inCorso:
          Scheletro(righe: 3)
        case .spento:
          ModuloSpento()
        case .fallito(let errore):
          SezioneErrore(errore: errore)
        case .pronto(let stato) where !stato.editable:
          if let corrente = stato.current {
            riga("Energia", formati.energia(corrente.kcal))
            riga("Proteine", "\(Formato.numero(corrente.protein)) g")
            riga("Carboidrati", "\(Formato.numero(corrente.carbs)) g")
            riga("Grassi", "\(Formato.numero(corrente.fat)) g")
            if let acqua = corrente.waterMl {
              riga("Acqua", "\(Formato.litri(Int(acqua))) l")
            }
          }
        case .pronto:
          campo("Kcal", $modulo.kcal)
          campo("Proteine · g", $modulo.proteine)
          campo("Carboidrati · g", $modulo.carboidrati)
          campo("Grassi · g", $modulo.grassi)
          campo("Acqua · ml, facoltativa", $modulo.acqua)
          Button("Salva da oggi") { Task { await salvaObiettivo() } }
            .fontWeight(.semibold)
            .disabled(!modulo.valido)
        }
      } header: {
        Text("Obiettivo")
      } footer: {
        if obiettivi.valore?.editable == false {
          Text("Arriva da YAZIO: si cambia nell'app YAZIO.")
        } else if let problema = modulo.problema, obiettivi.valore != nil {
          Text(problema)
        } else {
          Text("I giorni passati tengono l'obiettivo che avevano.")
        }
      }
      .listRowBackground(Color.white.opacity(0.06))
    }

    private func riga(_ titolo: String, _ valore: String, rosso: Bool = false) -> some View {
      HStack {
        Text(titolo)
          .foregroundStyle(Stile.testo)
        Spacer()
        Text(valore)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(rosso ? Stile.brand : Stile.testoTenue)
      }
      .accessibilityElement(children: .combine)
    }

    private func campo(_ titolo: String, _ testo: Binding<String>) -> some View {
      HStack {
        Text(titolo)
          .foregroundStyle(Stile.testo)
        Spacer()
        TextField("0", text: testo)
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .font(.system(.body, design: .monospaced))
          .frame(maxWidth: 120)
      }
    }

    private func carica() async {
      let client = sessione.client
      async let collegamento = Carico.da { try await client.collegamentoYazio() }
      async let letti = Carico.da { try await client.obiettiviDieta() }
      yazio = await collegamento
      obiettivi = await letti
      if let corrente = obiettivi.valore?.current { modulo = ModuloObiettivo(corrente) }
    }

    private func accendi(_ acceso: Bool) async {
      do {
        yazio = .pronto(try await sessione.client.sincronizzazioneYazio(acceso))
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }

    private func sincronizza() async {
      sincronizzo = true
      defer { sincronizzo = false }
      do {
        let collegamento = try await sessione.client.sincronizzaYazio()
        yazio = .pronto(collegamento)
        sessione.mostra(collegamento.inErrore ? Avviso("YAZIO non ha risposto") : Avviso("Sincronizzato"))
        let client = sessione.client
        obiettivi = await Carico.da { try await client.obiettiviDieta() }
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }

    private func salvaObiettivo() async {
      do {
        _ = try await sessione.client.nuovoObiettivo(modulo)
        sessione.mostra(.salvato)
        let client = sessione.client
        obiettivi = await Carico.da { try await client.obiettiviDieta() }
      } catch {
        let daYazio = error == .stato(409)
        sessione.mostra(daYazio ? Avviso("L'obiettivo arriva da YAZIO") : .nonSalvato)
      }
    }
  }

  /// Gli alimenti le cui righe non partono verso YAZIO (NUT-023): si
  /// abbinano a un prodotto YAZIO o si lasciano solo in ron1nOS.
  struct SenzaEquivalenteView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<[SenzaEquivalente]> = .inCorso
    @State private var abbina: SenzaEquivalente?

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
            Text("Ogni alimento ha il suo equivalente.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(Color.clear)
          }
          ForEach(alimenti) { alimento in
            Button {
              abbina = alimento
            } label: {
              VStack(alignment: .leading, spacing: 2) {
                Text(alimento.food.name)
                  .font(.subheadline)
                  .foregroundStyle(Stile.testo)
                Text(alimento.sottotitolo)
                  .font(.system(.footnote, design: .monospaced))
                  .foregroundStyle(Stile.testoTenue)
              }
              .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing) {
              Button("Solo ron1nOS") { Task { await usa(alimento.id, prodotto: nil) } }
            }
            .accessibilityAction(named: "Lascia solo in ron1nOS") {
              Task { await usa(alimento.id, prodotto: nil) }
            }
          }
        }
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Senza equivalente")
      .sheet(item: $abbina) { alimento in
        AbbinaYazioView(alimento: alimento) { prodotto in await usa(alimento.id, prodotto: prodotto) }
      }
      .refreshable { await carica() }
      .task { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.senzaEquivalente() }
    }

    private func usa(_ id: String, prodotto: String?) async {
      do {
        stato = .pronto(try await sessione.client.abbinaYazio(id, prodotto: prodotto))
        abbina = nil
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }
  }

  /// Cerca nel catalogo YAZIO il prodotto da abbinare.
  struct AbbinaYazioView: View {
    let alimento: SenzaEquivalente
    let scegli: (String?) async -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var testo = ""
    @State private var risultati: Carico<[Alimento]>?

    var body: some View {
      NavigationStack {
        List {
          if let risultati {
            switch risultati {
            case .inCorso:
              Scheletro(righe: 3).listRowBackground(Color.clear)
            case .spento:
              ModuloSpento().listRowBackground(Color.clear)
            case .fallito(let errore):
              SezioneErrore(errore: errore).listRowBackground(Color.clear)
            case .pronto(let prodotti):
              if prodotti.isEmpty {
                Text("Nessun prodotto.")
                  .foregroundStyle(Stile.testoTenue)
                  .listRowBackground(Color.clear)
              }
              ForEach(prodotti) { prodotto in
                Button {
                  Task { await scegli(prodotto.yazioProductId ?? prodotto.externalId) }
                } label: {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(prodotto.name)
                      .foregroundStyle(Stile.testo)
                    Text("\(formati.energia(prodotto.kcal)) per 100 g")
                      .font(.system(.footnote, design: .monospaced))
                      .foregroundStyle(Stile.testoTenue)
                  }
                }
                .listRowBackground(Color.clear)
              }
            }
          }
          Button("Lascia solo in ron1nOS") { Task { await scegli(nil) } }
            .foregroundStyle(Stile.testoTenue)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SfondoConAlone().ignoresSafeArea())
        .searchable(
          text: $testo, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca in YAZIO"
        )
        .onSubmit(of: .search) { Task { await cerca() } }
        .navigationTitle(alimento.food.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
        .task {
          testo = alimento.food.name
          await cerca()
        }
      }
      .tint(Stile.brand)
    }

    private func cerca() async {
      let parole = testo.trimmingCharacters(in: .whitespaces)
      guard !parole.isEmpty else { return }
      risultati = .inCorso
      let client = sessione.client
      risultati = await Carico.da { try await client.prodottiYazio(parole) }
    }
  }
#endif
