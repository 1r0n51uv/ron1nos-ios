import Foundation

/// Un esercizio del catalogo delle foto (GYM-014): free-exercise-db, nomi
/// in inglese.
public struct EsercizioCatalogo: Decodable, Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let primaryMuscles: [String]
  public let equipment: String?
  public let images: Int
  public let url: String

  public init(
    id: String, name: String, primaryMuscles: [String] = [], equipment: String? = nil, images: Int = 1,
    url: String
  ) {
    self.id = id
    self.name = name
    self.primaryMuscles = primaryMuscles
    self.equipment = equipment
    self.images = images
    self.url = url
  }

  /// La prima foto, da mostrare nella griglia.
  public var immagine: ImmagineEsercizio { ImmagineEsercizio(catalogId: id, source: "catalog", url: url) }
}

/// La risposta alla scelta dell'immagine: con il gruppo proposto se
/// l'esercizio non ne aveva uno (GYM-011).
public struct EsitoImmagine: Decodable, Equatable, Sendable {
  public let name: String
  public let image: ImmagineEsercizio?
  public let group: String?
}

extension APIClient {
  /// `GET /workout/catalog`: al massimo 60 risultati.
  public func catalogoEsercizi(cerca testo: String) async throws(APIError) -> [EsercizioCatalogo] {
    struct Risposta: Decodable { let exercises: [EsercizioCatalogo] }
    let parole = testo.trimmingCharacters(in: .whitespaces)
    let query = parole.isEmpty ? [] : [URLQueryItem(name: "q", value: parole)]
    let risposta: Risposta = try await get("workout/catalog", query: query)
    return risposta.exercises
  }

  /// `PUT /workout/exercises/{name}/group`: nil toglie il gruppo. Vale per
  /// tutto lo storico.
  public func gruppoEsercizio(_ nome: String, gruppo: String?) async throws(APIError) -> String? {
    struct Corpo: Encodable, Sendable {
      let group: String?
      func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(group, forKey: .group)
      }
      enum CodingKeys: String, CodingKey { case group }
    }
    struct Risposta: Decodable { let group: String? }
    let risposta: Risposta = try await invia(
      "PUT", "workout/exercises/\(APIClient.segmento(nome))/group", corpo: Corpo(group: gruppo))
    return risposta.group
  }

  /// `PUT /workout/exercises/{name}/image`: nil torna all'abbinamento
  /// automatico.
  public func immagineEsercizio(_ nome: String, catalogId: String?) async throws(APIError) -> EsitoImmagine {
    struct Corpo: Encodable, Sendable {
      let catalogId: String?
      func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(catalogId, forKey: .catalogId)
      }
      enum CodingKeys: String, CodingKey { case catalogId }
    }
    return try await invia(
      "PUT", "workout/exercises/\(APIClient.segmento(nome))/image", corpo: Corpo(catalogId: catalogId))
  }
}
