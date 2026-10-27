import Foundation

/// Allegati e PDF scaricati per Quick Look o per condividerli: stanno in
/// una cartella temporanea che si svuota quando si chiude il documento e
/// all'avvio dell'app (IOS-061).
public struct FileTemporanei: Sendable {
  public let cartella: URL

  public init(cartella: URL = FileManager.default.temporaryDirectory.appending(component: "documenti")) {
    self.cartella = cartella
  }

  /// Scrive i dati con il loro nome, protetti finché il telefono è bloccato.
  public func scrivi(_ dati: Data, nome: String) throws -> URL {
    let sottocartella = cartella.appending(component: UUID().uuidString)
    try FileManager.default.createDirectory(at: sottocartella, withIntermediateDirectories: true)
    let pulito = nome.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
    let url = sottocartella.appending(component: pulito.isEmpty ? "file" : pulito)
    #if os(iOS)
      try dati.write(to: url, options: [.atomic, .completeFileProtection])
    #else
      try dati.write(to: url, options: .atomic)
    #endif
    return url
  }

  /// Cancella tutto.
  public func svuota() {
    try? FileManager.default.removeItem(at: cartella)
  }
}
