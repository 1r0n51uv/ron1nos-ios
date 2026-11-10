#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le Impostazioni hanno solo l'accesso: l'indirizzo del server, la
  /// versione dell'app e il login.
  struct ImpostazioniView: View {
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          VStack(alignment: .leading, spacing: 12) {
            RigaValore(nome: "Server", valore: sessione.autenticazione.indirizzo.host() ?? "·")
            RigaValore(nome: "Versione", valore: versione)
          }
          .glassPanel()
          AccessoView()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Impostazioni")
    }

    /// "0.1.68 (68)": la versione e la build scritte dal builder nell'Info.plist.
    private var versione: String {
      let info = Bundle.main.infoDictionary
      let corta = info?["CFBundleShortVersionString"] as? String ?? "·"
      let build = info?["CFBundleVersion"] as? String ?? "·"
      return "\(corta) (\(build))"
    }
  }
#endif
