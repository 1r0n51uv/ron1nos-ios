#if canImport(SwiftUI)
  import SwiftUI

  @main
  struct Ron1nOSApp: App {
    var body: some Scene {
      WindowGroup {
        StatoView()
          .preferredColorScheme(.dark)
      }
    }
  }
#endif
