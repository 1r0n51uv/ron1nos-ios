#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// L'accesso a ron1nOS. Il service token di Cloudflare Access (IOS-004) si
  /// incolla e si salva nel Portachiavi; il login (IOS-019) si fa con il
  /// codice a 4 cifre della dashboard, che resta nel Portachiavi dietro Face ID
  /// per rifarlo quando la sessione scade. I segreti non si rileggono mai a
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
      VStack(alignment: .leading, spacing: Stile.traCard) {
        accesso
          .comparsa(0)
        token
          .comparsa(1)
      }
      .onAppear(perform: aggiorna)
      .task(id: sessione.versione) { login = await autenticazione.stato() }
    }

    /// Il login con il codice a 4 cifre di ron1nOS: è quello che serve più
    /// spesso, quindi sta in cima.
    private var accesso: some View {
      let ciano = Modulo.server.colore
      return VStack(alignment: .leading, spacing: 14) {
        IntestazioneCard(titolo: "Login di ron1nOS", simbolo: "person.fill", tinta: ciano) {
          Text(login.testo)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(login.problema ? Stile.brandTesto : ciano)
        }
        Text(
          "Il codice a 4 cifre della dashboard. La sessione dura 30 giorni; quando scade l'app la rifà con Face ID."
        )
        .font(.footnote)
        .foregroundStyle(Stile.testoTenue)
        SecureField("", text: codice, prompt: Text("····").foregroundStyle(Stile.testoTenue))
          .keyboardType(.numberPad)
          .textContentType(.password)
          .font(.system(.title2, design: .monospaced).weight(.semibold))
          .tracking(12)
          .multilineTextAlignment(.center)
          .foregroundStyle(Stile.testo)
          .frame(minHeight: 52)
          .background(Stile.velo, in: RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous)
              .strokeBorder(avvisoLogin == nil ? Stile.bordo : Stile.brand.opacity(0.6))
          )
          .accessibilityLabel("Codice")
        Toggle("Ricorda con Face ID", isOn: $ricordaConFaceID)
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
          .tint(ciano)
        if let avvisoLogin {
          Text(avvisoLogin)
            .font(.footnote)
            .foregroundStyle(Stile.brandTesto)
        }
        HStack(spacing: 8) {
          Button {
            Task { await entra() }
          } label: {
            HStack(spacing: 8) {
              if inCorso { ProgressView().tint(Stile.inchiostro) }
              Text(inCorso ? "Entro" : "Entra")
            }
            .animation(Stile.molla, value: inCorso)
          }
          .pulsantePieno(ciano)
          .disabled(inCorso || password.count != 4)
          if haSessione {
            Button("Esci") { Task { await esci() } }
              .glassChip()
              .disabled(inCorso)
          }
        }
        .buttonStyle(StilePremuto())
      }
      .glassPanel()
    }

    /// Solo cifre, al massimo 4.
    private var codice: Binding<String> {
      Binding(
        get: { password },
        set: { password = String($0.filter(\.isNumber).prefix(4)) })
    }

    /// Il service token di Cloudflare Access: si incolla una volta e basta.
    private var token: some View {
      VStack(alignment: .leading, spacing: 14) {
        IntestazioneCard(
          titolo: "Cloudflare Access", simbolo: "lock.shield.fill", tinta: Modulo.impostazioni.colore
        ) {
          Text(haToken ? "salvato" : "assente")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(haToken ? Modulo.impostazioni.colore : Stile.brandTesto)
        }
        Text(
          "Il service token fa entrare l'app senza il codice via email. "
            + "Sul server è in ~/.cf-home/ron1nos-ios.json: copialo tutto e tocca Incolla."
        )
        .font(.footnote)
        .foregroundStyle(Stile.testoTenue)
        campo("Client ID", testo: $clientId, segreto: false)
        campo("Client Secret", testo: $clientSecret, segreto: true)
        if let avvisoToken {
          Text(avvisoToken)
            .font(.footnote)
            .foregroundStyle(Stile.brandTesto)
        }
        HStack(spacing: 8) {
          Button {
            incolla()
          } label: {
            Label("Incolla", systemImage: "doc.on.clipboard")
          }
          .pulsantePieno(Modulo.impostazioni.colore)
          pulsante("Salva") { salvaToken() }
          if haToken {
            Button("Elimina") { eliminaToken() }
              .glassChip()
              .foregroundStyle(Stile.brandTesto)
          }
        }
        .buttonStyle(StilePremuto())
      }
      .glassPanel()
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
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Stile.velo, in: RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: Stile.raggioPiccolo, style: .continuous).strokeBorder(Stile.bordo))
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
        avvisoLogin = "Servono le 4 cifre del codice."
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
          avvisoLogin = "Codice non valido."
        case .loginSpento:
          avvisoLogin = "Il login di ron1nOS è spento: il codice non serve."
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
