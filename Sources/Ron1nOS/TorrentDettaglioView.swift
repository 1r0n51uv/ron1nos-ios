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

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel()
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
            dati(dettaglio)
            azioni(dettaglio)
            file(dettaglio)
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Dettaglio")
      .navigationBarTitleDisplayMode(.inline)
      .confirmationDialog("Eliminare il torrent?", isPresented: $eliminando, titleVisibility: .visible) {
        Button("Elimina e tieni i file", role: .destructive) { elimina(conFile: false) }
        Button("Elimina anche i file", role: .destructive) { elimina(conFile: true) }
        Button("Annulla", role: .cancel) {}
      }
      .task(id: sessione.versione) { await carica() }
      .aggiornaOgni(5) { await carica() }
    }

    private func intestazione(_ dettaglio: DettaglioTorrent) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(dettaglio.name)
          .font(.headline)
          .foregroundStyle(Stile.testo)
        Barra(valore: dettaglio.progress)
        Text("\(dettaglio.statoTesto) · \(Formato.percento(dettaglio.progress * 100))")
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
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

    private func azioni(_ dettaglio: DettaglioTorrent) -> some View {
      HStack(spacing: 12) {
        if dettaglio.inPausa {
          Button("Riprendi") { esegui(.resume) }.glassChip()
        } else {
          Button("Pausa") { esegui(.pause) }.glassChip()
        }
        Button("Elimina") { eliminando = true }
          .glassChip()
          .foregroundStyle(Stile.brandTesto)
      }
      .disabled(inCorso)
    }

    private func file(_ dettaglio: DettaglioTorrent) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("File · \(dettaglio.files.count)")
          .font(.footnote.weight(.medium))
          .foregroundStyle(Stile.testoTenue)
        VStack(alignment: .leading, spacing: 14) {
          ForEach(dettaglio.files, id: \.index) { file in
            VStack(alignment: .leading, spacing: 6) {
              Text(file.name)
                .font(.footnote)
                .foregroundStyle(file.selected ? Stile.testo : Stile.testoTenue)
                .lineLimit(2)
                .truncationMode(.middle)
              if file.selected { Barra(valore: file.progress) }
              Text(
                file.selected
                  ? "\(Formato.percento(file.progress * 100)) · \(Formato.dimensione(file.size))"
                  : "escluso · \(Formato.dimensione(file.size))"
              )
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
            }
            .accessibilityElement(children: .combine)
          }
        }
        .glassPanel()
      }
    }

    private func carica() async {
      let client = sessione.client
      let hash = hash
      let nuovo = await Carico.da { try await client.dettaglio(torrent: hash) }
      // Un aggiornamento fallito dopo il primo non cancella i dati.
      if case .fallito(let errore) = nuovo, errore != .stato(404), stato.valore != nil { return }
      stato = nuovo
    }

    private func esegui(_ azione: AzioneTorrent) {
      Task {
        inCorso = true
        defer { inCorso = false }
        do {
          try await sessione.client.azione(azione, hashes: [hash])
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
