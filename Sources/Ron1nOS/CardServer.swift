#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Server, mezza larghezza nella Home: CPU, RAM e disco come tre anelli,
  /// rossi oltre l'80%, poi temperatura e da quanto è acceso.
  struct CardServer: View {
    let carico: Carico<StatoServer>

    var body: some View {
      Card(titolo: "Server", modulo: .server, carico: carico) { stato in
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 0) {
            ForEach(stato.risorse, id: \.nome) { risorsa in
              VStack(spacing: 6) {
                Anello(
                  valore: risorsa.valore, tinta: Modulo.server.colore, spessore: 5, segnale: risorsa.segnale
                ) {
                  Text(risorsa.testo.replacingOccurrences(of: "%", with: ""))
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(risorsa.segnale ? Stile.brandTesto : Stile.testo)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                }
                .frame(width: 42, height: 42)
                Text(risorsa.nome)
                  .font(.caption2.weight(.medium))
                  .foregroundStyle(Stile.testoTenue)
              }
              .frame(maxWidth: .infinity)
              .accessibilityElement(children: .ignore)
              .accessibilityLabel("\(risorsa.nome) \(risorsa.testo)")
            }
          }
          if let caldo = stato.caldo {
            Pillola(testo: caldo, tono: .alert)
          } else {
            Text(stato.temperaturaEUptime)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
        }
      }
    }
  }
#endif
