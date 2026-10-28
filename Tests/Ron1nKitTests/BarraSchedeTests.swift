import Testing

@testable import Ron1nKit

@Suite struct BarraSchedeTests {
  @Test func cinqueVociToccabiliSulloSchermoPiuStretto() {
    // iPhone SE e mini: 320 e 375 punti.
    for schermo in [320.0, 375.0, 393.0, 440.0] {
      #expect(BarraSchede.larghezzaVoce(schermo: schermo, voci: 5) >= BarraSchede.minimoTocco)
    }
    #expect(BarraSchede.altezza - 2 * BarraSchede.interno >= BarraSchede.minimoTocco)
  }

  @Test func staccataDaiBordi() {
    #expect(BarraSchede.larghezza(schermo: 393) == 361)
  }

  @Test func suUnoSchermoLargoNonCresce() {
    #expect(BarraSchede.larghezza(schermo: 1024) == BarraSchede.larghezzaMassima)
  }

  @Test func iContenutiNonFinisconoSotto() {
    #expect(BarraSchede.spazioContenuti > BarraSchede.altezza)
  }

  @Test func ancheSenzaVoci() {
    #expect(BarraSchede.larghezzaVoce(schermo: 393, voci: 0) > 0)
  }
}
