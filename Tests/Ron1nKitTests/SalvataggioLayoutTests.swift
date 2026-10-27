import Foundation
import Testing

@testable import Ron1nKit

/// Registra i layout inviati e risponde come deciso.
final class InvioFinto: @unchecked Sendable {
  private let blocco = NSLock()
  private var registro: [LayoutHome] = []
  var errore: APIError?

  var inviati: [LayoutHome] {
    blocco.lock()
    defer { blocco.unlock() }
    return registro
  }

  func invia(_ layout: LayoutHome) throws(APIError) -> LayoutHome {
    blocco.lock()
    registro.append(layout)
    blocco.unlock()
    if let errore { throw errore }
    return layout
  }
}

@MainActor
@Suite struct SalvataggioLayoutTests {
  static let layout = LayoutHome(items: [ElementoLayout(id: "downloads.speed", misura: .small)])

  static func salvataggio(_ finto: InvioFinto) -> (SalvataggioLayout, Esiti) {
    let salvataggio = SalvataggioLayout(ritardo: .milliseconds(30)) {
      (layout: LayoutHome) throws(APIError) -> LayoutHome in
      try finto.invia(layout)
    }
    let esiti = Esiti()
    salvataggio.esito = { esiti.elenco.append($0) }
    return (salvataggio, esiti)
  }

  final class Esiti {
    var elenco: [SalvataggioLayout.Esito] = []
  }

  @Test func unSoloInvioDopoLUltimaModifica() async throws {
    let finto = InvioFinto()
    let (salvataggio, esiti) = SalvataggioLayoutTests.salvataggio(finto)
    var layout = SalvataggioLayoutTests.layout
    salvataggio.programma(layout)
    layout.header = .line
    salvataggio.programma(layout)
    layout.header = .hidden
    salvataggio.programma(layout)
    #expect(finto.inviati.isEmpty)
    await salvataggio.attendi()
    #expect(finto.inviati.map(\.header) == [.hidden])
    #expect(esiti.elenco == [.salvato(layout)])
    #expect(salvataggio.inSospeso == nil)
  }

  @Test func seFallisceRestaInSospesoESiRiprova() async throws {
    let finto = InvioFinto()
    finto.errore = .stato(503)
    let (salvataggio, esiti) = SalvataggioLayoutTests.salvataggio(finto)
    salvataggio.programma(SalvataggioLayoutTests.layout)
    await salvataggio.attendi()
    #expect(esiti.elenco == [.fallito(APIError.stato(503).titolo)])
    #expect(salvataggio.inSospeso == SalvataggioLayoutTests.layout)

    finto.errore = nil
    salvataggio.riprova()
    await salvataggio.attendi()
    #expect(finto.inviati.count == 2)
    #expect(esiti.elenco.last == .salvato(SalvataggioLayoutTests.layout))
    #expect(salvataggio.inSospeso == nil)
  }

  @Test func unLayoutFuoriRegolaNonParte() async throws {
    let finto = InvioFinto()
    let (salvataggio, esiti) = SalvataggioLayoutTests.salvataggio(finto)
    salvataggio.catalogo = try CatalogoTests.catalogo()
    var layout = SalvataggioLayoutTests.layout
    layout.items[0].x = 3
    salvataggio.programma(layout)
    await salvataggio.attendi()
    #expect(finto.inviati.isEmpty)
    #expect(esiti.elenco == [.fallito("Fuori dalla griglia: downloads.speed")])
  }

  @Test func riprovaSenzaNullaInSospesoNonInvia() async {
    let finto = InvioFinto()
    let (salvataggio, _) = SalvataggioLayoutTests.salvataggio(finto)
    salvataggio.riprova()
    await salvataggio.attendi()
    #expect(finto.inviati.isEmpty)
  }

  @Test func avviso() {
    #expect(Avviso.layoutNonSalvato.etichetta == "Layout non salvato · Riprova")
    #expect(Avviso.layoutNonSalvato.durata == 8)
  }
}
