import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Il form di un tipo di documento (DOC-016): nome, icona e campi da
/// aggiungere, rinominare, riordinare, togliere.
public struct ModuloTipo: Equatable, Sendable {
  public static let icone = ["id-card", "passport", "car", "health", "file", "card", "person"]
  public static let generi = ["text", "date", "code"]

  public var nome: String
  public var icona: String
  public var campi: [CampoTipo]

  public init(nome: String = "", icona: String = "file", campi: [CampoTipo] = []) {
    self.nome = nome
    self.icona = icona
    self.campi = campi
  }

  public init(tipo: TipoDocumento) {
    self.init(nome: tipo.name, icona: tipo.icon, campi: tipo.fields)
  }

  /// "Testo", "Data", "Codice".
  public static func nomeGenere(_ genere: String) -> String {
    switch genere {
    case "date": "Data"
    case "code": "Codice"
    default: "Testo"
    }
  }

  /// Il primo problema, o nil. Gli stessi limiti del backend.
  public var problema: String? {
    let nome = nome.trimmingCharacters(in: .whitespaces)
    if nome.isEmpty { return "Serve un nome." }
    if nome.count > 60 { return "Il nome è troppo lungo." }
    if campi.count > 40 { return "Al massimo 40 campi." }
    if campi.contains(where: { $0.label.trimmingCharacters(in: .whitespaces).isEmpty }) {
      return "Ogni campo vuole un'etichetta."
    }
    if campi.contains(where: { $0.label.trimmingCharacters(in: .whitespaces).count > 60 }) {
      return "Un'etichetta è troppo lunga."
    }
    return nil
  }

  /// I campi esistenti con la loro chiave, i nuovi senza: le chiavi nuove
  /// le genera il server.
  var corpo: Corpo {
    Corpo(
      name: nome.trimmingCharacters(in: .whitespaces), icon: icona,
      fields: campi.map {
        CampoTipo(
          key: $0.key, label: $0.label.trimmingCharacters(in: .whitespaces), kind: $0.kind,
          copyable: $0.copyable)
      })
  }

  struct Corpo: Encodable, Sendable {
    let name: String
    let icon: String
    let fields: [CampoTipo]
  }
}

extension APIClient {
  /// `POST /documents/types`.
  public func creaTipo(_ modulo: ModuloTipo) async throws(APIError) -> Esito<TipoDocumento> {
    try await inviaConMessaggio("POST", "documents/types", corpo: modulo.corpo)
  }

  /// `PATCH /documents/types/{id}`: `fields` è l'elenco completo e ordinato.
  public func modificaTipo(
    _ id: String, _ modulo: ModuloTipo
  ) async throws(APIError) -> Esito<TipoDocumento> {
    try await inviaConMessaggio("PATCH", "documents/types/\(id)", corpo: modulo.corpo)
  }

  /// `DELETE /documents/types/{id}`: nil se eliminato, se no il messaggio
  /// del server (quanti documenti lo usano).
  public func eliminaTipo(_ id: String) async throws(APIError) -> String? {
    let (data, http) = try await risposta("documents/types/\(id)", metodo: "DELETE")
    struct Errore: Decodable { let message: String }
    if http.statusCode == 409 {
      return (try? JSONDecoder().decode(Errore.self, from: data))?.message ?? "Il tipo è in uso."
    }
    guard (200..<300).contains(http.statusCode) else { throw .stato(http.statusCode) }
    return nil
  }
}
