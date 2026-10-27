import Foundation
import Testing

@testable import Ron1nKit

@Suite struct GruppoImmagineTests {
  @Test func cercaNelCatalogo() async throws {
    let json = """
      {"exercises":[{"id":"Barbell_Bench_Press","name":"Barbell Bench Press","primaryMuscles":["chest"],
        "equipment":"barbell","images":2,"url":"/api/v1/workout/catalog/images/Barbell_Bench_Press/0.jpg"}]}
      """
    let transport = TransportFinto(.risposta(200, json))
    let catalogo = try await APIClient(transport: transport).catalogoEsercizi(cerca: " bench ")
    let url = try #require(transport.richiesta?.url)
    #expect(url.path == "/api/v1/workout/catalog")
    #expect(url.query == "q=bench")
    #expect(catalogo.map(\.name) == ["Barbell Bench Press"])
    #expect(catalogo[0].immagine.percorso == "workout/catalog/images/Barbell_Bench_Press/0.jpg")
  }

  @Test func assegnaIlGruppo() async throws {
    let transport = TransportFinto(.risposta(200, #"{"name":"panca piana","group":"petto"}"#))
    let gruppo = try await APIClient(transport: transport).gruppoEsercizio("Panca piana", gruppo: "petto")
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.httpMethod == "PUT")
    #expect(richiesta.url?.path(percentEncoded: true) == "/api/v1/workout/exercises/Panca%20piana/group")
    #expect(String(decoding: richiesta.httpBody ?? Data(), as: UTF8.self) == #"{"group":"petto"}"#)
    #expect(gruppo == "petto")
  }

  @Test func togliereIlGruppoMandaNull() async throws {
    let transport = TransportFinto(.risposta(200, #"{"name":"panca piana","group":null}"#))
    let gruppo = try await APIClient(transport: transport).gruppoEsercizio("Panca piana", gruppo: nil)
    #expect(String(decoding: transport.richiesta?.httpBody ?? Data(), as: UTF8.self) == #"{"group":null}"#)
    #expect(gruppo == nil)
  }

  @Test func sceglieLImmagine() async throws {
    let json = """
      {"name":"panca piana","group":"petto",
       "image":{"catalogId":"Barbell_Bench_Press","source":"manual",
        "url":"/api/v1/workout/catalog/images/Barbell_Bench_Press/0.jpg"}}
      """
    let transport = TransportFinto(.risposta(200, json))
    let esito = try await APIClient(transport: transport).immagineEsercizio(
      "Panca piana", catalogId: "Barbell_Bench_Press")
    let richiesta = try #require(transport.richiesta)
    #expect(richiesta.url?.path(percentEncoded: true) == "/api/v1/workout/exercises/Panca%20piana/image")
    let corpo = String(decoding: richiesta.httpBody ?? Data(), as: UTF8.self)
    #expect(corpo == #"{"catalogId":"Barbell_Bench_Press"}"#)
    #expect(esito.image?.source == "manual")
    #expect(esito.group == "petto")

    let automatico = TransportFinto(.risposta(200, #"{"name":"panca piana","group":null,"image":null}"#))
    _ = try await APIClient(transport: automatico).immagineEsercizio("Panca piana", catalogId: nil)
    let nullo = String(decoding: automatico.richiesta?.httpBody ?? Data(), as: UTF8.self)
    #expect(nullo == #"{"catalogId":null}"#)
  }
}
