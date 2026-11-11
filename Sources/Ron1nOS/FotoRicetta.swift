#if canImport(SwiftUI)
  import SwiftUI

  /// La foto di una ricetta (IOS-038): quelle di YAZIO ne hanno una, quelle
  /// create qui no, e allora non si mostra niente. L'indirizzo è del CDN di
  /// YAZIO, già ridimensionato (684×558), quindi pesa circa 30 KB.
  struct FotoRicetta: View {
    enum Forma {
      /// Quadrata, accanto al nome.
      case miniatura
      /// A tutta larghezza, in cima alla ricetta.
      case copertina
    }

    let indirizzo: String?
    var forma = Forma.miniatura

    var body: some View {
      if let indirizzo, let url = URL(string: indirizzo) {
        AsyncImage(url: url) { fase in
          switch fase {
          case .success(let immagine):
            immagine.resizable().scaledToFill()
          case .failure:
            segnaposto(simbolo: "photo")
          default:
            segnaposto(simbolo: nil)
          }
        }
        .modifier(Dimensioni(forma: forma))
        .accessibilityHidden(true)
      }
    }

    private func segnaposto(simbolo: String?) -> some View {
      ZStack {
        Color.white.opacity(0.06)
        if let simbolo {
          Image(systemName: simbolo).foregroundStyle(Stile.testoTenue)
        }
      }
    }

    /// Misure e angoli della forma scelta.
    private struct Dimensioni: ViewModifier {
      let forma: Forma

      func body(content: Content) -> some View {
        switch forma {
        case .miniatura:
          content
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .copertina:
          content
            .frame(maxWidth: .infinity)
            .aspectRatio(684.0 / 558.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous))
        }
      }
    }
  }
#endif
