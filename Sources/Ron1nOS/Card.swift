#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Una card della Home: intestazione con la tessera del modulo, poi il
  /// contenuto quando i dati ci sono. In caricamento mostra lo scheletro
  /// (IOS-012), in errore il titolo dell'errore e il codice. Un modulo spento
  /// non si mostra. Con `freccia` l'intestazione dice che la card si apre.
  struct Card<Valore: Equatable & Sendable, Contenuto: View>: View {
    let titolo: String
    let modulo: Modulo
    let carico: Carico<Valore>
    var freccia = false
    @ViewBuilder let contenuto: (Valore) -> Contenuto

    var body: some View {
      if carico != .spento {
        VStack(alignment: .leading, spacing: 12) {
          IntestazioneCard(titolo: titolo, simbolo: modulo.simbolo, tinta: modulo.colore) {
            if freccia {
              Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Stile.testoTenue)
            }
          }
          switch carico {
          case .inCorso, .spento:
            Scheletro(righe: 2)
          case .pronto(let valore):
            contenuto(valore)
          case .fallito(let errore):
            SezioneErrore(errore: errore)
          }
        }
        // Due card affiancate prendono la stessa altezza.
        .frame(maxHeight: .infinity, alignment: .top)
        .glassPanel()
      }
    }
  }
#endif
