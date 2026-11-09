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

extension APIClient {
  /// `DELETE /auth/sessions/{id}`.
  public func chiudiSessione(_ id: String) async throws(APIError) {
    _ = try await dati("auth/sessions/\(APIClient.segmento(id))", metodo: "DELETE")
  }

  /// `DELETE /auth/sessions/others`: resta aperta solo la sessione di
  /// questo telefono.
  public func chiudiAltreSessioni() async throws(APIError) {
    _ = try await dati("auth/sessions/others", metodo: "DELETE")
  }
}
