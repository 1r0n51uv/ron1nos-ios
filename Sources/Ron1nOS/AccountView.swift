#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  private let veloAccount = Color.white.opacity(0.06)

  /// Impostazioni › Account (IOS-092, SET-007, IOS-019): le sessioni aperte,
  /// quella di questo iPhone segnata, con `Chiudi` e `Chiudi le altre`, e
  /// come cambiare la password.
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
            Text("Sessioni attive")
          } footer: {
            VStack(alignment: .leading, spacing: 6) {
              Text("Chiudi le altre lascia aperta solo la sessione di questo iPhone.")
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
      .confirmationDialog("Chiudere le altre sessioni?", isPresented: $conferma) {
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
          Text("Nessuna sessione aperta.")
            .foregroundStyle(Stile.testoTenue)
            .listRowBackground(veloAccount)
        }
        ForEach(elenco) { voce in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Text(voce.device).foregroundStyle(Stile.testo)
                if voce.current {
                  Text("questo iPhone")
                    .font(.caption)
                    .foregroundStyle(Stile.testoTenue)
                }
              }
              Text("ultimo uso \(Formato.momento(voce.lastSeenAt, fuso: fuso) ?? "·")")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Stile.testoTenue)
            }
            Spacer()
            if !voce.current {
              Button("Chiudi") { Task { await chiudi(voce.id) } }
                .buttonStyle(.borderless)
                .tint(Stile.testo)
            }
          }
          .listRowBackground(veloAccount)
        }
        Button("Chiudi le altre", role: .destructive) { conferma = true }
          .disabled(elenco.allSatisfy(\.current))
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
        try await sessione.client.chiudiAltreSessioni()
        errore = nil
      } catch {
        errore = "Sessioni non chiuse · riprova"
      }
      await carica()
    }
  }
#endif
