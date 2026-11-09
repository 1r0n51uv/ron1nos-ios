import Foundation
import Testing

@testable import Ron1nKit

@Suite struct AccountTests {
  let fuso = TimeZone(identifier: "Europe/Rome")!

  @Test func quandoComeSulSito() throws {
    let adesso = try #require(CollegamentoYazio.istante("2026-10-27T15:00:00Z"))
    #expect(Formato.momento("2026-10-27T14:59:30Z", adesso: adesso, fuso: fuso) == "ora")
    #expect(Formato.momento("2026-10-27T14:48:00Z", adesso: adesso, fuso: fuso) == "12 min fa")
    #expect(Formato.momento("2026-10-27T09:05:00.123Z", adesso: adesso, fuso: fuso) == "oggi alle 10:05")
    #expect(Formato.momento("2026-10-26T13:05:00Z", adesso: adesso, fuso: fuso) == "26/10 alle 14:05")
    #expect(Formato.momento("boh", adesso: adesso, fuso: fuso) == nil)
  }

  @Test func leSessioni() async throws {
    let una = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: una).chiudiSessione("s1")
    #expect(una.richiesta?.url?.path == "/api/v1/auth/sessions/s1")
    #expect(una.richiesta?.httpMethod == "DELETE")
    let altre = TransportFinto(.risposta(204, ""))
    try await APIClient(transport: altre).chiudiAltreSessioni()
    #expect(altre.richiesta?.url?.path == "/api/v1/auth/sessions/others")
    #expect(altre.richiesta?.httpMethod == "DELETE")
  }
}
