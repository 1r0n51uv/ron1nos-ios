#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Server (IOS-008): CPU, RAM e disco con una barra, rossa oltre il 90%,
  /// poi temperatura, da quanto è acceso e la rete.
  struct CardServer: View {
    let carico: Carico<StatoServer>
    var misura: Misura?

    var body: some View {
      Card(titolo: "Server", carico: carico, riempi: misura != nil) { stato in
        VStack(alignment: .leading, spacing: misura == .small ? 6 : 10) {
          ForEach(stato.risorse, id: \.nome) { risorsa in
            VStack(alignment: .leading, spacing: 6) {
              RigaValore(nome: risorsa.nome, valore: risorsa.testo)
              if misura != .small {
                Barra(valore: risorsa.valore, segnale: risorsa.segnale)
              }
            }
          }
          if misura == nil || misura == .large {
            Text(stato.riepilogo)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
    }
  }
#endif
