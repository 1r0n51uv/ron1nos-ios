import Foundation
import Testing

@testable import Ron1nKit

@Suite struct FileTemporaneiTests {
  @Test func scriveESvuota() throws {
    let cartella = FileManager.default.temporaryDirectory.appending(component: "prova-\(UUID().uuidString)")
    let temporanei = FileTemporanei(cartella: cartella)
    let url = try temporanei.scrivi(Data("ciao".utf8), nome: "a/b.pdf")
    #expect(url.lastPathComponent == "a-b.pdf")
    #expect(try Data(contentsOf: url) == Data("ciao".utf8))
    temporanei.svuota()
    #expect(!FileManager.default.fileExists(atPath: cartella.path(percentEncoded: false)))
  }
}
