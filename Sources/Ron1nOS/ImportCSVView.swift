#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Un CSV arrivato da Liftin' o da File, da importare (IOS-051).
  struct FileCSV: Identifiable, Equatable {
    let id = UUID()
    let nome: String
    let dati: Data

    /// Legge il file, anche fuori dalla sandbox dell'app.
    static func leggi(_ url: URL) -> FileCSV? {
      let accesso = url.startAccessingSecurityScopedResource()
      defer { if accesso { url.stopAccessingSecurityScopedResource() } }
      guard let dati = try? Data(contentsOf: url) else { return nil }
      return FileCSV(nome: url.lastPathComponent, dati: dati)
    }
  }

  /// Il foglio dell'import: l'anteprima del server, poi `Importa` scrive e
  /// `Annulla` lascia tutto com'era.
  struct ImportCSVView: View {
    let file: FileCSV
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var stato: Carico<RispostaImport> = .inCorso
    @State private var importo = false

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            Text(file.nome)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
            switch stato {
            case .inCorso:
              Scheletro(righe: 4).glassPanel()
            case .spento:
              ModuloSpento()
            case .fallito(let errore):
              SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
            case .pronto(.rifiutato(let motivo)):
              Text(motivo)
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPanel(tinta: Stile.brand)
            case .pronto(.pronto(let esito)):
              anteprima(esito)
            }
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Importa da Liftin'")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Importa") { Task { await importa() } }
              .fontWeight(.semibold)
              .disabled(!pronto || importo)
          }
        }
        .task { await anteprima() }
      }
      .tint(Stile.brand)
    }

    private var pronto: Bool {
      if case .pronto(.pronto(let esito)) = stato { return !esito.nienteDiNuovo }
      return false
    }

    @ViewBuilder
    private func anteprima(_ esito: EsitoImport) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text(esito.periodo)
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        ForEach(esito.righe, id: \.0) { riga in
          HStack {
            Text(riga.0)
              .foregroundStyle(Stile.testo)
            Spacer()
            Text(riga.1)
              .font(.system(.body, design: .monospaced))
              .foregroundStyle(Stile.testo)
          }
          .accessibilityElement(children: .combine)
        }
        if esito.nienteDiNuovo {
          Text("Niente di nuovo: lo storico è già aggiornato.")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
      }
      .glassPanel()
    }

    private func anteprima() async {
      let client = sessione.client
      let file = file
      stato = await Carico.da { try await client.anteprimaImport(file.dati, nome: file.nome) }
    }

    private func importa() async {
      importo = true
      defer { importo = false }
      do {
        switch try await sessione.client.importa(file.dati, nome: file.nome) {
        case .pronto(let esito):
          let nuovi = esito.newSessions
          sessione.mostra(Avviso(nuovi == 1 ? "1 allenamento importato" : "\(nuovi) allenamenti importati"))
          sessione.palestraCambiata += 1
          chiudi()
        case .rifiutato(let motivo):
          stato = .pronto(.rifiutato(motivo))
        }
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }
  }
#endif
