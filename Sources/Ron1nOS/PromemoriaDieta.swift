#if canImport(SwiftUI)
  import Foundation
  import Ron1nKit
  import UserNotifications

  /// I promemoria dei pasti e dell'acqua (IOS-041): li prepara il telefono
  /// dal giorno di oggi e di domani, e risponde ai pulsanti `Sì` e
  /// `Rimanda`.
  @MainActor
  enum PromemoriaApp {
    nonisolated static let si = "si"
    nonisolated static let rimanda = "rimanda"

    /// La categoria dei pasti pianificati, con i due pulsanti.
    static func registraCategorie() {
      let si = UNNotificationAction(identifier: PromemoriaApp.si, title: "Sì", options: [])
      let rimanda = UNNotificationAction(identifier: PromemoriaApp.rimanda, title: "Rimanda", options: [])
      let pasto = UNNotificationCategory(
        identifier: PromemoriaDieta.categoriaPasto, actions: [si, rimanda], intentIdentifiers: [])
      UNUserNotificationCenter.current().setNotificationCategories([pasto])
    }

    /// Le notifiche di oggi e domani con gli orari delle preferenze.
    static func notifiche(
      client: APIClient, promemoria: Promemoria, fuso: TimeZone
    ) async -> [NotificaLocale] {
      let striscia = Striscia(fuso: fuso)
      var giorni: [GiornoDieta] = []
      for giorno in striscia.giorni.dropFirst(Striscia.indietro).prefix(2) {
        // Un modulo spento o un backend che non risponde: niente promemoria.
        guard let letto = try? await client.dieta(giorno.id) else { return [] }
        giorni.append(letto)
      }
      return PromemoriaDieta.notifiche(
        giorni: giorni, promemoria: promemoria, oggi: striscia.oggi, adesso: Date(), fuso: fuso)
    }

    /// `Sì` segna mangiato il pasto pianificato e ricalcola le notifiche.
    static func mangiato(piano: String) async {
      let sessione = Sessione.condivisa
      try? await sessione.client.statoPiano(piano, "eaten")
      await sessione.ricalcolaNotifiche()
    }
  }

  /// Riceve i tocchi sulle notifiche, anche ad app chiusa.
  final class RispostaNotifiche: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let condivisa = RispostaNotifiche()

    func userNotificationCenter(
      _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
      let richiesta = response.notification.request
      switch response.actionIdentifier {
      case PromemoriaApp.si:
        guard let piano = richiesta.content.userInfo["piano"] as? String else { return }
        await PromemoriaApp.mangiato(piano: piano)
      case PromemoriaApp.rimanda:
        // Rimanda: la stessa notifica fra 30 minuti.
        guard let copia = richiesta.content.mutableCopy() as? UNMutableNotificationContent else { return }
        let fra = UNTimeIntervalNotificationTrigger(timeInterval: PromemoriaDieta.rinvio, repeats: false)
        let rimandata = UNNotificationRequest(
          identifier: "\(richiesta.identifier)-rimandata", content: copia, trigger: fra)
        try? await center.add(rimandata)
      default:
        break
      }
    }

    /// Con l'app aperta la notifica si vede lo stesso, in alto.
    func userNotificationCenter(
      _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
      [.banner, .sound]
    }
  }
#endif
