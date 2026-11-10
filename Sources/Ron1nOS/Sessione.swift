#if canImport(SwiftUI)
  import Combine
  import Ron1nKit

  /// Lo stato condiviso dell'app: l'accesso e un contatore che dice alle
  /// pagine quando i segreti sono cambiati. Niente macro (`@Observable`): la
  /// build sul server usa la toolchain di Linux.
  @MainActor
  final class Sessione: ObservableObject {
    /// Una sola per l'app.
    static let condivisa = Sessione()

    /// Il service token di Access, la sessione e la password dietro Face ID
    /// stanno nel Portachiavi, nelle stesse voci di prima: chi era già
    /// entrato resta entrato (IOS-019).
    let autenticazione = Autenticazione(
      token: Portachiavi(),
      cookie: PortachiaviTesto(servizio: "home.ron1n.ios.sessione-ron1nos"),
      password: PortachiaviTesto(servizio: "home.ron1n.ios.password-ron1nos", conFaceID: true))

    /// Cresce a ogni cambio dei segreti: le pagine ricaricano.
    @Published private(set) var versione = 0

    func cambiato() { versione += 1 }
  }
#endif
