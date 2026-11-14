#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le Impostazioni (IOS-043): le categorie in un solo pannello, ognuna con
  /// la sua tessera colorata come nelle Impostazioni di iOS, e sotto server e
  /// versione, che si leggono senza aprire niente.
  struct ImpostazioniView: View {
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          VStack(spacing: 0) {
            categoria(
              "Accesso", simbolo: "key.fill", tinta: Modulo.server.colore,
              dettaglio: "Codice e token di Access"
            ) {
              AccessoView()
            }
            divisore
            categoria(
              "Pasti", simbolo: "clock.fill", tinta: Modulo.nutrizione.colore,
              dettaglio: "Orari dei pasti e rinvio"
            ) {
              OrariPastiView()
            }
            divisore
            categoria(
              "Notifiche", simbolo: "bell.badge.fill", tinta: Stile.brandTesto,
              dettaglio: "Permesso e prove degli avvisi"
            ) {
              AvvisiView()
            }
          }
          .glassPanel(spazio: 4)
          .comparsa(0)

          VStack(alignment: .leading, spacing: 12) {
            IntestazioneCard(
              titolo: "Informazioni", simbolo: "info.circle", tinta: Modulo.impostazioni.colore)
            RigaValore(nome: "Server", valore: sessione.autenticazione.indirizzo.host() ?? "·")
            RigaValore(nome: "Versione", valore: versione)
          }
          .glassPanel()
          .comparsa(1)
        }
        .padding(.horizontal, Stile.margine)
        .padding(.top, 4)
      }
      .sfondoPagina()
      .navigationTitle("Impostazioni")
    }

    private var divisore: some View {
      Rectangle()
        .fill(Stile.bordo)
        .frame(height: 0.5)
        .padding(.leading, 58)
    }

    /// Una riga che apre la pagina della categoria.
    private func categoria<Contenuto: View>(
      _ titolo: String, simbolo: String, tinta: Color, dettaglio: String,
      @ViewBuilder contenuto: @escaping () -> Contenuto
    ) -> some View {
      NavigationLink {
        PaginaImpostazioni(titolo: titolo, contenuto: contenuto)
      } label: {
        HStack(spacing: 14) {
          Tessera(simbolo: simbolo, tinta: tinta, lato: 32)
          VStack(alignment: .leading, spacing: 2) {
            Text(titolo)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Stile.testo)
            Text(dettaglio)
              .font(.caption)
              .foregroundStyle(Stile.testoTenue)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Stile.testoTenue)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
      }
      .buttonStyle(StilePremuto())
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
        VStack(alignment: .leading, spacing: Stile.traCard) {
          contenuto()
        }
        .padding(.horizontal, Stile.margine)
        .padding(.top, 4)
        .padding(.bottom, 24)
      }
      .sfondoPagina()
      .navigationTitle(titolo)
      .navigationBarTitleDisplayMode(.inline)
    }
  }
#endif
