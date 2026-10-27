import Foundation

/// Il toast in basso, sopra la TabBar, con l'esito di un'azione che cambia
/// dati (IOS-012). Testi brevi, senza punti esclamativi.
public struct Avviso: Equatable, Identifiable, Sendable {
  public let id: UUID
  public let testo: String
  /// Il pulsante a destra, se c'è: `Riprova`, `Annulla`.
  public let azione: String?
  /// Quanto resta a schermo, in secondi.
  public let durata: Double

  public init(_ testo: String, azione: String? = nil, durata: Double? = nil) {
    id = UUID()
    self.testo = testo
    self.azione = azione
    self.durata = durata ?? (azione == nil ? 2.5 : 8)
  }

  public static var salvato: Avviso { Avviso("Salvato") }
  public static var copiato: Avviso { Avviso("Copiato") }
  public static var nonSalvato: Avviso { Avviso("Non salvato", azione: "Riprova") }

  /// "Non salvato · Riprova": come lo legge VoiceOver.
  public var etichetta: String { [testo, azione].compactMap { $0 }.joined(separator: " · ") }
}

extension APIError {
  /// Il modulo è spento nelle Impostazioni (404 `module_disabled`).
  public var moduloSpento: Bool { self == .stato(404) }
}
