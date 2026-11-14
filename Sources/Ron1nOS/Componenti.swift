#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Un simbolo su una tessera piena nella tinta (IOS-043): dice di che cosa
  /// si parla prima di leggere il titolo.
  struct Tessera: View {
    let simbolo: String
    var tinta: Color
    var lato: CGFloat = 28

    var body: some View {
      RoundedRectangle(cornerRadius: lato * 0.3, style: .continuous)
        .fill(LinearGradient(colors: [tinta, tinta.opacity(0.78)], startPoint: .top, endPoint: .bottom))
        .frame(width: lato, height: lato)
        .overlay {
          Image(systemName: simbolo)
            .font(.system(size: lato * 0.5, weight: .semibold))
            .foregroundStyle(Stile.inchiostro)
        }
        .accessibilityHidden(true)
    }
  }

  /// L'intestazione di una card: tessera, titolo e, a destra, un'azione.
  struct IntestazioneCard<Destra: View>: View {
    let titolo: String
    let simbolo: String
    var tinta: Color
    @ViewBuilder var destra: () -> Destra

    var body: some View {
      HStack(spacing: 10) {
        Tessera(simbolo: simbolo, tinta: tinta, lato: 26)
        Text(titolo)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
          .lineLimit(1)
        Spacer(minLength: 8)
        destra()
      }
      .accessibilityElement(children: .contain)
    }
  }

  extension IntestazioneCard where Destra == EmptyView {
    init(titolo: String, simbolo: String, tinta: Color) {
      self.init(titolo: titolo, simbolo: simbolo, tinta: tinta) { EmptyView() }
    }
  }

  /// "Apri ›": il collegamento a destra di un'intestazione.
  struct Apri: View {
    let titolo: String
    let azione: () -> Void

    var body: some View {
      Button(action: azione) {
        HStack(spacing: 4) {
          Text(titolo)
          Image(systemName: "chevron.right").font(.caption.weight(.semibold))
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Stile.testoTenue)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(StilePremuto())
    }
  }

  /// Un anello da 0 a 1 che si riempie con una molla; rosso con `segnale`.
  struct Anello<Centro: View>: View {
    let valore: Double
    var tinta: Color
    var spessore: CGFloat = 6
    var segnale = false
    @ViewBuilder var centro: () -> Centro
    @State private var mostrato = 0.0
    @Environment(\.accessibilityReduceMotion) private var ridotto

    var body: some View {
      ZStack {
        Circle().stroke(tinta.opacity(0.16), lineWidth: spessore)
        Circle()
          .trim(from: 0, to: mostrato)
          .stroke(
            AngularGradient(
              colors: [colore.opacity(0.7), colore], center: .center, startAngle: .degrees(0),
              endAngle: .degrees(360 * max(mostrato, 0.01))),
            style: StrokeStyle(lineWidth: spessore, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
        centro()
      }
      .onAppear { anima(valore) }
      .onChange(of: valore) { _, nuovo in anima(nuovo) }
    }

    private var colore: Color { segnale ? Stile.brand : tinta }

    private func anima(_ nuovo: Double) {
      let fine = max(0, min(1, nuovo))
      if ridotto {
        mostrato = fine
      } else {
        withAnimation(Stile.riempimento) { mostrato = fine }
      }
    }
  }

  extension Anello where Centro == EmptyView {
    init(valore: Double, tinta: Color, spessore: CGFloat = 6, segnale: Bool = false) {
      self.init(valore: valore, tinta: tinta, spessore: spessore, segnale: segnale) { EmptyView() }
    }
  }

  /// Barra sottile da 0 a 1 nella tinta, rossa con `segnale`. Si riempie con
  /// una molla quando compare e quando cambia.
  struct Barra: View {
    let valore: Double
    var tinta: Color = Stile.testo
    var segnale = false
    var altezza: CGFloat = 6
    @State private var mostrato = 0.0
    @Environment(\.accessibilityReduceMotion) private var ridotto

    var body: some View {
      let colore = segnale ? Stile.brand : tinta
      GeometryReader { spazio in
        ZStack(alignment: .leading) {
          Capsule().fill(colore.opacity(0.16))
          Capsule()
            .fill(
              LinearGradient(
                colors: [colore.opacity(0.75), colore], startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: max(altezza, spazio.size.width * mostrato))
            .opacity(mostrato > 0 ? 1 : 0)
        }
      }
      .frame(height: altezza)
      .onAppear { anima(valore) }
      .onChange(of: valore) { _, nuovo in anima(nuovo) }
      .accessibilityHidden(true)
    }

    private func anima(_ nuovo: Double) {
      let fine = max(0, min(1, nuovo))
      if ridotto {
        mostrato = fine
      } else {
        withAnimation(Stile.riempimento) { mostrato = fine }
      }
    }
  }

  /// Nome a sinistra, valore in monospazio a destra.
  struct RigaValore: View {
    let nome: String
    let valore: String

    var body: some View {
      HStack {
        Text(nome)
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        Spacer()
        Text(valore)
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(Stile.testo)
          .contentTransition(.numericText())
      }
      .accessibilityElement(children: .combine)
    }
  }

  /// Un valore grande con la sua etichetta piccola sotto, in una tessera di
  /// vetro colorata: kcal e macro di una ricetta.
  struct Dato: View {
    let valore: String
    let etichetta: String
    var tinta: Color

    var body: some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(valore)
          .font(.system(.headline, design: .monospaced))
          .foregroundStyle(Stile.testo)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(etichetta)
          .font(.caption.weight(.medium))
          .foregroundStyle(tinta)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(
        tinta.opacity(0.12), in: RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous)
      )
      .accessibilityElement(children: .combine)
    }
  }

  /// La spunta di un pasto: un cerchio che si riempie di verde con un
  /// rimbalzo e una vibrazione. Toccata di nuovo, annulla.
  struct PulsanteMangiato: View {
    let mangiato: Bool
    var abilitato = true
    let azione: () -> Void

    var body: some View {
      let verde = Modulo.nutrizione.colore
      Button(action: azione) {
        ZStack {
          Circle().fill(mangiato ? verde : Stile.velo)
          Circle().strokeBorder(mangiato ? Color.clear : verde.opacity(0.7), lineWidth: 1.5)
          Image(systemName: "checkmark")
            .font(.body.weight(.bold))
            .foregroundStyle(mangiato ? Stile.inchiostro : verde)
            .symbolEffect(.bounce, value: mangiato)
        }
        .frame(width: 44, height: 44)
        .animation(Stile.mollaViva, value: mangiato)
      }
      .buttonStyle(StilePremuto())
      .disabled(!abilitato)
      .sensoryFeedback(.success, trigger: mangiato) { _, nuovo in nuovo }
      .accessibilityLabel(mangiato ? "Mangiato" : "Segna come mangiato")
      .accessibilityHint(mangiato && abilitato ? "Tocca per rimetterlo in programma" : "")
    }
  }

  /// Il tocco: si stringe appena sotto il dito e torna con una molla.
  struct StilePremuto: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .opacity(configuration.isPressed ? 0.88 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
  }

  /// La comparsa a cascata delle card: salgono di poco e si accendono, una
  /// dopo l'altra. Con Riduci movimento solo la dissolvenza.
  struct Comparsa: ViewModifier {
    let indice: Int
    @State private var visibile = false
    @Environment(\.accessibilityReduceMotion) private var ridotto

    func body(content: Content) -> some View {
      content
        .opacity(visibile ? 1 : 0)
        .offset(y: visibile || ridotto ? 0 : 16)
        .scaleEffect(visibile || ridotto ? 1 : 0.98, anchor: .top)
        .onAppear {
          guard !visibile else { return }
          withAnimation(Stile.molla.delay(Double(min(indice, 8)) * 0.05)) { visibile = true }
        }
    }
  }

  extension View {
    func comparsa(_ indice: Int) -> some View { modifier(Comparsa(indice: indice)) }

    /// La sorgente della transizione a zoom verso una pagina (iOS 18).
    @ViewBuilder
    func sorgenteZoom(_ id: String, in spazio: Namespace.ID) -> some View {
      if #available(iOS 18, *) {
        matchedTransitionSource(id: id, in: spazio)
      } else {
        self
      }
    }

    /// La pagina che si apre a zoom dalla sua sorgente (iOS 18).
    @ViewBuilder
    func destinazioneZoom(_ id: String, in spazio: Namespace.ID) -> some View {
      if #available(iOS 18, *) {
        navigationTransition(.zoom(sourceID: id, in: spazio))
      } else {
        self
      }
    }
  }

  /// Uno stato vuoto composto: tessera, titolo, cosa fare e, se c'è,
  /// l'azione che lo riempie.
  struct StatoVuoto<Azione: View>: View {
    let simbolo: String
    let titolo: String
    let testo: String
    var tinta: Color
    @ViewBuilder var azione: () -> Azione

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        Tessera(simbolo: simbolo, tinta: tinta, lato: 36)
        VStack(alignment: .leading, spacing: 4) {
          Text(titolo)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Stile.testo)
          Text(testo)
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        azione()
      }
      .glassPanel()
    }
  }

  extension StatoVuoto where Azione == EmptyView {
    init(simbolo: String, titolo: String, testo: String, tinta: Color) {
      self.init(simbolo: simbolo, titolo: titolo, testo: testo, tinta: tinta) { EmptyView() }
    }
  }
#endif
