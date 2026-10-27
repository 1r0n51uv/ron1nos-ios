#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UniformTypeIdentifiers

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
    /// Il salvataggio da solo del layout (IOS-024). Le modifiche arrivano
    /// dalla modalità Modifica (IOS-022) con `cambia(_:)`.
    @State private var salvataggio = SalvataggioLayout {
      (layout: LayoutHome) throws(APIError) -> LayoutHome in
      try await Sessione.condivisa.client.salvaLayoutHome(layout)
    }
    @State private var catalogo: Catalogo?
    /// La modalità Modifica (IOS-022): non si ricorda tra un'apertura e
    /// l'altra.
    @State private var modifica = false
    @State private var aggiunta = false
    /// Il widget che si sta trascinando.
    @State private var trascinato: String?

    var body: some View {
      GeometryReader { spazio in
        let larghezza = max(0, spazio.size.width - 32)
        let lato = (larghezza - aspetto.spazio) / 2
        ScrollView {
          VStack(alignment: .leading, spacing: aspetto.spazio) {
            comandi
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
      .onAppear { salvataggio.esito = esitoSalvataggio }
      .onDisappear { modifica = false }
      .sheet(isPresented: $aggiunta) {
        AggiungiWidgetView(
          voci: disponibili, dati: dati,
          aggiungi: { voce, misura in
            cambia { $0.aggiungi(voce, misura: misura) }
            aggiunta = false
          })
      }
      .toolbar(.hidden, for: .navigationBar)
    }

    private var forma: LayoutHome.Testata { layout?.header ?? .full }

    /// In alto a destra: `Modifica`, oppure in Modifica `+`, la forma della
    /// testata e `Fine`.
    private var comandi: some View {
      HStack(spacing: 16) {
        Spacer()
        if modifica {
          Button {
            aggiunta = true
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Aggiungi widget")
          .disabled(disponibili.isEmpty)
          Menu {
            Picker(
              "Testata",
              selection: Binding(get: { forma }, set: { nuova in cambia { $0.header = nuova } })
            ) {
              ForEach(LayoutHome.Testata.allCases, id: \.self) { Text($0.titolo).tag($0) }
            }
          } label: {
            Image(systemName: "textformat.size")
          }
          .accessibilityLabel("Testata")
          Button("Fine") { esci() }
            .fontWeight(.semibold)
        } else {
          Button("Modifica") { entra() }
        }
      }
      .font(.body)
      .tint(Stile.brand)
    }

    /// Il catalogo per l'iPhone senza i widget già sulla Home.
    private var disponibili: [VoceCatalogo] {
      let presenti = Set((layout ?? LayoutHome.predefinito).items.map(\.id))
      return (catalogo?.perIPhone(spenti: sessione.preferenze.disabledModules) ?? [])
        .filter { !presenti.contains($0.id) }
    }

    private func entra() {
      withAnimation(.snappy) { modifica = true }
    }

    private func esci() {
      withAnimation(.snappy) { modifica = false }
      trascinato = nil
    }

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
            cella(elemento)
              .frame(
                width: elemento.misura == .small ? lato : larghezza,
                height: elemento.misura == .large ? lato * 2 + aspetto.spazio : lato,
                alignment: .topLeading)
          }
          if riga.count == 1, riga[0].misura == .small { Spacer(minLength: 0) }
        }
      }
    }

    /// Un widget: fuori da Modifica si tocca per aprire il modulo e si
    /// tiene premuto per entrare in Modifica; in Modifica trema, ha il `−`
    /// e si trascina.
    @ViewBuilder
    private func cella(_ elemento: ElementoLayout) -> some View {
      let widget = WidgetHome(elemento: elemento, dati: dati)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
      if modifica {
        widget
          .modifier(Tremolio())
          .overlay(alignment: .topLeading) {
            Button {
              rimuovi(elemento.id)
            } label: {
              Image(systemName: "minus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Stile.testo)
                .frame(width: 26, height: 26)
                .background(Circle().fill(.ultraThinMaterial))
            }
            .buttonStyle(.plain)
            .offset(x: -8, y: -8)
            .accessibilityLabel("Rimuovi")
          }
          .opacity(trascinato == elemento.id ? 0.4 : 1)
          .onDrag {
            trascinato = elemento.id
            return NSItemProvider(object: elemento.id as NSString)
          }
          .onDrop(
            of: [.text],
            delegate: SpostaWidget(
              bersaglio: elemento.id, trascinato: $trascinato,
              sposta: { da, a in sposta(da, sopra: a) })
          )
          .accessibilityAction(named: "Sposta su") { cambia { $0.sposta(elemento.id, di: -1) } }
          .accessibilityAction(named: "Sposta giù") { cambia { $0.sposta(elemento.id, di: 1) } }
          .accessibilityAction(named: "Rimuovi") { rimuovi(elemento.id) }
      } else {
        widget
          .onTapGesture {
            if let scheda = Scheda.perModulo(elemento.modulo) { sessione.apri(scheda) }
          }
          .onLongPressGesture(minimumDuration: 0.5) { entra() }
          .accessibilityAction(named: "Modifica") { entra() }
      }
    }

    /// Mentre si trascina, il widget prende il posto di quello sotto e gli
    /// altri fanno posto.
    private func sposta(_ id: String, sopra bersaglio: String) {
      let ordine = (layout ?? LayoutHome.predefinito).ordinati.map(\.id)
      guard let da = ordine.firstIndex(of: id), let a = ordine.firstIndex(of: bersaglio) else { return }
      withAnimation(.snappy) { cambia { $0.sposta(da: da, a: a) } }
    }

    /// Toglie subito il widget; `Annulla` nel toast lo rimette dov'era.
    private func rimuovi(_ id: String) {
      guard let prima = layout else { return }
      withAnimation(.snappy) { cambia { $0.rimuovi(id) } }
      sessione.mostra(.widgetRimosso) {
        withAnimation(.snappy) { cambia { $0 = prima } }
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
      // Un layout cambiato e non ancora salvato resta sullo schermo.
      if let l, salvataggio.inSospeso == nil { layout = l }
      dati = d
      if catalogo == nil, let letto = try? await client.catalogo() {
        catalogo = letto
        salvataggio.catalogo = letto
      }
    }

    /// Applica una modifica al layout sullo schermo e la salva un secondo
    /// dopo l'ultima.
    func cambia(_ modifica: (inout LayoutHome) -> Void) {
      var nuovo = layout ?? LayoutHome.predefinito
      modifica(&nuovo)
      guard nuovo != layout else { return }
      layout = nuovo
      salvataggio.programma(nuovo)
    }

    private func esitoSalvataggio(_ esito: SalvataggioLayout.Esito) {
      switch esito {
      case .salvato(let salvato):
        // Il server rimette in ordine: vale la sua versione se non è
        // cambiato altro nel frattempo.
        if salvataggio.inSospeso == nil { layout = salvato }
      case .fallito:
        sessione.mostra(.layoutNonSalvato) { [salvataggio] in salvataggio.riprova() }
      }
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
