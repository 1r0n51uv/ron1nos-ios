#if canImport(SwiftUI)
  import Combine
  import Ron1nKit
  import UIKit
  import UserNotifications

  /// Lo stato condiviso dell'app: le credenziali nel Portachiavi e le
  /// preferenze del sito, che decidono la TabBar (IOS-009). Niente macro
  /// (`@Observable`): la build sul server usa la toolchain di Linux.
  @MainActor
  final class Sessione: ObservableObject {
    /// Una sola per l'app: la usa anche l'aggiornamento in background.
    static let condivisa = Sessione()

    let archivio = Portachiavi()
    let archivioToken = PortachiaviToken()
    /// Finché il backend non risponde valgono le ultime salvate sul
    /// telefono, poi i predefiniti (IOS-010).
    @Published var preferenze: Preferenze
    /// L'immagine di sfondo caricata sul sito, se in uso.
    @Published var immagineSfondo: UIImage?
    private let memoria = MemoriaPreferenze()
    /// Le notifiche locali di questo telefono (IOS-011).
    let notifiche = CentroNotifiche()
    /// Una pagina da aprire dalla Home (un widget toccato): la apre la TabBar.
    @Published var daAprire: Scheda?
    /// Il toast in basso (IOS-012) e cosa fa il suo pulsante.
    @Published private(set) var avviso: Avviso?
    private var azioneAvviso: (@MainActor () -> Void)?
    /// Cresce a ogni cambio delle credenziali: le pagine ricaricano.
    @Published var versione = 0
    /// Un CSV di Liftin' arrivato dal foglio di condivisione (IOS-051).
    @Published var csvInArrivo: FileCSV?
    /// Il wizard `Aggiungi` dei Torrent da aprire (IOS-071).
    @Published var torrentInArrivo: TorrentInArrivo?
    /// Cresce dopo un import o un'eliminazione: la Palestra ricarica.
    @Published var palestraCambiata = 0
    /// Cresce a ogni modifica dei Documenti: l'elenco si ricarica.
    @Published var documentiCambiati = 0
    /// Face ID per i Documenti (IOS-064).
    @Published var blocco = BloccoDocumenti(defaults: .standard)

    var client: APIClient {
      APIClient(credenziali: archivio.carica(), token: archivioToken.carica())
    }

    var navigazione: Navigazione { Navigazione(preferenze) }

    init() {
      preferenze = memoria.carica() ?? .predefinite
      // I promemoria dei pasti e dell'acqua (IOS-041).
      PromemoriaApp.registraCategorie()
      UNUserNotificationCenter.current().delegate = RispostaNotifiche.condivisa
      notifiche.aggiungi { [weak self] client in
        guard let self else { return [] }
        return await PromemoriaApp.notifiche(
          client: client, promemoria: self.preferenze.reminders, fuso: self.preferenze.formats.fuso)
      }
      // Gli avvisi di scadenza dei Documenti (IOS-065).
      notifiche.aggiungi { [weak self] client in
        guard let self, let documenti = try? await client.elencoDocumenti(FiltroDocumenti()) else {
          return []
        }
        return AvvisiScadenze.notifiche(documenti, adesso: Date(), fuso: self.preferenze.formats.fuso)
      }
    }

    /// Salva gli orari dei promemoria e riprogramma le notifiche.
    func salvaPromemoria(_ promemoria: Promemoria) async -> Bool {
      guard let salvate = try? await client.salvaPromemoria(promemoria) else { return false }
      preferenze = salvate
      memoria.salva(salvate)
      await ricalcolaNotifiche()
      return true
    }

    /// Se la lettura non riesce restano le preferenze di prima.
    func aggiornaPreferenze() async {
      guard let lette = try? await client.preferenze() else { return }
      if lette != preferenze { preferenze = lette }
      memoria.salva(lette)
      await caricaSfondo()
    }

    /// L'immagine si scarica solo se è in uso e non c'è già.
    private func caricaSfondo() async {
      guard preferenze.sfondo == .image, let versione = preferenze.backgroundImage else {
        immagineSfondo = nil
        return
      }
      if immagineSfondo != nil, versioneSfondo == versione { return }
      if let dati = try? await client.immagineSfondo(versione: versione), let immagine = UIImage(data: dati) {
        immagineSfondo = immagine
        versioneSfondo = versione
      }
    }

    private var versioneSfondo: String?

    /// Un file o un link aperto con ron1nOS: un CSV va all'import della
    /// Palestra, un `.torrent` o un `magnet:` al wizard dei Torrent.
    func apri(file url: URL) {
      if url.scheme?.lowercased() == "magnet" {
        daAprire = .torrent
        torrentInArrivo = .link(url.absoluteString)
        return
      }
      switch url.pathExtension.lowercased() {
      case "csv":
        guard let file = FileCSV.leggi(url) else { return }
        daAprire = .palestra
        csvInArrivo = file
      case "torrent":
        guard let torrent = TorrentInArrivo.leggi(url) else { return }
        daAprire = .torrent
        torrentInArrivo = torrent
      default:
        return
      }
    }

    func apri(_ scheda: Scheda) {
      daAprire = scheda
    }

    /// Il documento di un avviso di scadenza (IOS-065): si apre nella sua
    /// scheda, dietro Face ID.
    @Published var documentoDaAprire: String?

    func apri(documento id: String) {
      documentoDaAprire = id
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

    /// Ricalcola le notifiche locali: all'apertura e in background.
    func ricalcolaNotifiche() async {
      await notifiche.ricalcola(client: client)
    }

    /// Le credenziali sono cambiate in Accesso.
    func credenzialiCambiate() {
      versione += 1
      Task { await aggiornaPreferenze() }
    }
  }
#endif
