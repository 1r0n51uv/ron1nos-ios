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

  /// L'app ha quattro pagine: Home, Nutrizione, Torrent e Impostazioni. Le
  /// apre la barra fluttuante di vetro in basso (IOS-044), che prende il
  /// posto di quella di sistema; toccare di nuovo la scheda attiva torna
  /// alla sua prima pagina.
  struct RadiceView: View {
    @StateObject private var sessione = Sessione.condivisa
    @Environment(\.scenePhase) private var fase
    /// Cresce quando si ritocca una scheda: la sua pila riparte da capo.
    @State private var radici: [Scheda: Int] = [:]

    var body: some View {
      TabView(selection: $sessione.scheda) {
        scheda(.home) { HomeView() }
        scheda(.nutrizione) { NutrizioneView() }
        scheda(.torrent) { TorrentView() }
        scheda(.impostazioni) { ImpostazioniView() }
      }
      .tint(sessione.scheda.modulo.colore)
      .overlay(alignment: .bottom) {
        BarraSchede(scheda: $sessione.scheda) { voce in
          withAnimation(Stile.molla) { radici[voce, default: 0] += 1 }
        }
        .padding(.bottom, 2)
        .ignoresSafeArea(.keyboard)
      }
      .sensoryFeedback(.selection, trigger: sessione.scheda)
      .overlay(alignment: .bottom) {
        if let avviso = sessione.avviso {
          VistaAvviso(avviso: avviso) { sessione.eseguiAvviso() }
            .environment(\.modulo, sessione.scheda.modulo)
            .padding(.bottom, BarraSchede.altezza + 76)
            .transition(
              .move(edge: .bottom).combined(with: .opacity).combined(
                with: .scale(scale: 0.9, anchor: .bottom)))
        }
      }
      .animation(Stile.mollaViva, value: sessione.avviso)
      .sheet(item: $sessione.torrentInArrivo) { partenza in
        AggiungiTorrentView(partenza: partenza)
          .environmentObject(sessione)
          .environment(\.modulo, .torrent)
          .buttonStyle(StilePremuto())
      }
      .buttonStyle(StilePremuto())
      .environmentObject(sessione)
      .environment(\.formati, sessione.formati)
      .preferredColorScheme(.dark)
      .task { await sessione.aggiornaPreferenze() }
      .onChange(of: fase) { _, nuova in
        // A ogni apertura i promemoria dei pasti si rifanno.
        if nuova == .active { Task { await sessione.ricalcolaPromemoria() } }
      }
    }

    private func scheda<Pagina: View>(_ scheda: Scheda, @ViewBuilder pagina: () -> Pagina) -> some View {
      NavigationStack { pagina() }
        .id(radici[scheda, default: 0])
        // Lo spazio della barra fluttuante: le pagine scorrono sotto il vetro
        // ma il loro fondo e le loro azioni restano sopra.
        .safeAreaInset(edge: .bottom, spacing: 0) {
          Color.clear.frame(height: BarraSchede.altezza + 4)
        }
        .environment(\.modulo, scheda.modulo)
        .tint(scheda.modulo.colore)
        .toolbar(.hidden, for: .tabBar)
        .tag(scheda)
    }
  }
#endif
