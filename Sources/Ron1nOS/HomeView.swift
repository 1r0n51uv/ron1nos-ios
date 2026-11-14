#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La Home (IOS-043): la testata, il pasto di adesso con la spunta, poi
  /// Server e Download affiancati e, se scarica qualcosa, i torrent attivi.
  /// Si aggiorna ogni 5 secondi e con il gesto di tirare giù.
  struct HomeView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var server = Carico<StatoServer>.inCorso
    @State private var download = Carico<Download>.inCorso
    @State private var giornoNutrizione = Carico<GiornoDieta>.inCorso

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          testata
            .comparsa(0)
          if daAccedere {
            invito
              .comparsa(1)
          } else {
            CardPasto(
              carico: giornoNutrizione, slot: slotCorrente, conferma: { id in Task { await mangiato(id) } },
              apri: { sessione.scheda = .nutrizione }
            )
            .comparsa(1)
            HStack(alignment: .top, spacing: Stile.traCard) {
              CardServer(carico: server)
              Button {
                sessione.scheda = .torrent
              } label: {
                CardTorrent(carico: download)
              }
              .buttonStyle(StilePremuto())
            }
            .fixedSize(horizontal: false, vertical: true)
            .comparsa(2)
            if let attivi = download.valore, !attivi.inVista.isEmpty {
              Button {
                sessione.scheda = .torrent
              } label: {
                CardInDownload(download: attivi)
              }
              .buttonStyle(StilePremuto())
              .transition(.opacity.combined(with: .move(edge: .top)))
              .comparsa(3)
            }
          }
        }
        .padding(.horizontal, Stile.margine)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .animation(Stile.molla, value: download.valore?.inVista.isEmpty)
      }
      .sfondoPagina()
      .navigationBarTitleDisplayMode(.inline)
      .task(id: sessione.versione) { await carica() }
      .aggiornaOgni(5) { await carica() }
      .refreshable { await carica() }
    }

    private var testata: some View {
      VStack(alignment: .leading, spacing: 2) {
        Text(
          Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "it_IT")))
            .uppercased()
        )
        .font(.system(.caption, design: .monospaced).weight(.medium))
        .tracking(1.2)
        .foregroundStyle(Stile.brandTesto)
        Text(saluto)
          .font(.largeTitle.weight(.bold))
          .foregroundStyle(Stile.testo)
      }
      .padding(.bottom, 4)
      .accessibilityElement(children: .combine)
    }

    private var saluto: String {
      switch Calendar.current.component(.hour, from: Date.now) {
      case 5..<12: "Buongiorno"
      case 12..<18: "Buon pomeriggio"
      default: "Buonasera"
      }
    }

    /// Senza sessione le rotte rispondono 401: la Home invita ad accedere.
    private var daAccedere: Bool {
      for errore in [erroreDi(server), erroreDi(download), erroreDi(giornoNutrizione)] {
        if let errore, case .login = errore { return true }
      }
      return false
    }

    private func erroreDi<V>(_ carico: Carico<V>) -> APIError? {
      if case .fallito(let errore) = carico { return errore }
      return nil
    }

    private var invito: some View {
      StatoVuoto(
        simbolo: "key.fill", titolo: "Manca l'accesso",
        testo: "Entra con il codice di ron1nOS: serve una volta, poi lo ricorda Face ID.",
        tinta: Stile.brandTesto
      ) {
        Button("Vai all'accesso") { sessione.scheda = .impostazioni }
          .pulsantePieno(Stile.brandTesto)
          .buttonStyle(StilePremuto())
      }
    }

    /// Lo slot che corrisponde all'ora, secondo gli orari dei pasti.
    private var slotCorrente: String {
      sessione.promemoria.slotCorrente(
        minuti: Promemoria.minutiDi(Date(), fuso: sessione.formati.fuso))
    }

    private func mangiato(_ piano: String) async {
      if await sessione.conferma(piano: piano) {
        sessione.mostra(Avviso("Mangiato"))
        await carica()
      } else {
        sessione.mostra(.nonSalvato)
      }
    }

    private func carica() async {
      let client = sessione.autenticazione.client()
      async let nuovoServer = Carico.da { try await client.statoServer() }
      async let nuoviDownload = Carico.da { try await client.download() }
      async let nuovoGiorno = Carico.da { try await client.dieta() }
      server = await nuovoServer
      download = await nuoviDownload
      giornoNutrizione = await nuovoGiorno
      if let letti = download.valore { sessione.letti(letti) }
    }
  }
#endif
