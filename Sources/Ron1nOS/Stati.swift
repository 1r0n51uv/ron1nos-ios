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

  /// La pagina di un modulo spento nelle Impostazioni (IOS-012), con il
  /// link per riaccenderlo.
  struct ModuloSpento: View {
    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("Modulo spento")
          .font(.headline)
          .foregroundStyle(Stile.testo)
        Text("Si riaccende in Impostazioni › Moduli.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        NavigationLink(value: Pagina.modulo(.impostazioni)) {
          Text("Apri Impostazioni")
        }
        .glassChip()
      }
      .glassPanel()
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

  /// Il toast sopra la TabBar (IOS-012).
  struct VistaAvviso: View {
    let avviso: Avviso
    let azione: () -> Void

    var body: some View {
      HStack(spacing: 14) {
        Text(avviso.testo)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
        if let titolo = avviso.azione {
          Button(titolo, action: azione)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Stile.brandTesto)
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .background(Color.black.opacity(0.7), in: Capsule())
      .overlay(Capsule().strokeBorder(Stile.bordo))
      .accessibilityElement(children: .combine)
      .accessibilityLabel(avviso.etichetta)
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
