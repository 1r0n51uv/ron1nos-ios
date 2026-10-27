import Foundation

/// I gruppi di notifiche locali (IOS-011), ognuno con il suo interruttore
/// in Impostazioni › Notifiche.
public enum GruppoNotifiche: String, CaseIterable, Codable, Sendable {
  case pasti, acqua, scadenze

  public var titolo: String {
    switch self {
    case .pasti: "Pasti"
    case .acqua: "Acqua"
    case .scadenze: "Scadenze documenti"
    }
  }
}

/// Quali gruppi sono accesi su questo telefono. Tutti spenti finché non si
/// accendono: il permesso di iOS si chiede solo allora.
public struct ScelteNotifiche: Codable, Equatable, Sendable {
  public var accesi: Set<GruppoNotifiche>

  public init(accesi: Set<GruppoNotifiche> = []) {
    self.accesi = accesi
  }

  public func acceso(_ gruppo: GruppoNotifiche) -> Bool { accesi.contains(gruppo) }

  public mutating func imposta(_ gruppo: GruppoNotifiche, acceso: Bool) {
    if acceso { accesi.insert(gruppo) } else { accesi.remove(gruppo) }
  }
}

/// Una notifica da programmare con `UNUserNotificationCenter`.
public struct NotificaLocale: Equatable, Sendable {
  /// Stabile tra un ricalcolo e l'altro: `pasto-2026-10-27-lunch`.
  public let id: String
  public let gruppo: GruppoNotifiche
  public let titolo: String
  public let corpo: String
  public let quando: Date
  /// La categoria con i pulsanti (`Sì`, `Rimanda`), se c'è.
  public let categoria: String?
  /// Cosa aprire o fare quando si tocca: id del documento, slot e giorno.
  public let dati: [String: String]

  public init(
    id: String, gruppo: GruppoNotifiche, titolo: String, corpo: String, quando: Date,
    categoria: String? = nil, dati: [String: String] = [:]
  ) {
    self.id = id
    self.gruppo = gruppo
    self.titolo = titolo
    self.corpo = corpo
    self.quando = quando
    self.categoria = categoria
    self.dati = dati
  }
}

/// Sceglie quali notifiche programmare (IOS-011): solo i gruppi accesi,
/// solo nel futuro, le più vicine per prime. iOS ne tiene al massimo 64
/// in attesa per app.
public enum PianoNotifiche {
  public static let massimo = 64

  public static func scegli(
    _ candidate: [NotificaLocale], scelte: ScelteNotifiche, adesso: Date
  ) -> [NotificaLocale] {
    var visti = Set<String>()
    let valide = candidate.filter { notifica in
      scelte.acceso(notifica.gruppo) && notifica.quando > adesso && visti.insert(notifica.id).inserted
    }
    return Array(valide.sorted { $0.quando < $1.quando }.prefix(massimo))
  }
}

/// Le scelte sul telefono: le notifiche sono di questo iPhone, non vanno
/// nelle preferenze condivise.
public struct MemoriaNotifiche: @unchecked Sendable {
  let defaults: UserDefaults
  static let chiave = "ron1nos.notifiche"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func carica() -> ScelteNotifiche {
    guard let dati = defaults.data(forKey: MemoriaNotifiche.chiave),
      let scelte = try? JSONDecoder().decode(ScelteNotifiche.self, from: dati)
    else { return ScelteNotifiche() }
    return scelte
  }

  public func salva(_ scelte: ScelteNotifiche) {
    if let dati = try? JSONEncoder().encode(scelte) {
      defaults.set(dati, forKey: MemoriaNotifiche.chiave)
    }
  }
}

/// Il permesso di iOS per le notifiche, come appare in Impostazioni ›
/// Notifiche e Salute (IOS-094).
public enum PermessoNotifiche: Equatable, Sendable {
  case nonChiesto, concesso, negato

  public var testo: String {
    switch self {
    case .nonChiesto: "da chiedere"
    case .concesso: "concesso"
    case .negato: "negato in iOS"
    }
  }

  /// Da segnalare in rosso: con il permesso negato nessun gruppo suona.
  public var segnale: Bool { self == .negato }

  /// Cosa dire sotto lo stato.
  public var spiegazione: String {
    switch self {
    case .nonChiesto: "iOS lo chiede la prima volta che accendi un gruppo."
    case .concesso: "Le notifiche accese arrivano su questo iPhone."
    case .negato: "Le notifiche di ron1nOS sono spente nelle impostazioni di iOS."
    }
  }
}
