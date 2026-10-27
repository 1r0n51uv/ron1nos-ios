#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Una pagina dentro la pila di navigazione di una scheda.
  enum Pagina: Hashable {
    case modulo(Scheda)
    case accesso
    case notifiche
    /// Le pagine della Dieta sotto il giorno (IOS-030).
    case dieta(PaginaDieta)
    /// Il dettaglio di un pasto mangiato (IOS-031).
    case dettaglioPasto(giorno: String, slot: String)
    /// Gli alimenti personali (IOS-033), con un codice a barre da
    /// precompilare se si arriva dalla fotocamera.
    case alimenti(codice: String?)
    /// Il dettaglio di una ricetta (IOS-034).
    case ricetta(id: String)
    /// Un template settimanale (IOS-035).
    case template(id: String)
    /// Impostazioni › Moduli › Dieta: YAZIO e obiettivo (IOS-039).
    case impostazioniDieta
    /// Gli alimenti senza equivalente YAZIO (IOS-039).
    case senzaEquivalente
    /// Lo storico delle sessioni e il dettaglio di una (IOS-052).
    case storicoPalestra
    case sessione(id: String)
    /// Gli esercizi e la pagina di uno (IOS-053).
    case esercizi
    case esercizio(nome: String)
    /// Volume per gruppo muscolare (IOS-055).
    case volumeGruppi
    /// Il dettaglio di un documento (IOS-061).
    case documento(id: String)
    /// Impostazioni › Moduli › Documenti (IOS-063, IOS-064).
    case impostazioniDocumenti
  }

  /// La TabBar dell'app (IOS-009): Home, i primi tre moduli nell'ordine del
  /// sito e `Altro`. Su iOS 26 è il Liquid Glass di sistema e si riduce
  /// scorrendo in basso. Ogni scheda ha la sua pila; toccare la voce già
  /// attiva torna alla radice.
  struct RadiceView: View {
    @StateObject private var sessione = Sessione.condivisa
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
      .overlay(alignment: .bottom) {
        if let avviso = sessione.avviso {
          VistaAvviso(avviso: avviso) { sessione.eseguiAvviso() }
            .padding(.bottom, 96)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(.easeOut(duration: 0.2), value: sessione.avviso)
      .sheet(item: $sessione.csvInArrivo) { file in
        ImportCSVView(file: file)
          .environmentObject(sessione)
          .environment(\.formati, sessione.preferenze.formats)
      }
      .environmentObject(sessione)
      .environment(\.aspetto, sessione.preferenze.appearance)
      .environment(\.formati, sessione.preferenze.formats)
      .task {
        primoAvvio()
        await sessione.aggiornaPreferenze()
      }
      .onChange(of: sessione.daAprire) { _, scheda in
        guard let scheda else { return }
        sessione.daAprire = nil
        apri(scheda)
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

    /// Un widget toccato apre il suo modulo: nella sua scheda se sta nella
    /// TabBar, se no dentro `Altro`.
    private func apri(_ scheda: Scheda) {
      let navigazione = sessione.navigazione
      if navigazione.schede.contains(scheda) {
        percorsi[scheda] = []
        selezione = scheda
      } else if navigazione.altro.contains(scheda) {
        percorsi[.altro] = [.modulo(scheda)]
        selezione = .altro
      }
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
      case .home: HomeView()
      case .dieta: DietaView()
      case .palestra: PalestraView()
      case .documenti: DocumentiView()
      case .altro: AltroView()
      case .impostazioni: ImpostazioniView()
      default: PaginaInArrivo(scheda: scheda)
      }
    }

    /// Le pagine della Dieta sotto il giorno.
    @ViewBuilder
    private func paginaDieta(_ pagina: PaginaDieta) -> some View {
      switch pagina {
      case .ricette: RicetteView()
      case .template: TemplateView()
      case .spesa: SpesaView()
      case .andamento: AndamentoView()
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
      case .notifiche:
        NotificheView(centro: sessione.notifiche)
      case .dieta(let pagina):
        paginaDieta(pagina)
      case .dettaglioPasto(let giorno, let slot):
        DettaglioPastoView(giorno: giorno, slot: slot)
      case .alimenti(let codice):
        AlimentiPersonaliView(codice: codice)
      case .ricetta(let id):
        DettaglioRicettaView(id: id)
      case .template(let id):
        DettaglioTemplateView(id: id)
      case .impostazioniDieta:
        ImpostazioniDietaView()
      case .senzaEquivalente:
        SenzaEquivalenteView()
      case .storicoPalestra:
        StoricoView()
      case .sessione(let id):
        DettaglioSessioneView(id: id)
      case .esercizi:
        EserciziView()
      case .esercizio(let nome):
        DettaglioEsercizioView(nome: nome)
      case .volumeGruppi:
        VolumeGruppiView()
      case .documento(let id):
        DettaglioDocumentoView(id: id)
      case .impostazioniDocumenti:
        ImpostazioniDocumentiView()
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
        Section("Moduli") {
          NavigationLink(value: Pagina.impostazioniDieta) {
            Label("Dieta · Obiettivo e YAZIO", systemImage: "fork.knife")
              .foregroundStyle(Stile.testo)
          }
          .listRowBackground(Color.white.opacity(0.06))
          NavigationLink(value: Pagina.alimenti(codice: nil)) {
            Label("Dieta · Alimenti", systemImage: "carrot")
              .foregroundStyle(Stile.testo)
          }
          .listRowBackground(Color.white.opacity(0.06))
          NavigationLink(value: Pagina.impostazioniDocumenti) {
            Label("Documenti · Tipi", systemImage: "doc.text")
              .foregroundStyle(Stile.testo)
          }
          .listRowBackground(Color.white.opacity(0.06))
        }
        Section("Questo iPhone") {
          NavigationLink(value: Pagina.accesso) {
            Label("Accesso", systemImage: "key")
              .foregroundStyle(Stile.testo)
          }
          .listRowBackground(Color.white.opacity(0.06))
          NavigationLink(value: Pagina.notifiche) {
            Label("Notifiche", systemImage: "bell")
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
