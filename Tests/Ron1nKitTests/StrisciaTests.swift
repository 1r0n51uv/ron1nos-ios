import Foundation
import Testing

@testable import Ron1nKit

@Suite struct StrisciaTests {
  // 27 ottobre 2026, 08:41 UTC: martedì 27 a Roma.
  static let adesso = Date(timeIntervalSince1970: 1_793_090_460)

  @Test func dieciIndietroETrediciAvanti() throws {
    let roma = try #require(TimeZone(identifier: "Europe/Rome"))
    let striscia = Striscia(oggi: StrisciaTests.adesso, fuso: roma)
    #expect(striscia.oggi == "2026-10-27")
    #expect(striscia.giorni.count == 24)
    #expect(striscia.giorni.first?.id == "2026-10-17")
    #expect(striscia.giorni.last?.id == "2026-11-09")
    let oggi = try #require(striscia.giorno("2026-10-27"))
    #expect(oggi.oggi)
    #expect(!oggi.futuro)
    #expect(oggi.lettera == "M")
    #expect(oggi.numero == 27)
    #expect(striscia.giorno("2026-10-28")?.futuro == true)
    #expect(striscia.giorno("2026-10-26")?.lettera == "L")
    #expect(striscia.giorno("2026-11-01")?.lettera == "D")
    #expect(striscia.giorni.filter(\.oggi).count == 1)
  }

  @Test func ilFusoDecideIlGiorno() throws {
    // 23:30 a Roma è il 27; alle Hawaii è il 27 a mezzogiorno.
    let sera = Date(timeIntervalSince1970: 1_793_140_200)
    let roma = try #require(TimeZone(identifier: "Europe/Rome"))
    let honolulu = try #require(TimeZone(identifier: "Pacific/Honolulu"))
    #expect(Striscia(oggi: sera, fuso: roma).oggi == "2026-10-27")
    #expect(Striscia(oggi: sera, fuso: honolulu).oggi == "2026-10-27")
    // Un'ora dopo a Roma è il 28, alle Hawaii è ancora il 27.
    let notte = sera.addingTimeInterval(3_600)
    #expect(Striscia(oggi: notte, fuso: roma).oggi == "2026-10-28")
    #expect(Striscia(oggi: notte, fuso: honolulu).oggi == "2026-10-27")
  }
}
