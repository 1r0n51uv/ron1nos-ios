import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Cosa fa, o farebbe, l'import del CSV di Liftin' (GYM-003). Il CSV lo
/// legge solo il server: l'app manda il file e mostra i conti.
public struct EsitoImport: Decodable, Equatable, Sendable {
  public let newSessions: Int
  public let updatedSessions: Int
  public let unchangedSessions: Int
  public let deletedSessions: Int
  public let newSets: Int
  public let updatedSets: Int
  public let skippedRows: Int
  public let from: String
  public let to: String

  public init(
    newSessions: Int, updatedSessions: Int = 0, unchangedSessions: Int = 0, deletedSessions: Int = 0,
    newSets: Int = 0, updatedSets: Int = 0, skippedRows: Int = 0, from: String, to: String
  ) {
    self.newSessions = newSessions
    self.updatedSessions = updatedSessions
    self.unchangedSessions = unchangedSessions
    self.deletedSessions = deletedSessions
    self.newSets = newSets
    self.updatedSets = updatedSets
    self.skippedRows = skippedRows
    self.from = from
    self.to = to
  }

  /// Le righe del foglio: "Allenamenti nuovi" e "12".
  public var righe: [(String, String)] {
    var righe = [
      ("Allenamenti nuovi", "\(newSessions)"), ("Allenamenti aggiornati", "\(updatedSessions)"),
      ("Già presenti", "\(unchangedSessions)"),
    ]
    if deletedSessions > 0 { righe.append(("Eliminati in ron1nOS, lasciati fuori", "\(deletedSessions)")) }
    if skippedRows > 0 { righe.append(("Righe scartate", "\(skippedRows)")) }
    return righe
  }

  /// "Dal 3 gennaio 2025 al 26 ottobre 2026".
  public var periodo: String {
    "Dal \(EsitoImport.giorno(from)) al \(EsitoImport.giorno(to))"
  }

  /// Niente da scrivere: tutto già presente.
  public var nienteDiNuovo: Bool { newSessions == 0 && updatedSessions == 0 }

  static func giorno(_ testo: String) -> String {
    let parti = testo.split(separator: "-").compactMap { Int($0) }
    guard parti.count == 3, (1...12).contains(parti[1]) else { return testo }
    return "\(parti[2]) \(Testata.mesi[parti[1] - 1]) \(parti[0])"
  }
}

/// La risposta del server a un CSV: i conti, o il motivo per cui il file
/// non va (file vuoto, colonne mancanti…), con il suo testo.
public enum RispostaImport: Equatable, Sendable {
  case pronto(EsitoImport)
  case rifiutato(String)
}

extension APIClient {
  /// `POST /workout/import/preview`: i conti senza scrivere niente.
  public func anteprimaImport(_ file: Data, nome: String) async throws(APIError) -> RispostaImport {
    try await inviaCSV("workout/import/preview", file: file, nome: nome)
  }

  /// `POST /workout/import`: unisce il file allo storico.
  public func importa(_ file: Data, nome: String) async throws(APIError) -> RispostaImport {
    try await inviaCSV("workout/import", file: file, nome: nome)
  }

  func inviaCSV(_ path: String, file: Data, nome: String) async throws(APIError) -> RispostaImport {
    let confine = "ron1nOS-\(UUID().uuidString)"
    let (data, http) = try await risposta(
      path, metodo: "POST", corpo: APIClient.multipart(file, nome: nome, confine: confine),
      tipo: "multipart/form-data; boundary=\(confine)")
    struct Errore: Decodable { let message: String }
    if http.statusCode == 400 {
      let errore = try? JSONDecoder().decode(Errore.self, from: data)
      return .rifiutato(errore?.message ?? "Il file non è un CSV di Liftin'.")
    }
    guard (200..<300).contains(http.statusCode) else { throw .stato(http.statusCode) }
    do {
      return .pronto(try JSONDecoder().decode(EsitoImport.self, from: data))
    } catch {
      throw .rispostaInattesa(codice: nil)
    }
  }

  /// Un corpo `multipart/form-data` con il campo `file` e, se ci sono,
  /// campi di testo.
  static func multipart(
    _ file: Data, nome: String, confine: String, tipo: String = "text/csv", campi: [(String, String)] = []
  ) -> Data {
    let pulito = nome.replacingOccurrences(of: "\"", with: "")
    var corpo = Data()
    for (chiave, valore) in campi {
      corpo.append(Data("--\(confine)\r\n".utf8))
      corpo.append(Data("Content-Disposition: form-data; name=\"\(chiave)\"\r\n\r\n\(valore)\r\n".utf8))
    }
    corpo.append(Data("--\(confine)\r\n".utf8))
    corpo.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(pulito)\"\r\n".utf8))
    corpo.append(Data("Content-Type: \(tipo)\r\n\r\n".utf8))
    corpo.append(file)
    corpo.append(Data("\r\n--\(confine)--\r\n".utf8))
    return corpo
  }
}
