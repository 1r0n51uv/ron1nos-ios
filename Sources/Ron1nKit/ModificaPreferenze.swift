import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

/// Una modifica alle preferenze (IOS-091, SET-003…SET-006, SET-010): solo i
/// gruppi cambiati, come `PATCH /preferences` del sito.
public struct ModificaPreferenze: Encodable, Equatable, Sendable {
  public var appearance: Aspetto?
  public var disabledModules: [String]?
  public var navOrder: [String]?
  public var formats: Formati?

  public init(
    appearance: Aspetto? = nil, disabledModules: [String]? = nil, navOrder: [String]? = nil,
    formats: Formati? = nil
  ) {
    self.appearance = appearance
    self.disabledModules = disabledModules
    self.navOrder = navOrder
    self.formats = formats
  }

  /// Accende o spegne un modulo, lasciando gli altri come sono.
  public static func modulo(
    _ modulo: String, acceso: Bool, in preferenze: Preferenze
  ) -> ModificaPreferenze {
    var spenti = preferenze.disabledModules.filter { $0 != modulo }
    if !acceso { spenti.append(modulo) }
    return ModificaPreferenze(disabledModules: spenti)
  }

  /// Le preferenze come saranno, per mostrarle subito.
  public func applicata(a preferenze: Preferenze) -> Preferenze {
    var nuove = preferenze
    if let appearance { nuove.appearance = appearance }
    if let disabledModules { nuove.disabledModules = disabledModules }
    if let navOrder { nuove.navOrder = navOrder }
    if let formats { nuove.formats = formats }
    return nuove
  }
}

extension Aspetto.Sfondo {
  public var titolo: String {
    switch self {
    case .brace: "Brace"
    case .nebbia: "Nebbia"
    case .grafite: "Grafite"
    case .nero: "Nero"
    case .image: "Immagine"
    }
  }
}

extension Aspetto.Vetro {
  public var titolo: String {
    switch self {
    case .light: "Leggero"
    case .medium: "Medio"
    case .strong: "Intenso"
    }
  }
}

extension Aspetto.Densita {
  public var titolo: String {
    switch self {
    case .comfortable: "Comoda"
    case .compact: "Compatta"
    }
  }
}

/// I moduli che si accendono e spengono (SET-005), con i nomi del sito.
public enum ModuloRon1n: String, CaseIterable, Sendable {
  case nutrition, workout, weight, home, server, containers, downloads, notes, documents

  public var titolo: String {
    switch self {
    case .nutrition: "Nutrizione"
    case .workout: "Allenamento"
    case .weight: "Peso"
    case .home: "Casa"
    case .server: "Server"
    case .containers: "Container"
    case .downloads: "Download"
    case .notes: "Note"
    case .documents: "Documenti"
    }
  }
}

/// Le voci della barra del sito (SET-006), con il nome della pagina.
public enum VoceNavigazione {
  public static func titolo(_ voce: String) -> String {
    switch voce {
    case "pasti": "Dieta"
    case "allenamenti": "Palestra"
    case "documenti": "Documenti"
    case "note": "Note"
    case "casa": "Casa"
    case "server": "Server"
    default: voce
    }
  }

  /// "Nella TabBar: Dieta, Palestra, Documenti".
  public static func riepilogo(_ preferenze: Preferenze) -> (barra: String, altro: String) {
    let navigazione = Navigazione(preferenze)
    let barra = navigazione.schede.filter { $0 != .home && $0 != .altro }.map(\.titolo)
    let altro = navigazione.altro.filter { $0 != .impostazioni }.map(\.titolo)
    return (
      barra.isEmpty ? "nessun modulo" : barra.joined(separator: ", "),
      altro.isEmpty ? "nessun modulo" : altro.joined(separator: ", ")
    )
  }

  /// Sposta le voci come `onMove` di SwiftUI.
  public static func sposta(_ ordine: [String], da origine: IndexSet, a destinazione: Int) -> [String] {
    var nuovo = ordine
    let spostate = origine.map { nuovo[$0] }
    for indice in origine.sorted(by: >) { nuovo.remove(at: indice) }
    let prima = origine.filter { $0 < destinazione }.count
    nuovo.insert(contentsOf: spostate, at: destinazione - prima)
    return nuovo
  }
}

extension Formati {
  /// "80 kg = 176,4 lb".
  public func esempioPeso() -> String {
    weightUnit == .lb ? "80 kg = \(Formato.numero(80 * Formati.lbPerKg, decimali: 1)) lb" : "80 kg = 80 kg"
  }

  /// "2000 kcal = 8.368 kJ".
  public func esempioEnergia() -> String {
    "2000 kcal = \(Formato.numero(valoreEnergia(2000))) \(energyUnit.rawValue)"
  }
}

extension APIClient {
  /// `PATCH /preferences`: le preferenze dopo la modifica.
  public func modificaPreferenze(_ modifica: ModificaPreferenze) async throws(APIError) -> Preferenze {
    try await invia("PATCH", "preferences", corpo: modifica)
  }

  /// `PUT /preferences/background`: JPEG, PNG o WebP fino a 5 MB. Oltre il
  /// limite o con un altro formato il server risponde con un messaggio.
  public func caricaSfondo(
    _ immagine: Data, nome: String, tipo: String
  ) async throws(APIError) -> Esito<Preferenze> {
    let confine = "ron1nOS-\(UUID().uuidString)"
    let corpo = APIClient.multipart(immagine, nome: nome, confine: confine, tipo: tipo)
    let (data, http) = try await risposta(
      "preferences/background", metodo: "PUT", corpo: corpo, tipo: "multipart/form-data; boundary=\(confine)")
    return try APIClient.esito(data, http)
  }

  /// `DELETE /preferences/background`: torna lo sfondo predefinito.
  public func togliSfondo() async throws(APIError) -> Preferenze {
    try await invia("DELETE", "preferences/background")
  }
}
