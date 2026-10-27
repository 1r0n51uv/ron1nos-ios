#if canImport(SwiftUI)
  import BackgroundTasks
  import Combine
  import Ron1nKit
  import UserNotifications

  /// Le notifiche locali dell'app (IOS-011): con SideStore e un Apple ID
  /// gratuito le push non ci sono, quindi le programma il telefono a partire
  /// dai dati letti dall'API.
  @MainActor
  final class CentroNotifiche: ObservableObject {
    /// L'aggiornamento in background di iOS, quando lo concede.
    static let compito = "home.ron1n.ios.notifiche"

    @Published private(set) var scelte: ScelteNotifiche
    @Published private(set) var permesso: UNAuthorizationStatus = .notDetermined
    private let memoria = MemoriaNotifiche()
    private var centro: UNUserNotificationCenter { .current() }

    /// Chi prepara le notifiche di un gruppo: le aggiungono i moduli
    /// (promemoria dei pasti IOS-041, scadenze IOS-065).
    private var sorgenti: [@MainActor (APIClient) async -> [NotificaLocale]] = []

    init() {
      scelte = memoria.carica()
    }

    func aggiungi(sorgente: @escaping @MainActor (APIClient) async -> [NotificaLocale]) {
      sorgenti.append(sorgente)
    }

    func leggiPermesso() async {
      permesso = await centro.notificationSettings().authorizationStatus
    }

    /// Il permesso si chiede la prima volta che si accende un gruppo, mai
    /// all'avvio. Se iOS lo nega il gruppo resta spento.
    func imposta(_ gruppo: GruppoNotifiche, acceso: Bool, client: APIClient) async {
      if acceso {
        await leggiPermesso()
        if permesso == .notDetermined {
          _ = try? await centro.requestAuthorization(options: [.alert, .sound, .badge])
          await leggiPermesso()
        }
        guard permesso == .authorized || permesso == .provisional else { return }
      }
      scelte.imposta(gruppo, acceso: acceso)
      memoria.salva(scelte)
      await ricalcola(client: client)
    }

    /// Toglie le notifiche in attesa e programma quelle di adesso. Si chiama
    /// a ogni apertura dell'app e dall'aggiornamento in background.
    func ricalcola(client: APIClient) async {
      var candidate: [NotificaLocale] = []
      if !scelte.accesi.isEmpty {
        for sorgente in sorgenti {
          candidate += await sorgente(client)
        }
      }
      let daProgrammare = PianoNotifiche.scegli(candidate, scelte: scelte, adesso: Date())
      centro.removeAllPendingNotificationRequests()
      for notifica in daProgrammare {
        try? await centro.add(richiesta(notifica))
      }
      pianificaAggiornamento()
    }

    private func richiesta(_ notifica: NotificaLocale) -> UNNotificationRequest {
      let contenuto = UNMutableNotificationContent()
      contenuto.title = notifica.titolo
      contenuto.body = notifica.corpo
      contenuto.sound = .default
      contenuto.userInfo = notifica.dati
      if let categoria = notifica.categoria { contenuto.categoryIdentifier = categoria }
      let componenti = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: notifica.quando)
      let quando = UNCalendarNotificationTrigger(dateMatching: componenti, repeats: false)
      return UNNotificationRequest(identifier: notifica.id, content: contenuto, trigger: quando)
    }

    /// Chiede a iOS di svegliare l'app fra qualche ora per ricalcolare.
    private func pianificaAggiornamento() {
      let richiesta = BGAppRefreshTaskRequest(identifier: CentroNotifiche.compito)
      richiesta.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3_600)
      try? BGTaskScheduler.shared.submit(richiesta)
    }
  }
#endif
