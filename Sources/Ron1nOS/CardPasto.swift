#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il pasto di adesso nella Home (IOS-036, IOS-043): quello dello slot che
  /// corrisponde all'ora. La foto del piatto in grande con il nome sopra, la
  /// spunta a portata di pollice e sotto l'anello delle kcal del giorno.
  struct CardPasto: View {
    let carico: Carico<GiornoDieta>
    /// Lo slot dell'ora corrente.
    let slot: String
    @Environment(\.formati) private var formati
    /// Si tocca `Mangiato`: l'id del piano.
    let conferma: (String) -> Void
    /// Si apre la pagina Nutrizione.
    let apri: () -> Void

    private let verde = Modulo.nutrizione.colore

    var body: some View {
      if carico != .spento {
        VStack(alignment: .leading, spacing: 12) {
          IntestazioneCard(
            titolo: GiornoDieta.nomiSlot[slot] ?? "Pasto",
            simbolo: GiornoDieta.simboliSlot[slot] ?? "fork.knife",
            tinta: verde
          ) {
            Apri(titolo: "Nutrizione", azione: apri)
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
        .glassPanel(tinta: verde)
      }
    }

    @ViewBuilder
    private func contenuto(_ giorno: GiornoDieta) -> some View {
      let pasto = giorno.slotInOrdine.first { $0.slot == slot }
      let vista = pasto?.vista(giorno: giorno.date, oggi: giorno.date) ?? .vuoto
      VStack(alignment: .leading, spacing: 14) {
        if let pasto, vista != .vuoto, let nome = pasto.planned?.recipeName ?? pasto.elenco {
          piatto(pasto, nome: nome, vista: vista)
        } else {
          Text("Niente in programma per adesso.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        riepilogo(giorno)
      }
    }

    /// Foto con il nome sopra, o solo il nome se la foto non c'è; la spunta
    /// sempre a destra.
    @ViewBuilder
    private func piatto(_ pasto: SlotGiorno, nome: String, vista: VistaPasto) -> some View {
      let spunta = Group {
        if vista == .mangiato {
          PulsanteMangiato(mangiato: true, abilitato: false) {}
        } else if vista == .pianificato, let id = pasto.planned?.id {
          PulsanteMangiato(mangiato: false) { conferma(id) }
        }
      }
      if let immagine = pasto.planned?.recipeImage {
        ZStack(alignment: .bottomLeading) {
          FotoRicetta(indirizzo: immagine, forma: .fascia)
          LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous))
            .allowsHitTesting(false)
          HStack(alignment: .bottom, spacing: 12) {
            nomeEKcal(nome, kcal: pasto.kcal)
            Spacer(minLength: 8)
            spunta
          }
          .padding(12)
        }
      } else {
        HStack(spacing: 12) {
          nomeEKcal(nome, kcal: pasto.kcal)
          Spacer(minLength: 8)
          spunta
        }
      }
    }

    private func nomeEKcal(_ nome: String, kcal: Double?) -> some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(nome)
          .font(.headline)
          .foregroundStyle(Stile.testo)
          .lineLimit(2)
          .shadow(color: .black.opacity(0.5), radius: 6)
        Text(formati.energia(kcal ?? 0))
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(Stile.testo.opacity(0.8))
      }
      .accessibilityElement(children: .combine)
    }

    /// L'anello delle kcal del giorno e quanto manca.
    @ViewBuilder
    private func riepilogo(_ giorno: GiornoDieta) -> some View {
      if giorno.kcalObiettivo != nil {
        HStack(spacing: 12) {
          Anello(valore: giorno.avanzamento ?? 0, tinta: verde, spessore: 5, segnale: giorno.oltre) {
            Image(systemName: "flame.fill")
              .font(.caption)
              .foregroundStyle(giorno.oltre ? Stile.brandTesto : verde)
          }
          .frame(width: 36, height: 36)
          VStack(alignment: .leading, spacing: 2) {
            Text(giorno.testoEnergia(formati))
              .font(.system(.footnote, design: .monospaced).weight(.medium))
              .foregroundStyle(Stile.testo)
              .contentTransition(.numericText())
            if let rimanenti = giorno.testoRimanenti(formati) {
              Text(rimanenti)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(giorno.oltre ? Stile.brandTesto : Stile.testoTenue)
            }
          }
        }
        .accessibilityElement(children: .combine)
      }
    }
  }
#endif
