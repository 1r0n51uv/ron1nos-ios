#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Le icone delle categorie di una ricetta (IOS-046), in fila: sulle card
  /// della griglia, accanto alle kcal. Una composta ha in testa le sue tre
  /// pile.
  struct IconeCategorie: View {
    let ricetta: Ricetta

    var body: some View {
      let categorie = ricetta.categorie
      if !categorie.isEmpty || ricetta.composta {
        HStack(spacing: 5) {
          if ricetta.composta {
            Image(systemName: "square.stack.3d.up.fill")
          }
          ForEach(categorie) { categoria in
            Image(systemName: categoria.simbolo)
          }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Modulo.nutrizione.colore)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.descrizione(ricetta))
      }
    }

    /// "Composta, Pranzo, Freddo".
    static func descrizione(_ ricetta: Ricetta) -> String {
      let nomi = (ricetta.composta ? ["Composta"] : []) + ricetta.categorie.map(\.nome)
      return nomi.joined(separator: ", ")
    }
  }

  /// Una categoria con il suo simbolo e il nome, nel dettaglio di una ricetta.
  struct ChipCategoria: View {
    let categoria: CategoriaRicetta

    var body: some View {
      Label(categoria.nome, systemImage: categoria.simbolo)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(Modulo.nutrizione.colore)
        .padding(.horizontal, 12)
        .frame(minHeight: 32)
        .background(Modulo.nutrizione.colore.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(Modulo.nutrizione.colore.opacity(0.35)))
    }
  }

  /// I filtri sopra la griglia: tutte, poi una categoria per volta.
  struct FiltroCategorie: View {
    @Binding var scelta: CategoriaRicetta?

    var body: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          voce(nil, titolo: "Tutte", simbolo: "square.grid.2x2.fill")
          ForEach(CategoriaRicetta.allCases) { categoria in
            voce(categoria, titolo: categoria.nome, simbolo: categoria.simbolo)
          }
        }
        .padding(.horizontal, Stile.margine)
      }
      .padding(.horizontal, -Stile.margine)
    }

    private func voce(_ categoria: CategoriaRicetta?, titolo: String, simbolo: String) -> some View {
      let attiva = scelta == categoria
      let tinta = Modulo.nutrizione.colore
      return Button {
        withAnimation(Stile.molla) { scelta = categoria }
      } label: {
        Label(titolo, systemImage: simbolo)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(attiva ? Stile.inchiostro : Stile.testo)
          .padding(.horizontal, 12)
          .frame(minHeight: 44)
          .background(attiva ? tinta : Stile.velo, in: Capsule())
          .overlay(Capsule().strokeBorder(attiva ? Color.clear : Stile.bordo))
      }
      .buttonStyle(StilePremuto())
      .accessibilityAddTraits(attiva ? .isSelected : [])
    }
  }

  /// Le categorie scelte nel foglio della ricetta: si accendono e si spengono.
  struct SceltaCategorie: View {
    @Binding var scelte: Set<CategoriaRicetta>

    var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("Categorie")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(CategoriaRicetta.allCases) { categoria in
              let attiva = scelte.contains(categoria)
              Button {
                withAnimation(Stile.molla) {
                  if attiva { scelte.remove(categoria) } else { scelte.insert(categoria) }
                }
              } label: {
                Label(categoria.nome, systemImage: categoria.simbolo)
                  .font(.footnote.weight(.semibold))
                  .foregroundStyle(attiva ? Stile.inchiostro : Stile.testo)
                  .padding(.horizontal, 12)
                  .frame(minHeight: 44)
                  .background(attiva ? Modulo.nutrizione.colore : Stile.velo, in: Capsule())
                  .overlay(Capsule().strokeBorder(attiva ? Color.clear : Stile.bordo))
              }
              .buttonStyle(StilePremuto())
              .accessibilityAddTraits(attiva ? .isSelected : [])
            }
          }
        }
      }
      .glassPanel()
    }
  }

  /// Le parti di una ricetta composta, nel foglio: una riga per ruolo, con la
  /// ricetta scelta e le porzioni. Il ruolo senza ricetta ha il pulsante per
  /// sceglierla.
  struct PartiRicetta: View {
    @Binding var parti: [BozzaParte]
    /// Il ruolo per cui si sta scegliendo una ricetta.
    @State private var scegliendo: RuoloParte?
    let ricette: [Ricetta]
    /// La ricetta che si sta correggendo, che non può contenere se stessa.
    let escludi: String?
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 14) {
        Text("Parti")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Stile.testo)
        Text("Una ricetta per ruolo, o più d'una se serve. Kcal e ingredienti si sommano.")
          .font(.footnote)
          .foregroundStyle(Stile.testoTenue)
        ForEach(RuoloParte.allCases) { ruolo in
          sezione(ruolo)
        }
        if !parti.isEmpty {
          HStack {
            Text("Totale")
              .font(.subheadline)
              .foregroundStyle(Stile.testoTenue)
            Spacer()
            Text(formati.energia(parti.reduce(0) { $0 + $1.kcalTotali }))
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(Stile.testo)
          }
        }
      }
      .glassPanel()
      .sheet(item: $scegliendo) { ruolo in
        SceltaParteView(ruolo: ruolo, ricette: ricette.filter { $0.id != escludi && !$0.composta }) {
          ricetta in
          parti.append(BozzaParte(ruolo: ruolo, ricetta))
          scegliendo = nil
        }
        .environment(\.formati, formati)
        .environment(\.modulo, .nutrizione)
      }
    }

    private func sezione(_ ruolo: RuoloParte) -> some View {
      VStack(alignment: .leading, spacing: 8) {
        Label(ruolo.nome, systemImage: ruolo.simbolo)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Modulo.nutrizione.colore)
        ForEach($parti) { $parte in
          if parte.ruolo == ruolo {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(parte.nome)
                  .font(.subheadline)
                  .foregroundStyle(Stile.testo)
                  .lineLimit(2)
                Spacer()
                Button {
                  parti.removeAll { $0.id == parte.id }
                } label: {
                  Image(systemName: "minus.circle")
                    .foregroundStyle(Stile.testoTenue)
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(StilePremuto())
                .accessibilityLabel("Togli \(parte.nome)")
              }
              Stepper(value: $parte.porzioni, in: BozzaParte.porzioniPossibili, step: 0.5) {
                HStack {
                  Text(porzioni(parte.porzioni))
                    .font(.footnote)
                    .foregroundStyle(Stile.testoTenue)
                  Spacer()
                  Text(formati.energia(parte.kcalTotali))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Stile.testo)
                }
              }
            }
          }
        }
        Button {
          scegliendo = ruolo
        } label: {
          Label("Aggiungi \(ruolo.nome.lowercased())", systemImage: "plus")
        }
        .glassChip()
      }
    }

    /// "1 porzione", "1,5 porzioni".
    private func porzioni(_ n: Double) -> String {
      let testo = Formato.numero(n, decimali: n == n.rounded() ? 0 : 1)
      return "\(testo) \(n == 1 ? "porzione" : "porzioni")"
    }
  }

  /// Il foglio per scegliere la ricetta di una parte: le ricette semplici,
  /// con una ricerca per nome.
  struct SceltaParteView: View {
    let ruolo: RuoloParte
    let ricette: [Ricetta]
    let scegli: (Ricetta) -> Void
    @Environment(\.dismiss) private var chiudi
    @Environment(\.formati) private var formati
    @State private var cerca = ""

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: Stile.traCard) {
            CampoRicerca(testo: $cerca, prompt: "Cerca per nome o ingrediente")
            VStack(alignment: .leading, spacing: 10) {
              let mostrate =
                cerca.trimmingCharacters(in: .whitespaces).isEmpty
                ? ricette : RicercaRicette.filtra(ricette, testo: cerca)
              if mostrate.isEmpty {
                Text(ricette.isEmpty ? "Non ci sono ricette semplici da usare." : "Nessuna ricetta.")
                  .font(.subheadline)
                  .foregroundStyle(Stile.testoTenue)
              }
              ForEach(mostrate) { ricetta in
                Button {
                  scegli(ricetta)
                } label: {
                  HStack(spacing: 12) {
                    FotoRicetta(indirizzo: ricetta.imageUrl, forma: .miniatura, segnaposto: true)
                    VStack(alignment: .leading, spacing: 2) {
                      Text(ricetta.name)
                        .font(.subheadline)
                        .foregroundStyle(Stile.testo)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                      Text(ricetta.sottotitolo(formati))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Stile.testoTenue)
                    }
                    Spacer()
                    IconeCategorie(ricetta: ricetta)
                  }
                  .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                  .contentShape(Rectangle())
                }
                .buttonStyle(StilePremuto())
              }
            }
            .glassPanel()
          }
          .padding(16)
        }
        .sfondoPagina()
        .navigationTitle(ruolo.nome)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
      }
      .tint(Modulo.nutrizione.colore)
    }
  }

  /// Aggiungere una ricetta al piano di un giorno (IOS-046): il giorno e il
  /// pasto, una porzione. Sostituisce ciò che è già programmato in quel pasto.
  struct PianificaRicettaView: View {
    let ricetta: Ricetta
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var giorno = Date()
    @State private var slot = "dinner"
    @State private var salvando = false
    @State private var errore: String?

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: Stile.traCard) {
            VStack(alignment: .leading, spacing: 12) {
              Text(ricetta.name)
                .font(.headline)
                .foregroundStyle(Stile.testo)
              DatePicker("Giorno", selection: $giorno, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "it_IT"))
                .tint(Modulo.nutrizione.colore)
              Picker("Pasto", selection: $slot) {
                ForEach(GiornoDieta.ordineSlot, id: \.self) { nome in
                  Text(GiornoDieta.nomiSlot[nome] ?? nome).tag(nome)
                }
              }
              .pickerStyle(.menu)
              .tint(Modulo.nutrizione.colore)
              Text("Se in quel pasto c'è già qualcosa, la ricetta prende il suo posto.")
                .font(.footnote)
                .foregroundStyle(Stile.testoTenue)
            }
            .glassPanel()
            if let errore {
              Text(errore)
                .font(.subheadline)
                .foregroundStyle(Stile.brandTesto)
            }
          }
          .padding(16)
        }
        .sfondoPagina()
        .navigationTitle("Aggiungi al piano")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
        }
        .azioniInBasso {
          AzioneBarra(
            titolo: "Programma", simbolo: "calendar.badge.plus", principale: true, inCorso: salvando
          ) {
            Task { await programma() }
          }
        }
      }
      .tint(Modulo.nutrizione.colore)
      .environment(\.modulo, .nutrizione)
    }

    private func programma() async {
      salvando = true
      defer { salvando = false }
      do {
        let testo = Settimana.testo(giorno, fuso: sessione.formati.fuso)
        try await sessione.client.programmaRicetta(ricetta.id, giorno: testo, slot: slot)
        sessione.cambiato()
        await sessione.ricalcolaPromemoria()
        sessione.mostra(Avviso("Programmata"))
        chiudi()
      } catch let problema as APIError {
        errore = problema.titolo
      } catch {
        errore = "Non programmata."
      }
    }
  }
#endif
