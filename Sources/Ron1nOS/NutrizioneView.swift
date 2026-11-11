#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Da dove si apre il resto della Nutrizione.
  enum DestinazioneNutrizione: Hashable {
    case piani, ricette, spesa
  }

  /// La pagina Nutrizione (IOS-032): la settimana programmata, un pannello
  /// per giorno con i suoi cinque pasti. Un tocco su un giorno apre il
  /// dettaglio; da qui si arriva ai piani, alle ricette e alla spesa.
  struct NutrizioneView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var lunedi = Settimana.lunedi(di: Date())
    @State private var stato = Carico<SettimanaNutrizione>.inCorso
    @State private var destinazione: DestinazioneNutrizione?

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          navigazione
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel()
          case .spento:
            Text("Il modulo Nutrizione è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel()
          case .pronto(let settimana):
            if settimana.days.allSatisfy({ $0.slots.allSatisfy { $0.state == "empty" } }) {
              vuota
            }
            ForEach(settimana.days) { giorno in
              NavigationLink {
                GiornoNutrizioneView(giorno: giorno.date)
              } label: {
                PannelloGiorno(giorno: giorno, oggi: Settimana.oggi())
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(16)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Nutrizione")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button("Piani", systemImage: "calendar") { destinazione = .piani }
            Button("Ricette", systemImage: "book") { destinazione = .ricette }
            Button("Spesa", systemImage: "cart") { destinazione = .spesa }
          } label: {
            Image(systemName: "ellipsis")
          }
          .accessibilityLabel("Piani, ricette e spesa")
        }
      }
      .navigationDestination(item: $destinazione) { scelta in
        switch scelta {
        case .piani: PianiView()
        case .ricette: RicetteView()
        case .spesa: SpesaView()
        }
      }
      .refreshable { await carica() }
      .task(id: Carica(lunedi: lunedi, versione: sessione.versione)) {
        await carica()
        await sessione.ricalcolaPromemoria(chiediPermesso: true)
      }
    }

    private struct Carica: Equatable {
      let lunedi: String
      let versione: Int
    }

    /// Prima, dopo e `Oggi`, con la settimana al centro.
    private var navigazione: some View {
      HStack(spacing: 12) {
        Button {
          lunedi = Settimana.piu(-7, a: lunedi)
        } label: {
          Image(systemName: "chevron.left").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Settimana prima")
        Spacer()
        VStack(spacing: 2) {
          Text(intervallo)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Stile.testo)
          if lunedi != Settimana.lunedi(di: Date()) {
            Button("Oggi") { lunedi = Settimana.lunedi(di: Date()) }
              .font(.footnote)
              .tint(Stile.brandTesto)
          }
        }
        Spacer()
        Button {
          lunedi = Settimana.piu(7, a: lunedi)
        } label: {
          Image(systemName: "chevron.right").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Settimana dopo")
      }
      .foregroundStyle(Stile.testo)
    }

    /// "26 ott – 1 nov".
    private var intervallo: String {
      let stile = Date.FormatStyle().day().month(.abbreviated).locale(Locale(identifier: "it_IT"))
      guard let primo = Settimana.data(lunedi), let ultimo = Settimana.data(Settimana.piu(6, a: lunedi))
      else { return lunedi }
      return "\(primo.formatted(stile)) – \(ultimo.formatted(stile))"
    }

    private var vuota: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("Niente in programma")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text("Scegli un piano dal menu e programmalo: da oggi fino a una data o per questa settimana.")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        Button("Piani") { destinazione = .piani }
          .glassChip()
      }
      .glassPanel()
    }

    private func carica() async {
      let client = sessione.client
      let da = lunedi
      stato = await Carico.da { try await client.settimana(da: da) }
    }
  }

  /// Un giorno della settimana: titolo, kcal e i pasti con lo stato.
  struct PannelloGiorno: View {
    let giorno: GiornoSettimana
    let oggi: String
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(titolo)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(giorno.date == oggi ? Stile.brandTesto : Stile.testo)
          Spacer()
          if giorno.kcal > 0 {
            Text(formati.energia(giorno.kcal))
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(Stile.testoTenue)
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          ForEach(giorno.slots) { pasto in
            RigaPastoSettimana(pasto: pasto, vista: pasto.vista(giorno: giorno.date, oggi: oggi))
          }
        }
      }
      .glassPanel(tinta: giorno.date == oggi ? Stile.brand : nil)
    }

    /// "Lunedì 26".
    private var titolo: String {
      guard let data = Settimana.data(giorno.date) else { return giorno.date }
      return data.formatted(.dateTime.weekday(.wide).day().locale(Locale(identifier: "it_IT"))).capitalized
    }
  }

  /// Un pasto in una riga: simbolo dello stato, pasto e ricetta.
  struct RigaPastoSettimana: View {
    let pasto: PastoSettimana
    let vista: VistaPasto

    var body: some View {
      HStack(spacing: 10) {
        Image(systemName: simbolo)
          .font(.footnote)
          .foregroundStyle(colore)
          .frame(width: 18)
        Text(pasto.titolo)
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
          .frame(width: 72, alignment: .leading)
        Text(pasto.plan?.name ?? "·")
          .font(.footnote)
          .foregroundStyle(vista == .saltato ? Stile.testoTenue : Stile.testo)
          .strikethrough(vista == .saltato)
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: 0)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(pasto.titolo), \(pasto.plan?.name ?? "niente"), \(vista.testo)")
    }

    private var simbolo: String {
      switch vista {
      case .mangiato: "checkmark.circle.fill"
      case .saltato: "xmark.circle"
      case .pianificato: "circle"
      case .vuoto: "minus"
      }
    }

    private var colore: Color {
      switch vista {
      case .mangiato: Stile.testo
      default: Stile.testoTenue
      }
    }
  }
#endif
