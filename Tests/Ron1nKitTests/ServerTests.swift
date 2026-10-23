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
}
