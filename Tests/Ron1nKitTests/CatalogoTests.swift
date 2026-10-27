import Foundation
import Testing

@testable import Ron1nKit

@Suite struct CatalogoTests {
  static let corpo = """
    {"grids":{"desktop":{"columns":24},"iphone":{"columns":4,"sizes":{"small":{"w":2,"h":2}}}},
     "widgets":[
      {"id":"nutrition.summary","module":"nutrition","size":{"min":[6,6]},"variants":[],
       "options":[{"key":"macros","label":"Macro","type":"multi",
         "choices":[{"value":"protein","label":"Proteine"},{"value":"fat","label":"Grassi"}],
         "default":["protein"]}],
       "iphone":["large","medium"]},
      {"id":"weight.summary","module":"weight","variants":["detailed","compact"]},
      {"id":"server.metric","module":"server","variants":["detailed","compact"],
       "options":[{"key":"metric","label":"Risorsa","type":"choice",
         "choices":[{"value":"cpu","label":"CPU"},{"value":"ram","label":"RAM"}],"default":"cpu"}],
       "iphone":["small","medium"]},
      {"id":"downloads.summary","module":"downloads","variants":[],
       "options":[{"key":"limit","label":"Download mostrati","type":"count","min":1,"max":6,"default":3}],
       "iphone":["medium","large"]},
      {"id":"downloads.speed","module":"downloads","variants":[],"iphone":["small","medium"]}
     ]}
    """

  static func catalogo() throws -> Catalogo {
    try JSONDecoder().decode(Catalogo.self, from: Data(corpo.utf8))
  }

  @Test func leggeIlCatalogo() async throws {
    let transport = TransportFinto(.risposta(200, CatalogoTests.corpo))
    let catalogo = try await APIClient(transport: transport).catalogo()
    #expect(transport.richiesta?.url?.path == "/api/v1/dashboard/catalog")
    #expect(catalogo.widgets.count == 5)
    #expect(catalogo.voce("server.metric")?.iphone == [.small, .medium])
    #expect(catalogo.voce("server.metric")?.options?.first?.default == .testo("cpu"))
    #expect(catalogo.voce("weight.summary")?.iphone == nil)
    #expect(catalogo.voce("nutrition.summary")?.titolo == "Dieta")
  }

