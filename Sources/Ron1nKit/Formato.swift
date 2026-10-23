import Foundation

/// Numeri all'italiana, come nella dashboard web (src/lib/format.ts):
/// virgola decimale, punto delle migliaia. Senza NumberFormatter, così il
/// risultato è lo stesso su iOS e su Linux.
public enum Formato {
  public static func numero(_ valore: Double, decimali: Int = 0) -> String {
    let fattore = pow(10, Double(decimali))
    let arrotondato = (abs(valore) * fattore).rounded() / fattore
    let intero = Int(arrotondato)
    var cifre = String(intero)
    var gruppi: [String] = []
    while cifre.count > 3 {
      gruppi.insert(String(cifre.suffix(3)), at: 0)
      cifre.removeLast(3)
    }
    gruppi.insert(cifre, at: 0)
    var testo = gruppi.joined(separator: ".")
    if decimali > 0 {
      let parte = Int(((arrotondato - Double(intero)) * fattore).rounded())
      let decimale = String(parte)
      testo += "," + String(repeating: "0", count: max(0, decimali - decimale.count)) + decimale
    }
    return valore < 0 && arrotondato > 0 ? "−" + testo : testo
  }

  /// Una percentuale già in 0…100: "42%".
  public static func percento(_ valore: Double) -> String { "\(numero(valore))%" }

  /// Velocità in unità decimali: kB/s sotto 1 MB/s, poi MB/s.
  public static func velocita(_ bytePerSecondo: Double) -> String {
    let b = max(0, bytePerSecondo)
    return b < 1_000_000 ? "\(numero(b / 1_000)) kB/s" : "\(numero(b / 1_000_000, decimali: 1)) MB/s"
  }

  /// Da quanto è acceso il server: ore sotto il giorno, poi giorni.
  public static func acceso(_ secondi: Int) -> String {
    let ore = max(0, secondi) / 3_600
    return ore < 24 ? "\(ore) h" : "\(ore / 24) g"
  }

  /// Tempo alla fine di un torrent.
  public static func rimanente(_ secondi: Int?) -> String {
    guard let secondi else { return "tempo non stimabile" }
    if secondi < 60 { return "meno di 1 min" }
    let minuti = Int((Double(secondi) / 60).rounded())
    return minuti < 60 ? "\(minuti) min" : "\(minuti / 60) h \(minuti % 60) min"
  }
}
