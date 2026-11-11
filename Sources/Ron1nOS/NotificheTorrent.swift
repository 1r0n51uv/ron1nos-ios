#if canImport(SwiftUI)
  import BackgroundTasks
  import Foundation
  import Ron1nKit
  import UserNotifications

  /// Le notifiche locali dei download (IOS-075). Con SideStore e un Apple ID
  /// gratuito le push non ci sono: il telefono programma da sé una notifica
  /// all'ora di fine prevista e ne manda una quando vede un download finito.
  /// Cosa programmare lo decide `PianoNotificheTorrent` di Ron1nKit.
  @MainActor
  final class NotificheTorrent {
    /// L'aggiornamento in background di iOS, quando lo concede.
    static let compito = "home.ron1n.ios.notifiche"

    private static let chiave = "torrent.inDownload"
    private var centro: UNUserNotificationCenter { .current() }

    init() {
      centro.delegate = RispostaNotifiche.condivisa
    }

    /// Applica il piano ai download appena letti. Con `chiediPermesso` la
    /// prima volta compare la richiesta di iOS; senza, se il permesso non
    /// c'è, non si manda niente.
    func aggiorna(con download: Download, chiediPermesso: Bool) async {
      let prima = Set(UserDefaults.standard.stringArray(forKey: NotificheTorrent.chiave) ?? [])
      let piano = PianoNotificheTorrent.piano(download: download, prima: prima)
      UserDefaults.standard.set(Array(piano.inDownload), forKey: NotificheTorrent.chiave)

      guard await permesso(chiedi: chiediPermesso) else { return }
      centro.removePendingNotificationRequests(
        withIdentifiers: piano.annulla + piano.programma.map(\.id))
      for notifica in piano.programma + piano.finiti {
        try? await centro.add(richiesta(notifica))
      }
      if !piano.inDownload.isEmpty { pianificaAggiornamento() }
    }

    /// Com'è messo il telefono: il permesso di iOS e gli avvisi in attesa.
    struct Stato: Equatable {
      let permesso: String
      let programmati: Int
      /// Fra quanti secondi parte il prossimo, se ce n'è uno.
      let prossimo: TimeInterval?
    }

    func stato() async -> Stato {
      let impostazioni = await centro.notificationSettings()
      let permesso =
        switch impostazioni.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "consentite"
        case .denied: "negate"
        default: "da chiedere"
        }
      let attesa = await centro.pendingNotificationRequests().filter { $0.identifier.hasPrefix("torrent-") }
      let date = attesa.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() }
      return Stato(
        permesso: permesso, programmati: attesa.count,
        prossimo: date.min().map { $0.timeIntervalSinceNow })
    }

    /// Chiede il permesso e manda un avviso di prova fra 10 secondi: per
    /// vederlo in background basta uscire dall'app.
    func prova() async -> Bool {
      guard await permesso(chiedi: true) else { return false }
      let contenuto = UNMutableNotificationContent()
      contenuto.title = "Prova degli avvisi"
      contenuto.body = "Gli avvisi dei download arrivano così."
      contenuto.sound = .default
      let richiesta = UNNotificationRequest(
        identifier: "prova-avvisi", content: contenuto,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false))
      try? await centro.add(richiesta)
      return true
    }

    private func permesso(chiedi: Bool) async -> Bool {
      var stato = await centro.notificationSettings().authorizationStatus
      if stato == .notDetermined, chiedi {
        _ = try? await centro.requestAuthorization(options: [.alert, .sound])
        stato = await centro.notificationSettings().authorizationStatus
      }
      return stato == .authorized || stato == .provisional
    }

    private func richiesta(_ notifica: NotificaTorrent) -> UNNotificationRequest {
      let contenuto = UNMutableNotificationContent()
      contenuto.title = notifica.titolo
      contenuto.body = notifica.corpo
      contenuto.sound = .default
      let quando = notifica.tra.map {
        UNTimeIntervalNotificationTrigger(timeInterval: $0, repeats: false)
      }
      return UNNotificationRequest(identifier: notifica.id, content: contenuto, trigger: quando)
    }

    /// Chiede a iOS di svegliare l'app fra un quarto d'ora per riguardare i
    /// download, finché ce n'è uno in corso.
    private func pianificaAggiornamento() {
      let richiesta = BGAppRefreshTaskRequest(identifier: NotificheTorrent.compito)
      richiesta.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
      try? BGTaskScheduler.shared.submit(richiesta)
    }
  }

  /// Riceve le notifiche con l'app aperta e i tocchi su di esse, anche con
  /// l'app chiusa. Senza questo iOS non mostra nulla mentre l'app è in
  /// primo piano.
  final class RispostaNotifiche: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let condivisa = RispostaNotifiche()

    /// Con l'app aperta la notifica si vede lo stesso, in alto.
    func userNotificationCenter(
      _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
      [.banner, .sound]
    }

    /// `Mangiato` segna il pasto, `Rimanda` ripropone l'avviso fra 30 minuti,
    /// un tocco apre la pagina del pasto o dei torrent.
    func userNotificationCenter(
      _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
      let richiesta = response.notification.request
      switch response.actionIdentifier {
      case AzioniPasto.si:
        guard let piano = richiesta.content.userInfo["piano"] as? String else { return }
        _ = await Sessione.condivisa.conferma(piano: piano)
      case AzioniPasto.rimanda:
        guard let copia = richiesta.content.mutableCopy() as? UNMutableNotificationContent else { return }
        let fra = UNTimeIntervalNotificationTrigger(timeInterval: PromemoriaPasti.rinvio, repeats: false)
        let rimandata = UNNotificationRequest(
          identifier: "\(richiesta.identifier)-rimandata", content: copia, trigger: fra)
        try? await center.add(rimandata)
      default:
        let pasto = richiesta.identifier.hasPrefix("pasto-")
        await MainActor.run { Sessione.condivisa.scheda = pasto ? .nutrizione : .torrent }
      }
    }
  }
#endif
