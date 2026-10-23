import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Perché una chiamata all'API non è andata, detto in modo che si sappia
/// cosa controllare.
public enum APIError: Error, Equatable, Sendable {
  /// Nessuna risposta: server spento, Tailscale spento o nome non risolto.
  case nonRaggiungibile
  /// Connessione rifiutata per il certificato: manca la CA di Caddy.
  case certificato
  /// Il server ha risposto con un codice HTTP di errore.
  case stato(Int)
  /// Ha risposto, ma non con quello che l'app si aspetta.
  case rispostaInattesa

  init(_ error: Error) {
    guard let urlError = error as? URLError else {
      self = .nonRaggiungibile
      return
    }
    switch urlError.code {
    case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
      .serverCertificateHasBadDate, .serverCertificateNotYetValid, .secureConnectionFailed:
      self = .certificato
    case .badServerResponse, .cannotParseResponse, .cannotDecodeContentData:
      self = .rispostaInattesa
    default:
      self = .nonRaggiungibile
    }
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
      "Controlla che Tailscale sia acceso sul telefono e che il server sia nella tailnet."
    case .certificato:
      "Installa il certificato di Caddy da ca.ron1n.home e attivalo in Impostazioni › Generali › Info › Certificati."
    case .stato(401), .stato(403):
      "Il server chiede il login, che questa versione dell'app non ha ancora."
    case .stato:
      "Il backend ron1nOS ha un problema: guarda i suoi log sul server."
    case .rispostaInattesa:
      "All'indirizzo risponde qualcosa che non è il backend ron1nOS."
    }
  }
}
