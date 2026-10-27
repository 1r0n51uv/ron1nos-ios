import Foundation
import Testing

@testable import Ron1nKit

@Suite struct AggiungiTorrentTests {
  static let bozza = """
    {"id":"d1","source":"file","status":"ready","infoHash":"abc","name":"Debian","size":3900000000,
     "files":[{"index":0,"path":"Debian/iso/debian.iso","size":3800000000},
              {"index":1,"path":"Debian/iso/debian.sig","size":1000},
              {"index":2,"path":"Debian/LEGGIMI.txt","size":99999000}]}
    """

  @Test func ilTitoloDelPasso() {
    #expect(AggiungiTorrent.titolo(passo: 2) == "AGGIUNGI TORRENT · 2 DI 4")
  }

  @Test func iLinkValidi() {
    #expect(AggiungiTorrent.Link(" magnet:?xt=urn:btih:ABC&dn=x ") == .magnet(versione: "v1"))
    #expect(AggiungiTorrent.Link("magnet:?xt=urn:btmh:1220abc") == .magnet(versione: "v2"))
    #expect(AggiungiTorrent.Link("https://esempio.it/file.torrent") == .url)
    #expect(AggiungiTorrent.Link("magnet:?dn=senza-hash") == nil)
    #expect(AggiungiTorrent.Link("ftp://esempio.it/x.torrent") == nil)
    #expect(AggiungiTorrent.Link("ciao") == nil)
    #expect(AggiungiTorrent.Link("https://esempio.it/a")?.etichetta == "URL di un file .torrent")
    #expect(AggiungiTorrent.Link("magnet:?xt=urn:btih:A")?.etichetta == "magnet · v1")
  }

  @Test func ilFileTorrent() {
    #expect(AggiungiTorrent.fileValido(nome: "Debian.TORRENT", dimensione: 2_000))
    #expect(!AggiungiTorrent.fileValido(nome: "debian.iso", dimensione: 2_000))
    #expect(!AggiungiTorrent.fileValido(nome: "vuoto.torrent", dimensione: 0))
    #expect(!AggiungiTorrent.fileValido(nome: "grande.torrent", dimensione: 10 * 1024 * 1024 + 1))
  }

  @Test func tempiEStati() {
    #expect(AggiungiTorrent.orologio(18) == "0:18")
    #expect(AggiungiTorrent.orologio(75) == "1:15")
    let attesa = BozzaTorrent.Attesa(peers: 3, waitedSeconds: 18, limitSeconds: 60)
    #expect(attesa.testo == "3 peer · 0:18 su 1:00")
    #expect(AggiungiTorrent.stato("seeding") == "in seed")
    #expect(Formato.dimensione(850_000) == "850 KB")
    #expect(Formato.dimensione(3_900_000_000) == "3,9 GB")
    #expect(Formato.dimensione(12_400_000_000) == "12 GB")
  }

  @Test func lAlberoDeiFile() throws {
    let dati = Data(AggiungiTorrentTests.bozza.utf8)
    let bozza = try JSONDecoder().decode(BozzaTorrent.self, from: dati)
    #expect(bozza.pronta)
    #expect(bozza.riepilogo == "3 file · 3,9 GB")
    let albero = NodoFile.albero(bozza.files)
    #expect(albero.map(\.nome) == ["Debian"])
    let radice = albero[0]
    #expect(radice.indici == [0, 1, 2])
    #expect(radice.figli.map(\.nome) == ["iso", "LEGGIMI.txt"])
    let iso = radice.figli[0]
    #expect(iso.cartella)
    #expect(iso.figliOpzionali?.count == 2)
    #expect(radice.figli[1].figliOpzionali == nil)
    #expect(iso.dimensione == 3_800_001_000)

    var scelti: Set<Int> = [0, 1, 2]
    #expect(radice.spunta(scelti) == .tutto)
    scelti = iso.alterna(scelti)
    #expect(scelti == [2])
    #expect(radice.spunta(scelti) == .parte)
    #expect(iso.spunta(scelti) == .niente)
    scelti = radice.alterna(scelti)
    #expect(scelti == [0, 1, 2])
    #expect(NodoFile.dimensione(bozza.files, scelti: [1, 2]) == 100_000_000)
  }

  @Test func loSpazio() {
    let spazio = Spazio(free: 2_100_000_000, path: "/downloads")
    #expect(spazio.avviso(servono: 1_000) == nil)
    let avviso = spazio.avviso(servono: 3_900_000_000)
    #expect(avviso == "Servono 3,9 GB, liberi 2,1 GB. Togli qualche file al passo precedente.")
  }

