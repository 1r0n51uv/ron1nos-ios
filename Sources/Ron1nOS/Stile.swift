#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Token del design system ron1nOS (IOS-043): fondo nero, vetro neutro e
  /// una tinta per modulo, che lo fa riconoscere. Il rosso resta il marchio e
  /// il segnale di allarme. I valori stanno in `Palette` di Ron1nKit, dove i
  /// test ne provano il contrasto (IOS-014).
  ///
  /// Forme: card a 20, tessere, foto e campi a 12, azioni a capsula.
  /// Spazi su una griglia da 4: 16 dal bordo e dentro le card, 12 tra le card.
  enum Stile {
    /// Barre, bordi, punti: elementi grafici del marchio e degli allarmi.
    static let brand = Color(Palette.brand)
    /// Testi e simboli rossi: `brand` non arriva a 4,5:1 sul velo.
    static let brandTesto = Color(Palette.brandTesto)
    static let sfondo = Color(Palette.sfondo)
    static let foschia = Color(red: 110 / 255, green: 110 / 255, blue: 130 / 255)
    static let testo = Color.white
    static let testoTenue = Color.white.opacity(Palette.opacitaTestoTenue)
    static let bordo = Color.white.opacity(0.12)
    /// Il nero dei simboli sopra una tinta piena.
    static let inchiostro = Color(Palette.inchiostro)
    static let velo = Color.white.opacity(Palette.velo)

    static let raggio: CGFloat = 20
    static let raggioPiccolo: CGFloat = 12
    static let margine: CGFloat = 16
    static let traCard: CGFloat = 12

    /// La molla di tutta l'app: tocchi, comparse e cambi di stato.
    static let molla = Animation.spring(response: 0.35, dampingFraction: 0.86)
    /// Una molla con un filo di rimbalzo, per le conferme.
    static let mollaViva = Animation.spring(response: 0.4, dampingFraction: 0.68)
    /// Il riempimento di barre e anelli.
    static let riempimento = Animation.spring(response: 0.9, dampingFraction: 0.9)
  }

  extension Color {
    init(_ colore: ColoreRGB) {
      self.init(red: colore.rosso, green: colore.verde, blue: colore.blu)
    }
  }

  extension Modulo {
    var colore: Color { Color(tinta) }
  }

  private struct ChiaveFormati: EnvironmentKey {
    static let defaultValue = Formati()
  }

  private struct ChiaveModulo: EnvironmentKey {
    static let defaultValue = Modulo.home
  }

  extension EnvironmentValues {
    /// Unità e fuso orario scelti nelle preferenze (SET-010).
    var formati: Formati {
      get { self[ChiaveFormati.self] }
      set { self[ChiaveFormati.self] = newValue }
    }

    /// Il modulo della pagina: ne colora lo sfondo e i componenti (IOS-043).
    var modulo: Modulo {
      get { self[ChiaveModulo.self] }
      set { self[ChiaveModulo.self] = newValue }
    }
  }

  /// Pannello di vetro (IOS-003): un velo bianco, senza sfocatura, e il bordo
  /// di luce, più chiaro in alto a sinistra. `tinta` colora il bordo e
  /// scalda appena il velo.
  struct GlassPanel: ViewModifier {
    var tinta: Color?
    var spazio: CGFloat = 16

    func body(content: Content) -> some View {
      let forma = RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous)
      let luce = tinta ?? Color.white
      return
        content
        .padding(spazio)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
          ZStack {
            forma.fill(Stile.velo)
            if let tinta {
              forma.fill(
                LinearGradient(
                  colors: [tinta.opacity(0.14), tinta.opacity(0.02)], startPoint: .topLeading,
                  endPoint: .bottomTrailing))
            }
          }
        }
        .overlay(
          forma.strokeBorder(
            LinearGradient(
              colors: [luce.opacity(0.45), luce.opacity(0.1), luce.opacity(0.04)],
              startPoint: .topLeading, endPoint: .bottomTrailing),
            lineWidth: 1)
        )
    }
  }

  /// Lo sfondo: nero con due aloni, uno nella tinta del modulo e uno rosso
  /// del marchio, che si spostano piano. Con Riduci movimento stanno fermi.
  struct SfondoConAlone: View {
    @Environment(\.modulo) private var modulo
    @Environment(\.accessibilityReduceMotion) private var ridotto
    @State private var fase = false

    var body: some View {
      let tinta = modulo == .home ? Stile.brand : modulo.colore
      ZStack {
        Stile.sfondo
        RadialGradient(
          colors: [tinta.opacity(0.2), .clear],
          center: UnitPoint(x: fase ? 0.25 : 0.0, y: fase ? 0.05 : -0.05),
          startRadius: 0, endRadius: 440)
        RadialGradient(
          colors: [Stile.brand.opacity(0.12), .clear], center: UnitPoint(x: 1, y: fase ? 0.55 : 0.8),
          startRadius: 0, endRadius: 360)
        RadialGradient(
          colors: [Stile.foschia.opacity(0.18), .clear], center: UnitPoint(x: fase ? 0.6 : 0.3, y: 1.2),
          startRadius: 0, endRadius: 420)
      }
      .animation(.easeInOut(duration: 0.6), value: modulo)
      .onAppear {
        guard !ridotto else { return }
        withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { fase = true }
      }
    }
  }

  extension View {
    func glassPanel(tinta: Color? = nil, spazio: CGFloat = 16) -> some View {
      modifier(GlassPanel(tinta: tinta, spazio: spazio))
    }

    /// Pulsante secondario a capsula, con lo stesso velo delle card.
    func glassChip() -> some View {
      font(.subheadline.weight(.medium))
        .foregroundStyle(Stile.testo)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(Stile.velo, in: Capsule())
        .overlay(Capsule().strokeBorder(Stile.bordo))
    }

    /// Un pulsante di sola icona, tondo, grande quanto basta per il dito.
    func glassIcona() -> some View {
      font(.body.weight(.medium))
        .foregroundStyle(Stile.testo)
        .frame(width: 44, height: 44)
        .background(Stile.velo, in: Circle())
        .overlay(Circle().strokeBorder(Stile.bordo))
    }

    /// L'azione principale: capsula piena nella tinta, testo nero.
    func pulsantePieno(_ tinta: Color) -> some View {
      font(.subheadline.weight(.semibold))
        .foregroundStyle(Stile.inchiostro)
        .padding(.horizontal, 20)
        .frame(minHeight: 48)
        .background(
          LinearGradient(colors: [tinta, tinta.opacity(0.82)], startPoint: .top, endPoint: .bottom),
          in: Capsule()
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
        .shadow(color: tinta.opacity(0.35), radius: 12, y: 4)
    }

    /// Lo sfondo della pagina nel colore del suo modulo.
    func sfondoPagina() -> some View {
      background(SfondoConAlone().ignoresSafeArea())
    }
  }
#endif
