#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Una card della home: titolo, poi il contenuto quando i dati ci sono.
  /// In caricamento mostra lo scheletro (IOS-012), in errore il titolo
  /// dell'errore in rosso e il codice. Un modulo spento non si mostra.
  struct Card<Valore: Equatable & Sendable, Contenuto: View>: View {
    let titolo: String
    let carico: Carico<Valore>
    @ViewBuilder let contenuto: (Valore) -> Contenuto

    var body: some View {
      if carico != .spento {
        VStack(alignment: .leading, spacing: 12) {
          Text(titolo)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Stile.testoTenue)
          switch carico {
          case .inCorso, .spento:
            Scheletro()
          case .pronto(let valore):
            contenuto(valore)
          case .fallito(let errore):
            SezioneErrore(errore: errore)
          }
        }
        .glassPanel()
      }
    }
  }

  /// Barra sottile da 0 a 1: bianca, rossa solo come segnale.
  struct Barra: View {
    let valore: Double
    var segnale = false

    var body: some View {
      GeometryReader { spazio in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.1))
          Capsule()
            .fill(segnale ? Stile.brand : Stile.testo)
            .frame(width: spazio.size.width * max(0, min(1, valore)))
        }
      }
      .frame(height: 4)
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
      }
    }
  }
#endif
