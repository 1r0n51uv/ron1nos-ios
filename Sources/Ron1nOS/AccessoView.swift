#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// L'accesso a ron1nOS. Il service token di Cloudflare Access (IOS-004) si
  /// incolla e si salva nel Portachiavi; il login (IOS-019) si fa con la
  /// password della dashboard, che resta nel Portachiavi dietro Face ID per
  /// rifarlo quando la sessione scade. I segreti non si rileggono mai a
  /// schermo.
  struct AccessoView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var avvisoToken: String?
    @State private var haToken = false
    @State private var password = ""
    @State private var ricordaConFaceID = true
    @State private var avvisoLogin: String?
    @State private var haSessione = false
    @State private var inCorso = false
    @State private var login = StatoLogin.inCorso

    private var autenticazione: Autenticazione { sessione.autenticazione }

    var body: some View {
      VStack(alignment: .leading, spacing: 20) {
        Text(
          "Il service token di Cloudflare Access fa entrare l'app senza il codice via email. "
            + "Sul server è in ~/.cf-home/ron1nos-ios.json: copialo tutto e tocca Incolla."
        )
        .font(.subheadline)
        .foregroundStyle(Stile.testoTenue)

        VStack(alignment: .leading, spacing: 14) {
          Text(haToken ? "Token salvato in questo telefono" : "Nessun token salvato")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
          campo("Client ID", testo: $clientId, segreto: false)
          campo("Client Secret", testo: $clientSecret, segreto: true)
          if let avvisoToken {
            Text(avvisoToken)
              .font(.footnote)
              .foregroundStyle(Stile.brandTesto)
          }
        }
        .glassPanel()

        HStack(spacing: 12) {
          pulsante("Incolla") { incolla() }
          pulsante("Salva") { salvaToken() }
          if haToken {
            pulsante("Elimina") { eliminaToken() }
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
          if haSessione {
            pulsante("Esci") { Task { await esci() } }
              .disabled(inCorso)
          }
        }
      }
      .onAppear(perform: aggiorna)
      .task(id: sessione.versione) { login = await autenticazione.stato() }
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

    private func aggiorna() {
      haToken = autenticazione.haToken
      haSessione = autenticazione.haSessione
    }

    private func incolla() {
      guard let testo = UIPasteboard.general.string,
        let credenziali = CredenzialiAccesso.leggi(da: testo)
      else {
        avvisoToken = "Negli appunti non c'è un service token."
        return
      }
      clientId = credenziali.clientId
      clientSecret = credenziali.clientSecret
      avvisoToken = nil
    }

    private func salvaToken() {
      let testo = "CF-Access-Client-Id: \(clientId)\nCF-Access-Client-Secret: \(clientSecret)"
      do {
        guard try autenticazione.salvaToken(da: testo) != nil else {
          avvisoToken = "Servono Client ID e Client Secret, senza spazi."
          return
        }
        clientId = ""
        clientSecret = ""
        avvisoToken = nil
        cambiato()
      } catch {
        avvisoToken = "Il Portachiavi non ha salvato il token."
      }
    }

    private func eliminaToken() {
      do {
        try autenticazione.eliminaToken()
        cambiato()
      } catch {
        avvisoToken = "Il Portachiavi non ha eliminato il token."
      }
    }

    private func entra() async {
      guard !password.isEmpty else {
        avvisoLogin = "Serve la password."
        return
      }
      inCorso = true
      defer { inCorso = false }
      do {
        switch try await autenticazione.entra(password: password, ricordaConFaceID: ricordaConFaceID) {
        case .entrato:
          password = ""
          avvisoLogin = nil
          cambiato()
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

    private func esci() async {
      inCorso = true
      defer { inCorso = false }
      await autenticazione.esci()
      cambiato()
    }

    private func cambiato() {
      sessione.cambiato()
      aggiorna()
    }
  }
#endif
