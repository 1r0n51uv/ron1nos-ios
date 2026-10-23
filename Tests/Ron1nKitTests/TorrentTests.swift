import Foundation
import Testing

@testable import Ron1nKit

@Suite struct TorrentTests {
  func torrent(_ nome: String, _ stato: String, eta: String = "null") -> String {
    """
    {"hash":"\(nome)","name":"\(nome)","progress":0.42,"state":"\(stato)","etaSeconds":\(eta),
     "downloadSpeed":2400000,"size":1000}
    """
  }

  @Test func leggeIDownload() async throws {
    let lista = [
      torrent("a", "downloading", eta: "600"), torrent("b", "downloading"), torrent("c", "queued"),
      torrent("d", "seeding"), torrent("e", "checking"),
    ]
    let corpo = #"{"downloadSpeed":512000,"torrents":[\#(lista.joined(separator: ","))]}"#
    let transport = TransportFinto(.risposta(200, corpo))
    let download = try await APIClient(transport: transport).download()
    #expect(transport.richiesta?.url?.absoluteString == "https://home.ron1n.space/api/v1/downloads")
    #expect(Formato.velocita(download.downloadSpeed) == "512 kB/s")
    #expect(download.inVista.map(\.name) == ["a", "b"])
    #expect(download.inVista[0].dettaglio == "42% · 2,4 MB/s · 10 min")
    #expect(download.inVista[1].dettaglio.hasSuffix("tempo non stimabile"))
    #expect(download.riepilogo == "1 in coda · 1 in seed")
    #expect(download.torrents[4].state == .sconosciuto("checking"))
  }

  @Test func riepilogoConINascosti() {
    let attivi = (0..<5).map { Torrent(hash: "\($0)", name: "\($0)", progress: 0, state: .downloading) }
    let download = Download(downloadSpeed: 0, torrents: attivi)
    #expect(download.inVista.count == 3)
    #expect(download.riepilogo == "+2 attivi")
    let uno = Download(downloadSpeed: 0, torrents: Array(attivi.prefix(4)))
    #expect(uno.riepilogo == "+1 attivo")
    #expect(Download(downloadSpeed: 0, torrents: []).riepilogo == "")
  }

  @Test func qBittorrentNonRaggiungibile() async {
    let client = APIClient(transport: TransportFinto(.risposta(503, #"{"error":"qbittorrent_unreachable"}"#)))
    #expect(await Carico.da { try await client.download() } == .fallito(.stato(503)))
  }
}
