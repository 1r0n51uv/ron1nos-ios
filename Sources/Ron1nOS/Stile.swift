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

  /// Pannello quasi trasparente (IOS-003): un velo bianco al 6%, senza
  /// sfocatura, e il bordo di luce del vetro, più chiaro in alto a sinistra. `tinta` colora il bordo:
  /// solo il rosso, come segnale.
  struct GlassPanel: ViewModifier {
    var tinta: Color?

    func body(content: Content) -> some View {
      let forma = RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous)
      let luce = tinta ?? Color.white
      return
        content
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: forma)
        .overlay(
          forma.strokeBorder(
            LinearGradient(
              colors: [luce.opacity(0.5), luce.opacity(0.12), luce.opacity(0.05)],
              startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1)
        )
    }
  }

  /// Nero con due aloni appena visibili: senza niente dietro, il vetro sul
  /// nero puro non mostra la rifrazione.
  struct SfondoConAlone: View {
    var body: some View {
      ZStack {
        Stile.sfondo
        RadialGradient(
          colors: [Color.white.opacity(0.14), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
        RadialGradient(
          colors: [Color.white.opacity(0.08), .clear], center: .bottomLeading, startRadius: 0, endRadius: 360)
      }
    }
  }

  extension View {
    func glassPanel(tinta: Color? = nil) -> some View { modifier(GlassPanel(tinta: tinta)) }

    /// Pulsante a capsula con lo stesso velo delle card.
    func glassChip() -> some View {
      font(.subheadline.weight(.medium))
        .foregroundStyle(Stile.testo)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(Stile.bordo))
    }
  }
#endif
