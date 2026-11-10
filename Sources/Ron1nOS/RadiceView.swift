#if canImport(SwiftUI)
  import SwiftUI

  /// L'app ha tre pagine nella barra in basso: Home, Torrent e Impostazioni.
  struct RadiceView: View {
    @StateObject private var sessione = Sessione.condivisa

    var body: some View {
      TabView(selection: $sessione.scheda) {
        NavigationStack { HomeView() }
          .tabItem { Label("Home", systemImage: "square.grid.2x2") }
          .tag(Scheda.home)
        NavigationStack { TorrentView() }
          .tabItem { Label("Torrent", systemImage: "arrow.down.circle") }
          .tag(Scheda.torrent)
        NavigationStack { ImpostazioniView() }
          .tabItem { Label("Impostazioni", systemImage: "gearshape") }
          .tag(Scheda.impostazioni)
      }
      .tint(Stile.brand)
      .overlay(alignment: .bottom) {
        if let avviso = sessione.avviso {
          VistaAvviso(avviso: avviso) { sessione.eseguiAvviso() }
            .padding(.bottom, 64)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .animation(.easeOut(duration: 0.2), value: sessione.avviso)
      .sheet(item: $sessione.torrentInArrivo) { partenza in
        AggiungiTorrentView(partenza: partenza)
          .environmentObject(sessione)
      }
      .environmentObject(sessione)
    }
  }
#endif
