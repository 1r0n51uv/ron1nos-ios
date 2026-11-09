import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// La sessione dell'app nel login di ron1nOS (IOS-019): si ottiene con la
/// password della dashboard (`POST /auth/login`), dura 30 giorni rinnovati a
/// ogni uso e si manda in ogni richiesta nel cookie `ron1nos_session`.
public struct CookieSessione: Equatable, Sendable {
  public static let nome = "ron1nos_session"

  public let valore: String

  public init(_ valore: String) { self.valore = valore }

  /// L'header da aggiungere alla richiesta.
  public var header: [String: String] { ["Cookie": "\(CookieSessione.nome)=\(valore)"] }

  /// Il cookie che il server ha messo in `Set-Cookie`. nil se non c'è o se
  /// è vuoto, cioè tolto.
  public static func leggi(da risposta: HTTPURLResponse) -> CookieSessione? {
    guard let intestazione = risposta.value(forHTTPHeaderField: "Set-Cookie") else { return nil }
    let prefisso = "\(nome)="
    for parte in intestazione.split(whereSeparator: { $0 == ";" || $0 == "," }) {
      let parte = parte.trimmingCharacters(in: .whitespaces)
      guard parte.hasPrefix(prefisso) else { continue }
      let valore = String(parte.dropFirst(prefisso.count))
      return valore.isEmpty ? nil : CookieSessione(valore)
    }
    return nil
  }
}

/// Un testo segreto che l'app tiene sul telefono: il cookie di sessione o la
/// password. Sul telefono è il Portachiavi, nei test la memoria.
public protocol ArchivioTesto: Sendable {
  func carica() -> String?
  func salva(_ testo: String) throws
  func cancella() throws
}

/// Archivio in memoria, per i test e per Linux.
public final class TestoInMemoria: ArchivioTesto, @unchecked Sendable {
  private let lock = NSLock()
  private var testo: String?

  public init(_ testo: String? = nil) { self.testo = testo }

  public func carica() -> String? { lock.withLock { testo } }
  public func salva(_ testo: String) { lock.withLock { self.testo = testo } }
  public func cancella() { lock.withLock { testo = nil } }
}

#if canImport(Security)
  /// Un testo nel Portachiavi, in una voce sua. Con `conFaceID` la voce si
  /// legge solo con Face ID (o il codice del telefono).
  public struct PortachiaviTesto: ArchivioTesto {
    let voce: VocePortachiavi

    public init(servizio: String, conFaceID: Bool = false) {
      voce = VocePortachiavi(servizio: servizio, conFaceID: conFaceID)
    }

    public func carica() -> String? {
      voce.leggi().flatMap { String(data: $0, encoding: .utf8) }
    }

    public func salva(_ testo: String) throws { try voce.scrivi(Data(testo.utf8)) }

    public func cancella() throws { try voce.cancella() }
  }
#endif

/// Com'è andato un tentativo di login.
public enum EsitoAccesso: Equatable, Sendable {
  case entrato(CookieSessione)
  case passwordErrata
  /// Il login di ron1nOS è spento: l'app non ha bisogno della password.
  case loginSpento
  /// 5 password sbagliate in 15 minuti.
  case troppiTentativi
}

