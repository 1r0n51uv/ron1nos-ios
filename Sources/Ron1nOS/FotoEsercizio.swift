#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// Le foto degli esercizi già scaricate: il catalogo non cambia mai per
  /// lo stesso indirizzo, quindi bastano in memoria finché l'app è aperta.
  @MainActor
  final class ArchivioFoto {
    static let condiviso = ArchivioFoto()
    private let cache = NSCache<NSString, UIImage>()

    func foto(_ immagine: ImmagineEsercizio, client: APIClient) async -> UIImage? {
      let chiave = immagine.url as NSString
      if let pronta = cache.object(forKey: chiave) { return pronta }
      guard let dati = try? await client.fotoEsercizio(immagine), let foto = UIImage(data: dati) else {
        return nil
      }
      cache.setObject(foto, forKey: chiave)
      return foto
    }
  }

  /// La foto di un esercizio come sul sito: in bianco e nero, scurita.
  /// Senza foto, un riquadro di vetro con il manubrio.
  struct FotoEsercizio: View {
    let immagine: ImmagineEsercizio?
    var scurita = 0.35
    @EnvironmentObject private var sessione: Sessione
    @State private var foto: UIImage?

    var body: some View {
      ZStack {
        Color.white.opacity(0.06)
        if let foto {
          Image(uiImage: foto)
            .resizable()
            .scaledToFill()
            .grayscale(1)
            .overlay(Color.black.opacity(scurita))
        } else {
          Image(systemName: "dumbbell")
            .font(.title2)
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .clipped()
      .accessibilityHidden(true)
      .task(id: immagine?.url) {
        guard let immagine else {
          foto = nil
          return
        }
        foto = await ArchivioFoto.condiviso.foto(immagine, client: sessione.client)
      }
    }
  }
#endif
