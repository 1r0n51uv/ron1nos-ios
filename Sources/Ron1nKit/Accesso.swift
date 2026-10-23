import Foundation

/// Il service token di Cloudflare Access con cui l'app entra in
/// `*.ron1n.space` senza il login via email (IOS-004). Si manda in ogni
/// richiesta negli header `CF-Access-Client-Id` e `CF-Access-Client-Secret`.
public struct CredenzialiAccesso: Equatable, Sendable {
  public let clientId: String
  public let clientSecret: String

  public init(clientId: String, clientSecret: String) {
    self.clientId = clientId
    self.clientSecret = clientSecret
  }

  /// Gli header da aggiungere alla richiesta.
  public var header: [String: String] {
    ["CF-Access-Client-Id": clientId, "CF-Access-Client-Secret": clientSecret]
  }

  /// Legge le credenziali da un testo incollato. Accetta il JSON che dà
  /// Cloudflare alla creazione del token (`client_id` e `client_secret`,
  /// anche dentro `result`), le due righe di header
  /// (`CF-Access-Client-Id: …`) oppure due righe con id e secret.
  public static func leggi(da testo: String) -> CredenzialiAccesso? {
    if let dati = testo.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: dati),
      let trovate = cerca(in: json)
    {
      return trovate
    }
    let righe = testo.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    var header: [String: String] = [:]
    for riga in righe {
      guard let duePunti = riga.firstIndex(of: ":") else { continue }
      let nome = riga[..<duePunti].trimmingCharacters(in: .whitespaces).lowercased()
      header[nome] = riga[riga.index(after: duePunti)...].trimmingCharacters(in: .whitespaces)
    }
    if let id = header["cf-access-client-id"], let secret = header["cf-access-client-secret"] {
      return valide(id, secret)
    }
    if righe.count == 2 { return valide(righe[0], righe[1]) }
    return nil
  }

  private static func cerca(in json: Any) -> CredenzialiAccesso? {
    guard let oggetto = json as? [String: Any] else { return nil }
    if let id = oggetto["client_id"] as? String, let secret = oggetto["client_secret"] as? String {
      return valide(id, secret)
    }
    return oggetto["result"].flatMap(cerca(in:))
  }

  /// Niente spazi e niente valori vuoti: un id o un secret così è un
  /// errore di copia.
  private static func valide(_ id: String, _ secret: String) -> CredenzialiAccesso? {
    let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
    let secret = secret.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !id.isEmpty, !secret.isEmpty, !id.contains(" "), !secret.contains(" ") else { return nil }
    return CredenzialiAccesso(clientId: id, clientSecret: secret)
  }
}

/// Dove l'app tiene le credenziali. Sul telefono è il Portachiavi, nei test
/// la memoria.
public protocol ArchivioCredenziali: Sendable {
  func carica() -> CredenzialiAccesso?
  func salva(_ credenziali: CredenzialiAccesso) throws
  func cancella() throws
}

/// Archivio in memoria, per i test e per Linux.
public final class ArchivioInMemoria: ArchivioCredenziali, @unchecked Sendable {
  private let lock = NSLock()
  private var credenziali: CredenzialiAccesso?

  public init(_ credenziali: CredenzialiAccesso? = nil) { self.credenziali = credenziali }

  public func carica() -> CredenzialiAccesso? { lock.withLock { credenziali } }
  public func salva(_ credenziali: CredenzialiAccesso) { lock.withLock { self.credenziali = credenziali } }
  public func cancella() { lock.withLock { credenziali = nil } }
}

#if canImport(Security)
  import Security

  /// Una voce generic password del Portachiavi di iOS, leggibile solo su
  /// questo telefono dopo il primo sblocco.
  struct VocePortachiavi: Sendable {
    let servizio: String

    private var query: [String: Any] {
      [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: servizio]
    }

    func leggi() -> Data? {
      var q = query
      q[kSecReturnData as String] = true
      q[kSecMatchLimit as String] = kSecMatchLimitOne
      var risultato: AnyObject?
      guard SecItemCopyMatching(q as CFDictionary, &risultato) == errSecSuccess else { return nil }
      return risultato as? Data
    }

    func scrivi(_ dati: Data) throws {
      try cancella()
      var q = query
      q[kSecValueData as String] = dati
      q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      let stato = SecItemAdd(q as CFDictionary, nil)
      guard stato == errSecSuccess else { throw ErrorePortachiavi(stato: stato) }
    }

    func cancella() throws {
      let stato = SecItemDelete(query as CFDictionary)
      guard stato == errSecSuccess || stato == errSecItemNotFound else {
        throw ErrorePortachiavi(stato: stato)
      }
    }
  }

  /// Il service token di Access nel Portachiavi: id e secret in una voce.
  public struct Portachiavi: ArchivioCredenziali {
    let voce: VocePortachiavi

    public init(servizio: String = "home.ron1n.ios.accesso-cloudflare") {
      voce = VocePortachiavi(servizio: servizio)
    }

    public func carica() -> CredenzialiAccesso? {
      guard let dati = voce.leggi(),
        let valori = try? JSONDecoder().decode([String: String].self, from: dati),
        let id = valori["id"], let secret = valori["secret"]
      else { return nil }
      return CredenzialiAccesso(clientId: id, clientSecret: secret)
    }

    public func salva(_ credenziali: CredenzialiAccesso) throws {
      try voce.scrivi(
        JSONEncoder().encode(["id": credenziali.clientId, "secret": credenziali.clientSecret]))
    }

    public func cancella() throws { try voce.cancella() }
  }

  public struct ErrorePortachiavi: Error, Equatable {
    public let stato: OSStatus
  }
#endif