extension APIClient {
  /// `POST /auth/login`: la sessione arriva nel cookie della risposta.
  public func accedi(password: String) async throws(APIError) -> EsitoAccesso {
    struct Corpo: Encodable, Sendable { let password: String }
    let corpo: Data
    do {
      corpo = try JSONEncoder().encode(Corpo(password: password))
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
    let risposta: (Data, HTTPURLResponse)
    do {
      risposta = try await self.risposta("auth/login", metodo: "POST", corpo: corpo)
    } catch .login {
      return .passwordErrata
    }
    switch risposta.1.statusCode {
    case 200:
      guard let cookie = CookieSessione.leggi(da: risposta.1) else {
        throw .rispostaInattesa(codice: nil)
      }
      return .entrato(cookie)
    case 409: return .loginSpento
    case 429: return .troppiTentativi
    case let codice: throw .stato(codice)
    }
  }

  /// `POST /auth/logout`: chiude la sessione di questo telefono.
  public func esci() async throws(APIError) {
    _ = try await dati("auth/logout", metodo: "POST")
  }
}

/// Rifà il login quando la sessione scade o viene chiusa, con la password
/// tenuta nel Portachiavi dietro Face ID. Le richieste che trovano un 401
/// nello stesso momento aspettano un solo tentativo, quindi Face ID compare
/// una volta sola; dopo un tentativo andato male non si richiede per 30
/// secondi.
public actor RinnovoSessione {
  public static let pausa: TimeInterval = 30

  private let cookie: ArchivioTesto
  private let password: ArchivioTesto
  private var inCorso: Task<CookieSessione?, Never>?
  private var fallitoAlle: Date?

  public init(cookie: ArchivioTesto, password: ArchivioTesto) {
    self.cookie = cookie
    self.password = password
  }

  /// La sessione nuova, o nil se non si è potuta rifare. `rifiutato` è
  /// quella che il server ha respinto; `client` dice dove e con quali
  /// credenziali di Access fare il login.
  public func rinnova(rifiutato: CookieSessione?, con client: APIClient, adesso: Date = Date()) async
    -> CookieSessione?
  {
    // Un'altra richiesta l'ha già rifatta.
    if let attuale = cookie.carica().map(CookieSessione.init), attuale != rifiutato { return attuale }
    if let inCorso { return await inCorso.value }
    if let fallitoAlle, adesso.timeIntervalSince(fallitoAlle) < RinnovoSessione.pausa { return nil }
    let tentativo = Task { await accedi(con: client) }
    inCorso = tentativo
    let nuovo = await tentativo.value
    inCorso = nil
    fallitoAlle = nuovo == nil ? adesso : nil
    return nuovo
  }

  private func accedi(con client: APIClient) async -> CookieSessione? {
    // La lettura con Face ID aspetta la persona: fuori dall'actor.
    let archivio = password
    guard let testo = await Task.detached(operation: { archivio.carica() }).value else { return nil }
    guard case .entrato(let nuovo)? = try? await client.accedi(password: testo) else { return nil }
    try? cookie.salva(nuovo.valore)
    return nuovo
  }
}

/// Risposta di `GET /api/v1/auth/me`.
public struct Me: Decodable, Equatable, Sendable {
  /// false se il login di ron1nOS è spento.
  public let enabled: Bool
}

/// Il login di ron1nOS visto dall'app, nella schermata di stato.
public enum StatoLogin: Equatable, Sendable {
  case inCorso
  /// Login spento sul server: la password non serve.
  case spento
  /// Il server accetta la sessione salvata.
  case valido
  /// Nessuna sessione: manca l'accesso con la password.
  case nonEntrato
  /// La sessione salvata è scaduta o è stata chiusa.
  case sessioneScaduta
  /// Non si è potuto chiedere: server non raggiungibile, Access…
  case nonVerificato

  /// Chiede `GET /auth/me` con la sessione del client.
  public static func verifica(con client: APIClient) async -> StatoLogin {
    do {
      return try await client.me().enabled ? .valido : .spento
    } catch {
      if case .login(let conSessione) = error { return conSessione ? .sessioneScaduta : .nonEntrato }
      return .nonVerificato
    }
  }

  /// Come appare nella schermata.
  public var testo: String {
    switch self {
    case .inCorso: "controllo…"
    case .spento: "spento"
    case .valido: "sessione valida"
    case .nonEntrato: "da accedere"
    case .sessioneScaduta: "sessione scaduta"
    case .nonVerificato: "·"
    }
  }

  /// Da segnalare in rosso.
  public var problema: Bool { self == .nonEntrato || self == .sessioneScaduta }
}
