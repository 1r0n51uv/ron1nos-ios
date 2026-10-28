#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Registrare un pasto (IOS-031): si cerca un alimento, si scrivono i
  /// grammi col tastierino e si aggiungono più righe prima di salvare.
  struct RegistraPastoView: View {
    let giorno: String
    let slot: String
    /// Chiamata col giorno aggiornato quando il pasto è registrato.
    let registrato: (GiornoDieta) -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.formati) private var formati
    @Environment(\.dismiss) private var chiudi
    @State private var testo = ""
    @State private var soloItalia = true
    @State private var risultati: RisultatiRicerca?
    @State private var recenti: [Alimento] = []
    @State private var cercando = false
    @State private var errore: APIError?
    @State private var righe: [Bozza] = []
    @State private var salvando = false
    /// La fotocamera aperta (IOS-032) e l'esito della ricerca del codice.
    @State private var fotocamera = false
    @State private var codiceIgnoto: Codice?

    private var titolo: String { GiornoDieta.nomiSlot[slot] ?? slot }

    var body: some View {
      NavigationStack {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            if !righe.isEmpty { daRegistrare }
            campo
            if let avviso = risultati?.avviso {
              Text(avviso)
                .font(.footnote)
                .foregroundStyle(Stile.testoTenue)
            }
            if let errore {
              SezioneErrore(errore: errore).glassPanel(tinta: Stile.brand)
            }
            elenco
          }
          .padding(16)
        }
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle(titolo)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Salva") { Task { await salva() } }
              .fontWeight(.semibold)
              .disabled(!righe.salvabile || salvando)
          }
        }
      }
      .tint(Stile.brand)
      .sheet(isPresented: $fotocamera) {
        CodiceABarreView { codice in
          Task { await cercaCodice(codice) }
        }
      }
      .sheet(item: $codiceIgnoto) { ignoto in
        // Codice sconosciuto: si crea l'alimento col codice già scritto.
        NavigationStack {
          AlimentiPersonaliView(codice: ignoto.id)
        }
      }
      .task { await caricaRecenti() }
    }

    /// Il campo di ricerca e il filtro Solo Italia.
    @ViewBuilder
    private var campo: some View {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(Stile.testoTenue)
          TextField("Cerca un alimento", text: $testo)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(Stile.testo)
            .submitLabel(.search)
          if cercando { ProgressView().controlSize(.small) }
          Button {
            fotocamera = true
          } label: {
            Image(systemName: "barcode.viewfinder")
              .foregroundStyle(Stile.testo)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Leggi un codice a barre")
        }
        .glassChip()
        Toggle("Solo Italia", isOn: $soloItalia)
          .font(.subheadline)
          .tint(Stile.brand)
      }
      .task(id: Chiave(testo: testo, italia: soloItalia)) { await cerca() }
    }

    /// Le righe già scelte, coi grammi da scrivere.
    @ViewBuilder
    private var daRegistrare: some View {
      VStack(alignment: .leading, spacing: 12) {
        ForEach($righe) { $riga in
          RigaBozza(riga: $riga) {
            righe.removeAll { $0.id == riga.id }
          }
        }
        Divider().overlay(Color.white.opacity(0.12))
        HStack {
          Text("Totale")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Text(formati.energia(righe.totale.kcal))
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
        Text(RegistraPastoView.testoMacro(righe.totale))
          .font(.system(.footnote, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
      }
      .glassPanel()
    }

    /// "P 24 g · C 40 g · G 6 g".
    static func testoMacro(_ macro: Macro) -> String {
      "P \(Formato.numero(macro.protein)) g · C \(Formato.numero(macro.carbs)) g"
        + " · G \(Formato.numero(macro.fat)) g"
    }

    /// I risultati, o gli alimenti recenti col campo vuoto (NUT-028).
    @ViewBuilder
    private var elenco: some View {
      let cercato = testo.trimmingCharacters(in: .whitespaces).count >= 2
      let mostrati = cercato ? (risultati?.results ?? []) : recenti
      VStack(alignment: .leading, spacing: 10) {
        Text(cercato ? "RISULTATI" : "RECENTI")
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
        if mostrati.isEmpty {
          Text(cercando ? "Cerco." : "Nessun alimento.")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
        }
        ForEach(mostrati, id: \.chiave) { alimento in
          Button {
            aggiungi(alimento)
          } label: {
            VoceAlimento(alimento: alimento)
          }
          .buttonStyle(.plain)
        }
      }
      .glassPanel()
    }

    private func aggiungi(_ alimento: Alimento) {
      guard !righe.contains(where: { $0.alimento.chiave == alimento.chiave }) else { return }
      withAnimation(.snappy) { righe.append(Bozza(alimento)) }
    }

    /// Un codice a barre sconosciuto, da passare al foglio.
    struct Codice: Identifiable, Equatable {
      let id: String
    }

    /// Cosa fa ripartire la ricerca: il testo e il filtro.
    private struct Chiave: Equatable {
      let testo: String
      let italia: Bool
    }

    private func cerca() async {
      let q = testo.trimmingCharacters(in: .whitespaces)
      guard q.count >= 2 else {
        risultati = nil
        return
      }
      // Si aspetta un attimo: così non si cerca a ogni lettera.
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      cercando = true
      defer { cercando = false }
      do {
        risultati = try await sessione.client.cercaAlimenti(q, soloItalia: soloItalia)
        errore = nil
      } catch {
        errore = error
      }
    }

    /// Il codice letto va al backend: trovato si passa ai grammi,
    /// sconosciuto si apre Nuovo alimento (IOS-033).
    private func cercaCodice(_ codice: String) async {
      do {
        if let alimento = try await sessione.client.alimentoDaCodice(codice) {
          aggiungi(alimento)
        } else {
          codiceIgnoto = Codice(id: codice)
        }
      } catch {
        errore = error
      }
    }

    private func caricaRecenti() async {
      recenti = (try? await sessione.client.alimentiRecenti(slot: slot)) ?? []
    }

    private func salva() async {
      guard righe.salvabile else { return }
      salvando = true
      defer { salvando = false }
      do {
        let giorno = try await sessione.client.registraPasto(giorno: giorno, slot: slot, righe: righe)
        registrato(giorno)
        chiudi()
      } catch {
        errore = error
        sessione.mostra(.nonSalvato) { Task { await salva() } }
      }
    }
  }

  /// Una riga dell'elenco: nome, marca, kcal per 100 g e la fonte.
  struct VoceAlimento: View {
    let alimento: Alimento
    @Environment(\.formati) private var formati

    var body: some View {
      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
          Text(alimento.name)
            .font(.subheadline)
            .foregroundStyle(Stile.testo)
            .lineLimit(2)
          Text(alimento.sottotitolo(formati))
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
        }
        Spacer(minLength: 8)
        Text(alimento.fonte)
          .font(.system(.caption2, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(Color.white.opacity(0.08)))
      }
      .padding(.vertical, 6)
      .contentShape(Rectangle())
      .accessibilityElement(children: .combine)
      .accessibilityLabel("\(alimento.name), \(alimento.sottotitolo(formati)), fonte \(alimento.fonte)")
    }
  }

  /// Una riga da registrare: i grammi col tastierino numerico e le kcal che
  /// si aggiornano mentre si scrive.
  struct RigaBozza: View {
    @Binding var riga: Bozza
    let togli: () -> Void
    @Environment(\.formati) private var formati

    var body: some View {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(riga.alimento.name)
            .font(.subheadline)
            .foregroundStyle(Stile.testo)
            .lineLimit(1)
          Spacer()
          Button {
            togli()
          } label: {
            Image(systemName: "minus.circle")
              .foregroundStyle(Stile.testoTenue)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Togli \(riga.alimento.name)")
        }
        HStack(spacing: 10) {
          TextField("0", text: $riga.testoGrammi)
            .keyboardType(.decimalPad)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(riga.valida ? Stile.testo : Stile.brandTesto)
            .frame(width: 80)
            .glassChip()
            .accessibilityLabel("Grammi di \(riga.alimento.name)")
          Text("g")
            .font(.footnote)
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Text(formati.energia(riga.macro.kcal))
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testo)
        }
        Text(RegistraPastoView.testoMacro(riga.macro))
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(Stile.testoTenue)
      }
    }
  }
#endif
