import Foundation

/// Il salvataggio da solo del layout della Home (IOS-024): un secondo
/// dopo l'ultima modifica parte un solo `PUT`. Se il layout non passa le
/// regole del catalogo o il backend non risponde, resta in sospeso: il
/// layout sullo schermo non cambia e `riprova()` lo rimanda.
@MainActor
public final class SalvataggioLayout {
  public enum Esito: Equatable, Sendable {
    case salvato(LayoutHome)
    case fallito(String)
  }

  public typealias Invio = @Sendable (LayoutHome) async throws(APIError) -> LayoutHome

  private let ritardo: Duration
  private let invia: Invio
  /// Le regole per controllare il layout prima dell'invio, se lette.
  public var catalogo: Catalogo?
  /// Chiamata a ogni invio finito, riuscito o no.
  public var esito: (@MainActor (Esito) -> Void)?
  /// L'ultimo layout cambiato e non ancora salvato.
  public private(set) var inSospeso: LayoutHome?
  private var compito: Task<Void, Never>?

  public init(ritardo: Duration = .seconds(1), invia: @escaping Invio) {
    self.ritardo = ritardo
    self.invia = invia
  }

  /// Il layout è cambiato: riparte l'attesa.
  public func programma(_ layout: LayoutHome) {
    inSospeso = layout
    compito?.cancel()
    compito = Task { [ritardo] in
      try? await Task.sleep(for: ritardo)
      guard !Task.isCancelled else { return }
      await self.salva()
    }
  }

  /// Rimanda subito l'ultimo layout non salvato.
  public func riprova() {
    guard inSospeso != nil else { return }
    compito?.cancel()
    compito = Task { await self.salva() }
  }

  /// Aspetta l'invio in corso, se c'è.
  public func attendi() async {
    await compito?.value
  }

  private func salva() async {
    guard let layout = inSospeso else { return }
    if let problema = catalogo.flatMap(layout.problema) {
      esito?(.fallito(problema))
      return
    }
    do {
      let salvato = try await invia(layout)
      // Un cambio arrivato durante l'invio resta da salvare.
      if inSospeso == layout { inSospeso = nil }
      esito?(.salvato(salvato))
    } catch {
      esito?(.fallito(error.titolo))
    }
  }
}

extension Avviso {
  public static var layoutNonSalvato: Avviso { Avviso("Layout non salvato", azione: "Riprova") }
}
