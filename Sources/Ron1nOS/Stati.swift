#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Primo caricamento (IOS-012): righe grigie al posto dei dati, senza
  /// spinner a schermo intero.
  struct Scheletro: View {
    var righe = 3

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(0..<righe, id: \.self) { indice in
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .frame(height: indice == 0 ? 22 : 12)
            .frame(maxWidth: indice == 0 ? 160 : .infinity, alignment: .leading)
        }
      }
      .accessibilityLabel("Caricamento")
    }
  }

  /// Un errore dentro una sezione (IOS-002, IOS-012): titolo e codice in
  /// monospazio, senza bloccare il resto della pagina.
  struct SezioneErrore: View {
    let errore: APIError

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(errore.titolo)
          .font(.subheadline)
          .foregroundStyle(Stile.brandTesto)
        if let dettaglio = errore.dettaglio {
          Text(dettaglio)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
    }
  }

  /// Ripete `azione` ogni `secondi` finché la vista è visibile e l'app è in
  /// primo piano (IOS-012: Torrent e Server ogni 5 secondi).
  struct AggiornaOgni: ViewModifier {
    let secondi: Double
    let azione: @MainActor () async -> Void
    @Environment(\.scenePhase) private var fase

    func body(content: Content) -> some View {
      content.task(id: fase) {
        guard fase == .active else { return }
        while !Task.isCancelled {
          try? await Task.sleep(nanoseconds: UInt64(secondi * 1_000_000_000))
          if Task.isCancelled { break }
          await azione()
        }
      }
    }
  }

  extension View {
    func aggiornaOgni(_ secondi: Double, azione: @escaping @MainActor () async -> Void) -> some View {
      modifier(AggiornaOgni(secondi: secondi, azione: azione))
    }
  }
#endif
