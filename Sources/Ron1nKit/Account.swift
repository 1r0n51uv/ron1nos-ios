import Foundation

extension Formato {
  /// Quando è successo, come sul sito: "ora", "12 min fa", "oggi alle
  /// 14:05" o "26/10 alle 14:05". nil se l'istante non si legge.
  public static func momento(
    _ iso: String, adesso: Date = Date(), fuso: TimeZone = TimeZone(identifier: "Europe/Rome") ?? .gmt
  ) -> String? {
    guard let data = CollegamentoYazio.istante(iso) else { return nil }
    let minuti = Int(adesso.timeIntervalSince(data) / 60)
    if minuti < 1 { return "ora" }
    if minuti < 60 { return "\(minuti) min fa" }
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    let parti = calendario.dateComponents([.day, .month, .hour, .minute], from: data)
    let ora = "\(parti.hour ?? 0):\((parti.minute ?? 0) < 10 ? "0" : "")\(parti.minute ?? 0)"
    if calendario.isDate(data, inSameDayAs: adesso) { return "oggi alle \(ora)" }
    let giorno = "\((parti.day ?? 1) < 10 ? "0" : "")\(parti.day ?? 1)"
    let mese = "\((parti.month ?? 1) < 10 ? "0" : "")\(parti.month ?? 1)"
    return "\(giorno)/\(mese) alle \(ora)"
  }
}

/// Un token appena creato: il segreto si vede solo qui e va dritto nel
/// Portachiavi (IOS-092).
public struct TokenCreato: Decodable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let token: String

  public init(id: String, name: String, token: String) {
    self.id = id
    self.name = name
    self.token = token
  }
}

/// Il nome di un token nuovo: non vuoto, al massimo 60 caratteri.
public enum NomeToken {
  public static let predefinito = "iPhone"

  public static func problema(_ nome: String) -> String? {
    let pulito = nome.trimmingCharacters(in: .whitespaces)
    if pulito.isEmpty { return "Serve un nome." }
    if pulito.count > 60 { return "Al massimo 60 caratteri." }
    return nil
  }
}

extension APIClient {
  /// `DELETE /auth/sessions/{id}`.
  public func chiudiSessione(_ id: String) async throws(APIError) {
    _ = try await dati("auth/sessions/\(APIClient.segmento(id))", metodo: "DELETE")
  }

  /// `DELETE /auth/sessions`: l'app entra con il suo token e non ha una
  /// sessione, quindi chiude tutte quelle web.
  public func chiudiSessioniWeb() async throws(APIError) {
    _ = try await dati("auth/sessions", metodo: "DELETE")
  }

  /// `POST /auth/tokens`.
  public func creaToken(nome: String) async throws(APIError) -> TokenCreato {
    struct Corpo: Encodable, Sendable { let name: String }
    let corpo = Corpo(name: nome.trimmingCharacters(in: .whitespaces))
    return try await invia("POST", "auth/tokens", corpo: corpo)
  }

  /// `DELETE /auth/tokens/{id}`: da subito quel token risponde 401.
  public func revocaToken(_ id: String) async throws(APIError) {
    _ = try await dati("auth/tokens/\(APIClient.segmento(id))", metodo: "DELETE")
  }
}
