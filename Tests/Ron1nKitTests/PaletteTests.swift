import Testing

@testable import Ron1nKit

@Suite struct PaletteTests {
  @Test func contrastoDiRiferimento() {
    // Bianco su nero è 21:1, un colore con sé stesso 1:1.
    let nero = ColoreRGB(hex: 0x000000)
    #expect(abs(Palette.bianco.contrasto(con: nero) - 21) < 0.01)
    #expect(abs(Palette.brand.contrasto(con: Palette.brand) - 1) < 0.0001)
  }

  @Test func ilRossoDelMarchioNonBastaPerIlTestoPiccolo() {
    // Il motivo di IOS-014: #FF2A2A sul fondo peggiore scende sotto 4,5:1.
    #expect(Palette.brand.contrasto(con: Palette.fondoPeggiore) < 4.5)
  }

  @Test func ilRossoDeiTestiPassa() {
    for fondo in [Palette.sfondo, Palette.fondoPeggiore] {
      #expect(Palette.brandTesto.contrasto(con: fondo) >= 4.5)
    }
  }

  @Test func ilTestoTenuePassa() {
    for fondo in [Palette.sfondo, Palette.fondoPeggiore] {
      #expect(Palette.testoTenue(su: fondo).contrasto(con: fondo) >= 4.5)
    }
  }

  @Test func iSimboliRossiPassanoSulNero() {
    // Barre, punti e bordi sul nero chiedono 3:1 (WCAG 1.4.11).
    #expect(Palette.brand.contrasto(con: Palette.sfondo) >= 3)
  }
}
