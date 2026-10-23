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
    static let raggio: CGFloat = 20
  }

  /// Pannello in vetro, come `glass-panel` della dashboard web. Da iOS 26 è
  /// Liquid Glass (IOS-003); prima resta il materiale sfocato con bordo.
  /// `tinta` colora appena il vetro: solo il rosso, come segnale.
  struct GlassPanel: ViewModifier {
    var tinta: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
      let forma = RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous)
      let card = content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
      if #available(iOS 26, macOS 26, *) {
        card.glassEffect(tinta.map { Glass.regular.tint($0.opacity(0.2)) } ?? .regular, in: forma)
      } else {
        card
          .background(.ultraThinMaterial, in: forma)
          .overlay(forma.stroke(Stile.bordo, lineWidth: 1))
      }
    }
  }

  /// Raccoglie più pannelli di vetro, perché iOS 26 li disegni insieme e li
  /// fonda quando si avvicinano. Prima di iOS 26 non fa niente.
  struct ContenitoreVetro<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
      if #available(iOS 26, macOS 26, *) {
        GlassEffectContainer(spacing: spacing) { content }
      } else {
        content
      }
    }
  }

  /// Nero con due aloni appena visibili: senza niente dietro, il vetro sul
  /// nero puro non mostra la rifrazione.
  struct SfondoConAlone: View {
    var body: some View {
      ZStack {
        Stile.sfondo
        RadialGradient(
          colors: [Color.white.opacity(0.10), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
        RadialGradient(
          colors: [Color.white.opacity(0.05), .clear], center: .bottomLeading, startRadius: 0, endRadius: 360)
      }
    }
  }

  extension View {
    func glassPanel(tinta: Color? = nil) -> some View { modifier(GlassPanel(tinta: tinta)) }
  }
#endif
