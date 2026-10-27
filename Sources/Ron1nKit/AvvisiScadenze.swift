import Foundation

/// Gli avvisi di scadenza dei Documenti (IOS-065): una notifica locale per
/// ogni preavviso attivo e una il giorno dopo la scadenza, alle 9:00. Il
/// testo dice solo tipo e data, mai numeri del documento né nomi.
public enum AvvisiScadenze {
  public static let ora = 9
  public static let chiave = "documento"

  public static func notifiche(
    _ documenti: [DocumentoBreve], adesso: Date, fuso: TimeZone
  ) -> [NotificaLocale] {
    var calendario = Calendar(identifier: .gregorian)
    calendario.timeZone = fuso
    return documenti.flatMap { documento -> [NotificaLocale] in
      guard let scadenza = documento.expiresOn, let giorno = giorno(scadenza, calendario: calendario) else {
        return []
      }
      let tipo = documento.typeName ?? "Documento"
      let preavvisi = documento.warnings ?? ModuloDocumento.preavvisi
      var notifiche = preavvisi.compactMap { anticipo -> NotificaLocale? in
        guard let quando = calendario.date(byAdding: .day, value: -anticipo, to: giorno) else { return nil }
        let corpo = "\(tipo) · scade tra \(anticipo) giorni"
        return notifica(documento, "\(anticipo)", corpo: corpo, quando: quando)
      }
      if let dopo = calendario.date(byAdding: .day, value: 1, to: giorno) {
        notifiche.append(notifica(documento, "scaduto", corpo: "\(tipo) · scaduto", quando: dopo))
      }
      return notifiche.filter { $0.quando > adesso }
    }
  }

  static func notifica(
    _ documento: DocumentoBreve, _ quale: String, corpo: String, quando: Date
  ) -> NotificaLocale {
    NotificaLocale(
      id: "scadenza-\(documento.id)-\(quale)", gruppo: .scadenze, titolo: "Documenti", corpo: corpo,
      quando: quando, dati: [chiave: documento.id])
  }

  /// `2030-01-31` alle 9:00 nel fuso scelto.
  static func giorno(_ testo: String, calendario: Calendar) -> Date? {
    let parti = testo.split(separator: "-").compactMap { Int($0) }
    guard parti.count == 3 else { return nil }
    return calendario.date(from: DateComponents(year: parti[0], month: parti[1], day: parti[2], hour: ora))
  }
}
