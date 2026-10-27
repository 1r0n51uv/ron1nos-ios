import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Perché una chiamata all'API non è andata, detto in modo che si sappia
/// cosa controllare. Gli errori di rete portano il codice di URLError
/// (IOS-002), da mostrare così com'è.
public enum APIError: Error, Equatable, Sendable {
  /// Nessuna risposta: telefono offline, server o tunnel spenti, nome non
  /// risolto.
  case nonRaggiungibile(codice: Int?)
  /// Connessione rifiutata per il certificato, che iOS non accetta. `tls` è il codice di Secure Transport sotto (-98xx), se c'è;
  /// `motivo` quello che dice la valutazione del certificato di iOS.
  case certificato(codice: Int, tls: Int? = nil, motivo: String? = nil)
  /// Cloudflare Access ha fermato la richiesta: manca il service token, o
  /// quello salvato non vale più (IOS-004).
  case accesso(conToken: Bool)
  /// ron1nOS chiede il login (HTTP 401): manca il token dell'app, o quello
  /// salvato è stato revocato (IOS-005).
  case login(conToken: Bool)
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
      self = .certificato(
        codice: codice, tls: APIError.codiceTLS(urlError),
        motivo: urlError.userInfo[APIError.chiaveMotivoTLS] as? String)
    case .cancelled where urlError.userInfo[APIError.chiaveMotivoTLS] != nil:
      // Connessione chiusa da VerificaTLS: il certificato è stato rifiutato.
      self = .certificato(codice: codice, motivo: urlError.userInfo[APIError.chiaveMotivoTLS] as? String)
    case .badServerResponse, .cannotParseResponse, .cannotDecodeContentData:
      self = .rispostaInattesa(codice: codice)
    default:
      self = .nonRaggiungibile(codice: codice)
    }
  }

  /// Dove il trasporto mette il motivo per cui iOS ha rifiutato il
  /// certificato.
  static let chiaveMotivoTLS = "Ron1nMotivoTLS"

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
    case .accesso(conToken: false): "Manca l'accesso"
    case .accesso(conToken: true): "Accesso rifiutato"
    case .login(conToken: false): "Manca il token ron1nOS"
    case .login(conToken: true): "Token ron1nOS rifiutato"
    case .stato(let codice): "Errore del server · \(codice)"
    case .rispostaInattesa: "Risposta inattesa"
    }
  }

  /// Cosa controllare.
  public var suggerimento: String {
    switch self {
    case .nonRaggiungibile:
      "Controlla la connessione del telefono e che sul server siano accesi ron1nOS e il "
        + "tunnel Cloudflare (stack tunnel)."
    case .certificato:
      "iOS non accetta il certificato del server. Controlla data e ora del telefono: il "
        + "certificato di Cloudflare è pubblico e non va installato niente."
    case .accesso(conToken: false):
      "Cloudflare Access chiede il service token dell'app. Apri Altro › Impostazioni › Accesso e "
        + "incolla Client ID e Client Secret."
    case .accesso(conToken: true):
      "Cloudflare Access non accetta il token salvato: forse è scaduto o è stato revocato. "
        + "Apri Altro › Impostazioni › Accesso e incolla quello nuovo."
    case .login(conToken: false):
      "ron1nOS chiede il login. Nella dashboard apri Impostazioni › App iOS, crea un token e "
        + "incollalo in Altro › Impostazioni › Accesso."
    case .login(conToken: true):
      "ron1nOS non accetta il token salvato: forse è stato revocato. Creane uno nuovo in "
        + "Impostazioni › App iOS della dashboard e incollalo in Altro › Impostazioni › Accesso."
    case .stato:
      "Il backend ron1nOS ha un problema: guarda i suoi log sul server."
    case .rispostaInattesa:
      "All'indirizzo risponde qualcosa che non è il backend ron1nOS."
    }
  }

  /// Il codice preciso, per capire senza log: "URLError -1202", "HTTP 503",
  /// e sotto il motivo dato da iOS per un certificato rifiutato.
  public var dettaglio: String? {
    switch self {
    case .certificato(let codice, let tls, let motivo):
      let riga = tls.map { "URLError \(codice) · TLS \($0)" } ?? "URLError \(codice)"
      return motivo.map { "\(riga)\n\($0)" } ?? riga
    case .nonRaggiungibile(let codice?), .rispostaInattesa(let codice?): return "URLError \(codice)"
    case .stato(let codice): return "HTTP \(codice)"
    case .accesso: return "HTTP 302 · Cloudflare Access"
    case .login: return "HTTP 401 · ron1nOS"
    case .nonRaggiungibile(nil), .rispostaInattesa(nil): return nil
    }
  }
}
