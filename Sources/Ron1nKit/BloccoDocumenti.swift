import Foundation

/// Il blocco dei Documenti con Face ID (IOS-064): lo sblocco vale finché
/// l'app resta in primo piano e fino a 1 minuto in background.
public struct BloccoDocumenti: Equatable, Sendable {
  public static let tolleranza: TimeInterval = 60
  public static let chiave = "documenti.faceID"

  /// L'interruttore in Impostazioni, acceso di default.
  public var attivo: Bool
  public private(set) var sbloccato = false
  private var inBackgroundDa: Date?

  public init(attivo: Bool = true) {
    self.attivo = attivo
  }

  /// L'interruttore salvato su questo telefono.
  public init(defaults: UserDefaults) {
    self.init(attivo: defaults.object(forKey: BloccoDocumenti.chiave) as? Bool ?? true)
  }

  /// I Documenti si vedono solo così.
  public var aperto: Bool { !attivo || sbloccato }

  public mutating func sblocca() {
    sbloccato = true
    inBackgroundDa = nil
  }

  public mutating func blocca() {
    sbloccato = false
  }

  public mutating func entraInBackground(_ adesso: Date = Date()) {
    if inBackgroundDa == nil { inBackgroundDa = adesso }
  }

  /// Tornando in primo piano: oltre il minuto si richiede Face ID.
  public mutating func torna(_ adesso: Date = Date()) {
    if let da = inBackgroundDa, adesso.timeIntervalSince(da) > BloccoDocumenti.tolleranza {
      sbloccato = false
    }
    inBackgroundDa = nil
  }
}
