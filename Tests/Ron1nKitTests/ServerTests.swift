import Foundation
import Testing

@testable import Ron1nKit

@Suite struct ServerTests {
  @Test func leggeLeRisorse() async throws {
    let corpo = """
      {"cpu":12.4,"ram":47.6,"disk":91,"tempC":52.3,"uptimeSec":270000,
       "net":{"rxBps":1200000,"txBps":80000},"containers":[{"name":"ron1nos","cpu":3,"memBytes":1}]}
      """
    let transport = TransportFinto(.risposta(200, corpo))
    let stato = try await APIClient(transport: transport).statoServer()
    #expect(transport.richiesta?.url?.absoluteString == "https://home.ron1n.space/api/v1/server/stats")
    #expect(stato.risorse.map(\.testo) == ["12%", "48%", "91%"])
    #expect(stato.risorse.map(\.segnale) == [false, false, true])
    #expect(abs(stato.risorse[0].valore - 0.124) < 1e-9)
    #expect(stato.riepilogo == "52 °C · acceso da 3 g · ↓ 1,2 MB/s ↑ 80 kB/s")
  }

  @Test func senzaSensoreNeRete() async throws {
    let corpo = #"{"cpu":5,"ram":20,"disk":30,"uptimeSec":7200}"#
    let stato = try await APIClient(transport: TransportFinto(.risposta(200, corpo))).statoServer()
    #expect(stato.riepilogo == "acceso da 2 h")
  }

  @Test func glancesNonRaggiungibile() async {
    let client = APIClient(transport: TransportFinto(.risposta(503, "{}")))
    #expect(await Carico.da { try await client.statoServer() } == .fallito(.stato(503)))
  }

  @Test func laPaginaServer() throws {
    let corpo = """
      {"cpu":80,"ram":47.6,"disk":91,"tempC":88.4,"uptimeSec":3542400,
       "net":{"rxBps":12400000,"txBps":800000},
       "containers":[{"name":"glances","cpu":2,"memBytes":40000000},
                     {"name":"ron1nos","cpu":12.5,"memBytes":210000000},
                     {"name":"qbittorrent","cpu":12.5,"memBytes":1400000000},
                     {"name":"caddy","cpu":0.4,"memBytes":30000000}]}
      """
    let stato = try JSONDecoder().decode(StatoServer.self, from: Data(corpo.utf8))
    #expect(stato.anelli.map(\.nome) == ["CPU", "RAM", "SSD"])
    #expect(stato.anelli.map(\.segnale) == [true, false, true])
    #expect(stato.caldo == "CPU a 88 °C")
    #expect(stato.temperaturaEUptime == "88 °C · 41 g")
    #expect(stato.rete == "↓ 12,4 MB/s · ↑ 800 kB/s")
    #expect(stato.piuPesanti().map(\.name) == ["qbittorrent", "ron1nos", "glances"])
    #expect(Formato.memoria(210_000_000) == "210 MB")
    #expect(Formato.memoria(1_400_000_000) == "1,4 GB")
  }

  @Test func lePartiCheMancanoSiOmettono() throws {
    let stato = StatoServer(cpu: 5, ram: 20, disk: 30, tempC: 84.9, uptimeSec: 7200)
    #expect(stato.caldo == nil)
    #expect(stato.temperaturaEUptime == "85 °C · 2 h")
    #expect(stato.rete == nil)
    #expect(stato.piuPesanti().isEmpty)
    let senzaSensore = StatoServer(cpu: 5, ram: 20, disk: 30, uptimeSec: 7200)
    #expect(senzaSensore.temperaturaEUptime == "2 h")
  }
}