  @Test func unaBozzaDaFile() async throws {
    let transport = TransportFinto(.risposta(201, AggiungiTorrentTests.bozza))
    let esito = try await APIClient(transport: transport).creaBozza(file: Data("d8:".utf8), nome: "x.torrent")
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.httpMethod == "POST")
    #expect(richiesta.url?.path == "/api/v1/downloads/drafts")
    let tipo = try #require(richiesta.value(forHTTPHeaderField: "Content-Type"))
    #expect(tipo.hasPrefix("multipart/form-data; boundary=ron1nOS-"))
    let dati = try #require(richiesta.httpBody)
    let corpo = String(decoding: dati, as: UTF8.self)
    #expect(corpo.contains("filename=\"x.torrent\""))
    #expect(corpo.contains("Content-Type: application/x-bittorrent"))
    guard case .fatto(let bozza) = esito else {
      Issue.record("attesa la bozza")
      return
    }
    #expect(bozza.id == "d1")
  }

  @Test func unaBozzaDaLinkGiaPresente() async throws {
    let errore = """
      {"error":"duplicate","message":"Questo torrent è già nei download",
       "torrent":{"hash":"abc","name":"Debian","state":"seeding"}}
      """
    let transport = TransportFinto(.risposta(409, errore))
    let esito = try await APIClient(transport: transport).creaBozza(link: " magnet:?xt=urn:btih:A ")
    let corpo = try #require(transport.richiesta?.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: String])
    #expect(json == ["link": "magnet:?xt=urn:btih:A"])
    guard case .problema(let problema) = esito else {
      Issue.record("atteso il problema")
      return
    }
    #expect(problema.titolo == "Questo torrent è già nei download.")
    #expect(problema.testo == "Debian · in seed")
  }

  @Test func iProblemiComeSulSito() async throws {
    let errore = #"{"error":"insufficient_space","message":"Spazio insufficiente","needed":9,"free":1}"#
    let transport = TransportFinto(.risposta(409, errore))
    let esito = try await APIClient(transport: transport).avviaBozza("d1", file: [0])
    let atteso = ProblemaBozza(codice: "insufficient_space")
    #expect(esito == .problema(atteso))
    #expect(atteso.testo == "Togli qualche file al passo precedente.")
    #expect(ProblemaBozza(codice: "boh", messaggio: "Strano").testo == "Strano")
    #expect(ProblemaBozza.rete.titolo == "qBittorrent non raggiungibile.")
    let rifiutato = TransportFinto(.risposta(500, #"{"error":"internal","message":"no"}"#))
    await #expect(throws: APIError.stato(500)) {
      _ = try await APIClient(transport: rifiutato).bozza("d1")
    }
  }

  @Test func avviaConIFileScelti() async throws {
    let transport = TransportFinto(.risposta(200, #"{"hash":"abc"}"#))
    let esito = try await APIClient(transport: transport).avviaBozza("d1", file: [2, 0])
    #expect(transport.richiesta?.url?.path == "/api/v1/downloads/drafts/d1/start")
    let corpo = try #require(transport.richiesta?.httpBody)
    #expect(String(decoding: corpo, as: UTF8.self) == #"{"files":[0,2]}"#)
    #expect(esito == .fatto("abc"))
  }

  @Test func rileggeRiprovaEAnnulla() async throws {
    let attesa = """
      {"id":"d2","source":"magnet","status":"timeout","infoHash":"abc","name":"x","size":0,"files":[],
       "metadata":{"peers":0,"waitedSeconds":60,"limitSeconds":60}}
      """
    let transport = TransportFinto(.risposta(200, attesa))
    let client = APIClient(transport: transport)
    let letta = try await client.bozza("d2")
    #expect(transport.richiesta?.url?.path == "/api/v1/downloads/drafts/d2")
    guard case .fatto(let bozza) = letta else {
      Issue.record("attesa la bozza")
      return
    }
    #expect(bozza.scaduta)
    #expect(bozza.metadata?.testo == "0 peer · 1:00 su 1:00")
    _ = try await client.riprovaBozza("d2")
    #expect(transport.richiesta?.url?.path == "/api/v1/downloads/drafts/d2/retry")
    #expect(transport.richiesta?.httpMethod == "POST")
  }

  @Test func annullaELoSpazio() async throws {
    let transport = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: transport).annullaBozza("d1")
    #expect(transport.richiesta?.httpMethod == "DELETE")
    let pieno = TransportFinto(.risposta(200, #"{"free":2100000000,"path":"/downloads"}"#))
    let spazio = try await APIClient(transport: pieno).spazio()
    #expect(pieno.richiesta?.url?.path == "/api/v1/downloads/space")
    #expect(spazio.path == "/downloads")
  }
}
