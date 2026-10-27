#if canImport(SwiftUI)
  import PhotosUI
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// Le righe delle Impostazioni hanno tutte lo stesso velo.
  private let veloRiga = Color.white.opacity(0.06)

  /// Il footer rosso accanto a un campo non salvato.
  private struct NonSalvato: View {
    let testo: String?

    var body: some View {
      if let testo {
        Text(testo)
          .font(.footnote)
          .foregroundStyle(Stile.brand)
      }
    }
  }

  // MARK: Aspetto

  /// Impostazioni › Aspetto (IOS-091, SET-003): sfondo, vetro, densità e
  /// l'anteprima di una card. Ogni scelta si vede subito e si salva da sola.
  struct AspettoView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var foto: PhotosPickerItem?
    @State private var errore: String?
    @State private var caricamento = false

    private var aspetto: Aspetto { sessione.preferenze.appearance }

    var body: some View {
      List {
        Section {
          ForEach(sfondi, id: \.self) { sfondo in
            Button {
              var nuovo = aspetto
              nuovo.background = sfondo
              salva(nuovo)
            } label: {
              HStack {
                Text(sfondo == .brace ? "Brace (predefinito)" : sfondo.titolo)
                  .foregroundStyle(Stile.testo)
                Spacer()
                if sessione.preferenze.sfondo == sfondo {
                  Image(systemName: "checkmark").foregroundStyle(Stile.brand)
                }
              }
            }
            .listRowBackground(veloRiga)
          }
          PhotosPicker(selection: $foto, matching: .images) {
            Label(
              caricamento
                ? "Caricamento…"
                : sessione.preferenze.backgroundImage == nil ? "Carica immagine" : "Cambia immagine",
              systemImage: "photo")
          }
          .disabled(caricamento)
          .listRowBackground(veloRiga)
          if sessione.preferenze.backgroundImage != nil {
            Button("Togli immagine", role: .destructive) { Task { await togli() } }
              .listRowBackground(veloRiga)
          }
        } header: {
          Text("Sfondo")
        } footer: {
          NonSalvato(testo: errore)
        }

        Section("Vetro") {
          Picker("Vetro", selection: vetro) {
            ForEach([Aspetto.Vetro.light, .medium, .strong], id: \.self) { Text($0.titolo).tag($0) }
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
        }

        Section("Densità") {
          Picker("Densità", selection: densita) {
            ForEach([Aspetto.Densita.comfortable, .compact], id: \.self) { Text($0.titolo).tag($0) }
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
        }

        Section("Anteprima") {
          VStack(alignment: .leading, spacing: 8) {
            Text("Calorie")
              .font(.footnote)
              .foregroundStyle(Stile.testoTenue)
            Text("1.840 kcal")
              .font(.system(.title2, design: .monospaced).weight(.semibold))
              .foregroundStyle(Stile.testo)
            Barra(valore: 0.72)
          }
          .glassPanel()
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Aspetto")
      .onChange(of: foto) { _, scelta in
        guard let scelta else { return }
        Task { await carica(scelta) }
      }
    }

    private var sfondi: [Aspetto.Sfondo] {
      let base: [Aspetto.Sfondo] = [.brace, .nebbia, .grafite, .nero]
      return sessione.preferenze.backgroundImage == nil ? base : base + [.image]
    }

    private var vetro: Binding<Aspetto.Vetro> {
      Binding(
        get: { aspetto.glass },
        set: { valore in
          var nuovo = aspetto
          nuovo.glass = valore
          salva(nuovo)
        })
    }

    private var densita: Binding<Aspetto.Densita> {
      Binding(
        get: { aspetto.density },
        set: { valore in
          var nuovo = aspetto
          nuovo.density = valore
          salva(nuovo)
        })
    }

    private func salva(_ nuovo: Aspetto) {
      Task {
        let fatto = await sessione.salva(ModificaPreferenze(appearance: nuovo))
        errore = fatto ? nil : "Aspetto non salvato · riprova"
      }
    }

    /// L'immagine va al server in JPEG, sotto i 5 MB.
    private func carica(_ scelta: PhotosPickerItem) async {
      caricamento = true
      defer {
        caricamento = false
        foto = nil
      }
      guard let dati = try? await scelta.loadTransferable(type: Data.self),
        let immagine = UIImage(data: dati),
        let jpeg = AspettoView.jpeg(immagine)
      else {
        errore = "Immagine non letta."
        return
      }
      do {
        switch try await sessione.client.caricaSfondo(jpeg, nome: "sfondo.jpg", tipo: "image/jpeg") {
        case .fatto(let preferenze):
          errore = nil
          await sessione.usa(preferenze)
        case .rifiutato(let messaggio):
          errore = messaggio
        }
      } catch {
        errore = "Sfondo non salvato · riprova"
      }
    }

    private static func jpeg(_ immagine: UIImage) -> Data? {
      for qualita in [0.85, 0.6, 0.4] {
        if let dati = immagine.jpegData(compressionQuality: qualita), dati.count < 5_000_000 {
          return dati
        }
      }
      return nil
    }

    private func togli() async {
      do {
        await sessione.usa(try await sessione.client.togliSfondo())
        errore = nil
      } catch {
        errore = "Immagine non tolta · riprova"
      }
    }
  }

  // MARK: Dashboard

  /// Impostazioni › Dashboard (IOS-091, SET-004): forma della testata,
  /// widget presenti con `Rimuovi` e `Opzioni`, `Ripristina layout
  /// predefinito`. Vale il layout `iphone`.
  struct DashboardImpostazioniView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var layout: Carico<LayoutHome> = .inCorso
    @State private var catalogo: Catalogo?
    @State private var dati = DatiWidget()
    @State private var opzioni: ElementoLayout?
    @State private var conferma = false
    @State private var errore: String?

    var body: some View {
      List {
        switch layout {
        case .inCorso:
          Scheletro(righe: 4).listRowBackground(veloRiga)
        case .spento:
          ModuloSpento().listRowBackground(Color.clear)
        case .fallito(let problema):
          SezioneErrore(errore: problema).listRowBackground(veloRiga)
        case .pronto(let attuale):
          Section {
            Picker("Testata", selection: testata(attuale)) {
              ForEach(LayoutHome.Testata.allCases, id: \.self) { Text($0.titolo).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
          } header: {
            Text("Testata")
          } footer: {
            NonSalvato(testo: errore)
          }
          Section("Widget") {
            if attuale.items.isEmpty {
              Text("Nessun widget sulla Home.")
                .foregroundStyle(Stile.testoTenue)
                .listRowBackground(veloRiga)
            }
            ForEach(attuale.items) { elemento in
              riga(elemento, in: attuale)
            }
          }
          Section {
            Button("Ripristina layout predefinito", role: .destructive) { conferma = true }
              .listRowBackground(veloRiga)
          } footer: {
            Text("La Home torna con i widget di partenza. Le preferenze non cambiano.")
              .foregroundStyle(Stile.testoTenue)
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Dashboard")
      .task(id: sessione.layoutCambiato) { await carica() }
      .confirmationDialog("Ripristinare il layout predefinito?", isPresented: $conferma) {
        Button("Ripristina", role: .destructive) { Task { await ripristina() } }
      }
      .sheet(item: $opzioni) { elemento in
        if let voce = catalogo?.voce(elemento.id), let attuale = layout.valore {
          OpzioniWidgetView(voce: voce, dati: dati, elemento: elemento) { nuovo in
            var cambiato = attuale
            cambiato.modifica(elemento.id) { $0 = nuovo }
            Task { await salva(cambiato) }
          }
          .environment(\.aspetto, sessione.preferenze.appearance)
          .environment(\.formati, sessione.preferenze.formats)
        }
      }
    }

    private func riga(_ elemento: ElementoLayout, in attuale: LayoutHome) -> some View {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(catalogo?.voce(elemento.id)?.titolo ?? elemento.id)
            .foregroundStyle(Stile.testo)
          Text(elemento.misura.titolo)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
        Spacer()
        if catalogo?.voce(elemento.id) != nil {
          Button("Opzioni") { opzioni = elemento }
            .buttonStyle(.borderless)
            .tint(Stile.testo)
        }
        Button("Rimuovi", role: .destructive) {
          var cambiato = attuale
          cambiato.rimuovi(elemento.id)
          Task { await salva(cambiato) }
        }
        .buttonStyle(.borderless)
      }
      .listRowBackground(veloRiga)
    }

    private func testata(_ attuale: LayoutHome) -> Binding<LayoutHome.Testata> {
      Binding(
        get: { attuale.header },
        set: { valore in
          var cambiato = attuale
          cambiato.header = valore
          Task { await salva(cambiato) }
        })
    }

    private func carica() async {
      let client = sessione.client
      async let letto = Carico.da { try await client.layoutHome() }
      async let regole = Carico.da { try await client.catalogo() }
      async let nuovi = DatiWidget.carica(con: client)
      let (l, c, d) = await (letto, regole, nuovi)
      layout = l
      catalogo = c.valore
      dati = d
    }

    /// Si vede subito; se il server non lo prende torna com'era.
    private func salva(_ nuovo: LayoutHome) async {
      let prima = layout
      layout = .pronto(nuovo)
      if let problema = catalogo.flatMap(nuovo.problema) {
        layout = prima
        errore = problema
        return
      }
      do {
        layout = .pronto(try await sessione.client.salvaLayoutHome(nuovo))
        errore = nil
        sessione.layoutCambiato += 1
      } catch {
        layout = prima
        errore = "Layout non salvato · riprova"
      }
    }

    private func ripristina() async {
      do {
        layout = .pronto(try await sessione.client.ripristinaLayoutHome())
        errore = nil
        sessione.layoutCambiato += 1
      } catch {
        errore = "Layout non ripristinato · riprova"
      }
    }
  }

  // MARK: Moduli

  /// Impostazioni › Moduli (IOS-091, SET-005): un interruttore per modulo e
  /// le impostazioni di Dieta e Documenti.
  struct ModuliView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var errore: String?

    var body: some View {
      List {
        Section {
          ForEach(ModuloRon1n.allCases, id: \.self) { modulo in
            Toggle(modulo.titolo, isOn: interruttore(modulo))
              .tint(Stile.brand)
              .foregroundStyle(Stile.testo)
              .listRowBackground(veloRiga)
          }
        } header: {
          Text("Moduli accesi")
        } footer: {
          VStack(alignment: .leading, spacing: 6) {
            Text(
              "Un modulo spento sparisce da barra, dashboard e catalogo dei widget, e le sue API non "
                + "rispondono. I dati restano."
            )
            .foregroundStyle(Stile.testoTenue)
            NonSalvato(testo: errore)
          }
        }
        Section("Impostazioni dei moduli") {
          collegamento("Dieta · Obiettivo e YAZIO", icona: "fork.knife", pagina: .impostazioniDieta)
          collegamento("Dieta · Alimenti", icona: "carrot", pagina: .alimenti(codice: nil))
          collegamento("Documenti · Tipi e Face ID", icona: "doc.text", pagina: .impostazioniDocumenti)
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Moduli")
    }

    private func interruttore(_ modulo: ModuloRon1n) -> Binding<Bool> {
      Binding(
        get: { !sessione.preferenze.disabledModules.contains(modulo.rawValue) },
        set: { acceso in
          let modifica = ModificaPreferenze.modulo(modulo.rawValue, acceso: acceso, in: sessione.preferenze)
          Task {
            let fatto = await sessione.salva(modifica)
            errore = fatto ? nil : "\(modulo.titolo) · modifica non salvata, riprova"
          }
        })
    }

    private func collegamento(_ titolo: String, icona: String, pagina: Pagina) -> some View {
      NavigationLink(value: pagina) {
        Label(titolo, systemImage: icona)
          .foregroundStyle(Stile.testo)
      }
      .listRowBackground(veloRiga)
    }
  }

  // MARK: Navigazione

  /// Impostazioni › Navigazione (IOS-091, SET-006): l'ordine delle voci con
  /// le maniglie di iOS; i primi tre moduli accesi vanno nella TabBar, gli
  /// altri in `Altro` (IOS-009).
  struct NavigazioneView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var errore: String?

    var body: some View {
      let riepilogo = VoceNavigazione.riepilogo(sessione.preferenze)
      List {
        Section {
          ForEach(sessione.preferenze.navOrder, id: \.self) { voce in
            Text(VoceNavigazione.titolo(voce))
              .foregroundStyle(Stile.testo)
              .listRowBackground(veloRiga)
          }
          .onMove { origine, destinazione in
            let ordine = VoceNavigazione.sposta(
              sessione.preferenze.navOrder, da: origine, a: destinazione)
            Task {
              let fatto = await sessione.salva(ModificaPreferenze(navOrder: ordine))
              errore = fatto ? nil : "Ordine non salvato · riprova"
            }
          }
        } header: {
          Text("Ordine")
        } footer: {
          VStack(alignment: .leading, spacing: 6) {
            Text("Home è sempre prima e Altro sempre ultima. Lo stesso ordine vale sul sito.")
              .foregroundStyle(Stile.testoTenue)
            NonSalvato(testo: errore)
          }
        }
        Section("Sull'iPhone") {
          RigaValore(nome: "Nella TabBar", valore: riepilogo.barra)
            .listRowBackground(veloRiga)
          RigaValore(nome: "In Altro", valore: riepilogo.altro)
            .listRowBackground(veloRiga)
        }
      }
      .environment(\.editMode, .constant(.active))
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Navigazione")
    }
  }

  // MARK: Formati

  /// Impostazioni › Formati (IOS-091, SET-010): fuso, peso, energia; la
  /// lingua si vede e non si cambia.
  struct FormatiView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var errore: String?

    private var formati: Formati { sessione.preferenze.formats }

    var body: some View {
      List {
        Section {
          Picker("Fuso orario", selection: campo(\.timeZone)) {
            ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
          }
          .pickerStyle(.navigationLink)
          .foregroundStyle(Stile.testo)
          .listRowBackground(veloRiga)
        } footer: {
          VStack(alignment: .leading, spacing: 6) {
            Text("Per le ore mostrate nei moduli.").foregroundStyle(Stile.testoTenue)
            NonSalvato(testo: errore)
          }
        }
        Section {
          Picker("Peso", selection: campo(\.weightUnit)) {
            Text("kg").tag(Formati.Peso.kg)
            Text("lb").tag(Formati.Peso.lb)
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
        } header: {
          Text("Peso")
        } footer: {
          Text("Peso corporeo e carichi · \(formati.esempioPeso())")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
        Section {
          Picker("Energia", selection: campo(\.energyUnit)) {
            Text("kcal").tag(Formati.Energia.kcal)
            Text("kJ").tag(Formati.Energia.kJ)
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
        } header: {
          Text("Energia")
        } footer: {
          Text("Calorie dei pasti · \(formati.esempioEnergia())")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Stile.testoTenue)
        }
        Section {
          RigaValore(nome: "Lingua", valore: "Italiano")
            .listRowBackground(veloRiga)
        } footer: {
          Text("Per ora ron1nOS parla solo italiano.").foregroundStyle(Stile.testoTenue)
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Formati")
    }

    private func campo<Valore>(_ percorso: WritableKeyPath<Formati, Valore>) -> Binding<Valore> {
      Binding(
        get: { formati[keyPath: percorso] },
        set: { valore in
          var nuovi = formati
          nuovi[keyPath: percorso] = valore
          Task {
            let fatto = await sessione.salva(ModificaPreferenze(formats: nuovi))
            errore = fatto ? nil : "Formati non salvati · riprova"
          }
        })
    }
  }
#endif
