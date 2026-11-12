#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il contenuto di un giorno (IOS-033), dentro la pagina Nutrizione: la
  /// data, obiettivo e quota rimasta, poi i cinque pasti con la ricetta e la
  /// spunta. Si spunta fino a oggi; un pasto futuro resta in programma.
  struct GiornoNutrizioneView: View {
    let giorno: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato = Carico<GiornoDieta>.inCorso
    @State private var inCorso = false
    /// Cresce a ogni spunta riuscita: dà la vibrazione di conferma.
    @State private var riuscite = 0

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          Text(titolo)
            .font(.title2.weight(.semibold))
            .foregroundStyle(Stile.testo)
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel()
          case .spento:
            Text("Il modulo Nutrizione è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel()
          case .pronto(let dieta):
            quota(dieta)
            ForEach(dieta.slotInOrdine) { slot in
              pasto(slot)
            }
          }
        }
        .padding(16)
      }
      .sensoryFeedback(.success, trigger: riuscite)
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    /// "Lunedì 26 ottobre".
    private var titolo: String {
      guard let data = Settimana.data(giorno) else { return giorno }
      return data.formatted(
        .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "it_IT")))
    }

    private var oggi: String { Settimana.oggi(fuso: formati.fuso) }

    // MARK: - Quota

    @ViewBuilder
    private func quota(_ dieta: GiornoDieta) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(dieta.testoEnergia(formati))
          .font(.system(.title2, design: .monospaced).weight(.semibold))
          .foregroundStyle(Stile.testo)
        if let avanzamento = dieta.avanzamento {
          Barra(valore: avanzamento, segnale: dieta.oltre)
        }
        if let rimanenti = dieta.testoRimanenti(formati) {
          Text(rimanenti)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(dieta.oltre ? Stile.brandTesto : Stile.testoTenue)
        }
        ForEach(dieta.macro, id: \.chiave) { riga in
          RigaValore(nome: riga.nome, valore: riga.testo)
        }
      }
      .glassPanel()
    }

    // MARK: - Pasti

    private func pasto(_ slot: SlotGiorno) -> some View {
      let vista = slot.vista(giorno: giorno, oggi: oggi)
      return VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text(slot.titolo)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Stile.testo)
          Spacer()
          Text(vista.testo)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
        if let piano = slot.planned {
          HStack(spacing: 8) {
            cosa(slot, piano: piano)
            if let id = piano.id, giorno <= oggi, vista != .vuoto {
              spunta(id: id, mangiato: slot.mangiato)
            }
          }
        } else if slot.mangiato, let elenco = slot.elenco {
          Text(elenco)
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        } else {
          Text("Niente in programma")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .glassPanel()
    }

    @ViewBuilder
    private func cosa(_ slot: SlotGiorno, piano: SlotGiorno.Pianificato) -> some View {
      let nome = piano.recipeName ?? piano.items.map(\.name).joined(separator: " · ")
      let riga = HStack(spacing: 14) {
        FotoRicetta(indirizzo: piano.recipeImage)
        VStack(alignment: .leading, spacing: 4) {
          Text(nome)
            .font(.subheadline)
            .foregroundStyle(Stile.testo)
            .multilineTextAlignment(.leading)
          Text(formati.energia(slot.kcal ?? piano.kcal))
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
      if let ricetta = piano.recipeId {
        NavigationLink {
          RicettaView(id: ricetta)
        } label: {
          HStack {
            riga
            Spacer()
            Image(systemName: "chevron.right")
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
          }
        }
        .buttonStyle(.plain)
      } else {
        HStack {
          riga
          Spacer(minLength: 0)
        }
      }
    }

    private func spunta(id: String, mangiato: Bool) -> some View {
      Button {
        Task { await conferma(id: id, mangiato: !mangiato) }
      } label: {
        Image(systemName: mangiato ? "arrow.uturn.backward" : "checkmark").glassIcona()
      }
      .buttonStyle(.plain)
      .accessibilityLabel(mangiato ? "Annulla" : "Mangiato")
      .disabled(inCorso)
    }

    // MARK: - Dati

    private func carica() async {
      let client = sessione.client
      let giorno = giorno
      stato = await Carico.da { try await client.dieta(giorno) }
    }

    private func conferma(id: String, mangiato: Bool) async {
      inCorso = true
      defer { inCorso = false }
      if await sessione.conferma(piano: id, mangiato: mangiato) {
        riuscite += 1
        sessione.mostra(Avviso(mangiato ? "Mangiato" : "Di nuovo in programma"))
      } else {
        sessione.mostra(.nonSalvato)
      }
    }
  }
#endif
