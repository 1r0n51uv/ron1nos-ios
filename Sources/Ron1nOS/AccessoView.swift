#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// Il service token di Cloudflare Access (IOS-004): si incolla, si salva
  /// nel Portachiavi, si elimina. Il secret non si rilegge mai a schermo.
  struct AccessoView: View {
    let archivio: ArchivioCredenziali
    /// Chiamata dopo un salvataggio o un'eliminazione.
    let cambiato: @MainActor () -> Void

    @Environment(\.dismiss) private var chiudi
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var avviso: String?
    @State private var salvato = false

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          HStack {
            Text("Accesso")
              .font(.system(size: 28, weight: .semibold))
              .foregroundStyle(Stile.testo)
            Spacer()
            Button("Chiudi") { chiudi() }
              .foregroundStyle(Stile.testoTenue)
          }

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
                .foregroundStyle(Stile.brand)
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
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .onAppear { salvato = archivio.carica() != nil }
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
  }
#endif
