#if canImport(SwiftUI)
  import Observation
  import Ron1nKit

  /// Lo stato condiviso dell'app: le credenziali nel Portachiavi e le
  /// preferenze del sito, che decidono la TabBar (IOS-009).
  @MainActor @Observable
  final class Sessione {
    let archivio = Portachiavi()
    let archivioToken = PortachiaviToken()
    var preferenze = Preferenze.predefinite
    /// Cresce a ogni cambio delle credenziali: le pagine ricaricano.
    var versione = 0

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
