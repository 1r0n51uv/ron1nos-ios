import Foundation
import Testing

@testable import Ron1nKit

@Suite struct GestioneTorrentTests {
  func torrent(_ nome: String, _ stato: StatoTorrent, progresso: Double = 0.5) -> Torrent {
    Torrent(hash: nome, name: nome, progress: progresso, state: stato)
  }

  // MARK: - sezioni

  @Test func sezioniNelLOrdineDellaPagina() {
    let download = Download(
      downloadSpeed: 0,
      torrents: [
        torrent("seed", .seeding), torrent("a", .downloading), torrent("fermo", .stopped),
        torrent("coda", .queued), torrent("rotto", .error), torrent("nuovo", .sconosciuto("x")),
        torrent("b", .downloading),
      ])
    let sezioni = download.sezioni
    #expect(sezioni.map(\.titolo) == ["In download", "In coda", "In seed", "Fermi", "Errori"])
    #expect(sezioni[0].torrents.map(\.name) == ["a", "b"])
    #expect(sezioni[4].torrents.map(\.name) == ["rotto", "nuovo"])
  }

  @Test func ogniSezioneEOgniStatoHannoUnSimbolo() {
    let download = Download(
      downloadSpeed: 0,
      torrents: [
        torrent("a", .downloading), torrent("c", .queued), torrent("s", .seeding), torrent("f", .stopped),
        torrent("e", .error),
      ])
    let simboli = download.sezioni.map(\.simbolo)
    #expect(
      simboli == ["arrow.down", "hourglass", "arrow.up", "pause.fill", "exclamationmark.triangle.fill"])
    #expect(
      download.torrents.map(\.simbolo) == [
        "arrow.down", "hourglass", "arrow.up", "pause.fill", "exclamationmark",
      ])
  }

  @Test func soloInSeedStaChiusa() {
    let download = Download(
      downloadSpeed: 0, torrents: [torrent("a", .downloading), torrent("s", .seeding)])
    #expect(download.sezioni.map(\.chiusaDiDefault) == [false, true])
  }

  @Test func sezioniVuoteSiOmettono() {
    #expect(Download(downloadSpeed: 0, torrents: []).sezioni.isEmpty)
    let uno = Download(downloadSpeed: 0, torrents: [torrent("f", .stopped)])
    #expect(uno.sezioni.map(\.titolo) == ["Fermi"])
  }

  // MARK: - selezione

  @Test func sceglieEToglie() {
    var selezione = SelezioneTorrent()
    let a = torrent("a", .downloading)
    #expect(selezione.vuota)
    #expect(selezione.titolo == "Scegli")
    selezione.alterna(a)
    #expect(selezione.contiene(a))
    #expect(selezione.titolo == "1 scelto")
    selezione.alterna(torrent("b", .seeding))
    #expect(selezione.titolo == "2 scelti")
    selezione.alterna(a)
    #expect(!selezione.contiene(a))
  }

  @Test func laSezioneSiSceglieTuttaOSiToglie() {
    let download = Download(
      downloadSpeed: 0,
      torrents: [torrent("a", .downloading), torrent("b", .downloading), torrent("c", .queued)])
    let prima = download.sezioni[0]
    var selezione = SelezioneTorrent()
    selezione.alterna(download.torrents[0])
    selezione.alterna(prima)
    #expect(selezione.hashes == ["a", "b"])
    selezione.alterna(prima)
    #expect(selezione.vuota)
  }

  @Test func dopoUnAggiornamentoRestanoSoloQuelliCheCiSono() {
    var selezione = SelezioneTorrent()
    selezione.alterna(torrent("a", .downloading))
    selezione.alterna(torrent("b", .downloading))
    selezione.tieni([torrent("b", .seeding)])
    #expect(selezione.hashes == ["b"])
  }

  @Test func azioniPossibiliSuiScelti() {
    let tutti = [torrent("attivo", .downloading), torrent("fermo", .stopped)]
    var selezione = SelezioneTorrent()
    #expect(!selezione.puoPausa(in: tutti) && !selezione.puoRiprendere(in: tutti))
    selezione.alterna(tutti[0])
    #expect(selezione.puoPausa(in: tutti) && !selezione.puoRiprendere(in: tutti))
    selezione.alterna(tutti[1])
    #expect(selezione.puoPausa(in: tutti) && selezione.puoRiprendere(in: tutti))
    selezione.alterna(tutti[0])
    #expect(!selezione.puoPausa(in: tutti) && selezione.puoRiprendere(in: tutti))
  }

  // MARK: - API

  @Test(arguments: [
    (AzioneTorrent.pause, false, #"{"action":"pause","hashes":["a","b"],"deleteFiles":false}"#),
    (AzioneTorrent.resume, false, #"{"action":"resume","hashes":["a","b"],"deleteFiles":false}"#),
    (AzioneTorrent.delete, true, #"{"action":"delete","hashes":["a","b"],"deleteFiles":true}"#),
  ])
  func mandaLAzione(azione: AzioneTorrent, eliminaFile: Bool, atteso: String) async throws {
    let transport = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: transport).azione(
      azione, hashes: ["a", "b"], eliminaFile: eliminaFile)
    #expect(transport.richiesta?.httpMethod == "POST")
    #expect(transport.richiesta?.url?.path == "/api/v1/downloads/actions")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    let previsto = try #require(
      try JSONSerialization.jsonObject(with: Data(atteso.utf8)) as? [String: Any])
    #expect(NSDictionary(dictionary: json) == NSDictionary(dictionary: previsto))
    #expect(transport.richiesta?.value(forHTTPHeaderField: "Content-Type") == "application/json")
  }

  @Test func azioneSuTorrentSconosciuto() async {
    let transport = TransportFinto(.risposta(404, #"{"error":"torrent_not_found"}"#))
    await #expect(throws: APIError.stato(404)) {
      try await APIClient(transport: transport).azione(.pause, hashes: ["a"])
    }
  }

  @Test func leggeIlDettaglio() async throws {
    let corpo = """
      {"hash":"abc","name":"debian.iso","progress":0.5,"state":"downloading","etaSeconds":120,
       "downloadSpeed":2048,"size":4000000000,"downloaded":2000000000,"uploadSpeed":1024,
       "ratio":0.25,"savePath":"/downloads","addedAt":"2023-11-14T22:13:20.000Z",
       "files":[{"index":0,"name":"debian.iso","size":4000000000,"progress":0.5,"selected":true},
                {"index":1,"name":"nota.txt","size":10,"progress":0,"selected":false}]}
      """
    let transport = TransportFinto(.risposta(200, corpo))
    let dettaglio = try await APIClient(transport: transport).dettaglio(torrent: "abc")
    #expect(transport.richiesta?.url?.path == "/api/v1/downloads/abc")
    #expect(dettaglio.state == .downloading)
    #expect(dettaglio.files.map(\.selected) == [true, false])
    #expect(dettaglio.aggiunto == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(dettaglio.righe.first?.nome == "Dimensione")
    #expect(dettaglio.righe.last?.valore == "/downloads")
  }

  @Test func dataAggiuntaIllegibile() throws {
    let json = Data(
      #"""
      {"hash":"a","name":"n","progress":1,"state":"seeding","etaSeconds":null,"downloadSpeed":0,
       "size":1,"downloaded":1,"uploadSpeed":0,"ratio":0,"savePath":"","addedAt":"ieri","files":[]}
      """#.utf8)
    #expect(try JSONDecoder().decode(DettaglioTorrent.self, from: json).aggiunto == nil)
  }

  // MARK: - magnet negli appunti

  @Test(arguments: [
    ("magnet:?xt=urn:btih:abc123", "magnet:?xt=urn:btih:abc123"),
    ("  magnet:?xt=urn:btih:abc123\n", "magnet:?xt=urn:btih:abc123"),
  ])
  func trovaUnMagnet(testo: String, atteso: String) {
    #expect(AggiungiTorrent.magnet(in: testo) == atteso)
  }

  @Test(arguments: [nil, "", "ciao", "https://esempio.it/a.torrent", "magnet:?dn=senza-hash"])
  func nonEUnMagnet(testo: String?) {
    #expect(AggiungiTorrent.magnet(in: testo) == nil)
  }
}
