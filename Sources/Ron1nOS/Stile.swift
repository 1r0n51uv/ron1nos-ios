#if canImport(SwiftUI)
  import SwiftUI

  /// Token del design system ron1nOS (tokens.json): nero, vetro, un solo
  /// rosso usato come segnale.
  enum Stile {
    static let brand = Color(red: 1, green: 42 / 255, blue: 42 / 255)
    static let sfondo = Color.black
    static let testo = Color.white
    static let testoTenue = Color.white.opacity(0.55)
    static let bordo = Color.white.opacity(0.12)
  }

  /// Pannello in vetro, come `glass-panel` della dashboard web.
  struct GlassPanel: ViewModifier {
    func body(content: Content) -> some View {
      content
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Stile.bordo, lineWidth: 1))
    }
  }

  extension View {
    func glassPanel() -> some View { modifier(GlassPanel()) }
  }
#endif
