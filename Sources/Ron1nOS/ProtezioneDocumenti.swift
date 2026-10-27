#if canImport(SwiftUI)
  import LocalAuthentication
  import Ron1nKit
  import SwiftUI

  /// Le pagine dei Documenti dietro Face ID (IOS-064), con il codice del
  /// telefono come riserva. Nel selettore delle app un velo con il sigillo
  /// copre i dati.
  struct ProtezioneDocumenti: ViewModifier {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.scenePhase) private var fase
    @State private var errore: String?
    @State private var inCorso = false

    func body(content: Content) -> some View {
      ZStack {
        if sessione.blocco.aperto {
          content
        } else {
          bloccato
        }
        if fase != .active {
          Velo().transition(.opacity)
        }
      }
      .task(id: sessione.blocco.aperto) {
        if !sessione.blocco.aperto, fase == .active { await sblocca() }
      }
    }

    private var bloccato: some View {
      VStack(spacing: 16) {
        Sigillo()
        Text("Documenti bloccati")
          .font(.headline)
          .foregroundStyle(Stile.testo)
        if let errore {
          Text(errore)
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
            .multilineTextAlignment(.center)
        }
        Button("Sblocca", systemImage: "faceid") { Task { await sblocca() } }
          .buttonStyle(.borderedProminent)
          .tint(Stile.brand)
          .disabled(inCorso)
      }
      .padding(32)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(SfondoConAlone().ignoresSafeArea())
    }

    private func sblocca() async {
      guard !inCorso else { return }
      inCorso = true
      defer { inCorso = false }
      let contesto = LAContext()
      var problema: NSError?
      guard contesto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &problema) else {
        // Senza codice impostato sul telefono non c'è nulla da chiedere.
        errore = "Imposta un codice sul telefono per proteggere i Documenti."
        return
      }
      do {
        let motivo = "Per aprire i Documenti"
        if try await contesto.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: motivo) {
          errore = nil
          sessione.blocco.sblocca()
        }
      } catch {
        errore = "Non sbloccato. Riprova quando vuoi."
      }
    }
  }

  /// Il velo del selettore delle app: nero con il sigillo.
  struct Velo: View {
    var body: some View {
      ZStack {
        Color.black.ignoresSafeArea()
        Sigillo()
      }
      .accessibilityHidden(true)
    }
  }

  /// Il sigillo: un lucchetto nel cerchio rosso del marchio.
  struct Sigillo: View {
    var body: some View {
      Image(systemName: "lock.fill")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(Stile.testo)
        .frame(width: 72, height: 72)
        .background(Circle().stroke(Stile.brand, lineWidth: 2))
    }
  }

  extension View {
    func protezioneDocumenti() -> some View { modifier(ProtezioneDocumenti()) }
  }
#endif
