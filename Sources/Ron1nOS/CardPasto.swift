#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il pasto di adesso nella Home (IOS-036): quello dello slot che
  /// corrisponde all'ora, con la spunta, e sotto l'obiettivo del giorno e
  /// quanto manca.
  struct CardPasto: View {
    let carico: Carico<GiornoDieta>
    /// Lo slot dell'ora corrente.
    let slot: String
    @Environment(\.formati) private var formati
    /// Si tocca `Mangiato`: l'id del piano.
    let conferma: (String) -> Void
    /// Si apre la pagina Nutrizione.
    let apri: () -> Void

    var body: some View {
      if carico != .spento {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text(titolo)
              .font(.footnote.weight(.medium))
              .foregroundStyle(Stile.testoTenue)
            Spacer()
            Button(action: apri) {
              HStack(spacing: 4) {
                Text("Nutrizione")
                Image(systemName: "chevron.right")
              }
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
              .frame(minHeight: 32)
            }
            .buttonStyle(.plain)
          }
          switch carico {
          case .inCorso, .spento:
            Scheletro()
          case .pronto(let giorno):
            contenuto(giorno)
          case .fallito(let errore):
            SezioneErrore(errore: errore)
          }
        }
        .glassPanel()
      }
    }

    private var titolo: String { GiornoDieta.nomiSlot[slot] ?? "Pasto" }

    @ViewBuilder
    private func contenuto(_ giorno: GiornoDieta) -> some View {
      let pasto = giorno.slotInOrdine.first { $0.slot == slot }
      let vista = pasto?.vista(giorno: giorno.date, oggi: giorno.date) ?? .vuoto
      VStack(alignment: .leading, spacing: 10) {
        if let pasto, vista != .vuoto, let nome = nomePasto(pasto) {
          // La foto del piatto, ben visibile, in cima alla card.
          FotoRicetta(indirizzo: pasto.planned?.recipeImage, forma: .fascia)
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
              Text(nome)
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
                .lineLimit(2)
              Text(formati.energia(pasto.kcal ?? 0))
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
            }
            Spacer(minLength: 8)
            if vista == .mangiato {
              Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Stile.testo)
                .accessibilityLabel("Mangiato")
            } else if vista == .pianificato, let id = pasto.planned?.id {
              Button {
                conferma(id)
              } label: {
                Image(systemName: "checkmark").glassIcona()
              }
              .buttonStyle(.plain)
              .accessibilityLabel("Mangiato")
            }
          }
        } else {
          Text("Niente in programma")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        riepilogo(giorno)
      }
    }

    private func nomePasto(_ pasto: SlotGiorno) -> String? {
      pasto.planned?.recipeName ?? pasto.elenco
    }

    /// Obiettivo del giorno e quanto manca.
    @ViewBuilder
    private func riepilogo(_ giorno: GiornoDieta) -> some View {
      if giorno.kcalObiettivo != nil {
        VStack(alignment: .leading, spacing: 8) {
          if let avanzamento = giorno.avanzamento {
            Barra(valore: avanzamento, segnale: giorno.oltre)
          }
          Text(giorno.testoEnergia(formati))
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testo)
          if let rimanenti = giorno.testoRimanenti(formati) {
            Text(rimanenti)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(giorno.oltre ? Stile.brandTesto : Stile.testoTenue)
          }
        }
      }
    }
  }
#endif
