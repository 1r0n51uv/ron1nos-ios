import Foundation
import Testing

@testable import Ron1nKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Un archivio che rifiuta di salvare, come un Portachiavi bloccato.
private struct ArchivioRotto: ArchivioTesto {
  struct Errore: Error {}
  func carica() -> String? { nil }
  func salva(_ testo: String) throws { throw Errore() }
  func cancella() throws {}
}

@Suite struct AutenticazioneTests {
  let accesso = #"{"enabled":true}"#
  let cookieNuovo = ["Set-Cookie": "ron1nos_session=nuovo42; Path=/; HttpOnly"]

  private func autenticazione(
    _ transport: TransportFinto, cookie: ArchivioTesto = TestoInMemoria(),
    password: ArchivioTesto = TestoInMemoria(), token: ArchivioCredenziali = ArchivioInMemoria()
  ) -> Autenticazione {
    Autenticazione(token: token, cookie: cookie, password: password, transport: transport)
  }

  // MARK: - entra

  @Test func entraESalvaLaSessione() async throws {
    let cookie = TestoInMemoria()
    let transport = TransportFinto(.risposta(200, accesso, header: cookieNuovo))
    let esito = try await autenticazione(transport, cookie: cookie)
      .entra(password: "segreta", ricordaConFaceID: false)
    #expect(esito == .entrato(CookieSessione("nuovo42")))
    #expect(cookie.carica() == "nuovo42")
  }

  @Test func ricordaLaPasswordSoloSeLoChiede() async throws {
    let password = TestoInMemoria()
    let transport = TransportFinto(.risposta(200, accesso, header: cookieNuovo))
    let auth = autenticazione(transport, password: password)

    _ = try await auth.entra(password: "segreta", ricordaConFaceID: true)
    #expect(password.carica() == "segreta")

    _ = try await auth.entra(password: "segreta", ricordaConFaceID: false)
    #expect(password.carica() == nil)
  }

  @Test(arguments: [
    (401, EsitoAccesso.passwordErrata),
    (409, .loginSpento),
    (429, .troppiTentativi),
  ])
  func entrataNegataNonSalvaNiente(codice: Int, atteso: EsitoAccesso) async throws {
    let cookie = TestoInMemoria("vecchio")
    let password = TestoInMemoria("vecchia")
    let esito = try await autenticazione(
      TransportFinto(.risposta(codice, "{}")), cookie: cookie, password: password
    ).entra(password: "x", ricordaConFaceID: true)
    #expect(esito == atteso)
    #expect(cookie.carica() == "vecchio")
    #expect(password.carica() == "vecchia")
  }

  @Test func entraSenzaRinnovoESenzaCookie() async throws {
    let transport = TransportFinto(.risposta(200, accesso, header: cookieNuovo))
    _ = try await autenticazione(transport, cookie: TestoInMemoria("vecchio"))
      .entra(password: "x", ricordaConFaceID: false)
    #expect(transport.richiesta?.url?.path == "/api/v1/auth/login")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Cookie") == nil)
  }

  @Test func ilTokenDiAccessVaInOgniRichiesta() async throws {
    let token = ArchivioInMemoria(CredenzialiAccesso(clientId: "abc.access", clientSecret: "f00d"))
    let transport = TransportFinto(.risposta(200, accesso, header: cookieNuovo))
    _ = try await autenticazione(transport, token: token)
      .entra(password: "x", ricordaConFaceID: false)
    #expect(transport.richiesta?.value(forHTTPHeaderField: "CF-Access-Client-Id") == "abc.access")
  }

