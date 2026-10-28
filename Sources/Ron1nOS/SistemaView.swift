#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UniformTypeIdentifiers

  private let veloSistema = Color.white.opacity(0.06)

  /// Impostazioni › Integrazioni (IOS-093, SET-009): i servizi collegati con
  /// stato, ultimo controllo e `Verifica`; quelli da configurare dicono quali
  /// variabili mettere nel `.env`.
  struct IntegrazioniView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<[Integrazione]> = .inCorso
    @State private var inVerifica: Set<String> = []

    var body: some View {
      List {
        switch stato {
        case .inCorso:
          Scheletro(righe: 5).listRowBackground(veloSistema)
        case .spento:
          EmptyView()
        case .fallito:
          Text("Integrazioni non disponibili")
            .foregroundStyle(Stile.brandTesto)
            .listRowBackground(veloSistema)
        case .pronto(let elenco):
          ForEach(elenco) { servizio in
            riga(servizio).listRowBackground(veloSistema)
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Integrazioni")
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    private func riga(_ servizio: Integrazione) -> some View {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(servizio.name).foregroundStyle(Stile.testo)
          Spacer()
          Text(servizio.state.testo)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(servizio.state == .error ? Stile.brandTesto : Stile.testoTenue)
        }
        if let messaggio = servizio.message {
          Text(messaggio)
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
        if !servizio.env.isEmpty {
          Text(servizio.env.joined(separator: " · "))
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testo)
            .textSelection(.enabled)
        }
        HStack {
          Text("controllato \(Formato.momento(servizio.checkedAt, fuso: fuso) ?? "·")")
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Button("Verifica") { Task { await verifica(servizio.id) } }
            .buttonStyle(.borderless)
            .tint(Stile.testo)
            .disabled(inVerifica.contains(servizio.id))
        }
      }
      .accessibilityElement(children: .contain)
    }

    private var fuso: TimeZone { sessione.preferenze.formats.fuso }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.integrazioni() }
    }

    private func verifica(_ id: String) async {
      inVerifica.insert(id)
      defer { inVerifica.remove(id) }
      guard let nuovo = try? await sessione.client.verificaIntegrazione(id),
        case .pronto(var elenco) = stato,
        let indice = elenco.firstIndex(where: { $0.id == id })
      else { return }
      elenco[indice] = nuovo
      stato = .pronto(elenco)
    }
  }

  /// Impostazioni › Backup (IOS-093, SET-011): esporta la configurazione in
  /// un file da condividere; importa un file mostrando prima cosa cambia.
  struct BackupView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var condividi: FileDaCondividere?
    @State private var scegli = false
    @State private var file: Data?
    @State private var anteprima: EsitoBackup?
    @State private var messaggio: String?
    @State private var lavoro = false
    private let temporanei = FileTemporanei()

    var body: some View {
      List {
        Section {
          Button("Esporta configurazione") { Task { await esporta() } }
            .disabled(lavoro)
            .listRowBackground(veloSistema)
          Button("Importa da file") { scegli = true }
            .disabled(lavoro)
            .listRowBackground(veloSistema)
        } footer: {
          Text("Preferenze e layout di tutti i dispositivi. Niente dati dei moduli, niente segreti.")
            .foregroundStyle(Stile.testoTenue)
        }
        if let anteprima {
          Section("Importare la configurazione?") {
            if anteprima.nienteDaCambiare {
              Text("Niente da cambiare: è già tutto come nel file.")
                .foregroundStyle(Stile.testoTenue)
                .listRowBackground(veloSistema)
            }
            ForEach(anteprima.changes, id: \.self) { voce in
              Text(voce)
                .foregroundStyle(Stile.testo)
                .listRowBackground(veloSistema)
            }
            ForEach(anteprima.notes, id: \.self) { nota in
              Text(nota)
                .font(.footnote)
                .foregroundStyle(Stile.testoTenue)
                .listRowBackground(veloSistema)
            }
            if !anteprima.nienteDaCambiare {
              Button("Importa") { Task { await importa(conferma: true) } }
                .disabled(lavoro)
                .listRowBackground(veloSistema)
            }
            Button("Annulla", role: .cancel) { chiudiAnteprima() }
              .listRowBackground(veloSistema)
          }
        }
        if let messaggio {
          Text(messaggio)
            .foregroundStyle(Stile.testo)
            .listRowBackground(veloSistema)
        }
      }
      .tint(Stile.testo)
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Backup configurazione")
      .sheet(item: $condividi) { file in
        CondividiFile(url: file.url).presentationDetents([.medium, .large])
      }
      .fileImporter(isPresented: $scegli, allowedContentTypes: [.json]) { risultato in
        guard case .success(let url) = risultato else { return }
        leggi(url)
      }
    }

    private func esporta() async {
      lavoro = true
      defer { lavoro = false }
      do {
        let dati = try await sessione.client.esportaConfigurazione()
        let url = try temporanei.scrivi(dati, nome: EsitoBackup.nomeFile())
        condividi = FileDaCondividere(url: url)
        messaggio = nil
      } catch {
        messaggio = "Esportazione non riuscita."
      }
    }

    private func leggi(_ url: URL) {
      let accesso = url.startAccessingSecurityScopedResource()
      defer { if accesso { url.stopAccessingSecurityScopedResource() } }
      guard let dati = try? Data(contentsOf: url) else {
        messaggio = "File non leggibile."
        return
      }
      file = dati
      Task { await importa(conferma: false) }
    }

    private func importa(conferma: Bool) async {
      guard let file else { return }
      lavoro = true
      defer { lavoro = false }
      do {
        switch try await sessione.client.importaConfigurazione(file, conferma: conferma) {
        case .fatto(let esito):
          if esito.applied {
            chiudiAnteprima()
            messaggio = "Configurazione importata."
            sessione.layoutCambiato += 1
            await sessione.aggiornaPreferenze()
          } else {
            anteprima = esito
            messaggio = nil
          }
        case .rifiutato(let testo):
          chiudiAnteprima()
          messaggio = testo
        }
      } catch {
        messaggio = "Importazione non riuscita."
      }
    }

    private func chiudiAnteprima() {
      anteprima = nil
      file = nil
    }
  }

  /// Impostazioni › Informazioni (IOS-093, SET-012): versione dell'app e
  /// del backend, database, da quanto è acceso, i repository.
  struct InformazioniView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var informazioni: Carico<Informazioni> = .inCorso
    @State private var database: String?

    var body: some View {
      List {
        Section("App") {
          RigaValore(nome: "Versione", valore: versioneApp)
            .listRowBackground(veloSistema)
        }
        Section("Backend") {
          switch informazioni {
          case .inCorso:
            Scheletro(righe: 3).listRowBackground(veloSistema)
          case .spento:
            EmptyView()
          case .fallito:
            Text("non raggiungibile")
              .foregroundStyle(Stile.brandTesto)
              .listRowBackground(veloSistema)
          case .pronto(let info):
            backend(info)
          }
          RigaValore(nome: "Database", valore: database ?? "·")
            .listRowBackground(veloSistema)
        }
        Section("Repository") {
          collegamento("Repository di ron1nOS", Informazioni.repository)
          collegamento("Repository dell'app", Informazioni.repositoryApp)
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Informazioni")
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    @ViewBuilder
    private func backend(_ info: Informazioni) -> some View {
      HStack {
        Text("Commit").foregroundStyle(Stile.testoTenue)
        Spacer()
        if let url = info.indirizzoCommit {
          Link(info.commitBreve, destination: url)
            .font(.system(.body, design: .monospaced))
            .tint(Stile.testo)
        } else {
          Text(info.commitBreve)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
      }
      .listRowBackground(veloSistema)
      RigaValore(nome: "Build", valore: info.version.builtAt.flatMap { momento($0) } ?? "non indicata")
        .listRowBackground(veloSistema)
      RigaValore(nome: "Acceso da", valore: Formato.acceso(info.uptimeSeconds))
        .listRowBackground(veloSistema)
    }

    private func collegamento(_ titolo: String, _ indirizzo: String) -> some View {
      Group {
        if let url = URL(string: indirizzo) {
          Link(titolo, destination: url).tint(Stile.testo)
        }
      }
      .listRowBackground(veloSistema)
    }

    private var versioneApp: String {
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "·"
    }

    private func momento(_ iso: String) -> String? {
      Formato.momento(iso, fuso: sessione.preferenze.formats.fuso)
    }

    private func carica() async {
      let client = sessione.client
      informazioni = await Carico.da { try await client.informazioni() }
      let salute = try? await client.health()
      database = salute?.database.testo ?? "non raggiungibile"
    }
  }
#endif
