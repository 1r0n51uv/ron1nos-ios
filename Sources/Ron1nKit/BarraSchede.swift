/// Le misure della TabBar a pillola (IOS-015), in punti. Stanno qui per
/// provare su Linux che ogni voce resti toccabile anche sullo schermo più
/// stretto.
public enum BarraSchede {
  /// Distanza della pillola dai bordi dello schermo.
  public static let margine = 16.0
  /// Oltre questa larghezza la pillola non cresce e resta al centro.
  public static let larghezzaMassima = 440.0
  public static let altezza = 62.0
  /// Spazio tra il bordo della pillola e la bolla della voce attiva.
  public static let interno = 5.0
  /// Area minima di tocco (HIG: 44×44 pt).
  public static let minimoTocco = 44.0
  /// Lo spazio da lasciare in fondo ai contenuti perché la pillola non li
  /// copra: la pillola e il suo stacco dal fondo.
  public static let spazioContenuti = altezza + 8

  /// Larghezza della pillola su uno schermo largo `schermo`.
  public static func larghezza(schermo: Double) -> Double {
    min(larghezzaMassima, schermo - 2 * margine)
  }

  /// Larghezza di ogni voce con `voci` voci.
  public static func larghezzaVoce(schermo: Double, voci: Int) -> Double {
    (larghezza(schermo: schermo) - 2 * interno) / Double(max(1, voci))
  }
}
