import Testing

@testable import Ron1nKit

@Suite struct ModuloTests {
  @Test func ogniModuloHaUnaTintaDiversa() {
    let tinte = Modulo.allCases.map(\.tinta)
    for (indice, tinta) in tinte.enumerated() {
      #expect(!tinte[(indice + 1)...].contains(tinta))
    }
  }

  @Test func leTinteRegganoTestiESimboliSulVetro() {
    // Testi e simboli nella tinta del modulo, sopra una card sopra l'alone.
    for modulo in Modulo.allCases {
      for fondo in [Palette.sfondo, Palette.fondoPeggiore] {
        #expect(modulo.tinta.contrasto(con: fondo) >= 4.5, "\(modulo)")
      }
    }
  }

  @Test func ilSimboloNeroSiLeggeSopraLaTinta() {
    // Le tessere: simbolo `inchiostro` su fondo pieno della tinta.
    for modulo in Modulo.allCases {
      #expect(Palette.inchiostro.contrasto(con: modulo.tinta) >= 4.5, "\(modulo)")
    }
  }

  @Test func iMacroSiLegganoESonoDiversi() {
    let macro = ["protein", "carbs", "fat"].map(Palette.macro)
    #expect(Set(macro.map(\.rosso)).count == 3 || Set(macro.map(\.blu)).count == 3)
    for colore in macro {
      #expect(colore.contrasto(con: Palette.fondoPeggiore) >= 4.5)
    }
  }

  @Test func ogniPastoHaIlSuoSimbolo() {
    for slot in GiornoDieta.ordineSlot {
      #expect(GiornoDieta.simboliSlot[slot] != nil, "\(slot)")
    }
    #expect(Set(GiornoDieta.simboliSlot.values).count == GiornoDieta.ordineSlot.count)
  }
}
