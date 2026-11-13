#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// La foto di una ricetta (IOS-038): quelle di YAZIO ne hanno una, quelle
  /// create qui no, e allora non si mostra niente. L'indirizzo è del CDN di
  /// YAZIO, già ridimensionato (684×558), quindi pesa circa 30 KB.
  struct FotoRicetta: View {
    enum Forma {
      /// Quadrata, accanto al nome.
      case miniatura
      /// A tutta larghezza, in cima alla ricetta.
      case copertina
      /// Una fascia larga e bassa, in cima a una card.
      case fascia
    }

    let indirizzo: String?
    var forma = Forma.miniatura

    var body: some View {
      if let indirizzo, APIClient.percorsoProprio(indirizzo) != nil {
        FotoDelServer(indirizzo: indirizzo)
          .modifier(Dimensioni(forma: forma))
          .accessibilityHidden(true)
      } else if let indirizzo, let url = URL(string: indirizzo) {
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
      FotoSegnaposto(simbolo: simbolo)
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
        case .fascia:
          content
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      }
    }
  }

  private struct FotoSegnaposto: View {
    let simbolo: String?

    var body: some View {
      ZStack {
        Color.white.opacity(0.06)
        if let simbolo {
          Image(systemName: simbolo).foregroundStyle(Stile.testoTenue)
        }
      }
    }
  }

  /// Una foto generata, che sta sul server di ron1nOS dietro l'accesso:
  /// `AsyncImage` non manda le credenziali, quindi si scarica con il client
  /// dell'app e si tiene in memoria (l'indirizzo cambia con la foto).
  private struct FotoDelServer: View {
    let indirizzo: String
    @EnvironmentObject private var sessione: Sessione
    @State private var immagine: UIImage?
    private static let memoria = NSCache<NSString, UIImage>()

    var body: some View {
      Group {
        if let immagine {
          Image(uiImage: immagine).resizable().scaledToFill()
        } else {
          FotoSegnaposto(simbolo: nonRiuscita ? "photo" : nil)
        }
      }
      .task(id: indirizzo) { await carica() }
    }

    @State private var nonRiuscita = false

    private func carica() async {
      if let trovata = Self.memoria.object(forKey: indirizzo as NSString) {
        immagine = trovata
        return
      }
      let client = sessione.client
      let indirizzo = indirizzo
      guard let dati = try? await client.foto(indirizzo), let letta = UIImage(data: dati) else {
        nonRiuscita = true
        return
      }
      Self.memoria.setObject(letta, forKey: indirizzo as NSString)
      immagine = letta
    }
  }
#endif
