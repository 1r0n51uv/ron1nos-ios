#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Impostazioni (IOS-090, SET-001): quattro gruppi, ogni riga con lo
  /// stato in breve a destra.
  struct ImpostazioniView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: StatoImpostazioni?

    var body: some View {
      List {
        ForEach(VoceImpostazioni.gruppi, id: \.titolo) { gruppo in
          Section(gruppo.titolo) {
            ForEach(gruppo.voci, id: \.self) { voce in
              NavigationLink(value: ImpostazioniView.pagina(voce)) {
                RigaImpostazione(
                  voce: voce, riepilogo: stato?.riepilogo(voce), segnale: stato?.segnale(voce) ?? false)
              }
              .listRowBackground(Color.white.opacity(0.06))
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Impostazioni")
      .refreshable { await carica() }
      .task(id: "\(sessione.versione)-\(sessione.layoutCambiato)") { await carica() }
      .onChange(of: sessione.preferenze) { _, nuove in stato?.preferenze = nuove }
    }

    /// Accesso e Notifiche hanno già le loro pagine.
    static func pagina(_ voce: VoceImpostazioni) -> Pagina {
      switch voce {
      case .accesso: .accesso
      case .notifiche: .notifiche
      default: .impostazione(voce)
      }
    }

    private func carica() async {
      let client = sessione.client
      var nuovo = StatoImpostazioni(
        preferenze: sessione.preferenze, credenziali: sessione.archivio.carica() != nil,
        notificheAccese: sessione.notifiche.scelte.accesi.count,
        versioneApp: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
      if stato == nil { stato = nuovo }
      async let login = StatoLogin.verifica(con: client)
      async let layout = Carico.da { try await client.layoutHome() }
      async let sessioni = Carico.da { try await client.sessioniWeb() }
      async let token = Carico.da { try await client.tokenApp() }
      async let integrazioni = Carico.da { try await client.integrazioni() }
      nuovo.login = await login
      nuovo.widget = await layout.valore?.items.count
      nuovo.sessioni = await sessioni.valore?.count
      nuovo.token = await token.valore?.count
      nuovo.integrazioni = await integrazioni.valore
      stato = nuovo
    }
  }

  /// Icona, titolo e a destra lo stato in breve, rosso se è un problema.
  struct RigaImpostazione: View {
    let voce: VoceImpostazioni
    let riepilogo: String?
    let segnale: Bool

    var body: some View {
      HStack {
        Label(voce.titolo, systemImage: voce.icona)
          .foregroundStyle(Stile.testo)
        Spacer()
        if let riepilogo {
          Text(riepilogo)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(segnale ? Stile.brand : Stile.testoTenue)
            .lineLimit(1)
        }
      }
      .accessibilityElement(children: .combine)
    }
  }

  /// La pagina di una sezione delle Impostazioni.
  struct SezioneImpostazioni: View {
    let voce: VoceImpostazioni

    var body: some View {
      switch voce {
      case .aspetto: AspettoView()
      case .dashboard: DashboardImpostazioniView()
      case .moduli: ModuliView()
      case .navigazione: NavigazioneView()
      case .formati: FormatiView()
      default: inArrivo
      }
    }

    private var inArrivo: some View {
      ScrollView {
        Text("La sezione \(voce.titolo) arriva con i prossimi aggiornamenti dell'app.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
          .frame(maxWidth: .infinity, alignment: .leading)
          .glassPanel()
          .padding(.horizontal, 16)
          .padding(.top, 8)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle(voce.titolo)
    }
  }
#endif
