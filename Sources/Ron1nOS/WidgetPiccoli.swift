#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Anello di avanzamento da 0 a 1, bianco; rosso solo oltre la quota.
  struct Anello: View {
    let valore: Double
    var segnale = false
    var spessore: CGFloat = 8

    var body: some View {
      ZStack {
        Circle().stroke(Color.white.opacity(0.1), lineWidth: spessore)
        Circle()
          .trim(from: 0, to: max(0, min(1, valore)))
          .stroke(
            segnale ? Stile.brand : Stile.testo, style: StrokeStyle(lineWidth: spessore, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
      }
    }
  }

  /// `nutrition.calories`: l'anello delle kcal sulla quota del giorno.
  struct WidgetCalorie: View {
    let carico: Carico<GiornoDieta>
    @Environment(\.formati) private var formati

    var body: some View {
      Card(titolo: "Calorie", carico: carico, riempi: true) { giorno in
        HStack {
          Spacer(minLength: 0)
          ZStack {
            Anello(valore: giorno.avanzamento ?? 0, segnale: giorno.oltre)
            VStack(spacing: 2) {
              Text(Formato.numero(formati.valoreEnergia(giorno.totals.kcal)))
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(Stile.testo)
              Text(formati.energyUnit.rawValue)
                .font(.caption2)
                .foregroundStyle(Stile.testoTenue)
            }
          }
          .frame(width: 84, height: 84)
          Spacer(minLength: 0)
        }
      }
    }
  }

  /// `nutrition.next-meal`: il prossimo pasto e cosa c'è di pianificato.
  struct WidgetProssimoPasto: View {
    let carico: Carico<GiornoDieta>
    @Environment(\.formati) private var formati

    var body: some View {
      Card(titolo: "Prossimo pasto", carico: carico, riempi: true) { giorno in
        VStack(alignment: .leading, spacing: 4) {
          Text(giorno.titoloProssimoPasto)
            .font(.title3.weight(.semibold))
            .foregroundStyle(Stile.testo)
          if let piano = giorno.pianificato(formati) {
            Text(piano)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
              .lineLimit(2)
          }
        }
      }
    }
  }

  /// `nutrition.supplements`: quanti integratori presi e quali mancano.
  struct WidgetIntegratori: View {
    let carico: Carico<GiornoDieta>

    var body: some View {
      Card(titolo: "Integratori", carico: carico, riempi: true) { giorno in
        VStack(alignment: .leading, spacing: 8) {
          let lista = giorno.supplements ?? []
          if !lista.isEmpty {
            HStack(spacing: 4) {
              ForEach(lista, id: \.id) { integratore in
                Capsule()
                  .fill(integratore.taken ? Stile.testo : Color.white.opacity(0.12))
                  .frame(height: 6)
              }
            }
          }
          Text(giorno.testoIntegratori)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testo)
          if let mancano = giorno.mancanoIntegratori {
            Text(mancano)
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
              .lineLimit(2)
          }
        }
      }
    }
  }

  /// `workout.summary`: l'ultimo allenamento, la settimana, i giorni di
  /// fila e, dal medio, le ultime settimane in barre.
  struct WidgetAllenamento: View {
    let carico: Carico<RiepilogoAllenamento>
    let misura: Misura

    var body: some View {
      Card(titolo: "Palestra", carico: carico, riempi: true) { riepilogo in
        VStack(alignment: .leading, spacing: 10) {
          if let ultimo = riepilogo.testoUltimo {
            Text(ultimo)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
              .lineLimit(misura == .small ? 2 : 1)
          } else {
            Text("Nessun allenamento")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          }
          HStack(alignment: .bottom, spacing: 18) {
            numero(riepilogo.thisWeek, "settimana")
            if misura != .small { numero(riepilogo.streakDays, "di fila") }
            if misura != .small {
              Spacer(minLength: 0)
              Settimane(conteggi: riepilogo.weeks.suffix(misura == .large ? 12 : 8).map(\.count))
                .frame(width: 110, height: 36)
            }
          }
        }
      }
    }

    private func numero(_ valore: Int, _ etichetta: String) -> some View {
      VStack(alignment: .leading, spacing: 2) {
        Text("\(valore)")
          .font(.system(.title2, design: .monospaced).weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text(etichetta)
          .font(.caption)
          .foregroundStyle(Stile.testoTenue)
      }
    }
  }

  /// Gli allenamenti delle ultime settimane in barre verticali.
  struct Settimane: View {
    let conteggi: [Int]

    var body: some View {
      let massimo = max(1, conteggi.max() ?? 1)
      HStack(alignment: .bottom, spacing: 3) {
        ForEach(Array(conteggi.enumerated()), id: \.offset) { indice, conteggio in
          RoundedRectangle(cornerRadius: 2)
            .fill(indice == conteggi.count - 1 ? Stile.testo : Color.white.opacity(0.3))
            .frame(height: max(3, 36 * CGFloat(conteggio) / CGFloat(massimo)))
        }
      }
    }
  }

  /// `documents.summary`: i documenti in scadenza entro 90 giorni.
  struct WidgetDocumenti: View {
    let carico: Carico<[DocumentoBreve]>
    let misura: Misura

    var body: some View {
      Card(titolo: "Documenti", carico: carico, riempi: true) { documenti in
        let vista = VistaDocumenti(documenti)
        VStack(alignment: .leading, spacing: 8) {
          if documenti.isEmpty {
            Text("Nessun documento")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          } else if vista.inScadenza.isEmpty {
            let prossimo = vista.prossimo.map { "la prossima tra \($0) giorni" }
            Text(["Nessuna scadenza vicina", prossimo].compactMap { $0 }.joined(separator: " · "))
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          } else if misura == .small {
            Text("\(vista.inScadenza.count)")
              .font(.system(.title, design: .monospaced).weight(.semibold))
              .foregroundStyle(Stile.testo)
            Text("in scadenza")
              .font(.caption)
              .foregroundStyle(Stile.testoTenue)
          } else {
            ForEach(vista.inScadenza.prefix(misura == .large ? 6 : 2), id: \.id) { documento in
              HStack {
                Text(documento.etichetta)
                  .font(.subheadline)
                  .foregroundStyle(Stile.testo)
                  .lineLimit(1)
                Spacer()
                Text(documento.expiry?.testo ?? "")
                  .font(.system(.footnote, design: .monospaced))
                  .foregroundStyle(documento.expiry?.scaduto == true ? Stile.brandTesto : Stile.testoTenue)
              }
            }
          }
        }
      }
    }
  }

  /// `downloads.speed`: la velocità totale e quanti scaricano.
  struct WidgetVelocita: View {
    let carico: Carico<Download>

    var body: some View {
      Card(titolo: "Download", carico: carico, riempi: true) { download in
        VStack(alignment: .leading, spacing: 4) {
          Text(Formato.velocita(download.downloadSpeed))
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .foregroundStyle(Stile.testo)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
          Text(download.attivi.isEmpty ? "Niente in download" : "\(download.attivi.count) attivi")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
      }
    }
  }

  /// `server.metric`: una risorsa del server, scelta nelle opzioni.
  struct WidgetRisorsa: View {
    let carico: Carico<StatoServer>
    let risorsa: RisorsaServer
    let compatto: Bool

    var body: some View {
      Card(titolo: risorsa.titolo, carico: carico, riempi: true) { stato in
        VStack(alignment: .leading, spacing: 8) {
          if let valore = stato.percentuale(risorsa) {
            Text(Formato.percento(valore))
              .font(.system(.title, design: .monospaced).weight(.semibold))
              .foregroundStyle(valore >= StatoServer.soglia ? Stile.brandTesto : Stile.testo)
            if !compatto {
              Barra(valore: valore / 100, segnale: valore >= StatoServer.soglia)
            }
          } else if let rete = stato.net {
            Text("↓ \(Formato.velocita(rete.rxBps))")
              .font(.system(.headline, design: .monospaced))
              .foregroundStyle(Stile.testo)
            Text("↑ \(Formato.velocita(rete.txBps))")
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          } else {
            Text("Rete non disponibile")
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
    }
  }
#endif
