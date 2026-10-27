#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// La Dieta (IOS-030): la striscia dei giorni, le kcal del giorno con i
  /// macro e i cinque pasti. Dati da `GET /nutrition/day?date=`.
  struct DietaView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.aspetto) private var aspetto
    @Environment(\.formati) private var formati
    @State private var giorno: Carico<GiornoDieta> = .inCorso
    @State private var scelto: String?
    @State private var striscia = Striscia()
    /// Il pasto da registrare nel foglio (IOS-031).
    @State private var registra: Pasto?

    private var data: String { scelto ?? striscia.oggi }

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: aspetto.spazio) {
          StrisciaGiorni(striscia: striscia, scelto: data) { nuovo in
            scelto = nuovo
          }
          switch giorno {
          case .inCorso:
            Scheletro(righe: 4).glassPanel()
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
          case .pronto(let valore):
            QuotaDelGiorno(giorno: valore)
            ForEach(valore.slotInOrdine) { slot in
              CardSlot(slot: slot, giorno: data, segna: segna) { nuovo in
                registra = Pasto(giorno: data, slot: nuovo)
              }
            }
            TrackerInArrivo()
            CollegamentiDieta()
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
      }
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Dieta")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if data != striscia.oggi {
            Button("Oggi") { scelto = striscia.oggi }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            registra = Pasto(giorno: data, slot: slotProposto)
          } label: {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Registra un pasto")
        }
      }
      .sheet(item: $registra) { pasto in
        RegistraPastoView(giorno: pasto.giorno, slot: pasto.slot) { nuovo in
          giorno = .pronto(nuovo)
        }
      }
      .refreshable { await carica() }
      .task(id: data) { await carica() }
      .task(id: sessione.versione) { await carica() }
      .aggiornaOgni(60) { await carica() }
    }

    /// Lo slot proposto: quello dell'ora corrente, se no il prossimo da
    /// segnare, se no il pranzo.
    private var slotProposto: String {
      giorno.valore?.suggestedSlot ?? giorno.valore?.nextSlot ?? "lunch"
    }

    private func carica() async {
      striscia = Striscia(fuso: formati.fuso)
      let client = sessione.client
      let data = data
      giorno = await Carico.da { try await client.dieta(data) }
    }

    /// L'interruttore `Mangiato` di un pasto pianificato (NUT-009).
    private func segna(_ id: String, _ mangiato: Bool) {
      let client = sessione.client
      Task {
        do {
          try await client.statoPiano(id, mangiato ? "eaten" : "planned")
          await carica()
        } catch {
          sessione.mostra(.nonSalvato) { segna(id, mangiato) }
        }
      }
    }
  }

  /// Il pasto che il foglio di registrazione sta compilando.
  struct Pasto: Identifiable, Hashable {
    let giorno: String
    let slot: String

    var id: String { "\(giorno)/\(slot)" }
  }

  /// La striscia dei giorni in alto, scorrevole, con oggi al centro.
  struct StrisciaGiorni: View {
    let striscia: Striscia
    let scelto: String
    let scegli: (String) -> Void

    var body: some View {
      ScrollViewReader { vista in
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(striscia.giorni) { giorno in
              Button {
                scegli(giorno.id)
              } label: {
                VStack(spacing: 4) {
                  Text(giorno.lettera)
                    .font(.caption2)
                    .foregroundStyle(Stile.testoTenue)
                  Text("\(giorno.numero)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(giorno.futuro ? Stile.testoTenue : Stile.testo)
                }
                .frame(width: 44, height: 56)
                .background(
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(giorno.id == scelto ? Stile.brand.opacity(0.9) : Color.white.opacity(0.06))
                )
                .overlay {
                  if giorno.oggi, giorno.id != scelto {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                      .stroke(Stile.brand, lineWidth: 1)
                  }
                }
              }
              .buttonStyle(.plain)
              .id(giorno.id)
              .accessibilityLabel(etichetta(giorno))
              .accessibilityAddTraits(giorno.id == scelto ? [.isButton, .isSelected] : .isButton)
            }
          }
          .padding(.vertical, 4)
        }
        .onAppear { vista.scrollTo(scelto, anchor: .center) }
        .onChange(of: scelto) { _, nuovo in
          withAnimation(.snappy) { vista.scrollTo(nuovo, anchor: .center) }
        }
      }
    }

    private func etichetta(_ giorno: Striscia.Giorno) -> String {
      giorno.oggi ? "Oggi, \(giorno.numero)" : "Giorno \(giorno.numero)"
    }
  }

  /// L'anello delle kcal sulla quota e le tre barre dei macro.
  struct QuotaDelGiorno: View {
    let giorno: GiornoDieta
    @Environment(\.formati) private var formati

    var body: some View {
      HStack(spacing: 20) {
        ZStack {
          Anello(valore: giorno.avanzamento ?? 0, segnale: giorno.oltre, spessore: 10)
          VStack(spacing: 2) {
            Text(Formato.numero(formati.valoreEnergia(giorno.totals.kcal)))
              .font(.system(.title3, design: .monospaced))
              .foregroundStyle(Stile.testo)
            Text(formati.energyUnit.rawValue)
              .font(.caption2)
              .foregroundStyle(Stile.testoTenue)
          }
        }
        .frame(width: 104, height: 104)
        VStack(alignment: .leading, spacing: 10) {
          if let rimanenti = giorno.testoRimanenti(formati) {
            Text(rimanenti)
              .font(.subheadline)
              .foregroundStyle(giorno.oltre ? Stile.brand : Stile.testoTenue)
          }
          ForEach(giorno.macro, id: \.chiave) { riga in
            BarraMacro(riga: riga, valori: giorno)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .glassPanel()
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(giorno.testoEnergia(formati)). \(giorno.testoRimanenti(formati) ?? "")")
    }
  }

  /// Una barra di un macro: nome, valori e quanto manca all'obiettivo.
  struct BarraMacro: View {
    let riga: RigaMacro
    let valori: GiornoDieta

    private var avanzamento: Double {
      let mangiato: Double
      let obiettivo: Double?
      switch riga.chiave {
      case "protein":
        mangiato = valori.totals.protein
        obiettivo = valori.goal?.protein
      case "carbs":
        mangiato = valori.totals.carbs
        obiettivo = valori.goal?.carbs
      default:
        mangiato = valori.totals.fat
        obiettivo = valori.goal?.fat
      }
      guard let obiettivo, obiettivo > 0 else { return 0 }
      return min(1, mangiato / obiettivo)
    }

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(riga.nome)
            .font(.caption)
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Text(riga.testo)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
        GeometryReader { spazio in
          ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.1))
            Capsule().fill(Stile.testo).frame(width: spazio.size.width * avanzamento)
          }
        }
        .frame(height: 4)
      }
    }
  }

  /// La card di uno slot: vuoto con `+`, pianificato con `Mangiato`,
  /// mangiato con gli alimenti e le kcal.
  struct CardSlot: View {
    let slot: SlotGiorno
    let giorno: String
    let segna: (String, Bool) -> Void
    /// Tocca `+`: apre il foglio per registrare in questo slot.
    let registra: (String) -> Void
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(slot.titolo)
            .font(.headline)
            .foregroundStyle(Stile.testo)
          Spacer()
          if let kcal = slot.kcal {
            Text(formati.energia(kcal))
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(slot.mangiato ? Stile.testo : Stile.testoTenue)
          }
          if !slot.mangiato {
            Button {
              registra(slot.slot)
            } label: {
              Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .glassChip()
            .accessibilityLabel("Aggiungi a \(slot.titolo)")
          }
        }
        if let elenco = slot.elenco {
          Text(elenco)
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
            .lineLimit(3)
        } else if slot.vuoto {
          Text("Niente registrato.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        if slot.saltato {
          Text("Saltato")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
        if slot.state == "planned", let id = slot.planned?.id {
          Toggle("Mangiato", isOn: Binding(get: { false }, set: { nuovo in segna(id, nuovo) }))
            .font(.subheadline)
            .tint(Stile.brand)
        }
      }
      .glassPanel()
      .overlay {
        if slot.mangiato {
          NavigationLink(value: Pagina.dettaglioPasto(giorno: giorno, slot: slot.slot)) {
            Color.clear
          }
          .accessibilityLabel("Apri \(slot.titolo)")
        }
      }
    }
  }

  /// I tracker di acqua, caffeina e integratori arrivano con IOS-037.
  struct TrackerInArrivo: View {
    var body: some View {
      Text("Acqua, caffeina e integratori arrivano con il prossimo aggiornamento.")
        .font(.footnote)
        .foregroundStyle(Stile.testoTenue)
        .glassPanel()
    }
  }

  /// I link alle altre pagine della Dieta.
  struct CollegamentiDieta: View {
    var body: some View {
      VStack(spacing: 0) {
        ForEach(CollegamentiDieta.voci, id: \.titolo) { voce in
          NavigationLink(value: Pagina.dieta(voce.pagina)) {
            HStack {
              Label(voce.titolo, systemImage: voce.icona)
                .foregroundStyle(Stile.testo)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Stile.testoTenue)
            }
            .padding(.vertical, 12)
          }
        }
      }
      .glassPanel()
    }

    struct Voce {
      let titolo: String
      let icona: String
      let pagina: PaginaDieta
    }

    static let voci = [
      Voce(titolo: "Ricette", icona: "book", pagina: .ricette),
      Voce(titolo: "Template", icona: "calendar", pagina: .template),
      Voce(titolo: "Spesa", icona: "cart", pagina: .spesa),
      Voce(titolo: "Andamento", icona: "chart.line.uptrend.xyaxis", pagina: .andamento),
    ]
  }

  /// Le pagine della Dieta sotto il giorno.
  enum PaginaDieta: String, Hashable {
    case ricette, template, spesa, andamento

    var titolo: String {
      switch self {
      case .ricette: "Ricette"
      case .template: "Template"
      case .spesa: "Spesa"
      case .andamento: "Andamento"
      }
    }
  }
#endif
