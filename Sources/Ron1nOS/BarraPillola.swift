#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La TabBar dell'app (IOS-015): una pillola flottante staccata dai bordi,
  /// in Liquid Glass su iOS 26. La voce attiva ha una bolla di vetro e il
  /// rosso dei testi; le altre restano bianche.
  struct BarraPillola: View {
    let schede: [Scheda]
    @Binding var selezione: Scheda
    @Namespace private var bolla
    @Environment(\.accessibilityReduceMotion) private var riduciMovimento

    var body: some View {
      HStack(spacing: 0) {
        ForEach(schede, id: \.self) { scheda in
          voce(scheda)
        }
      }
      .padding(BarraSchede.interno)
      .frame(maxWidth: BarraSchede.larghezzaMassima)
      .frame(height: BarraSchede.altezza)
      .modifier(VetroPillola())
      .padding(.horizontal, BarraSchede.margine)
      .padding(.bottom, 4)
      .sensoryFeedback(.selection, trigger: selezione)
      .animation(riduciMovimento ? nil : .snappy(duration: 0.25), value: selezione)
    }

    private func voce(_ scheda: Scheda) -> some View {
      let attiva = scheda == selezione
      return Button {
        selezione = scheda
      } label: {
        VStack(spacing: 3) {
          Image(systemName: scheda.icona)
            .font(.system(size: 19, weight: attiva ? .semibold : .regular))
            .frame(height: 22)
          // Come la TabBar di sistema la misura è fissa: con il testo
          // grande la voce tenuta premuta si ingrandisce (Large Content
          // Viewer).
          Text(scheda.titolo)
            .font(.system(size: 10, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .foregroundStyle(attiva ? Stile.brandTesto : Stile.testo)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
          if attiva {
            Capsule()
              .fill(Color.white.opacity(0.12))
              .matchedGeometryEffect(id: "bolla", in: bolla)
          }
        }
        .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(scheda.titolo)
      .accessibilityAddTraits(attiva ? .isSelected : [])
      .accessibilityShowsLargeContentViewer {
        Label(scheda.titolo, systemImage: scheda.icona)
      }
    }
  }

  /// Il vetro della pillola: Liquid Glass su iOS 26, materiale sfocato
  /// prima. Con "Riduci trasparenza" un grigio pieno.
  private struct VetroPillola: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var riduciTrasparenza

    func body(content: Content) -> some View {
      if riduciTrasparenza {
        content
          .background(Color(white: 0.12), in: Capsule())
          .overlay(Capsule().strokeBorder(Stile.bordo))
      } else if #available(iOS 26.0, *) {
        content
          .glassEffect(.regular.interactive(), in: Capsule())
          .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
      } else {
        content
          .background(.ultraThinMaterial, in: Capsule())
          .overlay(Capsule().strokeBorder(Stile.bordo))
          .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
      }
    }
  }
#endif
