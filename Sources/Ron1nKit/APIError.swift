import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Perché una chiamata all'API non è andata, detto in modo che si sappia
/// cosa controllare. Gli errori di rete portano il codice di URLError
/// (IOS-002), da mostrare così com'è.
public enum APIError: Error, Equatable, Sendable {
  /// Nessuna risposta: server spento, Tailscale spento o nome non risolto.
  case nonRaggiungibile(codice: Int?)
  /// Connessione rifiutata per il certificato: CA di Caddy mancante o non
  /// attivata. `tls` è il codice di Secure Transport sotto (-98xx), se c'è.
  case certificato(codice: Int, tls: Int? = nil)
  /// Il server ha risposto con un codice HTTP di errore.
  case stato(Int)
  /// Ha risposto, ma non con quello che l'app si aspetta.
  case rispostaInattesa(codice: Int?)

  /// Da -1200 a -1206: TLS fallito, certificato scaduto, non attendibile,
  /// radice sconosciuta, non ancora valido, certificato client.
  static let codiciCertificato = -1206 ... -1200

  init(_ error: Error) {
    guard let urlError = error as? URLError else {
      self = .nonRaggiungibile(codice: nil)
      return
    }
    let codice = urlError.code.rawValue
    switch urlError.code {
    case _ where APIError.codiciCertificato.contains(codice):
      self = .certificato(codice: codice, tls: APIError.codiceTLS(urlError))
    case .badServerResponse, .cannotParseResponse, .cannotDecodeContentData:
      self = .rispostaInattesa(codice: codice)
    default:
      self = .nonRaggiungibile(codice: codice)
    }
  }

  /// Il codice di Secure Transport che CFNetwork mette nello userInfo, o
  /// in quello dell'errore sottostante.
  static func codiceTLS(_ urlError: URLError) -> Int? {
    let chiave = "_kCFStreamErrorCodeKey"
    if let codice = urlError.userInfo[chiave] as? Int { return codice }
    if let sotto = urlError.userInfo[NSUnderlyingErrorKey] as? NSError {
      return sotto.userInfo[chiave] as? Int
    }
    return nil
  }

  /// Titolo breve, per la schermata.
  public var titolo: String {
    switch self {
    case .nonRaggiungibile: "Server non raggiungibile"
    case .certificato: "Certificato non attendibile"
    case .stato(let codice): "Errore del server · \(codice)"
    case .rispostaInattesa: "Risposta inattesa"
    }
  }

  /// Cosa controllare.
  public var suggerimento: String {
    switch self {
    case .nonRaggiungibile:
      "Controlla che Tailscale sia acceso sul telefono e che il server sia nella tailnet. "
        + "iOS tiene accesa una sola VPN: con quella di SideStore attiva, Tailscale è spento."
    case .certificato:
      "Installa il certificato da ca.ron1n.home, poi attivalo in Impostazioni › Generali › Info › "
        + "Impostazioni certificati attendibili. Safari entra anche senza, l'app no."
    case .stato(401), .stato(403):
      "Il server chiede il login, che questa versione dell'app non ha ancora."
    case .stato:
      "Il backend ron1nOS ha un problema: guarda i suoi log sul server."
    case .rispostaInattesa:
      "All'indirizzo risponde qualcosa che non è il backend ron1nOS."
    }
  }

  /// Il codice preciso, per capire senza log: "URLError -1202", "HTTP 503".
  public var dettaglio: String? {
    switch self {
    case .certificato(let codice, let tls?): "URLError \(codice) · TLS \(tls)"
    case .nonRaggiungibile(let codice?), .rispostaInattesa(let codice?), .certificato(let codice, nil):
      "URLError \(codice)"
    case .stato(let codice): "HTTP \(codice)"
    case .nonRaggiungibile(nil), .rispostaInattesa(nil): nil
    }
  }
}
