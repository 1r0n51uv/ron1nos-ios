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
#endif
