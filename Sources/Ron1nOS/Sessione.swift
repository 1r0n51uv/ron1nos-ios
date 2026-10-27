#if canImport(SwiftUI)
  import Combine
  import Ron1nKit
  import UIKit

  /// Lo stato condiviso dell'app: le credenziali nel Portachiavi e le
  /// preferenze del sito, che decidono la TabBar (IOS-009). Niente macro
  /// (`@Observable`): la build sul server usa la toolchain di Linux.
  @MainActor
  final class Sessione: ObservableObject {
    let archivio = Portachiavi()
    let archivioToken = PortachiaviToken()
    /// Finché il backend non risponde valgono le ultime salvate sul
    /// telefono, poi i predefiniti (IOS-010).
    @Published var preferenze: Preferenze
    /// L'immagine di sfondo caricata sul sito, se in uso.
    @Published var immagineSfondo: UIImage?
    private let memoria = MemoriaPreferenze()
    /// Il toast in basso (IOS-012) e cosa fa il suo pulsante.
    @Published private(set) var avviso: Avviso?
    private var azioneAvviso: (@MainActor () -> Void)?
    /// Cresce a ogni cambio delle credenziali: le pagine ricaricano.
    @Published var versione = 0

    var client: APIClient {
      APIClient(credenziali: archivio.carica(), token: archivioToken.carica())
    }

    var navigazione: Navigazione { Navigazione(preferenze) }

    init() {
      preferenze = memoria.carica() ?? .predefinite
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

    /// Le credenziali sono cambiate in Accesso.
    func credenzialiCambiate() {
      versione += 1
      Task { await aggiornaPreferenze() }
    }
  }
#endif
