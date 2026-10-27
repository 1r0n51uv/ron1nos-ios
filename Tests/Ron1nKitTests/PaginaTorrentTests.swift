import Testing

@testable import Ron1nKit

@Suite struct PaginaTorrentTests {
  @Test func downloadEAltri() {
    let download = Download(
      downloadSpeed: 1_000_000,
      torrents: [
        Torrent(hash: "a", name: "A", progress: 0.9, state: .downloading),
        Torrent(hash: "b", name: "B", progress: 0.42, state: .queued),
        Torrent(hash: "c", name: "C", progress: 1, state: .seeding),
        Torrent(hash: "d", name: "D", progress: 0.1, state: .stopped),
      ])
    #expect(download.attivi.map(\.hash) == ["a"])
    #expect(download.altri.map(\.hash) == ["b", "c", "d"])
    #expect(download.altri.map(\.rigaBreve) == ["In coda · 42%", "In seed", "Fermo · 10%"])
  }
}
