#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Dieta di oggi (IOS-006): kcal mangiate sulla quota del giorno, la
  /// barra e i tre macro.
  struct CardDieta: View {
    let carico: Carico<GiornoDieta>
    @Environment(\.formati) private var formati

    var body: some View {
      Card(titolo: "Dieta · oggi", carico: carico) { giorno in
        VStack(alignment: .leading, spacing: 10) {
          Text(giorno.testoEnergia(formati))
            .font(.system(.title2, design: .monospaced).weight(.semibold))
            .foregroundStyle(Stile.testo)
          if let avanzamento = giorno.avanzamento {
            Barra(valore: avanzamento, segnale: giorno.oltre)
          }
          if let rimanenti = giorno.testoRimanenti(formati) {
            Text(rimanenti)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(giorno.oltre ? Stile.brand : Stile.testoTenue)
          }
          ForEach(giorno.macro, id: \.nome) { riga in
            RigaValore(nome: riga.nome, valore: riga.testo)
          }
        }
      }
    }
  }
#endif
