#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La home (IOS-001, IOS-006): chiama /health e mostra
  /// backend, database, login e ora dell'ultimo controllo. Il service token
  /// di Access (IOS-004) e il token di ron1nOS (IOS-005) vengono dal
  /// Portachiavi. Sotto, le card dei moduli.
  struct StatoView: View {
    @State private var controllo: Controllo = .inCorso
    @State private var login: StatoLogin = .inCorso
    @State private var dieta: Carico<GiornoDieta> = .inCorso
    @State private var mostraAccesso = false
    private let archivio = Portachiavi()
    private let archivioToken = PortachiaviToken()

    private var client: APIClient {
      APIClient(credenziali: archivio.carica(), token: archivioToken.carica())
    }

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          intestazione
          pannelloStato
          if case .fallito(let errore, _) = controllo {
            pannelloErrore(errore)
          } else if login.problema {
            pannelloErrore(.login(conToken: login == .tokenRifiutato))
          }
          CardDieta(carico: dieta)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .refreshable { await aggiorna() }
      .task { await aggiorna() }
      .sheet(isPresented: $mostraAccesso) {
        AccessoView(archivio: archivio, archivioToken: archivioToken) {
          Task { await aggiorna() }
        }
      }
    }

    private var intestazione: some View {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("ron1nOS")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(Stile.testo)
          Text(APIClient.indirizzoPredefinito.host() ?? "")
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
        Spacer()
        Button("Accesso") { mostraAccesso = true }
          .glassChip()
          .padding(.top, 8)
      }
    }

    private var pannelloStato: some View {
      VStack(alignment: .leading, spacing: 14) {
        riga("Backend", controllo.backend, segnale: isFallito)
        riga("Database", testoDatabase, segnale: databaseProblema)
        riga("Login", login.testo, segnale: login.problema)
        if let ora = controllo.testoOra() {
          Text(ora)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .glassPanel()
    }

    private func pannelloErrore(_ errore: APIError) -> some View {
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

    private func riga(_ titolo: String, _ valore: String, segnale: Bool) -> some View {
      HStack {
        Text(titolo)
          .foregroundStyle(Stile.testoTenue)
        Spacer()
        if segnale {
          Circle().fill(Stile.brand).frame(width: 8, height: 8)
        }
        Text(valore)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(Stile.testo)
      }
    }

    private var isFallito: Bool {
      if case .fallito = controllo { return true }
      return false
    }

    private var testoDatabase: String {
      if case .riuscito(let health, _) = controllo { return health.database.testo }
      return "·"
    }

    private var databaseProblema: Bool {
      if case .riuscito(let health, _) = controllo { return health.database.problema }
      return false
    }

    private func aggiorna() async {
      let client = client
      async let stato = Controllo.esegui(con: client)
      async let accesso = StatoLogin.verifica(con: client)
      async let giorno = Carico.da { try await client.dieta() }
      (controllo, login, dieta) = await (stato, accesso, giorno)
    }
  }
#endif
