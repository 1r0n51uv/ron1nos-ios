#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Una pagina dentro la pila di navigazione di una scheda.
  enum Pagina: Hashable {
    case modulo(Scheda)
    case accesso
  }

  /// La TabBar dell'app (IOS-009): Home, i primi tre moduli nell'ordine del
  /// sito e `Altro`. Su iOS 26 è il Liquid Glass di sistema e si riduce
  /// scorrendo in basso. Ogni scheda ha la sua pila; toccare la voce già
  /// attiva torna alla radice.
  struct RadiceView: View {
    @StateObject private var sessione = Sessione()
    @State private var selezione: Scheda = .home
    @State private var percorsi: [Scheda: [Pagina]] = [:]

    var body: some View {
      let navigazione = sessione.navigazione
      TabView(selection: selezioneConRitorno) {
        ForEach(navigazione.schede, id: \.self) { scheda in
          NavigationStack(path: percorso(scheda)) {
            radice(scheda)
              .navigationDestination(for: Pagina.self) { pagina in
                destinazione(pagina)
              }
          }
          .tabItem { Label(scheda.titolo, systemImage: scheda.icona) }
          .tag(scheda)
        }
      }
      .tint(Stile.brand)
      .riduciTabBarScorrendo()
      .environmentObject(sessione)
      .environment(\.aspetto, sessione.preferenze.appearance)
      .environment(\.formati, sessione.preferenze.formats)
      .task {
        primoAvvio()
        await sessione.aggiornaPreferenze()
      }
      .onChange(of: navigazione) { _, nuova in
        // Un modulo spento sparisce: se era aperto si torna alla Home.
        if !nuova.schede.contains(selezione) { selezione = .home }
        for (scheda, pila) in percorsi where !pila.allSatisfy({ visibile($0, in: nuova) }) {
          percorsi[scheda] = []
        }
      }
    }

    private var selezioneConRitorno: Binding<Scheda> {
      Binding(
        get: { selezione },
        set: { nuova in
          if nuova == selezione { percorsi[nuova] = [] }
          selezione = nuova
        })
    }

    private func percorso(_ scheda: Scheda) -> Binding<[Pagina]> {
      Binding(get: { percorsi[scheda] ?? [] }, set: { percorsi[scheda] = $0 })
    }

    private func visibile(_ pagina: Pagina, in navigazione: Navigazione) -> Bool {
      if case .modulo(let scheda) = pagina { return navigazione.contiene(scheda) }
      return true
    }

    /// Al primo avvio, senza service token, l'app apre Impostazioni › Accesso.
    private func primoAvvio() {
      guard sessione.archivio.carica() == nil else { return }
      selezione = .altro
      percorsi[.altro] = [.modulo(.impostazioni), .accesso]
    }

    @ViewBuilder
    private func radice(_ scheda: Scheda) -> some View {
      switch scheda {
      case .home: StatoView()
      case .altro: AltroView()
      case .impostazioni: ImpostazioniView()
      default: PaginaInArrivo(scheda: scheda)
      }
    }

    @ViewBuilder
    private func destinazione(_ pagina: Pagina) -> some View {
      switch pagina {
      case .modulo(let scheda): radice(scheda)
      case .accesso:
        AccessoView(archivio: sessione.archivio, archivioToken: sessione.archivioToken) {
          sessione.credenzialiCambiate()
        }
      }
    }
  }

  /// `Altro` (IOS-009): i moduli che non stanno nella TabBar e Impostazioni.
  struct AltroView: View {
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      List(sessione.navigazione.altro, id: \.self) { scheda in
        NavigationLink(value: Pagina.modulo(scheda)) {
          Label(scheda.titolo, systemImage: scheda.icona)
            .foregroundStyle(Stile.testo)
        }
        .listRowBackground(Color.white.opacity(0.06))
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Altro")
    }
  }

  /// Impostazioni: per ora solo Accesso; le altre sezioni arrivano con
  /// IOS-090…094.
  struct ImpostazioniView: View {
    var body: some View {
      List {
        Section("Questo iPhone") {
          NavigationLink(value: Pagina.accesso) {
            Label("Accesso", systemImage: "key")
              .foregroundStyle(Stile.testo)
          }
          .listRowBackground(Color.white.opacity(0.06))
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Impostazioni")
    }
  }

  /// La pagina di un modulo che nell'app non c'è ancora.
  struct PaginaInArrivo: View {
    let scheda: Scheda

    var body: some View {
      ScrollView {
        Text("La pagina \(scheda.titolo) arriva con i prossimi aggiornamenti dell'app.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
          .glassPanel()
          .padding(.horizontal, 16)
          .padding(.top, 8)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(scheda.titolo)
    }
  }
#endif
