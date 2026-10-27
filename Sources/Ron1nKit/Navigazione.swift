/// Una pagina dell'app raggiungibile dalla TabBar o da `Altro` (IOS-009).
public enum Scheda: String, CaseIterable, Hashable, Sendable {
  case home, dieta, palestra, documenti, torrent, server, impostazioni, altro

  public var titolo: String {
    switch self {
    case .home: "Home"
    case .dieta: "Dieta"
    case .palestra: "Palestra"
    case .documenti: "Documenti"
    case .torrent: "Torrent"
    case .server: "Server"
    case .impostazioni: "Impostazioni"
    case .altro: "Altro"
    }
  }

  /// Simbolo SF della voce.
  public var icona: String {
    switch self {
    case .home: "square.grid.2x2"
    case .dieta: "fork.knife"
    case .palestra: "dumbbell"
    case .documenti: "doc.text"
    case .torrent: "arrow.down.circle"
    case .server: "server.rack"
    case .impostazioni: "gearshape"
    case .altro: "ellipsis"
    }
  }

  /// Il modulo del backend, per sapere se è spento (SET-005).
  public var modulo: String? {
    switch self {
    case .dieta: "nutrition"
    case .palestra: "workout"
    case .documenti: "documents"
    case .torrent: "downloads"
    case .server: "server"
    case .home, .impostazioni, .altro: nil
    }
  }

  /// La voce della barra del sito (SET-006) che corrisponde a questa
  /// pagina. Torrent sul sito non ha una voce: viene dopo le altre.
  var voceSito: String? {
    switch self {
    case .dieta: "pasti"
    case .palestra: "allenamenti"
    case .documenti: "documenti"
    case .server: "server"
    default: nil
    }
  }
}

/// Come si dividono le pagine tra TabBar e `Altro` (IOS-009): Home prima,
/// poi i primi tre moduli accesi nell'ordine del sito, `Altro` ultima con
/// il resto e Impostazioni.
public struct Navigazione: Equatable, Sendable {
  /// Le cinque voci della TabBar, o meno se i moduli accesi sono pochi.
  public let schede: [Scheda]
  /// Le righe dell'elenco `Altro`.
  public let altro: [Scheda]

  /// Quanti moduli stanno nella TabBar tra Home e `Altro`.
  public static let moduliInBarra = 3

  public init(_ preferenze: Preferenze) {
    let moduli: [Scheda] = [.dieta, .palestra, .documenti, .server, .torrent]
    let ordinati =
      preferenze.navOrder.compactMap { voce in moduli.first { $0.voceSito == voce } }
      + moduli.filter { modulo in
        !preferenze.navOrder.contains { $0 == modulo.voceSito }
      }
    let accesi = ordinati.filter { !preferenze.disabledModules.contains($0.modulo ?? "") }
    let inBarra = Array(accesi.prefix(Navigazione.moduliInBarra))
    schede = [.home] + inBarra + [.altro]
    altro = Array(accesi.dropFirst(Navigazione.moduliInBarra)) + [.impostazioni]
  }

  /// La pagina è raggiungibile: un modulo spento sparisce da tutte e due.
  public func contiene(_ scheda: Scheda) -> Bool {
    schede.contains(scheda) || altro.contains(scheda)
  }
}

extension Scheda {
  /// La pagina di un modulo del backend: `nutrition` è la Dieta.
  public static func perModulo(_ modulo: String) -> Scheda? {
    Scheda.allCases.first { $0.modulo == modulo }
  }
}
