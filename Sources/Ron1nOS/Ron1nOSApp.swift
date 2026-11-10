#if canImport(SwiftUI)
  import SwiftUI

  @main
  struct Ron1nOSApp: App {
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
