#if canImport(SwiftUI)
  import Foundation
  import Ron1nKit
  import UserNotifications

  /// I nomi delle azioni sui promemoria dei pasti: fuori dall'attore perché
  /// li legge anche il delegato delle notifiche.
  enum AzioniPasto {
    static let si = "pasto-mangiato"
    static let rimanda = "pasto-rimanda"
  }

  /// I promemoria dei pasti programmati (IOS-035): una notifica locale
  /// all'orario di ogni pasto ancora da spuntare, con `Mangiato` e `Rimanda`.
  /// Quali sono lo decide `PromemoriaPasti` di Ron1nKit.
  @MainActor
  final class PromemoriaNutrizione {
    private var centro: UNUserNotificationCenter { .current() }

    /// I pulsanti `Mangiato` e `Rimanda 30 min` sotto la notifica.
    func registraCategorie() {
      let mangiato = UNNotificationAction(identifier: AzioniPasto.si, title: "Mangiato", options: [])
      let rimanda = UNNotificationAction(
        identifier: AzioniPasto.rimanda, title: "Rimanda 30 min", options: [])
      let categoria = UNNotificationCategory(
        identifier: PromemoriaPasti.categoria, actions: [mangiato, rimanda], intentIdentifiers: [],
        options: [])
      centro.setNotificationCategories([categoria])
    }

    /// Rifà i promemoria dei prossimi giorni: toglie quelli in attesa e
    /// programma quelli di adesso. Con `chiediPermesso` la prima volta
    /// compare la richiesta di iOS; senza, se il permesso non c'è, non si
    /// fa niente.
    func ricalcola(client: APIClient, promemoria: Promemoria, chiediPermesso: Bool) async {
      guard await permesso(chiedi: chiediPermesso) else { return }
      let adesso = Date()
      let questa = Settimana.lunedi(di: adesso)
      let prossima = Settimana.lunedi(di: adesso, piu: 1)
      var settimane: [SettimanaNutrizione] = []
      for lunedi in [questa, prossima] {
        if let letta = try? await client.settimana(da: lunedi) { settimane.append(letta) }
      }
      // Senza rete restano i promemoria di prima.
      guard !settimane.isEmpty else { return }
      let nuovi = PromemoriaPasti.notifiche(
        settimane: settimane, promemoria: promemoria, adesso: adesso)
      let attese = await centro.pendingNotificationRequests().map(\.identifier)
      centro.removePendingNotificationRequests(withIdentifiers: attese.filter { $0.hasPrefix("pasto-") })
      for notifica in nuovi {
        try? await centro.add(richiesta(notifica))
      }
    }

    private func permesso(chiedi: Bool) async -> Bool {
      var stato = await centro.notificationSettings().authorizationStatus
      if stato == .notDetermined, chiedi {
        _ = try? await centro.requestAuthorization(options: [.alert, .sound])
        stato = await centro.notificationSettings().authorizationStatus
      }
      return stato == .authorized || stato == .provisional
    }

    private func richiesta(_ notifica: NotificaPasto) -> UNNotificationRequest {
      let contenuto = UNMutableNotificationContent()
      contenuto.title = notifica.titolo
      contenuto.body = notifica.corpo
      contenuto.sound = .default
      contenuto.categoryIdentifier = PromemoriaPasti.categoria
      contenuto.userInfo = notifica.dati
      let fra = UNTimeIntervalNotificationTrigger(
        timeInterval: max(1, notifica.quando.timeIntervalSinceNow), repeats: false)
      return UNNotificationRequest(identifier: notifica.id, content: contenuto, trigger: fra)
    }
  }
#endif
