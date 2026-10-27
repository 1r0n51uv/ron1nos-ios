#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La Home (IOS-020): la dashboard del sito nella forma della Home di
  /// iOS. Il layout è quello del dispositivo `iphone`, su una griglia di 4
  /// colonne: piccolo 2×2, medio 4×2, grande 4×4. In cima la testata
  /// (DASH-006) e, se il server non risponde, il pannello d'errore.
  struct HomeView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.aspetto) private var aspetto
    @Environment(\.formati) private var formati
    @State private var layout: LayoutHome?
    @State private var controllo: Controllo = .inCorso
    @State private var login: StatoLogin = .inCorso
    @State private var dati = DatiWidget()

    var body: some View {
      GeometryReader { spazio in
        let larghezza = max(0, spazio.size.width - 32)
        let lato = (larghezza - aspetto.spazio) / 2
        ScrollView {
          VStack(alignment: .leading, spacing: aspetto.spazio) {
            testata
            if case .fallito(let errore, _) = controllo {
              PannelloErrore(errore: errore)
            } else if login.problema {
              PannelloErrore(errore: .login(conToken: login == .tokenRifiutato))
            }
            griglia(larghezza: larghezza, lato: lato)
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 24)
        }
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .refreshable {
        await sessione.aggiornaPreferenze()
        await aggiorna()
      }
      .task(id: sessione.versione) { await aggiorna() }
      .toolbar(.hidden, for: .navigationBar)
    }

    private var forma: LayoutHome.Testata { layout?.header ?? .full }

    @ViewBuilder
    private var testata: some View {
      TimelineView(.everyMinute) { contesto in
        let adesso = contesto.date
        switch forma {
        case .full:
          VStack(alignment: .leading, spacing: 6) {
            Text(Testata.data(adesso, fuso: formati.fuso))
              .font(.system(.caption, design: .monospaced))
              .tracking(1.6)
              .foregroundStyle(Stile.testoTenue)
            Text(Testata.saluto(adesso, fuso: formati.fuso))
              .font(.system(size: 34, weight: .bold))
              .foregroundStyle(Stile.testo)
            let stato = Testata.stato(prossimoPasto: dati.dieta.valore?.nextSlot)
            if !stato.isEmpty {
              Text(stato)
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
            }
          }
          .padding(.top, 8)
        case .line:
          HStack(spacing: 8) {
            Text(Testata.dataCorta(adesso, fuso: formati.fuso))
              .font(.system(.caption, design: .monospaced))
              .tracking(1.6)
              .foregroundStyle(Stile.testoTenue)
            let stato = Testata.stato(prossimoPasto: dati.dieta.valore?.nextSlot)
            if !stato.isEmpty {
              Text("· \(stato)")
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
                .lineLimit(1)
            }
          }
          .padding(.top, 8)
        case .hidden:
          EmptyView()
        }
      }
    }

    @ViewBuilder
    private func griglia(larghezza: CGFloat, lato: CGFloat) -> some View {
      let righe = (layout ?? LayoutHome.predefinito).righe(spenti: sessione.preferenze.disabledModules)
      ForEach(Array(righe.enumerated()), id: \.offset) { _, riga in
        HStack(alignment: .top, spacing: aspetto.spazio) {
          ForEach(riga, id: \.id) { elemento in
            Button {
              if let scheda = Scheda.perModulo(elemento.modulo) { sessione.apri(scheda) }
            } label: {
              WidgetHome(elemento: elemento, dati: dati)
                .frame(
                  width: elemento.misura == .small ? lato : larghezza,
                  height: elemento.misura == .large ? lato * 2 + aspetto.spazio : lato,
                  alignment: .topLeading)
            }
            .buttonStyle(.plain)
          }
          if riga.count == 1, riga[0].misura == .small { Spacer(minLength: 0) }
        }
      }
    }

    private func aggiorna() async {
      let client = sessione.client
      async let stato = Controllo.esegui(con: client)
      async let accesso = StatoLogin.verifica(con: client)
      async let letto = try? client.layoutHome()
      async let nuovi = DatiWidget.carica(con: client)
      let (s, a, l, d) = await (stato, accesso, letto, nuovi)
      controllo = s
      login = a
      if let l { layout = l }
      dati = d
    }
  }

  /// Il pannello rosso quando il server non risponde o rifiuta l'accesso.
  struct PannelloErrore: View {
    let errore: APIError

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text(errore.titolo)
          .font(.headline)
          .foregroundStyle(Stile.brand)
        Text(errore.suggerimento)
          .font(.subheadline)
          .foregroundStyle(Stile.testo)
        if let dettaglio = errore.dettaglio {
          Text(dettaglio)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
        Text("Trascina in basso per riprovare.")
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel(tinta: Stile.brand)
    }
  }
#endif
