/// Lo stato di una card della home: i dati di un modulo, chiesti all'API.
public enum Carico<Valore: Equatable & Sendable>: Equatable, Sendable {
  case inCorso
  case pronto(Valore)
  /// Il modulo è spento nelle Impostazioni della dashboard (404
  /// `module_disabled`): la card non si mostra.
  case spento
  case fallito(APIError)

  /// Esegue `richiesta` e ne fa lo stato della card.
  public static func da(_ richiesta: @Sendable () async throws -> Valore) async -> Carico {
    do {
      return .pronto(try await richiesta())
    } catch {
      let errore = error as? APIError ?? .nonRaggiungibile(codice: nil)
      return errore == .stato(404) ? .spento : .fallito(errore)
    }
  }

  public var valore: Valore? {
    if case .pronto(let valore) = self { return valore }
    return nil
  }
}
