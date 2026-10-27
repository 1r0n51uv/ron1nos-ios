#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  @main
  struct Ron1nOSApp: App {
    @Environment(\.scenePhase) private var fase

    init() {
      // Allegati e PDF rimasti da un'apertura chiusa male (IOS-061).
      FileTemporanei().svuota()
    }

    var body: some Scene {
      WindowGroup {
        RadiceView()
          .preferredColorScheme(.dark)
          // Da Liftin', Condividi → ron1nOS (IOS-051).
          .onOpenURL { url in Sessione.condivisa.apri(file: url) }
      }
      .onChange(of: fase) { _, nuova in
        // A ogni apertura le notifiche locali si ricalcolano (IOS-011).
        if nuova == .active {
          Task { await Sessione.condivisa.ricalcolaNotifiche() }
        }
      }
      .backgroundTask(.appRefresh(CentroNotifiche.compito)) {
        await Sessione.condivisa.ricalcolaNotifiche()
      }
    }
  }
#endif
