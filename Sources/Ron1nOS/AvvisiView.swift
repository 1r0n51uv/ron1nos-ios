#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Gli avvisi dei download (IOS-075), per capire perché arrivano o no: il
  /// permesso di iOS, quanti ne sono programmati e fra quanto parte il
  /// prossimo. `Prova` ne manda uno fra 10 secondi.
  struct AvvisiView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: NotificheTorrent.Stato?
    @State private var provaInviata = false
    @State private var negato = false

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text("Avvisi dei download")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        VStack(alignment: .leading, spacing: 12) {
          RigaValore(nome: "Permesso", valore: stato?.permesso ?? "·")
          RigaValore(nome: "Programmati", valore: programmati)
        }
        if provaInviata {
          Text("Prova inviata: esci dall'app, arriva fra 10 secondi.")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
        if negato {
          Text("Gli avvisi sono negati: si riaccendono in Impostazioni di iOS › ron1nOS › Notifiche.")
            .font(.footnote)
            .foregroundStyle(Stile.brandTesto)
        }
        Button("Prova") { Task { await prova() } }
          .glassChip()
      }
      .glassPanel()
      .task(id: sessione.versione) { stato = await sessione.notifiche.stato() }
    }

    private var programmati: String {
      guard let stato else { return "·" }
      guard stato.programmati > 0 else { return "nessuno" }
      let quando = stato.prossimo.map { " · tra \(Formato.rimanente(max(0, Int($0))))" } ?? ""
      return "\(stato.programmati)\(quando)"
    }

    private func prova() async {
      let inviata = await sessione.notifiche.prova()
      provaInviata = inviata
      negato = !inviata
      stato = await sessione.notifiche.stato()
    }
  }
#endif
