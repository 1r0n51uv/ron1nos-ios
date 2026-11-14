#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  extension Scheda {
    /// Il modulo della scheda: ne dà la tinta alla barra e alla pagina.
    var modulo: Modulo {
      switch self {
      case .home: .home
      case .nutrizione: .nutrizione
      case .torrent: .torrent
      case .impostazioni: .impostazioni
      }
    }
  }

  /// L'app ha quattro pagine nella barra in basso: Home, Nutrizione, Torrent e
  /// Impostazioni. La voce attiva prende la tinta del suo modulo (IOS-043).
  struct RadiceView: View {
    @StateObject private var sessione = Sessione.condivisa
    @Environment(\.scenePhase) private var fase

    var body: some View {
      TabView(selection: $sessione.scheda) {
        scheda(.home, "Home") { HomeView() }
        scheda(.nutrizione, "Nutrizione") { NutrizioneView() }
        scheda(.torrent, "Torrent") { TorrentView() }
        scheda(.impostazioni, "Impostazioni") { ImpostazioniView() }
      }
      .tint(sessione.scheda.modulo.colore)
      .animation(.easeOut(duration: 0.2), value: sessione.scheda)
      .sensoryFeedback(.selection, trigger: sessione.scheda)
      .overlay(alignment: .bottom) {
        if let avviso = sessione.avviso {
          VistaAvviso(avviso: avviso) { sessione.eseguiAvviso() }
            .environment(\.modulo, sessione.scheda.modulo)
            .padding(.bottom, 64)
            .transition(
              .move(edge: .bottom).combined(with: .opacity).combined(
                with: .scale(scale: 0.95, anchor: .bottom)))
        }
      }
      .animation(Stile.molla, value: sessione.avviso)
      .sheet(item: $sessione.torrentInArrivo) { partenza in
        AggiungiTorrentView(partenza: partenza)
          .environmentObject(sessione)
          .environment(\.modulo, .torrent)
      }
      .environmentObject(sessione)
      .environment(\.formati, sessione.formati)
      .preferredColorScheme(.dark)
      .task { await sessione.aggiornaPreferenze() }
      .onChange(of: fase) { _, nuova in
        // A ogni apertura i promemoria dei pasti si rifanno.
        if nuova == .active { Task { await sessione.ricalcolaPromemoria() } }
      }
    }

    private func scheda<Pagina: View>(_ scheda: Scheda, _ titolo: String, @ViewBuilder pagina: () -> Pagina)
      -> some View
    {
      NavigationStack { pagina() }
        .environment(\.modulo, scheda.modulo)
        .tint(scheda.modulo.colore)
        .tabItem { Label(titolo, systemImage: scheda.modulo.simbolo) }
        .tag(scheda)
    }
  }
#endif
