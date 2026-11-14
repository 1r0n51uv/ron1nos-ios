#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il contenuto di un giorno (IOS-033, IOS-043), dentro la pagina
  /// Nutrizione: l'anello delle kcal con i tre macro a colori, poi i cinque
  /// pasti con la foto e la spunta. Si spunta fino a oggi; un pasto futuro
  /// resta in programma.
  struct GiornoNutrizioneView: View {
    let giorno: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato = Carico<GiornoDieta>.inCorso
    @State private var inCorso = false
    @Namespace private var zoom

    private let verde = Modulo.nutrizione.colore

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel()
          case .spento:
            StatoVuoto(
              simbolo: "fork.knife", titolo: "Nutrizione spenta", testo: "Il modulo è spento su ron1nOS.",
              tinta: verde)
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel()
          case .pronto(let dieta):
            quota(dieta)
              .comparsa(0)
            ForEach(Array(dieta.slotInOrdine.enumerated()), id: \.element.id) { indice, slot in
              pasto(slot)
                .comparsa(indice + 1)
            }
          }
        }
        .padding(.horizontal, Stile.margine)
        .padding(.top, 4)
        .padding(.bottom, 24)
      }
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    private var oggi: String { Settimana.oggi(fuso: formati.fuso) }

    // MARK: - Quota

    /// L'anello delle kcal con il numero al centro e, accanto, i tre macro.
    private func quota(_ dieta: GiornoDieta) -> some View {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 18) {
          Anello(valore: dieta.avanzamento ?? 0, tinta: verde, spessore: 9, segnale: dieta.oltre) {
            VStack(spacing: 0) {
              Text(Formato.numero(formati.valoreEnergia(dieta.totals.kcal)))
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(Stile.testo)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
              Text(formati.energyUnit.rawValue)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Stile.testoTenue)
            }
            .padding(.horizontal, 14)
          }
          .frame(width: 104, height: 104)
          VStack(alignment: .leading, spacing: 10) {
            ForEach(dieta.macro, id: \.chiave) { riga in
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(riga.nome)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(Palette.macro(riga.chiave)))
                  Spacer(minLength: 4)
                  Text(riga.testo)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Stile.testo)
                }
                Barra(valore: riga.avanzamento ?? 0, tinta: Color(Palette.macro(riga.chiave)), altezza: 5)
              }
              .accessibilityElement(children: .combine)
            }
          }
        }
        if let rimanenti = dieta.testoRimanenti(formati) {
          Text("\(dieta.testoEnergia(formati)) · \(rimanenti)")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(dieta.oltre ? Stile.brandTesto : Stile.testoTenue)
        }
      }
      .glassPanel(tinta: verde)
    }

    // MARK: - Pasti

    /// Un pasto: la foto (o la tessera del pasto), lo slot, la ricetta e la
    /// spunta. Un pasto mangiato ha il bordo verde, uno saltato si spegne.
    private func pasto(_ slot: SlotGiorno) -> some View {
      let vista = slot.vista(giorno: giorno, oggi: oggi)
      return HStack(spacing: 12) {
        cosa(slot)
        if let id = slot.planned?.id, giorno <= oggi, vista != .vuoto {
          PulsanteMangiato(mangiato: slot.mangiato, abilitato: !inCorso) {
            Task { await conferma(id: id, mangiato: !slot.mangiato) }
          }
        }
      }
      .glassPanel(tinta: vista == .mangiato ? verde : nil, spazio: 12)
      .opacity(vista == .saltato ? 0.6 : 1)
      .animation(Stile.molla, value: vista)
    }

    @ViewBuilder
    private func cosa(_ slot: SlotGiorno) -> some View {
      let vista = slot.vista(giorno: giorno, oggi: oggi)
      let riga = HStack(spacing: 12) {
        if let immagine = slot.planned?.recipeImage {
          FotoRicetta(indirizzo: immagine, forma: .miniatura)
        } else {
          Tessera(
            simbolo: GiornoDieta.simboliSlot[slot.slot] ?? "fork.knife",
            tinta: vista == .vuoto ? Stile.testoTenue : verde, lato: 56)
        }
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(slot.titolo.uppercased())
              .font(.system(.caption2, design: .monospaced).weight(.semibold))
              .tracking(0.8)
              .foregroundStyle(verde)
            Text(vista.testo)
              .font(.caption2)
              .foregroundStyle(Stile.testoTenue)
          }
          Text(nome(slot) ?? "Niente in programma")
            .font(.subheadline.weight(nome(slot) == nil ? .regular : .medium))
            .foregroundStyle(nome(slot) == nil ? Stile.testoTenue : Stile.testo)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
          if let kcal = slot.kcal {
            Text(formati.energia(kcal))
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
        Spacer(minLength: 0)
      }
      if let ricetta = slot.planned?.recipeId {
        NavigationLink {
          RicettaView(id: ricetta)
            .destinazioneZoom(ricetta + slot.slot, in: zoom)
        } label: {
          riga.contentShape(Rectangle())
        }
        .buttonStyle(StilePremuto())
        .sorgenteZoom(ricetta + slot.slot, in: zoom)
      } else {
        riga
      }
    }

    private func nome(_ slot: SlotGiorno) -> String? {
      if let piano = slot.planned {
        return piano.recipeName ?? piano.items.map(\.name).joined(separator: " · ")
      }
      return slot.mangiato ? slot.elenco : nil
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
        sessione.mostra(Avviso(mangiato ? "Mangiato" : "Di nuovo in programma"))
      } else {
        sessione.mostra(.nonSalvato)
      }
    }
  }
#endif
