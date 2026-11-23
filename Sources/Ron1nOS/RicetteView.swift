#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le ricette (IOS-034, IOS-043): quelle importate dai preferiti di YAZIO e
  /// quelle create qui, in una griglia di foto. Un tocco apre la ricetta.
  struct RicetteView: View {
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @State private var stato = Carico<[Ricetta]>.inCorso
    @State private var nuova = false
    @State private var importando = false
    @State private var cerca = ""
    @State private var categoria: CategoriaRicetta?
    @State private var modifica: Ricetta?
    @State private var pianifica: Ricetta?
    @State private var daEliminare: Ricetta?
    @State private var inCorsoFoto: Set<String> = []
    @Namespace private var zoom

    private let colonne = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 5).glassPanel().transition(.blurReplace)
          case .spento:
            Text("Il modulo Nutrizione è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            SezioneErrore(errore: errore).glassPanel()
          case .pronto(let ricette):
            let trovate = cercando ? RicercaRicette.filtra(ricette, testo: cerca) : ricette
            let mostrate = RicercaRicette.conCategoria(trovate, categoria)
            if !ricette.isEmpty {
              CampoRicerca(testo: $cerca, prompt: "Cerca per nome o ingrediente")
              FiltroCategorie(scelta: $categoria)
            }
            if ricette.isEmpty {
              vuote
            } else if mostrate.isEmpty {
              nessunRisultato
            }
            LazyVGrid(columns: colonne, spacing: 12) {
              ForEach(Array(mostrate.enumerated()), id: \.element.id) { indice, ricetta in
                NavigationLink {
                  RicettaView(id: ricetta.id)
                    .destinazioneZoom(ricetta.id, in: zoom)
                } label: {
                  riquadro(ricetta)
                }
                .buttonStyle(StilePremuto())
                .sorgenteZoom(ricetta.id, in: zoom)
                .contextMenu { azioniRapide(ricetta) }
                .comparsa(indice)
              }
            }
            .animation(Stile.molla, value: mostrate.map(\.id))
          }
        }
        .padding(.horizontal, Stile.margine)
        .padding(.bottom, 24)
      }
      .paginaScheda()
      .navigationTitle("Ricette")
      .azioniInAlto {
        AzioneBarra(titolo: "Nuova ricetta", simbolo: "plus", principale: true) { nuova = true }
        AzioneBarra(titolo: "Importa da YAZIO", simbolo: "arrow.down.circle.fill", inCorso: importando) {
          Task { await importa() }
        }
      }
      .sheet(isPresented: $nuova) {
        RicettaFormView(ricetta: nil) { await carica() }
          .environmentObject(sessione)
          .environment(\.formati, formati)
          .environment(\.modulo, .nutrizione)
      }
      .sheet(item: $modifica) { ricetta in
        RicettaFormView(ricetta: ricetta) { await carica() }
          .environmentObject(sessione)
          .environment(\.formati, formati)
          .environment(\.modulo, .nutrizione)
      }
      .sheet(item: $pianifica) { ricetta in
        PianificaRicettaView(ricetta: ricetta)
          .environmentObject(sessione)
          .environment(\.formati, formati)
      }
      .confirmationDialog(
        "Eliminare la ricetta?",
        isPresented: Binding(get: { daEliminare != nil }, set: { if !$0 { daEliminare = nil } }),
        titleVisibility: .visible, presenting: daEliminare
      ) { ricetta in
        Button("Elimina \(ricetta.name)", role: .destructive) { Task { await elimina(ricetta) } }
        Button("Annulla", role: .cancel) {}
      } message: { _ in
        Text("I pasti già programmati con questa ricetta restano.")
      }
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
    }

    /// Il menu del tocco lungo su una ricetta (IOS-046).
    @ViewBuilder
    private func azioniRapide(_ ricetta: Ricetta) -> some View {
      Button {
        modifica = ricetta
      } label: {
        Label("Modifica", systemImage: "pencil")
      }
      Button {
        Task { await duplica(ricetta) }
      } label: {
        Label("Duplica", systemImage: "plus.square.on.square")
      }
      Button {
        Task { await generaFoto(ricetta) }
      } label: {
        Label(ricetta.imageUrl == nil ? "Genera foto" : "Rigenera foto", systemImage: "camera.fill")
      }
      .disabled(ricetta.photo?.inCorso == true || inCorsoFoto.contains(ricetta.id))
      Button {
        pianifica = ricetta
      } label: {
        Label("Aggiungi al piano", systemImage: "calendar.badge.plus")
      }
      Button {
        Task { await inSpesa(ricetta) }
      } label: {
        Label("Aggiungi alla spesa", systemImage: "cart.badge.plus")
      }
      Menu {
        ForEach(CategoriaRicetta.allCases) { voce in
          Toggle(
            isOn: Binding(
              get: { ricetta.categorie.contains(voce) },
              set: { acceso in Task { await imposta(voce, acceso, su: ricetta) } })
          ) {
            Label(voce.nome, systemImage: voce.simbolo)
          }
        }
      } label: {
        Label("Categorie", systemImage: "tag")
      }
      Divider()
      Button(role: .destructive) {
        daEliminare = ricetta
      } label: {
        Label("Elimina", systemImage: "trash")
      }
    }

    /// C'è del testo da cercare.
    private var cercando: Bool { !cerca.trimmingCharacters(in: .whitespaces).isEmpty }

    private var nessunRisultato: some View {
      StatoVuoto(
        simbolo: "magnifyingglass", titolo: "Nessuna ricetta",
        testo: cercando
          ? "Non ne trovo con \"\(cerca)\" nel nome o tra gli ingredienti."
          : "Nessuna ricetta in questa categoria. Tienine una premuta per assegnargliela.",
        tinta: Modulo.nutrizione.colore)
    }

    /// Senza ricette dice dove sono le due strade per averne, in alto.
    private var vuote: some View {
      StatoVuoto(
        simbolo: "book.closed.fill", titolo: "Nessuna ricetta",
        testo: "Importa i preferiti di YAZIO o creane una, dai pulsanti in alto.",
        tinta: Modulo.nutrizione.colore)
    }

    /// Una ricetta nella griglia: foto (o segnaposto), nome e kcal.
    private func riquadro(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 8) {
        FotoRicetta(indirizzo: ricetta.imageUrl, forma: .riquadro, segnaposto: true)
        Text(ricetta.name)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Stile.testo)
          .multilineTextAlignment(.leading)
          .lineLimit(2, reservesSpace: true)
        HStack(spacing: 6) {
          Text(formati.energia(ricetta.kcal))
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(Modulo.nutrizione.colore)
          Spacer(minLength: 0)
          IconeCategorie(ricetta: ricetta)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Stile.velo, in: RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous).strokeBorder(Stile.bordo))
      .accessibilityElement(children: .combine)
    }

    private func carica() async {
      let client = sessione.client
      let nuovo = await Carico.da { try await client.ricette() }
      withAnimation(Stile.molla) { stato = nuovo }
    }

    private func imposta(_ voce: CategoriaRicetta, _ acceso: Bool, su ricetta: Ricetta) async {
      var scelte = Set(ricetta.categorie)
      if acceso { scelte.insert(voce) } else { scelte.remove(voce) }
      do {
        _ = try await sessione.client.cambiaCategorie(
          ricetta.id, CategoriaRicetta.allCases.filter(scelte.contains))
        await carica()
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non salvata"))
      }
    }

    private func duplica(_ ricetta: Ricetta) async {
      var copia = ModuloRicetta(ricetta)
      copia.nome = "\(ricetta.name) (copia)"
      if let problema = copia.problema {
        sessione.mostra(Avviso(problema))
        return
      }
      do {
        _ = try await sessione.client.creaRicetta(copia)
        sessione.cambiato()
        sessione.mostra(Avviso("Duplicata"))
        await carica()
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non duplicata"))
      }
    }

    private func generaFoto(_ ricetta: Ricetta) async {
      inCorsoFoto.insert(ricetta.id)
      defer { inCorsoFoto.remove(ricetta.id) }
      do {
        _ = try await sessione.client.generaFoto(ricetta.id)
        sessione.mostra(Avviso("Foto in preparazione", durata: 4))
        await carica()
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore == .stato(503) ? "Le foto non sono attive sul server" : errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non avviata"))
      }
    }

    private func inSpesa(_ ricetta: Ricetta) async {
      do {
        let aggiunte = try await sessione.client.ricettaInSpesa(ricetta)
        sessione.cambiato()
        sessione.mostra(Avviso(aggiunte == 1 ? "1 voce nella spesa" : "\(aggiunte) voci nella spesa"))
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non riuscito"))
      }
    }

    private func elimina(_ ricetta: Ricetta) async {
      do {
        try await sessione.client.eliminaRicetta(ricetta.id)
        sessione.cambiato()
        sessione.mostra(Avviso("Eliminata"))
        await carica()
      } catch let errore as APIError {
        sessione.mostra(
          Avviso(errore == .stato(409) ? "Fa parte di una ricetta composta" : errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non riuscito"))
      }
    }

    private func importa() async {
      importando = true
      defer { importando = false }
      do {
        let esito = try await sessione.client.importaRicetteYazio()
        sessione.mostra(Avviso(esito.testo, durata: 4))
        await carica()
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore.titolo))
      } catch {
        sessione.mostra(Avviso("Import non riuscito"))
      }
    }
  }

  /// Una ricetta (IOS-034, IOS-043): la foto in copertina, che si allunga
  /// tirando giù, poi kcal e macro a colori, ingredienti, procedimento e note.
  struct RicettaView: View {
    let id: String
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var stato = Carico<Ricetta>.inCorso
    @State private var modifica = false
    @State private var eliminando = false
    @State private var avviando = false

    private let verde = Modulo.nutrizione.colore

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: Stile.traCard) {
          switch stato {
          case .inCorso:
            Scheletro(righe: 6).glassPanel().transition(.blurReplace)
          case .spento:
            Text("Il modulo Nutrizione è spento.")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
          case .fallito(let errore):
            if errore == .stato(404) {
              Text("La ricetta non c'è più.")
                .font(.subheadline)
                .foregroundStyle(Stile.testoTenue)
            } else {
              SezioneErrore(errore: errore).glassPanel()
            }
          case .pronto(let ricetta):
            copertina(ricetta)
            Text(ricetta.name)
              .font(.title2.weight(.bold))
              .foregroundStyle(Stile.testo)
              .padding(.top, 4)
              .comparsa(0)
            if !ricetta.categorie.isEmpty || ricetta.composta {
              categorie(ricetta)
                .comparsa(0)
            }
            totali(ricetta)
              .comparsa(1)
            if ricetta.composta {
              composizione(ricetta)
                .comparsa(2)
            }
            ingredienti(ricetta)
              .comparsa(2)
            if !ricetta.steps.isEmpty {
              procedimento(ricetta)
                .comparsa(3)
            }
            if let note = ricetta.notes, !note.isEmpty {
              noteDi(note)
                .comparsa(4)
            }
          }
        }
        .padding(.horizontal, Stile.margine)
        .padding(.bottom, 24)
      }
      .paginaScheda()
      .navigationTitle(stato.valore?.name ?? "Ricetta")
      .navigationBarTitleDisplayMode(.inline)
      .azioniInAlto {
        if stato.valore != nil {
          AzioneBarra(titolo: "Modifica", simbolo: "pencil", principale: true) { modifica = true }
          AzioneBarra(titolo: "Elimina", simbolo: "trash", distruttiva: true) { eliminando = true }
        }
      }
      .confirmationDialog("Eliminare la ricetta?", isPresented: $eliminando, titleVisibility: .visible) {
        Button("Elimina", role: .destructive) { Task { await elimina() } }
        Button("Annulla", role: .cancel) {}
      } message: {
        Text("I pasti già programmati con questa ricetta restano.")
      }
      .sheet(isPresented: $modifica) {
        RicettaFormView(ricetta: stato.valore) { await carica() }
          .environmentObject(sessione)
          .environment(\.formati, formati)
          .environment(\.modulo, .nutrizione)
      }
      .refreshable { await carica() }
      .task(id: sessione.versione) { await carica() }
      // Mentre image-chef lavora la ricetta si rilegge ogni 4 secondi.
      .task(id: stato.valore?.photo?.inCorso) {
        while stato.valore?.photo?.inCorso == true, !Task.isCancelled {
          try? await Task.sleep(nanoseconds: 4_000_000_000)
          await carica()
        }
      }
    }

    /// La foto in copertina: tirando giù la pagina si allunga verso l'alto.
    /// Senza foto, il segnaposto con il pulsante per generarla.
    @ViewBuilder
    private func copertina(_ ricetta: Ricetta) -> some View {
      let altezza: CGFloat = 240
      if ricetta.imageUrl != nil {
        GeometryReader { spazio in
          let tirata = max(0, spazio.frame(in: .scrollView).minY)
          FotoRicetta(indirizzo: ricetta.imageUrl, forma: .libera)
            .frame(width: spazio.size.width, height: altezza + tirata)
            .clipShape(RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous))
            .offset(y: -tirata)
        }
        .frame(height: altezza)
      } else {
        ZStack {
          FotoRicetta(indirizzo: nil, forma: .libera, segnaposto: true)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: Stile.raggio, style: .continuous))
          generaFoto(ricetta)
            .padding(16)
        }
      }
    }

    /// La ricetta senza foto: la si chiede all'agente del dojo (NUT-036).
    private func generaFoto(_ ricetta: Ricetta) -> some View {
      let inCorso = ricetta.photo?.inCorso == true || avviando
      return VStack(spacing: 10) {
        Button {
          Task { await avvia(ricetta.id) }
        } label: {
          if inCorso {
            HStack(spacing: 8) {
              ProgressView().controlSize(.small)
              Text("Foto in preparazione")
            }
          } else {
            Label("Genera foto", systemImage: "camera.fill")
          }
        }
        .pulsantePieno(verde)
        .buttonStyle(StilePremuto())
        .disabled(inCorso)
        if let errore = ricetta.photo?.error, ricetta.photo?.state == "failed" {
          Text("Non è riuscita: \(errore)")
            .font(.footnote)
            .foregroundStyle(Stile.brandTesto)
        } else if inCorso {
          Text("Ci vuole circa un minuto. Puoi uscire: la foto arriva da sola.")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
            .multilineTextAlignment(.center)
        }
      }
    }

    private func avvia(_ id: String) async {
      avviando = true
      defer { avviando = false }
      do {
        let ricetta = try await sessione.client.generaFoto(id)
        stato = .pronto(ricetta)
      } catch let errore as APIError {
        sessione.mostra(Avviso(errore == .stato(503) ? "Le foto non sono attive sul server" : errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non avviata"))
      }
    }

    /// Kcal e macro in quattro tessere colorate, poi il peso.
    private func totali(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Dato(
            valore: Formato.numero(formati.valoreEnergia(ricetta.kcal)),
            etichetta: formati.energyUnit.rawValue, tinta: verde)
          Dato(valore: Formato.numero(ricetta.protein), etichetta: "Proteine", tinta: Color(Palette.proteine))
          Dato(valore: Formato.numero(ricetta.carbs), etichetta: "Carbo", tinta: Color(Palette.carboidrati))
          Dato(valore: Formato.numero(ricetta.fat), etichetta: "Grassi", tinta: Color(Palette.grassi))
        }
        Text("Macro in grammi · \(Formato.numero(ricetta.grams)) g in tutto")
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
        if ricetta.incompleta {
          Text("Qualche alimento non c'è più: i totali non lo contano.")
            .font(.footnote)
            .foregroundStyle(Stile.brandTesto)
        }
      }
    }

    /// Le categorie della ricetta con la loro icona, e se è composta.
    private func categorie(_ ricetta: Ricetta) -> some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          if ricetta.composta {
            Label("Composta", systemImage: "square.stack.3d.up.fill")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(Stile.testo)
              .padding(.horizontal, 12)
              .frame(minHeight: 32)
              .background(Stile.velo, in: Capsule())
              .overlay(Capsule().strokeBorder(Stile.bordo))
          }
          ForEach(ricetta.categorie) { categoria in
            ChipCategoria(categoria: categoria)
          }
        }
      }
    }

    /// Le ricette che compongono questa, per ruolo: un tocco apre la parte.
    private func composizione(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        IntestazioneCard(titolo: "Composta da", simbolo: "square.stack.3d.up.fill", tinta: verde)
        ForEach(RuoloParte.allCases) { ruolo in
          ForEach(ricetta.parts.filter { $0.role == ruolo }) { parte in
            NavigationLink {
              RicettaView(id: parte.recipeId)
            } label: {
              HStack(spacing: 12) {
                Image(systemName: ruolo.simbolo)
                  .foregroundStyle(verde)
                  .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                  Text(parte.name)
                    .font(.subheadline)
                    .foregroundStyle(Stile.testo)
                    .multilineTextAlignment(.leading)
                  Text("\(ruolo.nome) · \(porzioni(parte.factor))")
                    .font(.footnote)
                    .foregroundStyle(Stile.testoTenue)
                }
                Spacer()
                Text(formati.energia(parte.kcal))
                  .font(.system(.footnote, design: .monospaced))
                  .foregroundStyle(Stile.testo)
                Image(systemName: "chevron.right")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Stile.testoTenue)
              }
              .frame(minHeight: 44)
              .contentShape(Rectangle())
            }
            .buttonStyle(StilePremuto())
          }
        }
      }
      .glassPanel()
    }

    /// "1 porzione", "1,5 porzioni".
    private func porzioni(_ n: Double) -> String {
      let testo = Formato.numero(n, decimali: n == n.rounded() ? 0 : 1)
      return "\(testo) \(n == 1 ? "porzione" : "porzioni")"
    }

    private func ingredienti(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        IntestazioneCard(
          titolo: "\(ricetta.composta ? "Ingredienti in tutto" : "Ingredienti") · \(ricetta.items.count)",
          simbolo: "basket.fill", tinta: verde)
        ForEach(ricetta.items) { riga in
          HStack(spacing: 10) {
            Circle().fill(verde).frame(width: 5, height: 5)
            RigaValore(nome: riga.name, valore: "\(Formato.numero(riga.grams)) g")
          }
        }
      }
      .glassPanel()
    }

    private func procedimento(_ ricetta: Ricetta) -> some View {
      VStack(alignment: .leading, spacing: 14) {
        IntestazioneCard(titolo: "Procedimento", simbolo: "list.number", tinta: verde)
        ForEach(Array(ricetta.steps.enumerated()), id: \.offset) { numero, passo in
          HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(numero + 1)")
              .font(.system(.caption, design: .monospaced).weight(.bold))
              .foregroundStyle(Stile.inchiostro)
              .frame(width: 22, height: 22)
              .background(verde, in: Circle())
            Text(passo)
              .font(.subheadline)
              .foregroundStyle(Stile.testo)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .glassPanel()
    }

    private func noteDi(_ note: String) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        IntestazioneCard(titolo: "Note", simbolo: "note.text", tinta: verde)
        Text(note)
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
    }

    private func carica() async {
      let client = sessione.client
      let id = id
      let nuovo = await Carico.da { try await client.ricetta(id) }
      // Un aggiornamento fallito dopo il primo non cancella i dati.
      if case .fallito(let errore) = nuovo, errore != .stato(404), stato.valore != nil { return }
      withAnimation(Stile.molla) { stato = nuovo }
    }

    private func elimina() async {
      do {
        try await sessione.client.eliminaRicetta(id)
        sessione.cambiato()
        sessione.mostra(Avviso("Eliminata"))
        chiudi()
      } catch let errore as APIError {
        sessione.mostra(
          Avviso(errore == .stato(409) ? "Fa parte di una ricetta composta" : errore.titolo))
      } catch {
        sessione.mostra(Avviso("Non riuscito"))
      }
    }
  }
#endif
