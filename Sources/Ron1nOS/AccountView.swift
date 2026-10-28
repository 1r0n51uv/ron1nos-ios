#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  private let veloAccount = Color.white.opacity(0.06)

  /// Impostazioni › Account (IOS-092, SET-007): le sessioni web con
  /// `Chiudi` e `Chiudi le altre`, e come cambiare la password.
  struct AccountView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var login = StatoLogin.inCorso
    @State private var sessioni: Carico<[SessioneWeb]> = .inCorso
    @State private var errore: String?
    @State private var conferma = false

    var body: some View {
      List {
        if login == .spento {
          Section("Login spento") {
            Text("Senza AUTH_PASSWORD_HASH nel .env la dashboard è aperta a chi può raggiungerla.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(veloAccount)
          }
        } else {
          Section {
            elenco
          } header: {
            Text("Sessioni web attive")
          } footer: {
            VStack(alignment: .leading, spacing: 6) {
              Text(
                "L'app entra con il suo token, non con una sessione: Chiudi le altre esce da tutti i browser."
              )
              .foregroundStyle(Stile.testoTenue)
              if let errore {
                Text(errore).foregroundStyle(Stile.brandTesto)
              }
            }
          }
        }
        Section("Password") {
          VStack(alignment: .leading, spacing: 10) {
            Text(
              "La password sta come hash nel .env del server, quindi non si cambia da qui. Per una nuova: "
                + "sul server lancia il comando qui sotto, metti il risultato in AUTH_PASSWORD_HASH e "
                + "riavvia lo stack."
            )
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
            Text("npm run auth:hash")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testo)
              .textSelection(.enabled)
          }
          .listRowBackground(veloAccount)
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Account")
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
      .confirmationDialog("Chiudere tutte le sessioni web?", isPresented: $conferma) {
        Button("Chiudi le altre", role: .destructive) { Task { await chiudiTutte() } }
      }
    }

    @ViewBuilder
    private var elenco: some View {
      switch sessioni {
      case .inCorso:
        Scheletro(righe: 3).listRowBackground(veloAccount)
      case .spento:
        EmptyView()
      case .fallito:
        Text("Sessioni non disponibili")
          .foregroundStyle(Stile.brandTesto)
          .listRowBackground(veloAccount)
      case .pronto(let elenco):
        if elenco.isEmpty {
          Text("Nessuna sessione web aperta.")
            .foregroundStyle(Stile.testoTenue)
            .listRowBackground(veloAccount)
        }
        ForEach(elenco) { voce in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(voce.device)
                .foregroundStyle(Stile.testo)
              Text("ultimo uso \(Formato.momento(voce.lastSeenAt, fuso: fuso) ?? "·")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
            }
            Spacer()
            Button("Chiudi") { Task { await chiudi(voce.id) } }
              .buttonStyle(.borderless)
              .tint(Stile.testo)
          }
          .listRowBackground(veloAccount)
        }
        Button("Chiudi le altre", role: .destructive) { conferma = true }
          .disabled(elenco.isEmpty)
          .listRowBackground(veloAccount)
      }
    }

    private var fuso: TimeZone { sessione.preferenze.formats.fuso }

    private func carica() async {
      let client = sessione.client
      async let stato = StatoLogin.verifica(con: client)
      async let lette = Carico.da { try await client.sessioniWeb() }
      login = await stato
      sessioni = await lette
    }

    private func chiudi(_ id: String) async {
      do {
        try await sessione.client.chiudiSessione(id)
        errore = nil
      } catch {
        errore = "Sessione non chiusa · riprova"
      }
      await carica()
    }

    private func chiudiTutte() async {
      do {
        try await sessione.client.chiudiSessioniWeb()
        errore = nil
      } catch {
        errore = "Sessioni non chiuse · riprova"
      }
      await carica()
    }
  }

  /// Impostazioni › App iOS (IOS-092, SET-008, AUTH-005): i token con nome e
  /// ultimo uso, quello di questo telefono segnato. `Nuovo token` lo salva
  /// dritto nel Portachiavi, senza copia e incolla.
  struct AppIOSView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var login = StatoLogin.inCorso
    @State private var token: Carico<[TokenApp]> = .inCorso
    @State private var nome = NomeToken.predefinito
    @State private var errore: String?
    @State private var daRevocare: TokenApp?
    @State private var esci = false
    @State private var lavoro = false

    var body: some View {
      List {
        if login == .spento {
          Section {
            Text("Il login di ron1nOS è spento: l'app non ha bisogno di un token.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
              .listRowBackground(veloAccount)
          }
        } else {
          Section("Token") { elenco }
          Section {
            TextField("Nome", text: $nome)
              .foregroundStyle(Stile.testo)
              .listRowBackground(veloAccount)
            Button("Nuovo token") { Task { await crea() } }
              .disabled(NomeToken.problema(nome) != nil || lavoro)
              .listRowBackground(veloAccount)
          } header: {
            Text("Nuovo token")
          } footer: {
            VStack(alignment: .leading, spacing: 6) {
              Text(
                "Il token nuovo va nel Portachiavi di questo iPhone e prende il posto di quello di prima."
              )
              .foregroundStyle(Stile.testoTenue)
              if let errore {
                Text(errore).foregroundStyle(Stile.brandTesto)
              }
            }
          }
          if sessione.archivioToken.carica() != nil {
            Section {
              Button("Esci da questo iPhone", role: .destructive) { esci = true }
                .disabled(lavoro)
                .listRowBackground(veloAccount)
            } footer: {
              Text("Revoca il token di questo telefono e lo toglie dal Portachiavi.")
                .foregroundStyle(Stile.testoTenue)
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("App iOS")
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
      .confirmationDialog(
        "Revocare \(daRevocare?.name ?? "il token")?",
        isPresented: Binding(get: { daRevocare != nil }, set: { if !$0 { daRevocare = nil } }),
        presenting: daRevocare
      ) { voce in
        Button("Revoca", role: .destructive) { Task { await revoca(voce) } }
      } message: { voce in
        if voce.current {
          Text("È il token di questo iPhone: l'app non entra più finché non ne salvi un altro.")
        }
      }
      .confirmationDialog("Uscire da questo iPhone?", isPresented: $esci) {
        Button("Esci", role: .destructive) { Task { await esciDaQui() } }
      }
    }

    @ViewBuilder
    private var elenco: some View {
      switch token {
      case .inCorso:
        Scheletro(righe: 2).listRowBackground(veloAccount)
      case .spento:
        EmptyView()
      case .fallito:
        Text("Token non disponibili")
          .foregroundStyle(Stile.brandTesto)
          .listRowBackground(veloAccount)
      case .pronto(let elenco):
        if elenco.isEmpty {
          Text("Nessun token.")
            .foregroundStyle(Stile.testoTenue)
            .listRowBackground(veloAccount)
        }
        ForEach(elenco) { voce in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Text(voce.name).foregroundStyle(Stile.testo)
                if voce.current {
                  Text("questo iPhone")
                    .font(.caption)
                    .foregroundStyle(Stile.testoTenue)
                }
              }
              Text("ultimo uso \(voce.lastUsedAt.flatMap { Formato.momento($0, fuso: fuso) } ?? "mai")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
            }
            Spacer()
            Button("Revoca", role: .destructive) { daRevocare = voce }
              .buttonStyle(.borderless)
          }
          .listRowBackground(veloAccount)
        }
      }
    }

    private var fuso: TimeZone { sessione.preferenze.formats.fuso }

    private func carica() async {
      let client = sessione.client
      async let stato = StatoLogin.verifica(con: client)
      async let letti = Carico.da { try await client.tokenApp() }
      login = await stato
      token = await letti
    }

    private func crea() async {
      lavoro = true
      defer { lavoro = false }
      do {
        let creato = try await sessione.client.creaToken(nome: nome)
        guard let valore = TokenRon1n.leggi(da: creato.token) else {
          errore = "Il server ha mandato un token che l'app non riconosce."
          return
        }
        try sessione.archivioToken.salva(valore)
        errore = nil
        nome = NomeToken.predefinito
        sessione.credenzialiCambiate()
      } catch {
        errore = "Token non creato · riprova"
      }
    }

    private func revoca(_ voce: TokenApp) async {
      do {
        try await sessione.client.revocaToken(voce.id)
        errore = nil
        if voce.current {
          try? sessione.archivioToken.cancella()
          sessione.credenzialiCambiate()
        } else {
          await carica()
        }
      } catch {
        errore = "Token non revocato · riprova"
      }
    }

    /// Revoca il token del telefono, se il server lo riconosce, e lo toglie
    /// dal Portachiavi comunque.
    private func esciDaQui() async {
      lavoro = true
      defer { lavoro = false }
      if let mio = token.valore?.first(where: { $0.current }) {
        try? await sessione.client.revocaToken(mio.id)
      }
      try? sessione.archivioToken.cancella()
      sessione.credenzialiCambiate()
    }
  }
#endif
