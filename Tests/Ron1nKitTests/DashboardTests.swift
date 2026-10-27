import Foundation
import Testing

@testable import Ron1nKit

@Suite struct DashboardTests {
  @Test func leggeIlLayoutDellIPhone() async throws {
    let corpo = """
      {"device":"iphone","header":"line","items":[
        {"id":"server.metric","x":2,"y":0,"w":2,"h":2,"variant":"compact","options":{"metric":"ram"}},
        {"id":"nutrition.summary","x":0,"y":2,"w":4,"h":4,"options":{"macros":["fat","protein"]}},
        {"id":"downloads.speed","x":0,"y":0,"w":2,"h":2},
        {"id":"downloads.summary","x":0,"y":6,"w":4,"h":2,"options":{"limit":2}}
      ],"updatedAt":null,"stored":false}
      """
    let transport = TransportFinto(.risposta(200, corpo))
    let layout = try await APIClient(transport: transport).layoutHome()
    #expect(transport.richiesta?.url?.path == "/api/v1/dashboard/layouts/iphone")
    #expect(layout.header == .line)
    #expect(!layout.stored)
    let ordine = ["downloads.speed", "server.metric", "nutrition.summary", "downloads.summary"]
    #expect(layout.ordinati.map(\.id) == ordine)
    #expect(layout.ordinati[1].options?["metric"] == .testo("ram"))
    #expect(layout.ordinati[2].options?["macros"] == .elenco(["fat", "protein"]))
    #expect(layout.ordinati[3].options?["limit"] == .numero(2))
    #expect(layout.ordinati[2].misura == .large)
  }

  @Test func predefinitoComeIlBackend() {
    let items = LayoutHome.predefinito.items
    #expect(
      items.map(\.id) == [
        "nutrition.summary", "workout.summary", "server.metric", "downloads.speed", "documents.summary",
      ])
    #expect(
      items.map { [$0.x, $0.y, $0.w, $0.h] } == [
        [0, 0, 4, 4], [0, 4, 4, 2], [0, 6, 2, 2], [2, 6, 2, 2], [0, 8, 4, 2],
      ])
  }

  @Test func righeConIPiccoliAffiancati() {
    let righe = LayoutHome.predefinito.righe()
    #expect(
      righe.map { $0.map(\.id) } == [
        ["nutrition.summary"], ["workout.summary"], ["server.metric", "downloads.speed"],
        ["documents.summary"],
      ])
  }

  @Test func moduloSpentoNonSiVedeMaResta() {
    let layout = LayoutHome.predefinito
    let righe = layout.righe(spenti: ["server"])
    // downloads.speed sale e resta da solo: un piccolo a sinistra.
    #expect(
      righe.map { $0.map(\.id) } == [
        ["nutrition.summary"], ["workout.summary"], ["downloads.speed"], ["documents.summary"],
      ])
    #expect(layout.items.count == 5)
  }

  @Test func misure() {
    #expect(Misura(w: 2, h: 2) == .small)
    #expect(Misura(w: 4, h: 2) == .medium)
    #expect(Misura(w: 4, h: 4) == .large)
    #expect(Misura(w: 2, h: 4) == nil)
    #expect(ElementoLayout(id: "server.metric", misura: .small).modulo == "server")
  }

  @Test func testata() throws {
    let roma = try #require(TimeZone(identifier: "Europe/Rome"))
    // 27 ottobre 2026, 08:41 UTC: 09:41 a Roma (ora solare dal 25 ottobre).
    let data = Date(timeIntervalSince1970: 1_793_090_460)
    #expect(Testata.data(data, fuso: roma) == "MARTEDÌ 27 OTTOBRE · 09:41")
    #expect(Testata.dataCorta(data, fuso: roma) == "MAR 27 OTT · 09:41")
    #expect(Testata.saluto(data, fuso: roma) == "Buongiorno.")
    #expect(Testata.stato(prossimoPasto: "dinner") == "Ti manca la cena.")
    #expect(Testata.stato(prossimoPasto: nil) == "")
  }
}
