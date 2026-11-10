#if canImport(SwiftUI)
  import SwiftUI

  @main
  struct Ron1nOSApp: App {
    var body: some Scene {
      WindowGroup {
        RadiceView()
          .preferredColorScheme(.dark)
      }
    }
  }
#endif
