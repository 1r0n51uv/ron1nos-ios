import Foundation
import Testing

@testable import Ron1nKit

@Suite struct VolumeGruppiTests {
  static let json = """
    {"groups":["petto","gambe",null],"weeks":[
      {"monday":"2026-10-19","groups":[{"group":"petto","volumeKg":3000,"sets":12},
        {"group":null,"volumeKg":500,"sets":3}]},
      {"monday":"2026-10-26","groups":[{"group":"gambe","volumeKg":4000,"sets":10},
        {"group":"petto","volumeKg":0,"sets":0}]}
    ]}
    """

  @Test func leBarreImpilate() async throws {
    let transport = TransportFinto(.risposta(200, VolumeGruppiTests.json))
    let volume = try await APIClient(transport: transport).volumeGruppi()
    let url = try #require(transport.richiesta?.url)
    #expect(url.path == "/api/v1/workout/muscle-groups")
    #expect(url.query == "weeks=12")
    let pezzi = volume.pezzi(.volume)
    #expect(pezzi.map(\.id) == ["2026-10-19-petto", "2026-10-19-", "2026-10-26-gambe"])
    #expect(pezzi.map(\.valore) == [3000, 500, 4000])
    #expect(pezzi.map(\.indice) == [0, 2, 1])
    #expect(volume.pezzi(.serie).map(\.valore) == [12, 3, 10])
    #expect(!volume.vuoto)
  }

  @Test func nomiEToni() {
    #expect(VolumeGruppi.nome("petto") == "Petto")
    #expect(VolumeGruppi.nome(nil) == "Non assegnato")
    let volume = VolumeGruppi(groups: ["petto", "gambe", nil], weeks: [])
    #expect(volume.opacita(0) == 0.9)
    #expect(abs(volume.opacita(1) - 0.25) < 0.0001)
    #expect(volume.vuoto)
  }
}
