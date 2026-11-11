#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le ricette (IOS-034): quelle importate dai preferiti di YAZIO e quelle
  /// create qui. Un tocco apre la ricetta.
  struct RicetteView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato = Carico<[Ricetta]>.inCorso
    @State private var nuova = false
    @State private var importando = false
    @State private var cerca = ""

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel()
          case .spento:
            Text("Il modulo Nutrizione è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel()
          case .pronto(let ricette):
            let mostrate = cercando ? RicercaRicette.filtra(ricette, testo: cerca) : ricette
            if ricette.isEmpty {
              vuote
            } else if mostrate.isEmpty {
              nessunRisultato
            }
            ForEach(mostrate) { ricetta in
              NavigationLink {
                RicettaView(id: ricetta.id)
              } label: {
                riga(ricetta)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Ricette")
      .searchable(
        text: $cerca, placement: .navigationBarDrawer(displayMode: .always),
        prompt: "Cerca per nome o ingrediente"
      )
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Nuova ricetta", systemImage: "plus") { nuova = true }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("Importa da YAZIO", systemImage: "arrow.down.circle") {
              Task { await importa() }
            }
            .disabled(importando)
          } label: {
            Image(systemName: "ellipsis")
          }
          .accessibilityLabel("Altre azioni")
        }
      }
      .sheet(isPresented: $nuova) {
        RicettaFormView(ricetta: nil) { await carica() }
          .environmentObject(sessione)
          .environment(\.formati, formati)
      }
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    /// C'è del testo da cercare.
    private var cercando: Bool { !cerca.trimmingCharacters(in: .whitespaces).isEmpty }

    private var nessunRisultato: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Nessuna ricetta")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text("Non ne trovo con \"\(cerca)\" nel nome o tra gli ingredienti.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
    }

    private var vuote: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Nessuna ricetta")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text("Importa i preferiti di YAZIO dal menu, oppure creane una con il +.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
    }

    private func riga(_ ricetta: Ricetta) -> some View {
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
        Spacer()
        Image(systemName: "chevron.right")
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.ricette() }
    }

    private func importa() async {
      importando = true
      defer { importando = false }
      do {
        let esito = try await sessione.client.importaRicetteYazio()
        sessione.mostra(Avviso(esito.testo, durata: 4))
        await carica()
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore.titolo))
      } catch {
        sessione.mostra(Avviso("Import non riuscito"))
      }
    }
  }

  /// Una ricetta (IOS-034): totali, ingredienti, procedimento e note.
  struct RicettaView: View {
    let id: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var stato = Carico<Ricetta>.inCorso
    @State private var modifica = false
    @State private var eliminando = false

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel()
          case .spento:
            Text("Il modulo Nutrizione è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            if errore == .stato(404) {
              Text("La ricetta non c'è più.")
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
            } else {
              SezioneErrore(errore: errore).glassPanel()
            }
          case .pronto(let ricetta):
            FotoRicetta(indirizzo: ricetta.imageUrl, forma: .copertina)
            totali(ricetta)
            ingredienti(ricetta)
            if !ricetta.steps.isEmpty { procedimento(ricetta) }
            if let note = ricetta.notes, !note.isEmpty { noteDi(note) }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(stato.valore?.name ?? "Ricetta")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        if stato.valore != nil {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Button("Modifica", systemImage: "pencil") { modifica = true }
              Button("Elimina", systemImage: "trash", role: .destructive) { eliminando = true }
            } label: {
              Image(systemName: "ellipsis")
            }
            .accessibilityLabel("Modifica o elimina")
          }
        }
      }
      .confirmationDialog("Eliminare la ricetta?", isPresented: $eliminando, titleVisibility: .visible) {
        Button("Elimina", role: .destructive) { Task { await elimina() } }
        Button("Annulla", role: .cancel) {}
      } message: {
        Text("I pasti già programmati con questa ricetta restano.")
      }
      .sheet(isPresented: $modifica) {
        RicettaFormView(ricetta: stato.valore) { await carica() }
          .environmentObject(sessione)
          .environment(\.formati, formati)
      }
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    private func totali(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(formati.energia(ricetta.kcal))
          .font(.system(.title2, design: .monospaced).weight(.semibold))
          .foregroundStyle(Stile.testo)
        RigaValore(nome: "Proteine", valore: "\(Formato.numero(ricetta.protein)) g")
        RigaValore(nome: "Carboidrati", valore: "\(Formato.numero(ricetta.carbs)) g")
        RigaValore(nome: "Grassi", valore: "\(Formato.numero(ricetta.fat)) g")
        RigaValore(nome: "Peso", valore: "\(Formato.numero(ricetta.grams)) g")
        if ricetta.incompleta {
          Text("Qualche alimento non c'è più: i totali non lo contano.")
            .font(.footnote)
            .foregroundStyle(Stile.brandTesto)
        }
      }
      .glassPanel()
    }

    private func ingredienti(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Ingredienti")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        ForEach(ricetta.items) { riga in
          RigaValore(nome: riga.name, valore: "\(Formato.numero(riga.grams)) g")
        }
      }
      .glassPanel()
    }

    private func procedimento(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 14) {
        Text("Procedimento")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        ForEach(Array(ricetta.steps.enumerated()), id: \.offset) { numero, passo in
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(numero + 1)")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
              .frame(width: 20, alignment: .trailing)
            Text(passo)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
          }
        }
      }
      .glassPanel()
    }

    private func noteDi(_ note: String) -> some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Note")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text(note)
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
    }

    private func carica() async {
      let client = sessione.client
      let id = id
      let nuovo = await Carico.da { try await client.ricetta(id) }
      // Un aggiornamento fallito dopo il primo non cancella i dati.
      if case .fallito(let errore) = nuovo, errore != .stato(404), stato.valore != nil { return }
      stato = nuovo
    }

    private func elimina() async {
      do {
        try await sessione.client.eliminaRicetta(id)
        sessione.cambiato()
        sessione.mostra(Avviso("Eliminata"))
        chiudi()
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non riuscito"))
      }
    }
  }
#endif
