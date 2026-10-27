#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// I dati dei widget della Home, letti dalle stesse rotte delle pagine
  /// dei moduli (IOS-021).
  struct DatiWidget {
    var dieta: Carico<GiornoDieta> = .inCorso
    var download: Carico<Download> = .inCorso
    var server: Carico<StatoServer> = .inCorso
    var allenamento: Carico<RiepilogoAllenamento> = .inCorso
    var documenti: Carico<[DocumentoBreve]> = .inCorso

    static func carica(con client: APIClient) async -> DatiWidget {
      async let giorno = Carico.da { try await client.dieta() }
      async let torrent = Carico.da { try await client.download() }
      async let risorse = Carico.da { try await client.statoServer() }
      async let palestra = Carico.da { try await client.allenamento() }
      async let elenco = Carico.da { try await client.documenti() }
      let (d, t, r, a, e) = await (giorno, torrent, risorse, palestra, elenco)
      return DatiWidget(dieta: d, download: t, server: r, allenamento: a, documenti: e)
    }
  }

  /// Un widget della Home: il contenuto giusto per id e misura.
  struct WidgetHome: View {
    let elemento: ElementoLayout
    let dati: DatiWidget

    var body: some View {
      Group {
        let misura = elemento.misura
        switch elemento.id {
        case "nutrition.summary":
          CardDieta(
            carico: dati.dieta, misura: misura,
            macro: elemento.opzione("macros", predefinita: ["protein", "carbs", "fat"]))
        case "nutrition.calories": WidgetCalorie(carico: dati.dieta)
        case "nutrition.next-meal": WidgetProssimoPasto(carico: dati.dieta)
        case "nutrition.supplements": WidgetIntegratori(carico: dati.dieta)
        case "workout.summary": WidgetAllenamento(carico: dati.allenamento, misura: misura)
        case "documents.summary": WidgetDocumenti(carico: dati.documenti, misura: misura)
        case "downloads.summary":
          let limite = elemento.opzione("limit", predefinita: Download.visibili)
          CardTorrent(carico: dati.download, misura: misura, limite: limite)
        case "downloads.speed": WidgetVelocita(carico: dati.download)
        case "server.summary": CardServer(carico: dati.server, misura: misura)
        case "server.metric":
          WidgetRisorsa(
            carico: dati.server,
            risorsa: RisorsaServer(rawValue: elemento.opzione("metric", predefinita: "cpu")) ?? .cpu,
            compatto: elemento.compatto)
        default: WidgetInArrivo(elemento: elemento)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }

  /// Un widget del catalogo che l'app non disegna ancora.
  struct WidgetInArrivo: View {
    let elemento: ElementoLayout

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text(Scheda.perModulo(elemento.modulo)?.titolo ?? elemento.modulo)
          .font(.footnote.weight(.medium))
          .foregroundStyle(Stile.testoTenue)
        Text("In arrivo")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        Spacer(minLength: 0)
      }
      .frame(maxHeight: .infinity, alignment: .topLeading)
      .glassPanel()
    }
  }
#endif
