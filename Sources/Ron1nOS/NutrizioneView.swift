#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Da dove si apre il resto della Nutrizione.
  enum DestinazioneNutrizione: Hashable {
    case piani, ricette, spesa
  }

  /// La pagina Nutrizione (IOS-032, IOS-043): un giorno alla volta, oggi
  /// all'apertura. Uno swipe a sinistra porta al giorno dopo, a destra a
  /// quello prima; in alto una barra per scegliere un giorno della settimana
  /// o, dal calendario, una data qualsiasi. Sotto, sempre in vista, le
  /// scorciatoie a piani, ricette e spesa.
  /// Le azioni stanno in una barra sotto il titolo (IOS-045).
  struct NutrizioneView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var giorno = Settimana.oggi()
    /// Verso dell'ultimo spostamento, per la direzione dell'animazione.
    @State private var avanti = true
    @State private var settimana = Carico<SettimanaNutrizione>.inCorso
    @State private var calendario = false
    @State private var destinazione: DestinazioneNutrizione?

    var body: some View {
      VStack(spacing: 0) {
        BarraGiorni(
          giorno: giorno, oggi: oggi, settimana: settimana.valore, scegli: vai,
          calendario: { calendario = true }
        )
        .padding(.horizontal, Stile.margine)
        .padding(.top, 4)
        .padding(.bottom, 8)
        GiornoNutrizioneView(giorno: giorno)
          .id(giorno)
          .transition(
            .asymmetric(
              insertion: .move(edge: avanti ? .trailing : .leading),
              removal: .move(edge: avanti ? .leading : .trailing)))
      }
      .clipped()
      .sfondoPagina()
      .contentShape(Rectangle())
      .simultaneousGesture(
        DragGesture(minimumDistance: 40).onEnded { spostamento in
          // Solo i gesti più orizzontali che verticali: lo scorrimento della pagina resta libero.
          guard abs(spostamento.translation.width) > abs(spostamento.translation.height) * 1.5 else {
            return
          }
          vai(Settimana.piu(spostamento.translation.width < 0 ? 1 : -1, a: giorno, fuso: formati.fuso))
        }
      )
      .navigationTitle("Nutrizione")
      .navigationBarTitleDisplayMode(.inline)
      .azioniInAlto {
        if giorno != oggi {
          AzioneBarra(titolo: "Oggi", simbolo: "arrow.uturn.backward", principale: true) { vai(oggi) }
        }
        AzioneBarra(titolo: "Piani", simbolo: "calendar.badge.clock", compatta: giorno != oggi) {
          destinazione = .piani
        }
        AzioneBarra(titolo: "Ricette", simbolo: "book.closed.fill", compatta: giorno != oggi) {
          destinazione = .ricette
        }
        AzioneBarra(titolo: "Spesa", simbolo: "cart.fill", compatta: giorno != oggi) { destinazione = .spesa }
        AzioneBarra(titolo: "Scegli una data", simbolo: "calendar", compatta: true) { calendario = true }
      }
      .animation(Stile.molla, value: giorno == oggi)
      .sensoryFeedback(.selection, trigger: giorno)
      .navigationDestination(item: $destinazione) { scelta in
        switch scelta {
        case .piani: PianiView()
        case .ricette: RicetteView()
        case .spesa: SpesaView()
        }
      }
      .sheet(isPresented: $calendario) {
        ScegliData(giorno: giorno) { scelto in
          calendario = false
          vai(scelto)
        }
        .environment(\.formati, formati)
      }
      .task(
        id: Carica(lunedi: Settimana.lunedi(del: giorno, fuso: formati.fuso), versione: sessione.versione)
      ) {
        await caricaSettimana()
        await sessione.ricalcolaPromemoria(chiediPermesso: true)
      }
    }

    private var oggi: String { Settimana.oggi(fuso: formati.fuso) }

    private struct Carica: Equatable {
      let lunedi: String
      let versione: Int
    }

    /// Passa a un altro giorno, con l'animazione nel verso giusto.
    private func vai(_ nuovo: String) {
      guard nuovo != giorno else { return }
      avanti = nuovo > giorno
      withAnimation(.easeInOut(duration: 0.25)) { giorno = nuovo }
    }

    /// La settimana del giorno scelto, per i puntini sulla barra.
    private func caricaSettimana() async {
      let client = sessione.client
      let lunedi = Settimana.lunedi(del: giorno, fuso: formati.fuso)
      let nuova = await Carico.da { try await client.settimana(da: lunedi) }
      // Un errore non cancella i puntini già mostrati.
      if case .fallito = nuova, settimana.valore != nil { return }
      settimana = nuova
    }
  }

  /// La barra in alto: i sette giorni della settimana del giorno scelto, con
  /// un puntino dove c'è qualcosa in programma, e il calendario.
  struct BarraGiorni: View {
    let giorno: String
    let oggi: String
    let settimana: SettimanaNutrizione?
    let scegli: (String) -> Void
    let calendario: () -> Void
    @Environment(\.formati) private var formati
    @Namespace private var selezione
    private let verde = Modulo.nutrizione.colore

    var body: some View {
      HStack(spacing: 4) {
        ForEach(
          Settimana.giorni(dalLunedi: Settimana.lunedi(del: giorno, fuso: formati.fuso), fuso: formati.fuso),
          id: \.self
        ) { data in
          cella(data)
        }
      }
      .padding(4)
      .background(Stile.velo, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Stile.bordo))
    }

    private func cella(_ data: String) -> some View {
      let scelto = data == giorno
      return Button {
        scegli(data)
      } label: {
        VStack(spacing: 3) {
          Text(lettera(data))
            .font(.system(.caption2, design: .monospaced).weight(.medium))
            .foregroundStyle(scelto ? Stile.inchiostro.opacity(0.7) : Stile.testoTenue)
          Text(numero(data))
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .foregroundStyle(scelto ? Stile.inchiostro : data == oggi ? verde : Stile.testo)
          Circle()
            .fill(haQualcosa(data) ? (scelto ? Stile.inchiostro : verde) : Color.clear)
            .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .background {
          if scelto {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .fill(verde)
              .matchedGeometryEffect(id: "giorno", in: selezione)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(StilePremuto())
      .animation(Stile.molla, value: giorno)
      .accessibilityLabel(etichetta(data))
      .accessibilityAddTraits(scelto ? .isSelected : [])
    }

    private func haQualcosa(_ data: String) -> Bool {
      settimana?.days.first { $0.date == data }?.slots.contains { $0.state != "empty" } ?? false
    }

    private func lettera(_ data: String) -> String {
      let giorni = Settimana.giorni(
        dalLunedi: Settimana.lunedi(del: giorno, fuso: formati.fuso), fuso: formati.fuso)
      return TemplateSettimana.lettere[giorni.firstIndex(of: data) ?? 0]
    }

    private func numero(_ data: String) -> String {
      String(data.suffix(2).drop { $0 == "0" })
    }

    private func etichetta(_ data: String) -> String {
      guard let d = Settimana.data(data, fuso: formati.fuso) else { return data }
      return d.formatted(
        .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "it_IT")))
    }
  }

  /// Il calendario per scegliere una data qualsiasi.
  struct ScegliData: View {
    let giorno: String
    let scelta: (String) -> Void
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var data = Date()

    var body: some View {
      NavigationStack {
        DatePicker("Data", selection: $data, displayedComponents: .date)
          .datePickerStyle(.graphical)
          .environment(\.timeZone, formati.fuso)
          .environment(\.locale, Locale(identifier: "it_IT"))
          .padding(16)
          .frame(maxHeight: .infinity, alignment: .top)
          .sfondoPagina()
          .navigationTitle("Scegli una data")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Annulla") { chiudi() }
            }
          }
          .azioniInBasso {
            AzioneBarra(titolo: "Vai a questo giorno", simbolo: "arrow.right", principale: true) {
              scelta(Settimana.testo(data, fuso: formati.fuso))
            }
          }
      }
      .tint(Modulo.nutrizione.colore)
      .environment(\.modulo, .nutrizione)
      .presentationDetents([.medium, .large])
      .onAppear {
        if let attuale = Settimana.data(giorno, fuso: formati.fuso) { data = attuale }
      }
    }
  }
#endif
