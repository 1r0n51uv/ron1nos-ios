#if canImport(SwiftUI)
  import Combine
  import Ron1nKit

  /// Lo stato condiviso dell'app: le credenziali nel Portachiavi e le
  /// preferenze del sito, che decidono la TabBar (IOS-009). Niente macro
  /// (`@Observable`): la build sul server usa la toolchain di Linux.
  @MainActor
  final class Sessione: ObservableObject {
    let archivio = Portachiavi()
    let archivioToken = PortachiaviToken()
    @Published var preferenze = Preferenze.predefinite
    /// Cresce a ogni cambio delle credenziali: le pagine ricaricano.
    @Published var versione = 0

    var client: APIClient {
      APIClient(credenziali: archivio.carica(), token: archivioToken.carica())
    }

    var navigazione: Navigazione { Navigazione(preferenze) }

    /// Se la lettura non riesce restano le preferenze di prima.
    func aggiornaPreferenze() async {
      if let lette = try? await client.preferenze() {
        preferenze = lette
      }
    }

    /// Le credenziali sono cambiate in Accesso.
    func credenzialiCambiate() {
      versione += 1
      Task { await aggiornaPreferenze() }
    }
  }
#endif
