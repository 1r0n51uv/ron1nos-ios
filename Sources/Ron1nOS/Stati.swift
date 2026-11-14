#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Primo caricamento (IOS-012, IOS-044): righe grigie al posto dei dati,
  /// con un riflesso che le attraversa, così si vede che qualcosa arriva.
  /// Con Riduci movimento le righe respirano invece di scorrere.
  struct Scheletro: View {
    var righe = 3
    @State private var fase = false
    @Environment(\.accessibilityReduceMotion) private var ridotto

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        ForEach(0..<righe, id: \.self) { indice in
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(ridotto && fase ? 0.13 : 0.08))
            .frame(height: indice == 0 ? 22 : 12)
            .frame(maxWidth: indice == 0 ? 160 : indice == righe - 1 ? 220 : .infinity, alignment: .leading)
        }
      }
      .overlay {
        if !ridotto {
          GeometryReader { spazio in
            LinearGradient(
              colors: [.clear, Color.white.opacity(0.14), .clear], startPoint: .leading, endPoint: .trailing
            )
            .frame(width: spazio.size.width * 0.6)
            .offset(x: fase ? spazio.size.width : -spazio.size.width * 0.6)
          }
          .mask {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(0..<righe, id: \.self) { indice in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .frame(height: indice == 0 ? 22 : 12)
                  .frame(
                    maxWidth: indice == 0 ? 160 : indice == righe - 1 ? 220 : .infinity, alignment: .leading)
              }
            }
          }
          .allowsHitTesting(false)
        }
      }
      .onAppear {
        let animazione =
          ridotto
          ? Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true)
          : Animation.linear(duration: 1.3).repeatForever(autoreverses: false)
        withAnimation(animazione) { fase = true }
      }
      .accessibilityLabel("Caricamento")
    }
  }

  /// Un caricamento in corso dentro una pagina che ha già i dati: una
  /// pillola con lo spinner, che compare e sparisce con una molla.
  struct InAggiornamento: View {
    let attivo: Bool
    var testo = "Aggiorno"
    @Environment(\.modulo) private var modulo

    var body: some View {
      if attivo {
        HStack(spacing: 6) {
          ProgressView()
            .controlSize(.mini)
            .tint(modulo == .home ? Stile.brandTesto : modulo.colore)
          Text(testo)
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .foregroundStyle(Stile.testoTenue)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Stile.velo, in: Capsule())
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .accessibilityLabel("Aggiornamento in corso")
      }
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

  /// Il toast sopra la barra (IOS-012): l'esito di un'azione.
  struct VistaAvviso: View {
    let avviso: Avviso
    let azione: () -> Void
    @Environment(\.modulo) private var modulo

    var body: some View {
      HStack(spacing: 12) {
        Text(avviso.testo)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
        if let titolo = avviso.azione {
          Button(titolo, action: azione)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(modulo.colore)
        }
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .background(.ultraThinMaterial, in: Capsule())
      .background(Color.black.opacity(0.5), in: Capsule())
      .overlay(Capsule().strokeBorder(Stile.bordo))
      .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
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
