import Foundation
import Testing

@testable import Ron1nKit

@Suite struct NotificheTorrentTests {
  func torrent(_ nome: String, _ stato: StatoTorrent, progresso: Double = 0.5, eta: Int? = nil)
    -> Torrent
  {
    Torrent(hash: nome, name: nome, progress: progresso, state: stato, etaSeconds: eta)
  }

  func download(_ torrents: [Torrent]) -> Download {
    Download(downloadSpeed: 0, torrents: torrents)
  }

  @Test func programmaLaFinePrevistaConIlMargine() {
    let piano = PianoNotificheTorrent.piano(
      download: download([torrent("a", .downloading, eta: 600)]), prima: [])
    #expect(piano.programma.map(\.id) == ["torrent-fine-a"])
    #expect(piano.programma.first?.tra == 660)
    #expect(piano.programma.first?.corpo == "a dovrebbe aver finito.")
    #expect(piano.inDownload == ["a"])
  }

  @Test func senzaStimaNonProgramma() {
    let piano = PianoNotificheTorrent.piano(
      download: download([torrent("a", .downloading, eta: nil)]), prima: [])
    #expect(piano.programma.isEmpty)
    #expect(piano.inDownload == ["a"])
  }

  @Test func unaStimaBrevissimaNonScattaSubito() {
    let piano = PianoNotificheTorrent.piano(
      download: download([torrent("a", .downloading, eta: 0)]), prima: [])
    #expect(piano.programma.first?.tra == 5 + PianoNotificheTorrent.margine)
  }

  @Test func finitoDaUltimaLettura() {
    let piano = PianoNotificheTorrent.piano(
      download: download([torrent("a", .seeding, progresso: 1)]), prima: ["a"])
    #expect(piano.finiti.map(\.id) == ["torrent-finito-a"])
    #expect(piano.finiti.first?.titolo == "Download finito")
    #expect(piano.finiti.first?.tra == nil)
    #expect(piano.annulla == ["torrent-fine-a"])
    #expect(piano.inDownload.isEmpty)
  }

  @Test func fermatoAMetaNonEFinito() {
    let piano = PianoNotificheTorrent.piano(
      download: download([torrent("a", .stopped, progresso: 0.4)]), prima: ["a"])
    #expect(piano.finiti.isEmpty)
    #expect(piano.annulla == ["torrent-fine-a"])
  }

  @Test func eliminatoNonEFinitoMaSiAnnulla() {
    let piano = PianoNotificheTorrent.piano(download: download([]), prima: ["a"])
    #expect(piano.finiti.isEmpty)
    #expect(piano.annulla == ["torrent-fine-a"])
  }

  @Test func giaInSeedNonAvvisaDiNuovo() {
    let piano = PianoNotificheTorrent.piano(
      download: download([torrent("a", .seeding, progresso: 1)]), prima: [])
    #expect(piano.finiti.isEmpty)
    #expect(piano.annulla.isEmpty)
  }

  @Test func ancoraInDownloadNonSiAnnulla() {
    let piano = PianoNotificheTorrent.piano(
      download: download([torrent("a", .downloading, eta: 60)]), prima: ["a"])
    #expect(piano.annulla.isEmpty)
    #expect(piano.finiti.isEmpty)
  }
}
