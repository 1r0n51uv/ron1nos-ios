import Foundation

/// Le frasi dei promemoria (NUT-035): per ogni pasto un po' di varietà, una
/// scelta in modo stabile dall'id della notifica, così il testo non cambia a
/// ogni ricalcolo ma da un giorno all'altro sì. `%@` è il nome del piatto.
public enum MessaggiPasto {
  public struct Messaggio: Equatable, Sendable {
    public let titolo: String
    public let corpo: String
  }

  static let frasi: [String: [Messaggio]] = [
    "breakfast": [
      .init(titolo: "Colazione, si parte", corpo: "Il caffè da solo non fa testo: oggi %@."),
      .init(titolo: "Buongiorno a stomaco vuoto", corpo: "Lo riempiamo con %@."),
      .init(titolo: "La giornata aspetta", corpo: "Ma prima %@."),
      .init(titolo: "Sveglia, carburante", corpo: "In tavola: %@."),
    ],
    "morning_snack": [
      .init(titolo: "Spuntino di metà mattina", corpo: "Il pranzo è ancora lontano: %@ ti salva."),
      .init(titolo: "Pausa, per favore", corpo: "Te lo sei meritato: %@."),
      .init(titolo: "Lo stomaco bussa", corpo: "Risposta pronta: %@."),
      .init(titolo: "Un morso strategico", corpo: "Oggi tocca a %@."),
    ],
    "lunch": [
      .init(titolo: "È ora di pranzo", corpo: "Oggi il menù dice %@. Non farti pregare."),
      .init(titolo: "Fermi tutti, si mangia", corpo: "%@ non si mangia da solo."),
      .init(titolo: "Pausa pranzo", corpo: "Chiudi un attimo il resto: c'è %@."),
      .init(titolo: "Mezzogiorno di fuoco", corpo: "Per spegnerlo: %@."),
    ],
    "afternoon_snack": [
      .init(titolo: "Merenda, il rito", corpo: "Il pomeriggio regge meglio con %@."),
      .init(titolo: "Calo di zuccheri in vista", corpo: "Prevenzione: %@."),
      .init(titolo: "Quattro passi verso la cucina", corpo: "Ti aspetta %@."),
      .init(titolo: "Piccola pausa", corpo: "Grande occasione per %@."),
    ],
    "dinner": [
      .init(titolo: "A cena", corpo: "Chiudiamo la giornata con %@."),
      .init(titolo: "La cucina ti chiama", corpo: "Stasera in scena: %@."),
      .init(titolo: "Ultimo pasto, il migliore", corpo: "%@, e poi divano."),
      .init(titolo: "Cena servita (da te)", corpo: "Il menù: %@."),
    ],
  ]

  static let generiche = [
    Messaggio(titolo: "Si mangia?", corpo: "In programma %@.")
  ]

  /// Il promemoria dell'orario del pasto.
  public static func promemoria(slot: String, nome: String, seme: String) -> Messaggio {
    let elenco = frasi[slot] ?? generiche
    let scelta = elenco[indice(seme, elenco.count)]
    return Messaggio(titolo: scelta.titolo, corpo: scelta.corpo.replacingOccurrences(of: "%@", with: nome))
  }

  /// L'avviso di un'azione collegata: il titolo è il suo, la riga sotto dice
  /// per quale piatto.
  public static func azione(_ titolo: String, nome: String, seme: String) -> Messaggio {
    let code = [
      "Così domani non sei in ritardo: %@.",
      "Lo dico adesso, poi non dire che non ti avevo avvisato: %@.",
      "Piccolo favore al te di domani: %@.",
      "Memo per %@.",
    ]
    let scelta = code[indice(seme, code.count)]
    return Messaggio(titolo: titolo, corpo: scelta.replacingOccurrences(of: "%@", with: nome))
  }

  /// Un indice stabile da un testo (la somma dei suoi byte; `hashValue` cambia a ogni avvio).
  static func indice(_ seme: String, _ quanti: Int) -> Int {
    seme.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) % 100_003 } % max(quanti, 1)
  }
}
