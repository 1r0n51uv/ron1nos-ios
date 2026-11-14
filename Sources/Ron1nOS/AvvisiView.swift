#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Gli avvisi dei download (IOS-075), per capire perché arrivano o no: il
  /// permesso di iOS, quanti ne sono programmati e fra quanto parte il
  /// prossimo. `Prova` ne manda uno fra 10 secondi; `Prova Mangiato e Rimanda`
  /// uno con i pulsanti dei promemoria dei pasti.
  struct AvvisiView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: NotificheTorrent.Stato?
    @State private var provaInviata = false
    @State private var negato = false
    @State private var provaPastoInviata = false

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        IntestazioneCard(
          titolo: "Avvisi dei download", simbolo: "arrow.down.circle.fill", tinta: Modulo.torrent.colore)
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
        IntestazioneCard(
          titolo: "Promemoria dei pasti", simbolo: "fork.knife", tinta: Modulo.nutrizione.colore
        )
        .padding(.top, 8)
        if provaPastoInviata {
          Text(
            "Prova inviata: esci dall'app, fra 10 secondi arriva. Tieni premuta la notifica (o tirala giù) per vedere Mangiato e Rimanda."
          )
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
        }
        Button("Prova Mangiato e Rimanda") { Task { await provaPasto() } }
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

    private func provaPasto() async {
      let inviata = await sessione.promemoriaPasti.prova(promemoria: sessione.promemoria)
      provaPastoInviata = inviata
      negato = !inviata
    }

    private func prova() async {
      let inviata = await sessione.notifiche.prova()
      provaInviata = inviata
      negato = !inviata
      stato = await sessione.notifiche.stato()
    }
  }
#endif
