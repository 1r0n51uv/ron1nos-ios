#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// Il service token di Cloudflare Access (IOS-004) si incolla e si salva
  /// nel Portachiavi; il login di ron1nOS (IOS-019) si fa con la password
  /// della dashboard, che resta nel Portachiavi dietro Face ID per rifarlo
  /// quando la sessione scade. I segreti non si rileggono mai a schermo.
  struct AccessoView: View {
    let archivio: ArchivioCredenziali
    /// Chiamata dopo un salvataggio o un'eliminazione.
    let cambiato: @MainActor () -> Void

    /// Dopo un salvataggio si torna alla pagina di prima.
    @Environment(\.dismiss) private var chiudi
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var avviso: String?
    @State private var salvato = false
    @State private var password = ""
    @State private var ricordaConFaceID = true
    @State private var avvisoLogin: String?
    @State private var entrato = false
    @State private var inCorso = false
    /// Lo stato del login con la sessione salvata (IOS-090).
    @State private var login = StatoLogin.inCorso
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(
            "Il service token di Cloudflare Access fa entrare l'app senza il codice via email. "
              + "Sul server è in ~/.cf-home/ron1nos-ios.json: copialo tutto e tocca Incolla."
          )
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)

          VStack(alignment: .leading, spacing: 14) {
            Text(salvato ? "Token salvato in questo telefono" : "Nessun token salvato")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
            campo("Client ID", testo: $clientId, segreto: false)
            campo("Client Secret", testo: $clientSecret, segreto: true)
            if let avviso {
              Text(avviso)
                .font(.footnote)
                .foregroundStyle(Stile.brandTesto)
            }
          }
          .glassPanel()

          HStack(spacing: 12) {
            pulsante("Incolla") { incolla() }
            pulsante("Salva") { salva() }
            if salvato {
              pulsante("Elimina") { elimina() }
            }
          }

          Text(
            "Il login di ron1nOS chiede la password della dashboard. La sessione dura 30 giorni; "
              + "quando scade l'app la rifà con Face ID."
          )
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
          .padding(.top, 8)

          VStack(alignment: .leading, spacing: 14) {
            HStack {
              Text("Login")
                .font(.footnote)
                .foregroundStyle(Stile.testoTenue)
              Spacer()
              Text(login.testo)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(login.problema ? Stile.brandTesto : Stile.testo)
            }
            campo("Password", testo: $password, segreto: true)
            Toggle("Ricorda con Face ID", isOn: $ricordaConFaceID)
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
              .tint(Stile.brand)
            if let avvisoLogin {
              Text(avvisoLogin)
                .font(.footnote)
                .foregroundStyle(Stile.brandTesto)
            }
          }
          .glassPanel()

          HStack(spacing: 12) {
            pulsante("Entra") { Task { await entra() } }
              .disabled(inCorso)
            if entrato {
              pulsante("Esci") { Task { await esci() } }
                .disabled(inCorso)
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Accesso")
      .onAppear {
        salvato = archivio.carica() != nil
        entrato = sessione.archivioCookie.carica() != nil
      }
      .task(id: sessione.versione) { login = await StatoLogin.verifica(con: sessione.client) }
    }

    private func campo(_ titolo: String, testo: Binding<String>, segreto: Bool) -> some View {
      VStack(alignment: .leading, spacing: 6) {
        Text(titolo)
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
        Group {
          if segreto {
            SecureField("", text: testo)
          } else {
            TextField("", text: testo)
          }
        }
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(Stile.testo)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
      }
    }

    private func pulsante(_ titolo: String, azione: @escaping () -> Void) -> some View {
      Button(titolo, action: azione).glassChip()
    }

    private func incolla() {
      guard let testo = UIPasteboard.general.string,
        let credenziali = CredenzialiAccesso.leggi(da: testo)
      else {
        avviso = "Negli appunti non c'è un service token."
        return
      }
      clientId = credenziali.clientId
      clientSecret = credenziali.clientSecret
      avviso = nil
    }

    private func salva() {
      let testo = "CF-Access-Client-Id: \(clientId)\nCF-Access-Client-Secret: \(clientSecret)"
      guard let credenziali = CredenzialiAccesso.leggi(da: testo) else {
        avviso = "Servono Client ID e Client Secret, senza spazi."
        return
      }
      do {
        try archivio.salva(credenziali)
        clientId = ""
        clientSecret = ""
        avviso = nil
        salvato = true
        cambiato()
        chiudi()
      } catch {
        avviso = "Il Portachiavi non ha salvato il token."
      }
    }

    private func elimina() {
      do {
        try archivio.cancella()
        salvato = false
        cambiato()
      } catch {
        avviso = "Il Portachiavi non ha eliminato il token."
      }
    }

    private func entra() async {
      guard !password.isEmpty else {
        avvisoLogin = "Serve la password."
        return
      }
      inCorso = true
      defer { inCorso = false }
      let base = APIClient(credenziali: archivio.carica())
      do {
        switch try await base.accedi(password: password) {
        case .entrato(let cookie):
          try sessione.archivioCookie.salva(cookie.valore)
          if ricordaConFaceID {
            try sessione.archivioPassword.salva(password)
          } else {
            try sessione.archivioPassword.cancella()
          }
          password = ""
          avvisoLogin = nil
          entrato = true
          cambiato()
          chiudi()
        case .passwordErrata:
          avvisoLogin = "Password non valida."
        case .loginSpento:
          avvisoLogin = "Il login di ron1nOS è spento: la password non serve."
        case .troppiTentativi:
          avvisoLogin = "Troppi tentativi · riprova tra qualche minuto."
        }
      } catch let errore as APIError {
        avvisoLogin = errore.titolo
      } catch {
        avvisoLogin = "Il Portachiavi non ha salvato l'accesso."
      }
    }

    /// Chiude la sessione sul server, se risponde, e toglie sessione e
    /// password dal telefono comunque.
    private func esci() async {
      inCorso = true
      defer { inCorso = false }
      // Senza rinnovo: uscire non deve chiedere Face ID per rifare il login.
      let cookie = sessione.archivioCookie.carica().map(CookieSessione.init)
      try? await APIClient(credenziali: archivio.carica(), sessione: cookie).esci()
      try? sessione.archivioCookie.cancella()
      try? sessione.archivioPassword.cancella()
      entrato = false
      cambiato()
    }
  }
#endif
