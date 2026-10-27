#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La pagina Server (IOS-080, SRV-001…SRV-007): tre anelli grandi, una
  /// riga con temperatura, uptime e rete, i 3 container più pesanti. Si
  /// aggiorna ogni 5 secondi; i valori scorrono senza lampeggiare.
  struct ServerView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<StatoServer> = .inCorso
    @State private var offline = false

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 4).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito:
            Pillola(testo: "offline", tono: .offline)
            Text("Glances non risponde. Riprovo da solo ogni 5 secondi.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .pronto(let server):
            pillole(server)
            anelli(server)
            righe(server)
            let pesanti = server.piuPesanti()
            if !pesanti.isEmpty {
              container(pesanti)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Server")
      .refreshable { await carica() }
      .task { await carica() }
      .aggiornaOgni(5) { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      let nuovo = await Carico.da { try await client.statoServer() }
      // Un aggiornamento fallito dopo il primo lascia i valori e lo dice
      // la pillola.
      if case .fallito = nuovo, stato.valore != nil {
        offline = true
      } else {
        withAnimation(.easeOut(duration: 0.4)) { stato = nuovo }
        offline = false
      }
    }

    @ViewBuilder
    private func pillole(_ server: StatoServer) -> some View {
      if offline || server.caldo != nil {
        HStack(spacing: 8) {
          if offline { Pillola(testo: "offline", tono: .offline) }
          if let caldo = server.caldo { Pillola(testo: caldo, tono: .alert) }
        }
      }
    }

    private func anelli(_ server: StatoServer) -> some View {
      HStack(spacing: 0) {
        ForEach(server.anelli, id: \.nome) { risorsa in
          AnelloRisorsa(risorsa: risorsa)
            .frame(maxWidth: .infinity)
        }
      }
      .glassPanel()
    }

    private func righe(_ server: StatoServer) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        RigaValore(nome: "Acceso", valore: server.temperaturaEUptime)
        if let rete = server.rete {
          RigaValore(nome: "Rete", valore: rete)
        }
      }
      .glassPanel()
    }

    private func container(_ elenco: [StatoServer.Container]) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("Container")
          Spacer()
          Text("CPU").frame(width: 64, alignment: .trailing)
          Text("RAM").frame(width: 72, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(Stile.testoTenue)
        ForEach(elenco, id: \.name) { voce in
          HStack {
            Text(voce.name)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
            Group {
              Text(Formato.percento(voce.cpu)).frame(width: 64, alignment: .trailing)
              Text(Formato.memoria(voce.memBytes)).frame(width: 72, alignment: .trailing)
            }
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testo)
            .contentTransition(.numericText())
          }
          .accessibilityElement(children: .combine)
        }
      }
      .glassPanel()
    }
  }

  /// Un anello grande con la percentuale in mono: bianco, rosso da 80%.
  struct AnelloRisorsa: View {
    let risorsa: Risorsa

    var body: some View {
      VStack(spacing: 8) {
        ZStack {
          Anello(valore: risorsa.valore, segnale: risorsa.segnale)
          Text(risorsa.testo)
            .font(.system(.title3, design: .monospaced).weight(.semibold))
            .foregroundStyle(Stile.testo)
            .contentTransition(.numericText())
        }
        .frame(width: 92, height: 92)
        Text(risorsa.nome)
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(risorsa.nome) \(risorsa.testo)\(risorsa.segnale ? ", sopra soglia" : "")")
    }
  }
#endif
