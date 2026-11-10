#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Token del design system ron1nOS (tokens.json): nero, vetro, un solo
  /// rosso usato come segnale.
  /// I valori stanno in `Palette` di Ron1nKit, dove i test ne provano il
  /// contrasto (IOS-014).
  enum Stile {
    /// Barre, bordi, punti, interruttori: elementi grafici.
    static let brand = Color(Palette.brand)
    /// Testi e simboli rossi: `brand` non arriva a 4,5:1 sul velo.
    static let brandTesto = Color(Palette.brandTesto)
    static let sfondo = Color(Palette.sfondo)
    static let foschia = Color(red: 110 / 255, green: 110 / 255, blue: 130 / 255)
    static let testo = Color.white
    static let testoTenue = Color.white.opacity(Palette.opacitaTestoTenue)
    static let bordo = Color.white.opacity(0.12)
    static let raggio: CGFloat = 20
  }

  extension Color {
    init(_ colore: ColoreRGB) {
      self.init(red: colore.rosso, green: colore.verde, blue: colore.blu)
    }
  }

  /// Pannello quasi trasparente (IOS-003): un velo bianco, senza sfocatura, e
  /// il bordo di luce del vetro, più chiaro in alto a sinistra. `tinta`
  /// colora il bordo: solo il rosso, come segnale.
  struct GlassPanel: ViewModifier {
    var tinta: Color?

    func body(content: Content) -> some View {
      let forma = RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous)
      let luce = tinta ?? Color.white
      return
        content
        .padding(16)
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

  /// Lo sfondo `brace` del sito: nero con aloni rossi e grigi. Il vetro sul
  /// nero puro non mostra la rifrazione: per questo gli aloni.
  struct SfondoConAlone: View {
    var body: some View {
      ZStack {
        Stile.sfondo
        RadialGradient(
          colors: [Stile.brand.opacity(0.3), .clear], center: UnitPoint(x: 0.08, y: 0), startRadius: 0,
          endRadius: 420)
        RadialGradient(
          colors: [Stile.brand.opacity(0.16), .clear], center: UnitPoint(x: 1, y: 0.7), startRadius: 0,
          endRadius: 360)
        RadialGradient(
          colors: [Stile.foschia.opacity(0.2), .clear], center: UnitPoint(x: 0.4, y: 1.2), startRadius: 0,
          endRadius: 420)
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
