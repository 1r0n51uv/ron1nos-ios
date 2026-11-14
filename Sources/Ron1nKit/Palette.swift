import Foundation

/// Un colore sRGB, canali da 0 a 1. Serve a tenere i token dei colori in un
/// posto solo e a provarne il contrasto su Linux (IOS-014).
public struct ColoreRGB: Equatable, Sendable {
  public let rosso: Double
  public let verde: Double
  public let blu: Double

  public init(rosso: Double, verde: Double, blu: Double) {
    self.rosso = rosso
    self.verde = verde
    self.blu = blu
  }

  /// Da un esadecimale come `0xFF2A2A`.
  public init(hex: UInt32) {
    self.init(
      rosso: Double((hex >> 16) & 0xFF) / 255,
      verde: Double((hex >> 8) & 0xFF) / 255,
      blu: Double(hex & 0xFF) / 255)
  }

  /// Questo colore con opacità `opacita` steso sopra `fondo`.
  public func sopra(_ fondo: ColoreRGB, opacita: Double) -> ColoreRGB {
    func mescola(_ a: Double, _ b: Double) -> Double { a * opacita + b * (1 - opacita) }
    return ColoreRGB(
      rosso: mescola(rosso, fondo.rosso), verde: mescola(verde, fondo.verde), blu: mescola(blu, fondo.blu))
  }

  /// Luminanza relativa secondo WCAG 2.
  public var luminanza: Double {
    func lineare(_ c: Double) -> Double {
      c <= 0.040_45 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * lineare(rosso) + 0.7152 * lineare(verde) + 0.0722 * lineare(blu)
  }

  /// Rapporto di contrasto WCAG con un altro colore, da 1 a 21.
  public func contrasto(con altro: ColoreRGB) -> Double {
    let chiaro = max(luminanza, altro.luminanza)
    let scuro = min(luminanza, altro.luminanza)
    return (chiaro + 0.05) / (scuro + 0.05)
  }
}

/// I colori del design system ron1nOS. Il fondo è nero e il vetro neutro;
/// ogni modulo ha la sua tinta (IOS-043), che lo fa riconoscere a colpo
/// d'occhio. Il rosso resta il marchio e il segnale di allarme.
public enum Palette {
  /// Il rosso del marchio: barre, bordi, punti e interruttori.
  public static let brand = ColoreRGB(hex: 0xFF2A2A)
  /// Il rosso per i testi e i simboli piccoli (`--brand-text` del sito):
  /// il `brand` scende sotto 4,5:1 sul velo delle card sopra l'alone.
  public static let brandTesto = ColoreRGB(hex: 0xFF8A8A)
  public static let sfondo = ColoreRGB(hex: 0x070707)
  public static let bianco = ColoreRGB(hex: 0xFFFFFF)
  /// Le tinte dei moduli (IOS-043), abbastanza chiare da reggere testi e
  /// simboli sul fondo peggiore e scure abbastanza da reggere un simbolo
  /// nero sopra di sé, nelle tessere.
  public static let nutrizione = ColoreRGB(hex: 0x34D399)
  public static let server = ColoreRGB(hex: 0x38BDF8)
  public static let torrent = ColoreRGB(hex: 0xFBBF24)
  public static let impostazioni = ColoreRGB(hex: 0xA5B4CB)
  /// I tre macro, nei grafici e nelle barre.
  public static let proteine = ColoreRGB(hex: 0x7DD3FC)
  public static let carboidrati = ColoreRGB(hex: 0xFCD34D)
  public static let grassi = ColoreRGB(hex: 0xF9A8D4)
  /// Il nero dei simboli sopra una tinta.
  public static let inchiostro = ColoreRGB(hex: 0x0A0A0A)

  /// Il colore di un macro dalla sua chiave (`protein`, `carbs`, `fat`).
  public static func macro(_ chiave: String) -> ColoreRGB {
    switch chiave {
    case "protein": proteine
    case "carbs": carboidrati
    default: grassi
    }
  }

  /// Opacità del velo bianco di card e pillole (IOS-003).
  public static let velo = 0.06
  /// Opacità del testo secondario, bianco.
  public static let opacitaTestoTenue = 0.6

  /// Il fondo più chiaro sotto un testo: una pillola (velo) dentro una card
  /// (velo) sopra l'alone rosso più forte dello sfondo `brace` (30%).
  public static var fondoPeggiore: ColoreRGB {
    let alone = brand.sopra(sfondo, opacita: 0.3)
    let card = bianco.sopra(alone, opacita: velo)
    return bianco.sopra(card, opacita: velo)
  }

  /// Il testo secondario steso su un fondo.
  public static func testoTenue(su fondo: ColoreRGB) -> ColoreRGB {
    bianco.sopra(fondo, opacita: opacitaTestoTenue)
  }
}
