#if canImport(SwiftUI)
  import AVFoundation
  import Ron1nKit
  import SwiftUI
  import UIKit
  import VisionKit

  /// Il codice a barre con la fotocamera (IOS-032, NUT-005): un riquadro
  /// guida e il primo EAN letto chiude la fotocamera. Senza permesso si
  /// scrive il codice a mano.
  struct CodiceABarreView: View {
    /// Chiamata col codice letto o scritto a mano.
    let letto: (String) -> Void
    @Environment(\.dismiss) private var chiudi
    @State private var permesso = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var aMano = ""

    private var puoLeggere: Bool {
      permesso == .authorized && DataScannerViewController.isSupported
        && DataScannerViewController.isAvailable
    }

    var body: some View {
      NavigationStack {
        VStack(spacing: 20) {
          if puoLeggere {
            Lettore { codice in
              letto(codice)
              chiudi()
            }
            .overlay { Riquadro() }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("Inquadra il codice a barre.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          } else {
            SenzaFotocamera(stato: permesso, supportata: DataScannerViewController.isSupported)
          }
          campoAMano
        }
        .padding(16)
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Codice a barre")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
      }
      .tint(Stile.brand)
      .task {
        guard permesso == .notDetermined else { return }
        _ = await AVCaptureDevice.requestAccess(for: .video)
        permesso = AVCaptureDevice.authorizationStatus(for: .video)
      }
    }

    /// Il codice scritto a mano: serve senza fotocamera e quando il codice
    /// è illeggibile.
    @ViewBuilder
    private var campoAMano: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("OPPURE SCRIVILO")
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
        HStack {
          TextField("8001234567890", text: $aMano)
            .keyboardType(.numberPad)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Stile.testo)
          Button("Cerca") {
            letto(aMano.trimmingCharacters(in: .whitespaces))
            chiudi()
          }
          .fontWeight(.semibold)
          .disabled(aMano.trimmingCharacters(in: .whitespaces).count < 8)
        }
        .glassChip()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Il riquadro guida sopra l'immagine della fotocamera.
  struct Riquadro: View {
    var body: some View {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(Stile.brand, lineWidth: 2)
        .frame(height: 140)
        .padding(.horizontal, 32)
        .accessibilityHidden(true)
    }
  }

  /// Perché la fotocamera non c'è, e come rimediare.
  struct SenzaFotocamera: View {
    let stato: AVAuthorizationStatus
    let supportata: Bool

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(titolo)
          .font(.headline)
          .foregroundStyle(Stile.testo)
        Text(spiegazione)
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        if stato == .denied || stato == .restricted,
          let impostazioni = URL(string: UIApplication.openSettingsURLString)
        {
          Link("Apri le impostazioni di sistema", destination: impostazioni)
            .glassChip()
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .glassPanel()
    }

    private var titolo: String {
      supportata ? "Fotocamera non disponibile" : "Questo iPhone non legge i codici"
    }

    private var spiegazione: String {
      switch stato {
      case .denied, .restricted: "Il permesso della fotocamera è spento. Scrivi il codice a mano."
      case .notDetermined: "Serve il permesso della fotocamera."
      default:
        supportata
          ? "La fotocamera non risponde. Scrivi il codice a mano."
          : "Scrivi il codice a mano."
      }
    }
  }

  /// `DataScannerViewController` di VisionKit dentro SwiftUI: solo codici a
  /// barre, uno alla volta.
  struct Lettore: UIViewControllerRepresentable {
    let codice: (String) -> Void

    func makeCoordinator() -> Coordinatore { Coordinatore(codice: codice) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
      let lettore = DataScannerViewController(
        recognizedDataTypes: [.barcode()], qualityLevel: .balanced,
        recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
        isHighlightingEnabled: true)
      lettore.delegate = context.coordinator
      try? lettore.startScanning()
      return lettore
    }

    func updateUIViewController(_ lettore: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ lettore: DataScannerViewController, coordinator: Coordinatore) {
      lettore.stopScanning()
    }

    /// Il primo codice letto vale: gli altri si ignorano.
    final class Coordinatore: NSObject, DataScannerViewControllerDelegate {
      private let codice: (String) -> Void
      private var fatto = false

      init(codice: @escaping (String) -> Void) {
        self.codice = codice
      }

      func dataScanner(
        _ scanner: DataScannerViewController, didAdd aggiunte: [RecognizedItem],
        allItems: [RecognizedItem]
      ) {
        prendi(aggiunte)
      }

      func dataScanner(
        _ scanner: DataScannerViewController, didTapOn item: RecognizedItem
      ) {
        prendi([item])
      }

      private func prendi(_ voci: [RecognizedItem]) {
        guard !fatto else { return }
        for voce in voci {
          if case .barcode(let codiceLetto) = voce, let valore = codiceLetto.payloadStringValue,
            !valore.isEmpty
          {
            fatto = true
            codice(valore)
            return
          }
        }
      }
    }
  }
#endif
