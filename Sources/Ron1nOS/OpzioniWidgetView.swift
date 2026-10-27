#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le opzioni di un widget (IOS-023): in alto l'anteprima viva, sotto
  /// misura, variante e dati mostrati. Ogni cambio si vede subito
  /// nell'anteprima e si salva con il layout (IOS-024).
  struct OpzioniWidgetView: View {
    let voce: VoceCatalogo
    let dati: DatiWidget
    /// L'elemento in prova: il foglio lo cambia e lo passa fuori.
    @State var elemento: ElementoLayout
    let cambia: (ElementoLayout) -> Void
    @Environment(\.aspetto) private var aspetto
    @Environment(\.dismiss) private var chiudi

    private var misure: [Misura] { voce.iphone ?? [] }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            anteprima
            if misure.count > 1 {
              sezione("Misura") {
                Picker("Misura", selection: misuraScelta) {
                  ForEach(misure, id: \.self) { Text($0.titolo).tag($0) }
                }
                .pickerStyle(.segmented)
              }
            }
            if voce.variants.count > 1 {
              sezione("Aspetto") {
                Picker("Aspetto", selection: variante) {
                  ForEach(voce.variants, id: \.self) { Text(voce.titoloVariante($0)).tag($0) }
                }
                .pickerStyle(.segmented)
              }
            }
            ForEach(voce.options ?? [], id: \.key) { opzione in
              sezione(opzione.label) { comando(opzione) }
            }
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle(voce.titolo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Fine") { chiudi() }
              .fontWeight(.semibold)
          }
        }
      }
      .tint(Stile.brand)
    }

    @ViewBuilder
    private var anteprima: some View {
      GeometryReader { spazio in
        let lato = (spazio.size.width - aspetto.spazio) / 2
        WidgetHome(elemento: elemento, dati: dati)
          .frame(
            width: elemento.misura == .small ? lato : spazio.size.width,
            height: elemento.misura == .large ? lato * 2 + aspetto.spazio : lato
          )
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .frame(height: elemento.misura == .large ? 340 : 170)
      .animation(.snappy, value: elemento)
    }

    @ViewBuilder
    private func sezione(_ titolo: String, @ViewBuilder contenuto: () -> some View) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(titolo.uppercased())
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
        contenuto()
      }
    }

    /// Il comando giusto per il tipo dell'opzione (DASH-005).
    @ViewBuilder
    private func comando(_ opzione: OpzioneCatalogo) -> some View {
      switch opzione.type {
      case "choice":
        Picker(opzione.label, selection: testo(opzione)) {
          ForEach(opzione.choices ?? [], id: \.value) { Text($0.label).tag($0.value) }
        }
        .pickerStyle(.segmented)
      case "multi":
        let scelti = elenco(opzione)
        VStack(spacing: 0) {
          ForEach(opzione.choices ?? [], id: \.value) { scelta in
            Toggle(
              scelta.label,
              isOn: Binding(
                get: { scelti.wrappedValue.contains(scelta.value) },
                set: { acceso in
                  var nuovi = scelti.wrappedValue
                  if acceso {
                    if !nuovi.contains(scelta.value) { nuovi.append(scelta.value) }
                  } else {
                    nuovi.removeAll { $0 == scelta.value }
                  }
                  // Senza nessuno scelto l'opzione non è valida: resta com'era.
                  if !nuovi.isEmpty { scelti.wrappedValue = nuovi }
                }))
          }
        }
        .tint(Stile.brand)
      case "count":
        let valore = numero(opzione)
        Stepper(value: valore, in: (opzione.min ?? 1)...(opzione.max ?? 6)) {
          Text("\(valore.wrappedValue)")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
      default:
        EmptyView()
      }
    }

    private var misuraScelta: Binding<Misura> {
      Binding(
        get: { elemento.misura },
        set: { nuova in
          var nuovo = elemento
          nuovo.w = nuova.w
          nuovo.h = nuova.h
          applica(nuovo)
        })
    }

    private var variante: Binding<String> {
      Binding(
        get: { elemento.variante(in: voce) ?? "" },
        set: { nuova in
          var nuovo = elemento
          nuovo.variant = nuova
          applica(nuovo)
        })
    }

    private func testo(_ opzione: OpzioneCatalogo) -> Binding<String> {
      Binding(
        get: {
          if case .testo(let valore) = elemento.valore(opzione.key, in: voce) { return valore }
          return ""
        },
        set: { nuovo in imposta(opzione, .testo(nuovo)) })
    }

    private func elenco(_ opzione: OpzioneCatalogo) -> Binding<[String]> {
      Binding(
        get: {
          if case .elenco(let valori) = elemento.valore(opzione.key, in: voce) { return valori }
          return []
        },
        set: { nuovi in imposta(opzione, .elenco(nuovi)) })
    }

    private func numero(_ opzione: OpzioneCatalogo) -> Binding<Int> {
      Binding(
        get: {
          if case .numero(let valore) = elemento.valore(opzione.key, in: voce) { return valore }
          return opzione.min ?? 1
        },
        set: { nuovo in imposta(opzione, .numero(nuovo)) })
    }

    private func imposta(_ opzione: OpzioneCatalogo, _ valore: ValoreOpzione) {
      var nuovo = elemento
      nuovo.imposta(opzione.key, valore, in: voce)
      applica(nuovo)
    }

    private func applica(_ nuovo: ElementoLayout) {
      guard nuovo != elemento else { return }
      elemento = nuovo
      cambia(nuovo)
    }
  }
#endif
