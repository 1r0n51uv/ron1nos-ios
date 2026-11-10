#if canImport(SwiftUI)
  import SwiftUI

  /// L'app ha due pagine: Home e Impostazioni, nella barra in basso.
  struct RadiceView: View {
    @StateObject private var sessione = Sessione.condivisa

    var body: some View {
      TabView {
        NavigationStack { HomeView() }
          .tabItem { Label("Home", systemImage: "square.grid.2x2") }
        NavigationStack { ImpostazioniView() }
          .tabItem { Label("Impostazioni", systemImage: "gearshape") }
      }
      .tint(Stile.brand)
      .environmentObject(sessione)
    }
  }
#endif
