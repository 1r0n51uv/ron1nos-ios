#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Dieta di oggi (IOS-006, `nutrition.summary`): kcal mangiate sulla
  /// quota del giorno, la barra e, dalla misura grande, i tre macro.
  struct CardDieta: View {
    let carico: Carico<GiornoDieta>
    var misura: Misura?
    /// Le macro mostrate (opzione `macros` del widget).
    var macro = ["protein", "carbs", "fat"]
    @Environment(\.formati) private var formati

    var body: some View {
      Card(titolo: "Dieta · oggi", carico: carico, riempi: misura != nil) { giorno in
        VStack(alignment: .leading, spacing: 10) {
          Text(giorno.testoEnergia(formati))
            .font(.system(misura == .small ? .headline : .title2, design: .monospaced).weight(.semibold))
            .foregroundStyle(Stile.testo)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
          if let avanzamento = giorno.avanzamento {
            Barra(valore: avanzamento, segnale: giorno.oltre)
          }
          if let rimanenti = giorno.testoRimanenti(formati) {
            Text(rimanenti)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(giorno.oltre ? Stile.brand : Stile.testoTenue)
          }
          if misura == nil || misura == .large {
            ForEach(giorno.macro.filter { macro.contains($0.chiave) }, id: \.nome) { riga in
              RigaValore(nome: riga.nome, valore: riga.testo)
            }
          }
        }
      }
    }
  }
#endif
