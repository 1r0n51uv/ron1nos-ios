#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le Impostazioni, per categoria: ognuna apre la sua pagina, così non c'è
  /// tutto assieme in una colonna sola.
  struct ImpostazioniView: View {
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          categoria("Accesso", simbolo: "person.crop.circle", dettaglio: "Login e token di Access") {
            AccessoView()
          }
          categoria("Pasti", simbolo: "fork.knife", dettaglio: "Orari dei pasti e rinvio") {
            OrariPastiView()
          }
          categoria("Notifiche", simbolo: "bell", dettaglio: "Permesso e prove degli avvisi") {
            AvvisiView()
          }
          categoria("Informazioni", simbolo: "info.circle", dettaglio: "Server e versione") {
            VStack(alignment: .leading, spacing: 12) {
              RigaValore(nome: "Server", valore: sessione.autenticazione.indirizzo.host() ?? "·")
              RigaValore(nome: "Versione", valore: versione)
            }
            .glassPanel()
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Impostazioni")
    }

    /// Una riga che apre la pagina della categoria.
    private func categoria<Contenuto: View>(
      _ titolo: String, simbolo: String, dettaglio: String, @ViewBuilder contenuto: @escaping () -> Contenuto
    ) -> some View {
      NavigationLink {
        PaginaImpostazioni(titolo: titolo, contenuto: contenuto)
      } label: {
        HStack(spacing: 14) {
          Image(systemName: simbolo)
            .font(.title3)
            .foregroundStyle(Stile.testo)
            .frame(width: 32)
          VStack(alignment: .leading, spacing: 2) {
            Text(titolo)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Stile.testo)
            Text(dettaglio)
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
        .frame(minHeight: 44)
        .glassPanel()
      }
      .buttonStyle(.plain)
    }

    /// "0.1.68 (68)": la versione e la build scritte dal builder nell'Info.plist.
    private var versione: String {
      let info = Bundle.main.infoDictionary
      let corta = info?["CFBundleShortVersionString"] as? String ?? "·"
      let build = info?["CFBundleVersion"] as? String ?? "·"
      return "\(corta) (\(build))"
    }
  }

  /// La pagina di una categoria delle Impostazioni.
  struct PaginaImpostazioni<Contenuto: View>: View {
    let titolo: String
    @ViewBuilder let contenuto: () -> Contenuto

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          contenuto()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(titolo)
      .navigationBarTitleDisplayMode(.inline)
    }
  }
#endif
