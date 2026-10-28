#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

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

  private struct ChiaveAspetto: EnvironmentKey {
    static let defaultValue = Aspetto()
  }

  private struct ChiaveFormati: EnvironmentKey {
    static let defaultValue = Formati()
  }

  extension EnvironmentValues {
    /// Vetro e densità scelti nelle Impostazioni del sito (IOS-010).
    var aspetto: Aspetto {
      get { self[ChiaveAspetto.self] }
      set { self[ChiaveAspetto.self] = newValue }
    }

    /// Unità e fuso orario (IOS-010).
    var formati: Formati {
      get { self[ChiaveFormati.self] }
      set { self[ChiaveFormati.self] = newValue }
    }
  }

  /// Pannello quasi trasparente (IOS-003): un velo bianco, senza sfocatura, e
  /// il bordo di luce del vetro, più chiaro in alto a sinistra. Velo, luce e
  /// padding seguono vetro e densità (IOS-010). `tinta` colora il bordo:
  /// solo il rosso, come segnale.
  struct GlassPanel: ViewModifier {
    var tinta: Color?
    @Environment(\.aspetto) private var aspetto

    func body(content: Content) -> some View {
      let forma = RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous)
      let luce = tinta ?? Color.white
      let k = aspetto.luce
      return
        content
        .padding(aspetto.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(aspetto.velo), in: forma)
        .overlay(
          forma.strokeBorder(
            LinearGradient(
              colors: [luce.opacity(0.5 * k), luce.opacity(0.12 * k), luce.opacity(0.05 * k)],
              startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1)
        )
    }
  }

  /// Lo sfondo scelto sul sito (SET-003, IOS-010): le sfumature `brace`,
  /// `nebbia`, `grafite`, `nero` o l'immagine caricata, scurita come sul sito.
  /// Il vetro sul nero puro non mostra la rifrazione: per questo gli aloni.
  struct SfondoConAlone: View {
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      ZStack {
        Stile.sfondo
        switch sessione.preferenze.sfondo {
        case .brace:
          RadialGradient(
            colors: [Stile.brand.opacity(0.3), .clear], center: UnitPoint(x: 0.08, y: 0), startRadius: 0,
            endRadius: 420)
          RadialGradient(
            colors: [Stile.brand.opacity(0.16), .clear], center: UnitPoint(x: 1, y: 0.7), startRadius: 0,
            endRadius: 360)
          RadialGradient(
            colors: [Stile.foschia.opacity(0.2), .clear], center: UnitPoint(x: 0.4, y: 1.2), startRadius: 0,
            endRadius: 420)
        case .nebbia:
          RadialGradient(
            colors: [Stile.foschia.opacity(0.4), .clear], center: UnitPoint(x: 0.5, y: 1.2), startRadius: 0,
            endRadius: 600)
        case .grafite:
          LinearGradient(
            stops: [
              .init(color: Color(red: 20 / 255, green: 20 / 255, blue: 22 / 255), location: 0),
              .init(color: Stile.sfondo, location: 0.7),
            ], startPoint: UnitPoint(x: 0.3, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
        case .nero:
          Stile.sfondo
        case .image:
          if let immagine = sessione.immagineSfondo {
            GeometryReader { spazio in
              Image(uiImage: immagine)
                .resizable()
                .scaledToFill()
                .frame(width: spazio.size.width, height: spazio.size.height)
                .clipped()
            }
            Stile.sfondo.opacity(0.62)
          }
        }
      }
    }
  }

  extension View {
    func glassPanel(tinta: Color? = nil) -> some View { modifier(GlassPanel(tinta: tinta)) }

    /// Su iOS 26 la TabBar si riduce scorrendo in basso e torna intera
    /// scorrendo in su (IOS-009). Prima della 26 resta com'è.
    @ViewBuilder
    func riduciTabBarScorrendo() -> some View {
      if #available(iOS 26.0, *) {
        tabBarMinimizeBehavior(.onScrollDown)
      } else {
        self
      }
    }

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
