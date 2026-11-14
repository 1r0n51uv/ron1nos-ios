#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il dettaglio di un torrent (IOS-074, DL-011): dimensione, rapporto,
  /// cartella, data e i file con l'avanzamento, più pausa, ripresa ed
  /// eliminazione. Si aggiorna ogni 5 secondi.
  struct TorrentDettaglioView: View {
    let hash: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var stato = Carico<DettaglioTorrent>.inCorso
    @State private var eliminando = false
    @State private var inCorso = false
    /// Cresce a ogni azione riuscita: dà la vibrazione di conferma.
    @State private var riuscite = 0

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel().transition(.blurReplace)
          case .spento:
            Text("Il modulo Download è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            if errore == .stato(404) {
              Text("Il torrent non c'è più.")
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
            } else {
              SezioneErrore(errore: errore).glassPanel()
            }
          case .pronto(let dettaglio):
            intestazione(dettaglio)
              .comparsa(0)
            dati(dettaglio)
              .comparsa(2)
            file(dettaglio)
              .comparsa(3)
          }
        }
        .padding(.horizontal, Stile.margine)
        .padding(.bottom, 24)
      }
      .sfondoPagina()
      .navigationTitle("Dettaglio")
      .navigationBarTitleDisplayMode(.inline)
      .confirmationDialog("Eliminare il torrent?", isPresented: $eliminando, titleVisibility: .visible) {
        Button("Elimina e tieni i file", role: .destructive) { elimina(conFile: false) }
        Button("Elimina anche i file", role: .destructive) { elimina(conFile: true) }
        Button("Annulla", role: .cancel) {}
      }
      // Pausa o ripresa, l'azione di tutti i giorni, piena e in basso;
      // Elimina accanto, in rosso (IOS-044).
      .azioniInBasso {
        if let dettaglio = stato.valore {
          AzioneBarra(
            titolo: dettaglio.inPausa ? "Riprendi" : "Pausa",
            simbolo: dettaglio.inPausa ? "play.fill" : "pause.fill",
            principale: true, inCorso: inCorso
          ) {
            esegui(dettaglio.inPausa ? .resume : .pause)
          }
          AzioneBarra(titolo: "Elimina", simbolo: "trash", distruttiva: true) { eliminando = true }
            .disabled(inCorso)
        }
      }
      .sensoryFeedback(.success, trigger: riuscite)
      .task(id: sessione.versione) { await carica() }
      .aggiornaOgni(5) { await carica() }
    }

    /// L'anello grande con la percentuale, il nome e lo stato.
    private func intestazione(_ dettaglio: DettaglioTorrent) -> some View {
      let ambra = Modulo.torrent.colore
      return HStack(spacing: 16) {
        Anello(valore: dettaglio.progress, tinta: ambra, spessore: 8) {
          Text(Formato.percento(dettaglio.progress * 100))
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .foregroundStyle(Stile.testo)
            .contentTransition(.numericText())
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .padding(.horizontal, 10)
        }
        .frame(width: 84, height: 84)
        VStack(alignment: .leading, spacing: 6) {
          Text(dettaglio.name)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Stile.testo)
            .lineLimit(4)
            .truncationMode(.middle)
          Text(dettaglio.statoTesto.uppercased())
            .font(.system(.caption2, design: .monospaced).weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(ambra)
        }
      }
      .glassPanel(tinta: ambra)
      .accessibilityElement(children: .combine)
    }

    private func dati(_ dettaglio: DettaglioTorrent) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        ForEach(dettaglio.righe, id: \.nome) { riga in
          RigaValore(nome: riga.nome, valore: riga.valore)
        }
        if let aggiunto = dettaglio.aggiunto {
          RigaValore(
            nome: "Aggiunto",
            valore: aggiunto.formatted(
              .dateTime.day().month(.abbreviated).year().hour().minute()
                .locale(Locale(identifier: "it_IT"))))
        }
      }
      .glassPanel()
    }

    private func file(_ dettaglio: DettaglioTorrent) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        IntestazioneCard(
          titolo: "File · \(dettaglio.files.count)", simbolo: "doc.on.doc.fill", tinta: Modulo.torrent.colore)
        VStack(alignment: .leading, spacing: 14) {
          ForEach(dettaglio.files, id: \.index) { file in
            VStack(alignment: .leading, spacing: 6) {
              Text(file.name)
                .font(.footnote)
                .foregroundStyle(file.selected ? Stile.testo : Stile.testoTenue)
                .lineLimit(2)
                .truncationMode(.middle)
              if file.selected { Barra(valore: file.progress, tinta: Modulo.torrent.colore, altezza: 4) }
              Text(
                file.selected
                  ? "\(Formato.percento(file.progress * 100)) · \(Formato.dimensione(file.size))"
                  : "escluso · \(Formato.dimensione(file.size))"
              )
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
            }
            .accessibilityElement(children: .combine)
          }
        }
      }
      .glassPanel()
    }

    private func carica() async {
      let client = sessione.client
      let hash = hash
      let nuovo = await Carico.da { try await client.dettaglio(torrent: hash) }
      // Un aggiornamento fallito dopo il primo non cancella i dati.
      if case .fallito(let errore) = nuovo, errore != .stato(404), stato.valore != nil { return }
      withAnimation(Stile.molla) { stato = nuovo }
    }

    private func esegui(_ azione: AzioneTorrent) {
      Task {
        inCorso = true
        defer { inCorso = false }
        do {
          try await sessione.client.azione(azione, hashes: [hash])
          riuscite += 1
          sessione.mostra(Avviso(azione == .pause ? "Messo in pausa" : "Ripreso"))
          await carica()
        } catch let errore as APIError {
          sessione.mostra(Avviso(errore.titolo))
        } catch {
          sessione.mostra(Avviso("Non riuscito"))
        }
      }
    }

    private func elimina(conFile: Bool) {
      Task {
        inCorso = true
        defer { inCorso = false }
        do {
          try await sessione.client.azione(.delete, hashes: [hash], eliminaFile: conFile)
          riuscite += 1
          sessione.mostra(Avviso("Eliminato"))
          chiudi()
        } catch let errore as APIError {
          sessione.mostra(Avviso(errore.titolo))
        } catch {
          sessione.mostra(Avviso("Non riuscito"))
        }
      }
    }
  }
#endif
