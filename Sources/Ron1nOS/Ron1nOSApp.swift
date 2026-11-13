#if canImport(SwiftUI)
  import SwiftUI

  @main
  struct Ron1nOSApp: App {
    /// Il delegato delle notifiche e i pulsanti dei promemoria vanno pronti
    /// all'avvio, anche quando iOS apre l'app solo per un pulsante: la
    /// sessione condivisa li imposta, quindi la si crea subito.
    init() {
      MainActor.assumeIsolated { _ = Sessione.condivisa }
    }

    var body: some Scene {
      WindowGroup {
        RadiceView()
          .preferredColorScheme(.dark)
          // Da Condividi o da Safari: un .torrent o un link magnet (IOS-076).
          .onOpenURL { url in Sessione.condivisa.apri(file: url) }
      }
      .backgroundTask(.appRefresh(NotificheTorrent.compito)) {
        await Sessione.condivisa.controllaTorrent()
      }
    }
  }
#endif
