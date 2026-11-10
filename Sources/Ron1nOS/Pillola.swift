#if canImport(SwiftUI)
  import SwiftUI

  /// La StatusPill del sito: `offline` grigia, `alert` rossa.
  struct Pillola: View {
    enum Tono { case offline, alert }

    let testo: String
    let tono: Tono

    var body: some View {
      HStack(spacing: 6) {
        Circle()
          .fill(tono == .alert ? Stile.brand : Stile.testoTenue)
          .frame(width: 6, height: 6)
        Text(testo)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(tono == .alert ? Stile.brandTesto : Stile.testoTenue)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(Color.white.opacity(0.06), in: Capsule())
      .overlay(Capsule().strokeBorder(tono == .alert ? Stile.brand.opacity(0.5) : Stile.bordo))
      .accessibilityElement(children: .combine)
    }
  }
#endif
