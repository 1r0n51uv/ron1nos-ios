#if canImport(SwiftUI)
  import SwiftUI

  @main
  struct Ron1nOSApp: App {
    @Environment(\.scenePhase) private var fase

    var body: some Scene {
      WindowGroup {
        RadiceView()
          .preferredColorScheme(.dark)
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
