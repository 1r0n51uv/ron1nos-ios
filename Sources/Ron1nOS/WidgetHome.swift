#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// I dati dei widget della Home, letti dalle stesse rotte delle pagine
  /// dei moduli (IOS-021).
  struct DatiWidget {
    var dieta: Carico<GiornoDieta> = .inCorso
    var download: Carico<Download> = .inCorso
    var server: Carico<StatoServer> = .inCorso

    static func carica(con client: APIClient) async -> DatiWidget {
      async let giorno = Carico.da { try await client.dieta() }
      async let torrent = Carico.da { try await client.download() }
      async let risorse = Carico.da { try await client.statoServer() }
      let (d, t, r) = await (giorno, torrent, risorse)
      return DatiWidget(dieta: d, download: t, server: r)
    }
  }

  /// Un widget della Home: il contenuto giusto per id e misura.
  struct WidgetHome: View {
    let elemento: ElementoLayout
    let dati: DatiWidget

    var body: some View {
      Group {
        switch elemento.id {
        case "nutrition.summary": CardDieta(carico: dati.dieta, misura: elemento.misura)
        case "downloads.summary": CardTorrent(carico: dati.download, misura: elemento.misura)
        case "server.summary": CardServer(carico: dati.server, misura: elemento.misura)
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
