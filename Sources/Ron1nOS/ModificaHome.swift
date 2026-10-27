#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il tremolio dei widget in Modifica, come nella Home di iOS. Con
  /// `Riduci movimento` i widget restano fermi.
  struct Tremolio: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var riduci
    @State private var su = false
    /// Ogni widget parte un po' sfasato, così non tremano all'unisono.
    @State private var ritardo = Double.random(in: 0...0.12)

    func body(content: Content) -> some View {
      content
        .rotationEffect(.degrees(riduci ? 0 : (su ? 1.1 : -1.1)))
        .onAppear {
          guard !riduci else { return }
          withAnimation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true).delay(ritardo)) {
            su = true
          }
        }
    }
  }

  /// Il trascinamento in Modifica: quando il widget trascinato passa sopra
  /// un altro, ne prende il posto.
  struct SpostaWidget: DropDelegate {
    let bersaglio: String
    @Binding var trascinato: String?
    let sposta: (String, String) -> Void

    func dropEntered(info: DropInfo) {
      guard let trascinato, trascinato != bersaglio else { return }
      sposta(trascinato, bersaglio)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
      DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
      trascinato = nil
      return true
    }
  }

  /// `Aggiungi widget` (IOS-022): il catalogo per l'iPhone diviso per
  /// modulo, con l'anteprima viva e le misure da scorrere.
  struct AggiungiWidgetView: View {
    let voci: [VoceCatalogo]
    let dati: DatiWidget
    let aggiungi: (VoceCatalogo, Misura) -> Void
    @Environment(\.dismiss) private var chiudi

    struct Gruppo {
      let titolo: String
      let voci: [VoceCatalogo]
    }

    private var gruppi: [Gruppo] {
      var ordine: [String] = []
      var perModulo: [String: [VoceCatalogo]] = [:]
      for voce in voci {
        if perModulo[voce.module] == nil { ordine.append(voce.module) }
        perModulo[voce.module, default: []].append(voce)
      }
      return ordine.map { modulo in
        Gruppo(titolo: Scheda.perModulo(modulo)?.titolo ?? modulo, voci: perModulo[modulo] ?? [])
      }
    }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 28) {
            ForEach(gruppi, id: \.titolo) { gruppo in
              VStack(alignment: .leading, spacing: 12) {
                Text(gruppo.titolo.uppercased())
                  .font(.system(.caption, design: .monospaced))
                  .tracking(1.6)
                  .foregroundStyle(Stile.testoTenue)
                ForEach(gruppo.voci, id: \.id) { voce in
                  VoceAggiunta(voce: voce, dati: dati) { misura in aggiungi(voce, misura) }
                }
              }
            }
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Aggiungi widget")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Chiudi") { chiudi() }
          }
        }
      }
      .tint(Stile.brand)
    }
  }

  /// Un widget del catalogo: anteprima viva per ogni misura ammessa, da
  /// scorrere, e `Aggiungi` per quella in vista.
  struct VoceAggiunta: View {
    let voce: VoceCatalogo
    let dati: DatiWidget
    let aggiungi: (Misura) -> Void
    @Environment(\.aspetto) private var aspetto
    @State private var misura: Misura?

    private var misure: [Misura] { voce.iphone ?? [] }

    var body: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(voce.titolo)
          .font(.headline)
          .foregroundStyle(Stile.testo)
        GeometryReader { spazio in
          let lato = (spazio.size.width - aspetto.spazio) / 2
          TabView(selection: $misura) {
            ForEach(misure, id: \.self) { scelta in
              WidgetHome(elemento: ElementoLayout(id: voce.id, misura: scelta), dati: dati)
                .frame(
                  width: scelta == .small ? lato : spazio.size.width,
                  height: scelta == .large ? lato * 2 + aspetto.spazio : lato
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .tag(Optional(scelta))
            }
          }
          .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .frame(height: altezza)
        HStack {
          Text(misure.map(\.titolo).joined(separator: " · "))
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Button("Aggiungi") { aggiungi(misura ?? misure.first ?? .medium) }
            .fontWeight(.semibold)
            .accessibilityLabel("Aggiungi \(voce.titolo), \((misura ?? misure.first)?.titolo ?? "")")
        }
      }
      .onAppear { if misura == nil { misura = misure.first } }
    }

    /// Lo spazio della misura più alta tra quelle ammesse.
    private var altezza: CGFloat {
      misure.contains(.large) ? 340 : 170
    }
  }
#endif