  @Test func errorePortachiaviNonLasciaUnaSessioneAMeta() async {
    let transport = TransportFinto(.risposta(200, accesso, header: cookieNuovo))
    let cookie = TestoInMemoria()
    let auth = autenticazione(transport, cookie: cookie, password: ArchivioRotto())
    await #expect(throws: ArchivioRotto.Errore.self) {
      try await auth.entra(password: "x", ricordaConFaceID: true)
    }
    #expect(cookie.carica() == nil)
  }

  @Test func erroreDelServerEsce() async {
    let auth = autenticazione(TransportFinto(.risposta(503, "{}")))
    await #expect(throws: APIError.stato(503)) {
      try await auth.entra(password: "x", ricordaConFaceID: false)
    }
  }

  // MARK: - esci

  @Test func esciToglieSessionePasswordEMantieneIlToken() async {
    let cookie = TestoInMemoria("sessione")
    let password = TestoInMemoria("segreta")
    let token = ArchivioInMemoria(CredenzialiAccesso(clientId: "a", clientSecret: "b"))
    let transport = TransportFinto(.risposta(200, "{}"))
    let auth = autenticazione(transport, cookie: cookie, password: password, token: token)

    await auth.esci()

    #expect(transport.richiesta?.url?.path == "/api/v1/auth/logout")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Cookie") == "ron1nos_session=sessione")
    #expect(cookie.carica() == nil)
    #expect(password.carica() == nil)
    #expect(token.carica() != nil)
    #expect(!auth.haSessione)
  }

  @Test func esciToglieTuttoAncheSeIlServerNonRisponde() async {
    let cookie = TestoInMemoria("sessione")
    let password = TestoInMemoria("segreta")
    let transport = TransportFinto(.errore(URLError(.notConnectedToInternet)))
    await autenticazione(transport, cookie: cookie, password: password).esci()
    #expect(cookie.carica() == nil)
    #expect(password.carica() == nil)
  }

  @Test func esciNonRifaIlLoginNeChiedeLaPassword() async {
    // Il logout prende un 401: senza rinnovo non deve ritentare con la password.
    let transport = TransportFinto(.risposta(401, "{}"))
    let auth = autenticazione(
      transport, cookie: TestoInMemoria("sessione"), password: TestoInMemoria("segreta"))
    await auth.esci()
    // Il 401 col cookie si riprova una volta (APIClient), ma mai col login.
    #expect(transport.richiesta?.url?.path == "/api/v1/auth/logout")
  }

  // MARK: - client e stato

  @Test func ilClientVedeLaSessioneDiAdesso() async throws {
    let cookie = TestoInMemoria()
    let transport = TransportFinto(.risposta(200, accesso, header: cookieNuovo))
    let auth = autenticazione(transport, cookie: cookie)
    #expect(auth.client().sessione == nil)

    _ = try await auth.entra(password: "x", ricordaConFaceID: false)

    #expect(auth.client().sessione == CookieSessione("nuovo42"))
    #expect(auth.haSessione)
  }

  @Test(arguments: [
    (200, #"{"enabled":true}"#, StatoLogin.valido),
    (200, #"{"enabled":false}"#, .spento),
    (401, "{}", .nonEntrato),
    (503, "{}", .nonVerificato),
  ])
  func statoSenzaSessione(codice: Int, corpo: String, atteso: StatoLogin) async {
    let auth = autenticazione(TransportFinto(.risposta(codice, corpo)))
    #expect(await auth.stato() == atteso)
  }

  @Test func sessioneScaduta() async {
    // Nessuna password salvata: il rinnovo non può rifare il login.
    let auth = autenticazione(
      TransportFinto(.risposta(401, "{}")), cookie: TestoInMemoria("vecchio"))
    #expect(await auth.stato() == .sessioneScaduta)
  }

  @Test func laSessioneScadutaSiRinnovaConLaPasswordSalvata() async {
    let cookie = TestoInMemoria("vecchio")
    let transport = TransportFinto(
      .sequenza([
        .risposta(401, "{}"),
        .risposta(401, "{}"),
        .risposta(200, accesso, header: cookieNuovo),
        .risposta(200, accesso),
      ]))
    let auth = autenticazione(transport, cookie: cookie, password: TestoInMemoria("segreta"))
    #expect(await auth.stato() == .valido)
    #expect(cookie.carica() == "nuovo42")
  }

  // MARK: - token di Access

  @Test func salvaEEliminaIlToken() throws {
    let token = ArchivioInMemoria()
    let auth = autenticazione(TransportFinto(.risposta(200, "{}")), token: token)
    #expect(!auth.haToken)

    let salvato = try auth.salvaToken(da: #"{"client_id":"abc.access","client_secret":"f00d"}"#)
    #expect(salvato == CredenzialiAccesso(clientId: "abc.access", clientSecret: "f00d"))
    #expect(auth.haToken)

    try auth.eliminaToken()
    #expect(!auth.haToken)
  }

  @Test func untestoCheNonETokenNonSalvaNiente() throws {
    let token = ArchivioInMemoria()
    let auth = autenticazione(TransportFinto(.risposta(200, "{}")), token: token)
    #expect(try auth.salvaToken(da: "ciao") == nil)
    #expect(!auth.haToken)
  }
}
