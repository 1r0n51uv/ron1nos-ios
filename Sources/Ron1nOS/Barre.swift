#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il vetro liquido delle barre in basso (IOS-044). Da iOS 26 è il vetro di
  /// sistema, che rifrange quello che scorre sotto e risponde al tocco;
  /// prima un materiale sottile. In tutti e due i casi un bordo di luce e
  /// un'ombra profonda lo staccano dalla pagina.
  struct VetroLiquido<Forma: Shape>: ViewModifier {
    let forma: Forma
    var tinta: Color?

    func body(content: Content) -> some View {
      Group {
        if #available(iOS 26, *) {
          content.glassEffect(Glass.regular.tint(tinta?.opacity(0.18)).interactive(), in: forma)
        } else {
          content
            .background(.ultraThinMaterial, in: forma)
            .background((tinta ?? .white).opacity(0.08), in: forma)
        }
      }
      .overlay(
        forma.stroke(
          LinearGradient(
            colors: [Color.white.opacity(0.55), Color.white.opacity(0.12), Color.white.opacity(0.3)],
            startPoint: .topLeading, endPoint: .bottomTrailing),
          lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
      .shadow(color: (tinta ?? .clear).opacity(0.25), radius: 18, y: 4)
    }
  }

  extension View {
    func vetroLiquido<Forma: Shape>(_ forma: Forma, tinta: Color? = nil) -> some View {
      modifier(VetroLiquido(forma: forma, tinta: tinta))
    }

    /// Le azioni della pagina in una barra di vetro in basso, dove arriva il
    /// pollice, sopra la barra delle schede.
    func azioniInBasso<Azioni: View>(@ViewBuilder _ azioni: @escaping () -> Azioni) -> some View {
      safeAreaInset(edge: .bottom, spacing: 0) {
        BarraAzioni(azioni: azioni)
      }
    }
  }

  /// La barra delle schede (IOS-044): una capsula di vetro che galleggia
  /// sopra la pagina. La scheda attiva ha una pillola nella sua tinta che
  /// scivola da una voce all'altra; toccata di nuovo, torna all'inizio.
  struct BarraSchede: View {
    @Binding var scheda: Scheda
    let ritocco: (Scheda) -> Void
    @Namespace private var pillola

    static let altezza: CGFloat = 64

    var body: some View {
      HStack(spacing: 2) {
        ForEach(Scheda.tutte, id: \.self) { voce in
          pulsante(voce)
        }
      }
      .padding(5)
      .vetroLiquido(Capsule(), tinta: scheda.modulo.colore)
      .padding(.horizontal, 20)
      .animation(Stile.mollaViva, value: scheda)
    }

    private func pulsante(_ voce: Scheda) -> some View {
      let attiva = voce == scheda
      let tinta = voce.modulo.colore
      return Button {
        if attiva { ritocco(voce) } else { scheda = voce }
      } label: {
        VStack(spacing: 3) {
          Image(systemName: voce.modulo.simbolo)
            .font(.system(size: 20, weight: .semibold))
            .symbolEffect(.bounce, value: attiva)
            .symbolEffectsRemoved(!attiva)
          Text(voce.titolo)
            .font(.system(size: 10, weight: .bold))
            .lineLimit(1)
        }
        .foregroundStyle(attiva ? tinta : Stile.testo.opacity(0.75))
        .frame(maxWidth: .infinity, minHeight: BarraSchede.altezza - 10)
        .background {
          if attiva {
            Capsule()
              .fill(tinta.opacity(0.2))
              .overlay(Capsule().strokeBorder(tinta.opacity(0.45), lineWidth: 0.75))
              .shadow(color: tinta.opacity(0.4), radius: 10)
              .matchedGeometryEffect(id: "pillola", in: pillola)
          }
        }
        .contentShape(Capsule())
      }
      .buttonStyle(StilePremuto())
      .accessibilityLabel(voce.titolo)
      .accessibilityAddTraits(attiva ? .isSelected : [])
    }
  }

  extension Scheda {
    static let tutte: [Scheda] = [.home, .nutrizione, .torrent, .impostazioni]

    var titolo: String {
      switch self {
      case .home: "Home"
      case .nutrizione: "Nutrizione"
      case .torrent: "Torrent"
      case .impostazioni: "Impostazioni"
      }
    }
  }

  /// La barra delle azioni di una pagina: una capsula di vetro con i
  /// pulsanti, la principale piena nella tinta del modulo.
  struct BarraAzioni<Azioni: View>: View {
    @ViewBuilder let azioni: () -> Azioni
    @Environment(\.modulo) private var modulo

    var body: some View {
      HStack(spacing: 6) {
        azioni()
      }
      .padding(5)
      .vetroLiquido(Capsule(), tinta: modulo == .home ? nil : modulo.colore)
      .padding(.horizontal, 20)
      .padding(.bottom, 10)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  /// Un pulsante della barra delle azioni. La principale è una capsula piena
  /// nella tinta; le altre sono simbolo e nome. Con `inCorso` lo spinner
  /// prende il posto del simbolo e il pulsante non si tocca.
  struct AzioneBarra: View {
    let titolo: String
    let simbolo: String
    var principale = false
    var distruttiva = false
    var inCorso = false
    /// Solo il simbolo, per le azioni secondarie quando lo spazio è poco.
    var compatta = false
    let azione: () -> Void
    @Environment(\.modulo) private var modulo

    var body: some View {
      let tinta = modulo == .home ? Stile.brandTesto : modulo.colore
      Button(action: azione) {
        HStack(spacing: 6) {
          Group {
            if inCorso {
              ProgressView().controlSize(.small).tint(principale ? Stile.inchiostro : tinta)
            } else {
              Image(systemName: simbolo).font(.subheadline.weight(.bold))
            }
          }
          .frame(width: 20)
          if !compatta {
            Text(titolo)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
        }
        .foregroundStyle(principale ? Stile.inchiostro : distruttiva ? Stile.brandTesto : Stile.testo)
        .padding(.horizontal, compatta ? 0 : 14)
        .frame(minWidth: 48, maxWidth: principale ? .infinity : nil, minHeight: 48)
        .background {
          if principale {
            Capsule()
              .fill(LinearGradient(colors: [tinta, tinta.opacity(0.8)], startPoint: .top, endPoint: .bottom))
              .shadow(color: tinta.opacity(0.45), radius: 10, y: 3)
          }
        }
        .contentShape(Capsule())
        .animation(Stile.molla, value: inCorso)
      }
      .buttonStyle(StilePremuto())
      .disabled(inCorso)
      .accessibilityLabel(titolo)
    }
  }
#endif
