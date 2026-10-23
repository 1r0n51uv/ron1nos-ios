import Foundation

/// Il token dell'app per il login di ron1nOS (IOS-005, AUTH-005 di
/// ron1nOS): si crea nella dashboard in Impostazioni › App iOS e si manda
/// in ogni richiesta come `Authorization: Bearer`. Vale finché non lo si
/// revoca.
public struct TokenRon1n: Equatable, Sendable {
  /// Il prefisso dei token di ron1nOS.
  public static let prefisso = "r1n_"

  public let valore: String

  public init(_ valore: String) { self.valore = valore }

  /// L'header da aggiungere alla richiesta.
  public var header: [String: String] { ["Authorization": "Bearer \(valore)"] }

  /// Legge il token da un testo incollato: il token da solo, o con davanti
  /// `Bearer `. Accetta solo `r1n_` seguito da caratteri base64url.
  public static func leggi(da testo: String) -> TokenRon1n? {
    var testo = testo.trimmingCharacters(in: .whitespacesAndNewlines)
    if testo.lowercased().hasPrefix("bearer ") {
      testo = String(testo.dropFirst(7)).trimmingCharacters(in: .whitespaces)
    }
    guard testo.hasPrefix(prefisso) else { return nil }
    let resto = testo.dropFirst(prefisso.count)
    let ammessi = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    guard resto.count >= 16, resto.allSatisfy(ammessi.contains) else { return nil }
    return TokenRon1n(testo)
  }
}

/// Dove l'app tiene il token di ron1nOS. Sul telefono è il Portachiavi, nei
/// test la memoria.
public protocol ArchivioToken: Sendable {
  func carica() -> TokenRon1n?
  func salva(_ token: TokenRon1n) throws
  func cancella() throws
}

/// Archivio in memoria, per i test e per Linux.
public final class TokenInMemoria: ArchivioToken, @unchecked Sendable {
  private let lock = NSLock()
  private var token: TokenRon1n?

  public init(_ token: TokenRon1n? = nil) { self.token = token }

  public func carica() -> TokenRon1n? { lock.withLock { token } }
  public func salva(_ token: TokenRon1n) { lock.withLock { self.token = token } }
  public func cancella() { lock.withLock { token = nil } }
}

#if canImport(Security)
  /// Il token di ron1nOS nel Portachiavi, in una voce sua.
  public struct PortachiaviToken: ArchivioToken {
    let voce: VocePortachiavi

    public init(servizio: String = "home.ron1n.ios.token-ron1nos") {
      voce = VocePortachiavi(servizio: servizio)
    }

    public func carica() -> TokenRon1n? {
      voce.leggi().flatMap { String(data: $0, encoding: .utf8) }.map(TokenRon1n.init)
    }

    public func salva(_ token: TokenRon1n) throws { try voce.scrivi(Data(token.valore.utf8)) }

    public func cancella() throws { try voce.cancella() }
  }
#endif

/// Risposta di `GET /api/v1/auth/me`.
public struct Me: Decodable, Equatable, Sendable {
  /// false se il login di ron1nOS è spento.
  public let enabled: Bool
}

/// Il login di ron1nOS visto dall'app, nella schermata di stato.
public enum StatoLogin: Equatable, Sendable {
  case inCorso
  /// Login spento sul server: il token non serve.
  case spento
  /// Il server accetta il token salvato.
  case valido
  case mancaToken
  case tokenRifiutato
  /// Non si è potuto chiedere: server non raggiungibile, Access…
  case nonVerificato

  /// Chiede `GET /auth/me` con il token del client.
  public static func verifica(con client: APIClient) async -> StatoLogin {
    do {
      return try await client.me().enabled ? .valido : .spento
    } catch {
      if case .login(let conToken) = error { return conToken ? .tokenRifiutato : .mancaToken }
      return .nonVerificato
    }
  }

  /// Come appare nella schermata.
  public var testo: String {
    switch self {
    case .inCorso: "controllo…"
    case .spento: "spento"
    case .valido: "token valido"
    case .mancaToken: "manca il token"
    case .tokenRifiutato: "token rifiutato"
    case .nonVerificato: "·"
    }
  }

  /// Da segnalare in rosso.
  public var problema: Bool { self == .mancaToken || self == .tokenRifiutato }
}
