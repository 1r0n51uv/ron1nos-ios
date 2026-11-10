import Foundation

/// Il ciclo di vita del login di ron1nOS (IOS-019): entrare con la password,
/// uscire, dire a che punto è la sessione e dare il client con cui parlare
/// all'API. Possiede i tre archivi segreti (il service token di Access, il
/// cookie di sessione e la password dietro Face ID) e il rinnovo della
/// sessione, così le viste non li toccano mai.
///
/// Il confine con l'esterno sono gli archivi e il trasporto: sul telefono
/// sono il Portachiavi e `URLSession`, nei test la memoria e un trasporto
/// finto.
public final class Autenticazione: Sendable {
  private let token: ArchivioCredenziali
  private let cookie: ArchivioTesto
  private let password: ArchivioTesto
  private let rinnovo: RinnovoSessione
  private let transport: HTTPTransport
  public let indirizzo: URL

  public init(
    token: ArchivioCredenziali, cookie: ArchivioTesto, password: ArchivioTesto,
    indirizzo: URL = APIClient.indirizzoPredefinito,
    transport: HTTPTransport = URLSessionTransport()
  ) {
    self.token = token
    self.cookie = cookie
    self.password = password
    self.indirizzo = indirizzo
    self.transport = transport
    rinnovo = RinnovoSessione(cookie: cookie, password: password)
  }

  /// Il client con il token di Access, la sessione salvata e il rinnovo.
  /// Si chiede a ogni uso: vede sempre i segreti di adesso.
  public func client() -> APIClient {
    APIClient(
      baseURL: indirizzo, credenziali: token.carica(),
      sessione: cookie.carica().map(CookieSessione.init), rinnovo: rinnovo, transport: transport)
  }

  /// Chiede al server a che punto è la sessione.
  public func stato() async -> StatoLogin {
    await StatoLogin.verifica(con: client())
  }

  /// `true` se sul telefono c'è una sessione salvata.
  public var haSessione: Bool { cookie.carica() != nil }

  /// `true` se sul telefono c'è il token di Access.
  public var haToken: Bool { token.carica() != nil }

  /// Entra con la password. Con `ricordaConFaceID` la tiene nel Portachiavi
  /// per rifare il login da sola quando la sessione scade; altrimenti toglie
  /// quella che c'era. Se il Portachiavi non salva, la sessione non resta
  /// a metà: l'errore esce e non si è entrati.
  public func entra(password testo: String, ricordaConFaceID: Bool) async throws -> EsitoAccesso {
    // Senza rinnovo: non c'è una sessione da rifare.
    let base = APIClient(baseURL: indirizzo, credenziali: token.carica(), transport: transport)
    let esito = try await base.accedi(password: testo)
    guard case .entrato(let nuova) = esito else { return esito }
    if ricordaConFaceID {
      try password.salva(testo)
    } else {
      try password.cancella()
    }
    try cookie.salva(nuova.valore)
    return esito
  }

  /// Chiude la sessione sul server, se risponde, e toglie sessione e
  /// password dal telefono comunque. Il token di Access resta.
  public func esci() async {
    // Senza rinnovo: uscire non deve chiedere Face ID per rifare il login.
    let chiusura = APIClient(
      baseURL: indirizzo, credenziali: token.carica(),
      sessione: cookie.carica().map(CookieSessione.init), transport: transport)
    try? await chiusura.esci()
    try? cookie.cancella()
    try? password.cancella()
  }

  /// Salva il service token di Access letto da un testo incollato. nil se
  /// il testo non è un token.
  @discardableResult
  public func salvaToken(da testo: String) throws -> CredenzialiAccesso? {
    guard let credenziali = CredenzialiAccesso.leggi(da: testo) else { return nil }
    try token.salva(credenziali)
    return credenziali
  }

  /// Toglie il service token di Access dal telefono.
  public func eliminaToken() throws {
    try token.cancella()
  }
}
