import Foundation
import Testing

@testable import Ron1nKit

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

@Suite struct LoginRon1nTests {
  let cookie = CookieSessione("abc123_-XYZ")
  let accesso = #"{"enabled":true,"expiresAt":"2026-12-09T10:00:00Z"}"#

  @Test func headerDelCookie() {
    #expect(cookie.header == ["Cookie": "ron1nos_session=abc123_-XYZ"])
  }

  @Test(arguments: [
    ("ron1nos_session=abc123_-XYZ; Path=/; HttpOnly; Secure; SameSite=Strict", "abc123_-XYZ"),
    ("altro=1, ron1nos_session=abc123_-XYZ; Max-Age=2592000", "abc123_-XYZ"),
  ])
  func leggeIlCookieDallaRisposta(intestazione: String, atteso: String) throws {
    let risposta = try #require(
      HTTPURLResponse(
        url: URL(string: "https://x.test")!, statusCode: 200, httpVersion: nil,
        headerFields: ["Set-Cookie": intestazione]))
    #expect(CookieSessione.leggi(da: risposta) == CookieSessione(atteso))
  }

  @Test(arguments: [nil, "altro=1; Path=/", "ron1nos_session=; Max-Age=0"])
  func nessunCookie(intestazione: String?) throws {
    let header = intestazione.map { ["Set-Cookie": $0] }
    let risposta = try #require(
      HTTPURLResponse(
        url: URL(string: "https://x.test")!, statusCode: 200, httpVersion: nil, headerFields: header))
    #expect(CookieSessione.leggi(da: risposta) == nil)
  }

  @Test func archivioInMemoria() {
    let archivio = TestoInMemoria()
    #expect(archivio.carica() == nil)
    archivio.salva("segreto")
    #expect(archivio.carica() == "segreto")
    archivio.cancella()
    #expect(archivio.carica() == nil)
  }

  @Test func headerInsiemeAQuelliDiAccess() async throws {
    let transport = TransportFinto(.risposta(200, #"{"enabled":true}"#))
    let credenziali = CredenzialiAccesso(clientId: "abc.access", clientSecret: "f00d")
    _ = try await APIClient(credenziali: credenziali, sessione: cookie, transport: transport).me()
    #expect(transport.richiesta?.url?.absoluteString == "https://home.ron1n.space/api/v1/auth/me")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Cookie") == "ron1nos_session=abc123_-XYZ")
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(transport.richiesta?.value(forHTTPHeaderField: "CF-Access-Client-Id") == "abc.access")
  }

  @Test(arguments: [false, true])
  func quattrocentouno(conSessione: Bool) async {
    let transport = TransportFinto(.risposta(401, #"{"error":"unauthenticated"}"#))
    let client = APIClient(sessione: conSessione ? cookie : nil, transport: transport)
    await #expect(throws: APIError.login(conSessione: conSessione)) { try await client.me() }
  }

  @Test(arguments: [
    (200, #"{"enabled":true}"#, StatoLogin.valido),
    (200, #"{"enabled":false}"#, .spento),
    (401, "{}", .nonEntrato),
    (503, "{}", .nonVerificato),
  ])
  func statoDelLogin(codice: Int, corpo: String, atteso: StatoLogin) async {
    let client = APIClient(transport: TransportFinto(.risposta(codice, corpo)))
    #expect(await StatoLogin.verifica(con: client) == atteso)
  }

  @Test func sessioneScaduta() async {
    let client = APIClient(sessione: cookie, transport: TransportFinto(.risposta(401, "{}")))
    let stato = await StatoLogin.verifica(con: client)
    #expect(stato == .sessioneScaduta)
    #expect(stato.problema)
    #expect(StatoLogin.nonEntrato.problema)
    #expect(!StatoLogin.valido.problema)
  }

  @Test func testiDelLogin() {
    #expect(APIError.login(conSessione: false).titolo == "Manca l'accesso a ron1nOS")
    #expect(APIError.login(conSessione: false).suggerimento.contains("password"))
    #expect(APIError.login(conSessione: true).titolo == "Sessione ron1nOS scaduta")
    #expect(APIError.login(conSessione: true).suggerimento.contains("chiusa"))
    #expect(APIError.login(conSessione: true).dettaglio == "HTTP 401 · ron1nOS")
    #expect(!APIError.login(conSessione: true).suggerimento.contains("!"))
  }

  // MARK: - Login con la password

  @Test func accessoRiuscito() async throws {
    let transport = TransportFinto(
      .risposta(200, accesso, header: ["Set-Cookie": "ron1nos_session=nuovo42; Path=/; HttpOnly"]))
    let esito = try await APIClient(transport: transport).accedi(password: "p\"w")
    #expect(esito == .entrato(CookieSessione("nuovo42")))
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/auth/login")
    let corpo = try #require(transport.richiesta?.httpBody)
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"password":"p\"w"}"#)
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Cookie") == nil)
  }

  @Test(arguments: [
    (401, EsitoAccesso.passwordErrata),
    (409, .loginSpento),
    (429, .troppiTentativi),
  ])
  func accessoNegato(codice: Int, atteso: EsitoAccesso) async throws {
    let transport = TransportFinto(.risposta(codice, "{}"))
    #expect(try await APIClient(transport: transport).accedi(password: "x") == atteso)
    #expect(transport.invii == 1)
  }

  @Test func accessoSenzaCookie() async {
    let transport = TransportFinto(.risposta(200, accesso))
    await #expect(throws: APIError.rispostaInattesa(codice: nil)) {
      try await APIClient(transport: transport).accedi(password: "x")
    }
  }

  @Test func accessoConErroreDelServer() async {
    let transport = TransportFinto(.risposta(503, "{}"))
    await #expect(throws: APIError.stato(503)) {
      try await APIClient(transport: transport).accedi(password: "x")
    }
  }

  @Test func esciChiudeLaSessione() async throws {
    let transport = TransportFinto(.risposta(204, ""))
    try await APIClient(sessione: cookie, transport: transport).esci()
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/auth/logout")
  }

  // MARK: - Rinnovo con la password salvata

  /// Un 401 con la sessione vecchia, poi il login, poi la richiesta ripetuta.
  func rinnovato(password: String?) -> (RinnovoSessione, TestoInMemoria, TestoInMemoria) {
    let archivioCookie = TestoInMemoria("vecchio")
    let archivioPassword = TestoInMemoria(password)
    return (
      RinnovoSessione(cookie: archivioCookie, password: archivioPassword), archivioCookie, archivioPassword
    )
  }

  @Test func rifaIlLoginSuUnQuattrocentouno() async throws {
    let (rinnovo, archivio, _) = rinnovato(password: "segreta")
    let transport = TransportFinto(
      .sequenza([
        .risposta(401, "{}"), .risposta(401, "{}"),
        .risposta(200, accesso, header: ["Set-Cookie": "ron1nos_session=nuovo; Path=/"]),
        .risposta(200, #"{"ok":true,"database":"ok"}"#),
      ]))
    let client = APIClient(sessione: CookieSessione("vecchio"), rinnovo: rinnovo, transport: transport)
    #expect(try await client.health().ok)
    // Richiesta, nuovo tentativo, login, richiesta ripetuta.
    #expect(transport.invii == 4)
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Cookie") == "ron1nos_session=nuovo")
    #expect(archivio.carica() == "nuovo")
  }

  @Test func senzaCookieSiEntraConLaPassword() async throws {
    let (rinnovo, archivio, _) = rinnovato(password: "segreta")
    archivio.cancella()
    let transport = TransportFinto(
      .sequenza([
        .risposta(401, "{}"),
        .risposta(200, accesso, header: ["Set-Cookie": "ron1nos_session=primo"]),
        .risposta(200, #"{"ok":true,"database":"ok"}"#),
      ]))
    let client = APIClient(rinnovo: rinnovo, transport: transport)
    #expect(try await client.health().ok)
    #expect(transport.invii == 3)
    #expect(archivio.carica() == "primo")
  }

  @Test func senzaPasswordResta401() async {
    let (rinnovo, _, _) = rinnovato(password: nil)
    let transport = TransportFinto(.risposta(401, "{}"))
    let client = APIClient(sessione: CookieSessione("vecchio"), rinnovo: rinnovo, transport: transport)
    await #expect(throws: APIError.login(conSessione: true)) { try await client.health() }
    #expect(transport.invii == 2)
  }

  @Test func passwordCambiataNonRiprovaSubito() async {
    let (rinnovo, _, _) = rinnovato(password: "vecchia")
    let transport = TransportFinto(.risposta(401, "{}"))
    let client = APIClient(sessione: CookieSessione("vecchio"), rinnovo: rinnovo, transport: transport)
    await #expect(throws: APIError.login(conSessione: true)) { try await client.health() }
    // Richiesta, nuovo tentativo, login respinto.
    #expect(transport.invii == 3)
    // Per 30 secondi niente altro login, quindi niente altro Face ID.
    await #expect(throws: APIError.login(conSessione: true)) { try await client.health() }
    #expect(transport.invii == 5)
  }

  @Test func seUnAltraRichiestaHaGiaRinnovatoLaUsa() async {
    let (rinnovo, archivio, _) = rinnovato(password: "segreta")
    archivio.salva("gia-nuovo")
    let client = APIClient(transport: TransportFinto(.risposta(200, "{}")))
    let usata = await rinnovo.rinnova(rifiutato: CookieSessione("vecchio"), con: client)
    #expect(usata == CookieSessione("gia-nuovo"))
  }
}
