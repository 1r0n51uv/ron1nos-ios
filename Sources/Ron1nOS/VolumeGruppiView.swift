#if canImport(SwiftUI)
  import Charts
  import Ron1nKit
  import SwiftUI

  /// Volume per gruppo muscolare (IOS-055, GYM-012): barre impilate delle
  /// ultime 12 settimane in toni di grigio, `Non assegnato` tratteggiato.
  struct VolumeGruppiView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato: Carico<VolumeGruppi> = .inCorso
    @State private var misura = VolumeGruppi.Misura.volume

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Picker("Misura", selection: $misura) {
            ForEach(VolumeGruppi.Misura.allCases, id: \.self) { voce in
              Text(voce.titolo).tag(voce)
            }
          }
          .pickerStyle(.segmented)
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
          case .pronto(let volume) where volume.vuoto:
            Text("Nessuna serie valida nelle ultime 12 settimane.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .pronto(let volume):
            grafico(volume)
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Volume per gruppo")
      .refreshable { await carica() }
      .task(id: sessione.palestraCambiata) { await carica() }
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.volumeGruppi(settimane: 12) }
    }

    private func grafico(_ volume: VolumeGruppi) -> some View {
      VStack(alignment: .leading, spacing: 16) {
        Chart(volume.pezzi(misura)) { pezzo in
          BarMark(x: .value("Settimana", pezzo.monday), y: .value(misura.titolo, pezzo.valore))
            .foregroundStyle(tinta(pezzo.gruppo, indice: pezzo.indice, volume: volume))
        }
        .chartXAxis(.hidden)
        .chartYAxis {
          AxisMarks(position: .leading) { _ in
            AxisGridLine().foregroundStyle(Color.white.opacity(0.1))
            AxisValueLabel().font(.system(.caption2, design: .monospaced))
          }
        }
        .frame(height: 220)
        .accessibilityLabel("\(misura.titolo) per gruppo nelle ultime 12 settimane")
        legenda(volume)
      }
      .glassPanel()
    }

    private func tinta(_ gruppo: String?, indice: Int, volume: VolumeGruppi) -> AnyShapeStyle {
      if gruppo == nil { return AnyShapeStyle(Tratteggio.paint) }
      return AnyShapeStyle(Color.white.opacity(volume.opacita(indice)))
    }

    private func legenda(_ volume: VolumeGruppi) -> some View {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
        ForEach(Array(volume.groups.enumerated()), id: \.offset) { indice, gruppo in
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
              .fill(tinta(gruppo, indice: indice, volume: volume))
              .overlay {
                if gruppo == nil {
                  RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                }
              }
              .frame(width: 12, height: 12)
            Text(VolumeGruppi.nome(gruppo))
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
    }
  }

  /// Le righe oblique di `Non assegnato`.
  @MainActor enum Tratteggio {
    static let paint: ImagePaint = {
      let lato: CGFloat = 6
      let immagine = UIGraphicsImageRenderer(size: CGSize(width: lato, height: lato)).image { contesto in
        UIColor.white.withAlphaComponent(0.08).setFill()
        contesto.fill(CGRect(x: 0, y: 0, width: lato, height: lato))
        let linea = UIBezierPath()
        linea.move(to: CGPoint(x: 0, y: lato))
        linea.addLine(to: CGPoint(x: lato, y: 0))
        linea.lineWidth = 1.5
        UIColor.white.withAlphaComponent(0.5).setStroke()
        linea.stroke()
      }
      return ImagePaint(image: Image(uiImage: immagine))
    }()
  }
#endif
