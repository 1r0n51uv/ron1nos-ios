#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La Home: la testata e lo stato di Server e Torrent, in sola lettura.
  /// Si aggiorna ogni 5 secondi e con il gesto di tirare giù.
  struct HomeView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var server = Carico<StatoServer>.inCorso
    @State private var download = Carico<Download>.inCorso

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          testata
          if daAccedere {
            invito
          } else {
            CardServer(carico: server)
            CardTorrent(carico: download)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .task(id: sessione.versione) { await carica() }
      .aggiornaOgni(5) { await carica() }
      .refreshable { await carica() }
    }

    private var testata: some View {
      VStack(alignment: .leading, spacing: 4) {
        Text(
          Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "it_IT")))
        )
        .font(.system(.footnote, design: .monospaced))
        .foregroundStyle(Stile.testoTenue)
        Text(saluto)
          .font(.largeTitle.weight(.semibold))
          .foregroundStyle(Stile.testo)
      }
      .padding(.bottom, 4)
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
      for errore in [erroreDi(server), erroreDi(download)] {
        if let errore, case .login = errore { return true }
      }
      return false
    }

    private func erroreDi<V>(_ carico: Carico<V>) -> APIError? {
      if case .fallito(let errore) = carico { return errore }
      return nil
    }

    private var invito: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("Manca l'accesso")
          .font(.headline)
          .foregroundStyle(Stile.testo)
        Text("Entra con la password di ron1nOS in Impostazioni.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel(tinta: Stile.brand)
    }

    private func carica() async {
      let client = sessione.autenticazione.client()
      async let nuovoServer = Carico.da { try await client.statoServer() }
      async let nuoviDownload = Carico.da { try await client.download() }
      server = await nuovoServer
      download = await nuoviDownload
    }
  }
#endif
