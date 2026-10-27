import Testing

@testable import Ron1nKit

@Suite struct AvvisoTests {
  @Test func testiEDurata() {
    #expect(Avviso.salvato.etichetta == "Salvato")
    #expect(Avviso.copiato.durata == 2.5)
    #expect(Avviso.nonSalvato.etichetta == "Non salvato · Riprova")
    #expect(Avviso.nonSalvato.durata == 8)
    #expect(Avviso("Widget rimosso", azione: "Annulla").durata == 8)
    #expect(Avviso.salvato != Avviso.salvato)
  }

  @Test func moduloSpento() {
    #expect(APIError.stato(404).moduloSpento)
    #expect(!APIError.stato(503).moduloSpento)
  }
}