  @Test func soloIWidgetDellIPhoneConModuloAcceso() throws {
    let catalogo = try CatalogoTests.catalogo()
    #expect(catalogo.perIPhone().map(\.id) == [
      "nutrition.summary", "server.metric", "downloads.summary", "downloads.speed",
    ])
    #expect(catalogo.perIPhone(spenti: ["downloads"]).map(\.id) == ["nutrition.summary", "server.metric"])
  }

  @Test func opzioniAmmesse() throws {
    let catalogo = try CatalogoTests.catalogo()
    let macro = try #require(catalogo.voce("nutrition.summary")?.options?.first)
    #expect(macro.ammette(.elenco(["fat", "protein"])))
    #expect(!macro.ammette(.elenco(["fat", "fat"])))
    #expect(!macro.ammette(.elenco(["carbs"])))
    #expect(!macro.ammette(.testo("fat")))
    let limite = try #require(catalogo.voce("downloads.summary")?.options?.first)
    #expect(limite.ammette(.numero(6)))
    #expect(!limite.ammette(.numero(0)))
    #expect(!limite.ammette(.numero(7)))
  }

  static func layout() -> LayoutHome {
    LayoutHome(
      items: LayoutHome.dispone([
        ElementoLayout(id: "nutrition.summary", misura: .large),
        ElementoLayout(id: "server.metric", misura: .small),
        ElementoLayout(id: "downloads.speed", misura: .small),
        ElementoLayout(id: "downloads.summary", misura: .medium),
      ]))
  }

  @Test func spostaRimettendoInGriglia() {
    var layout = CatalogoTests.layout()
    layout.sposta(da: 3, a: 0)
    #expect(layout.ordinati.map(\.id) == [
      "downloads.summary", "nutrition.summary", "server.metric", "downloads.speed",
    ])
    #expect(layout.ordinati.map { [$0.x, $0.y] } == [[0, 0], [0, 2], [0, 6], [2, 6]])
    layout.sposta("server.metric", di: 1)
    #expect(layout.ordinati.map(\.id).suffix(2) == ["downloads.speed", "server.metric"])
    layout.sposta("downloads.summary", di: -1)
    #expect(layout.ordinati.first?.id == "downloads.summary")
  }

  @Test func rimuoveEAggiungeInCima() throws {
    let catalogo = try CatalogoTests.catalogo()
    var layout = CatalogoTests.layout()
    layout.rimuovi("nutrition.summary")
    #expect(layout.ordinati.first?.id == "server.metric")
    #expect(layout.ordinati.first.map { [$0.x, $0.y] } == [0, 0])
    let voce = try #require(catalogo.voce("nutrition.summary"))
    layout.aggiungi(voce, misura: .medium)
    #expect(layout.ordinati.first?.id == "nutrition.summary")
    #expect(layout.ordinati.first?.misura == .medium)
    // Già presente: non si ripete.
    layout.aggiungi(voce)
    #expect(layout.items.count == 4)
    // Misura non ammessa: si usa la predefinita.
    layout.rimuovi("downloads.speed")
    layout.aggiungi(try #require(catalogo.voce("downloads.speed")), misura: .large)
    #expect(layout.ordinati.first?.misura == .small)
    // Senza misure iPhone non entra.
    layout.aggiungi(try #require(catalogo.voce("weight.summary")))
    #expect(!layout.items.contains { $0.id == "weight.summary" })
  }

  @Test func modificaMisuraEOpzioni() throws {
    var layout = CatalogoTests.layout()
    layout.modifica("server.metric") {
      $0.w = 4
      $0.options = ["metric": .testo("ram")]
    }
    let metrica = layout.ordinati.first { $0.id == "server.metric" }
    #expect(metrica?.misura == .medium)
    #expect(metrica?.options?["metric"] == .testo("ram"))
    #expect(layout.problema(try CatalogoTests.catalogo()) == nil)
  }

  @Test func problemiComeIlBackend() throws {
    let catalogo = try CatalogoTests.catalogo()
    #expect(CatalogoTests.layout().problema(catalogo) == nil)

    var ignoto = CatalogoTests.layout()
    ignoto.items.append(ElementoLayout(id: "foo.bar", y: 20, misura: .small))
    #expect(ignoto.problema(catalogo) == "Widget sconosciuto: foo.bar")

    var desktop = CatalogoTests.layout()
    desktop.items.append(ElementoLayout(id: "weight.summary", y: 20, misura: .small))
    #expect(desktop.problema(catalogo) == "Widget non disponibile su iPhone: weight.summary")

    var misura = CatalogoTests.layout()
    misura.items[1].w = 4
    misura.items[1].h = 4
    #expect(misura.problema(catalogo) == "Misura non ammessa: server.metric")

    var fuori = CatalogoTests.layout()
    fuori.items[2].x = 3
    #expect(fuori.problema(catalogo) == "Fuori dalla griglia: downloads.speed")

    var variante = CatalogoTests.layout()
    variante.items[1].variant = "huge"
    #expect(variante.problema(catalogo) == "Variante non disponibile: server.metric")

    var opzioni = CatalogoTests.layout()
    opzioni.items[3].options = ["limit": .numero(9)]
    #expect(opzioni.problema(catalogo) == "Opzioni non valide: downloads.summary")

    var sopra = CatalogoTests.layout()
    sopra.items[2].x = 0
    #expect(sopra.problema(catalogo) == "Widget sovrapposti: server.metric, downloads.speed")
  }

  @Test func salvaConPut() async throws {
    let risposta = """
      {"device":"iphone","header":"hidden","items":[{"id":"downloads.speed","x":0,"y":0,"w":2,"h":2}],
       "updatedAt":"2026-10-27T10:00:00.000Z","stored":true}
      """
    let transport = TransportFinto(.risposta(200, risposta))
    let layout = LayoutHome(header: .hidden, items: [ElementoLayout(id: "downloads.speed", misura: .small)])
    let salvato = try await APIClient(transport: transport).salvaLayoutHome(layout)
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.httpMethod == "PUT")
    #expect(richiesta.url?.path == "/api/v1/dashboard/layouts/iphone")
    #expect(richiesta.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let corpo = try #require(richiesta.httpBody)
    let json = try #require(try JSONSerialization.jsonObject(with: corpo) as? [String: Any])
    #expect(Set(json.keys) == ["header", "items"])
    #expect(json["header"] as? String == "hidden")
    #expect(salvato.items.map(\.id) == ["downloads.speed"])
    #expect(salvato.stored)
  }

  @Test func ripristinaConDelete() async throws {
    let risposta = """
      {"device":"iphone","header":"full","items":[],"updatedAt":null,"stored":true}
      """
    let transport = TransportFinto(.risposta(200, risposta))
    let layout = try await APIClient(transport: transport).ripristinaLayoutHome()
    #expect(transport.richiesta?.httpMethod == "DELETE")
    #expect(transport.richiesta?.httpBody == nil)
    #expect(layout.header == .full)
  }

  @Test func erroreDiValidazione() async {
    let transport = TransportFinto(.risposta(422, #"{"error":"layout non valido"}"#))
    await #expect(throws: APIError.self) {
      _ = try await APIClient(transport: transport).salvaLayoutHome(CatalogoTests.layout())
    }
  }
}
