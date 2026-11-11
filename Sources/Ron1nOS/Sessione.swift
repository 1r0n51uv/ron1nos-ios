#if canImport(SwiftUI)
  import Combine
  import Foundation
  import Ron1nKit

  /// Le pagine dell'app, nella barra in basso.
  enum Scheda: Hashable {
    case home, nutrizione, torrent, impostazioni
  }

  /// Lo stato condiviso dell'app: l'accesso, la pagina aperta, il toast e un
  /// contatore che dice alle pagine quando i segreti sono cambiati. Niente
  /// macro (`@Observable`): la build sul server usa la toolchain di Linux.
  @MainActor
  final class Sessione: ObservableObject {
    /// Una sola per l'app: la usa anche l'aggiornamento in background.
    static let condivisa = Sessione()

    /// Il service token di Access, la sessione e la password dietro Face ID
    /// stanno nel Portachiavi, nelle stesse voci di prima: chi era già
    /// entrato resta entrato (IOS-019).
    let autenticazione = Autenticazione(
      token: Portachiavi(),
      cookie: PortachiaviTesto(servizio: "home.ron1n.ios.sessione-ron1nos"),
      password: PortachiaviTesto(servizio: "home.ron1n.ios.password-ron1nos", conFaceID: true))

    /// Le notifiche locali dei download (IOS-075).
    let notifiche = NotificheTorrent()
    /// I promemoria dei pasti programmati (IOS-035).
    let promemoriaPasti = PromemoriaNutrizione()

    /// Cresce a ogni cambio dei segreti: le pagine ricaricano.
    @Published private(set) var versione = 0
    /// La pagina aperta nella barra.
    @Published var scheda = Scheda.home
    /// Da dove parte il wizard Aggiungi, se è aperto (IOS-071).
    @Published var torrentInArrivo: TorrentInArrivo?
    /// Il toast in basso e cosa fa il suo pulsante.
    @Published private(set) var avviso: Avviso?
    private var azioneAvviso: (@MainActor () -> Void)?

    /// Le preferenze del sito: gli orari dei pasti e le unità. Finché non
    /// arrivano valgono i predefiniti.
    @Published private(set) var preferenze: Preferenze?

    var promemoria: Promemoria { preferenze?.reminders ?? .predefiniti }
    var formati: Formati { preferenze?.formats ?? Formati() }

    var client: APIClient { autenticazione.client() }

    init() {
      promemoriaPasti.registraCategorie()
    }

    func cambiato() { versione += 1 }

    /// Un `.torrent` o un link `magnet:` aperto con ron1nOS: va al wizard,
    /// nella pagina Torrent.
    func apri(file url: URL) {
      if url.scheme?.lowercased() == "magnet" {
        scheda = .torrent
        torrentInArrivo = .link(url.absoluteString)
      } else if url.pathExtension.lowercased() == "torrent", let torrent = TorrentInArrivo.leggi(url) {
        scheda = .torrent
        torrentInArrivo = torrent
      }
    }

    /// Mostra il toast; ne resta uno solo, l'ultimo.
    func mostra(_ nuovo: Avviso, azione: (@MainActor () -> Void)? = nil) {
      avviso = nuovo
      azioneAvviso = azione
      Task {
        try? await Task.sleep(nanoseconds: UInt64(nuovo.durata * 1_000_000_000))
        if avviso?.id == nuovo.id { avviso = nil }
      }
    }

    /// Il pulsante del toast: esegue l'azione e lo chiude.
    func eseguiAvviso() {
      let azione = azioneAvviso
      avviso = nil
      azioneAvviso = nil
      azione?()
    }

    /// Dopo aver letto i download: programma e manda le notifiche. Il
    /// permesso si chiede solo dalla pagina Torrent.
    func letti(_ download: Download, chiediPermesso: Bool = false) {
      Task { await notifiche.aggiorna(con: download, chiediPermesso: chiediPermesso) }
    }

    /// L'aggiornamento in background di iOS: rilegge i download e i pasti e
    /// ricalcola le notifiche.
    func controllaTorrent() async {
      if let download = try? await client.download() {
        await notifiche.aggiorna(con: download, chiediPermesso: false)
      }
      await aggiornaPreferenze()
      await ricalcolaPromemoria()
    }

    func aggiornaPreferenze() async {
      if let lette = try? await client.preferenze() { preferenze = lette }
    }

    /// Salva gli orari dei pasti nelle preferenze e rifà i promemoria.
    func salvaOrari(_ orari: Promemoria) async -> Bool {
      do {
        preferenze = try await client.salvaPromemoria(orari)
        await ricalcolaPromemoria()
        return true
      } catch {
        return false
      }
    }

    /// Rifà i promemoria dei pasti; con `chiediPermesso`, la prima volta,
    /// compare la richiesta di iOS.
    func ricalcolaPromemoria(chiediPermesso: Bool = false) async {
      await promemoriaPasti.ricalcola(
        client: client, promemoria: promemoria, chiediPermesso: chiediPermesso)
    }

    /// Segna un pasto programmato mangiato; ricarica le pagine.
    func conferma(piano: String, mangiato: Bool = true) async -> Bool {
      do {
        try await client.statoPiano(piano, mangiato ? "eaten" : "planned")
        cambiato()
        await ricalcolaPromemoria()
        return true
      } catch {
        return false
      }
    }
  }
#endif
