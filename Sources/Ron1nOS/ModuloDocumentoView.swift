#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Il form di un documento (IOS-062, DOC-005), a una colonna: per un
  /// documento nuovo e per `Modifica`. I problemi vanno sotto il loro campo.
  struct CampiDocumento: View {
    @Binding var modulo: ModuloDocumento
    let titolari: [String]
    /// Il messaggio del server, se non appartiene a un campo.
    let errori: [String: String]

    var body: some View {
      Section {
        TextField("Titolo", text: $modulo.titolo)
        problema("Titolo")
        HStack {
          TextField("Titolare", text: $modulo.titolare)
          if !titolari.isEmpty {
            Menu {
              ForEach(titolari, id: \.self) { nome in
                Button(nome) { modulo.titolare = nome }
              }
            } label: {
              Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel("Titolari già usati")
          }
        }
        problema("Titolare")
      }
      if modulo.genere == .documento, let tipo = modulo.tipo {
        Section(tipo.name) {
          ForEach(tipo.fields, id: \.self) { campo in
            if let chiave = campo.key {
              if campo.kind == "date" {
                CampoData(etichetta: campo.label, valore: valore(chiave))
              } else {
                TextField(campo.label, text: valore(chiave))
                  .font(campo.kind == "code" ? .system(.body, design: .monospaced) : .body)
                  .textInputAutocapitalization(campo.kind == "code" ? .characters : .sentences)
                  .autocorrectionDisabled(campo.kind == "code")
              }
              problema(campo.label)
            }
          }
        }
        Section("Scadenza") {
          CampoData(etichetta: "Scade il", valore: $modulo.scadenza)
          problema("Scadenza")
          if !modulo.scadenza.isEmpty {
            ForEach(ModuloDocumento.preavvisi, id: \.self) { giorni in
              Toggle("Avviso \(giorni) giorni prima", isOn: avviso(giorni))
                .tint(Stile.brand)
            }
          }
        }
      }
      if modulo.genere != .libero {
        Section {
          ForEach(modulo.liberi.indices, id: \.self) { indice in
            VStack(alignment: .leading) {
              TextField("Etichetta", text: $modulo.liberi[indice].label)
                .font(.footnote)
              TextField("Valore", text: $modulo.liberi[indice].value)
                .font(.system(.body, design: .monospaced))
            }
          }
          .onDelete { modulo.liberi.remove(atOffsets: $0) }
          .onMove { modulo.liberi.move(fromOffsets: $0, toOffset: $1) }
          Button("Aggiungi campo", systemImage: "plus") {
            modulo.liberi.append(Documento.CampoLibero(label: "", value: ""))
          }
          problema("Campi liberi")
        } header: {
          Text("Campi liberi")
        } footer: {
          Text("Scorri per eliminare, tieni premuto per riordinare.")
        }
      }
      Section {
        TextField("Tag, separati da virgola", text: $modulo.tag)
          .textInputAutocapitalization(.never)
        problema("Tag")
        Toggle("In evidenza", isOn: $modulo.fissato).tint(Stile.brand)
        TextField("Note", text: $modulo.note, axis: .vertical)
          .lineLimit(3...8)
        problema("Note")
      }
    }

    @ViewBuilder
    private func problema(_ campo: String) -> some View {
      // "Serve un titolo" non si mostra finché il form è appena aperto.
      let vuoto = campo == "Titolo" && modulo.titolo.trimmingCharacters(in: .whitespaces).isEmpty
      if let testo = errori[campo] ?? (vuoto ? nil : modulo.problemi[campo]) {
        Text(testo)
          .font(.footnote)
          .foregroundStyle(Stile.brandTesto)
      }
    }

    private func valore(_ chiave: String) -> Binding<String> {
      Binding(get: { modulo.valori[chiave] ?? "" }, set: { modulo.valori[chiave] = $0 })
    }

    private func avviso(_ giorni: Int) -> Binding<Bool> {
      Binding(
        get: { modulo.avvisi.contains(giorni) },
        set: { acceso in
          modulo.avvisi.removeAll { $0 == giorni }
          if acceso { modulo.avvisi.append(giorni) }
          modulo.avvisi.sort(by: >)
        })
    }
  }

  /// Una data `YYYY-MM-DD` facoltativa: vuota finché non la si aggiunge.
  struct CampoData: View {
    let etichetta: String
    @Binding var valore: String

    var body: some View {
      if let data = CampoData.data(valore) {
        HStack {
          DatePicker(
            etichetta,
            selection: Binding(get: { data }, set: { valore = CampoData.giorno($0) }),
            displayedComponents: .date)
          Button {
            valore = ""
          } label: {
            Image(systemName: "xmark.circle.fill").foregroundStyle(Stile.testoTenue)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Togli \(etichetta)")
        }
      } else {
        Button {
          valore = CampoData.giorno(Date())
        } label: {
          HStack {
            Text(etichetta).foregroundStyle(Stile.testo)
            Spacer()
            Text("Aggiungi").foregroundStyle(Stile.testoTenue)
          }
        }
      }
    }

    static var calendario: Calendar {
      var calendario = Calendar(identifier: .gregorian)
      calendario.timeZone = TimeZone(identifier: "UTC")!
      return calendario
    }

    static func data(_ giorno: String) -> Date? {
      let parti = giorno.split(separator: "-").compactMap { Int($0) }
      guard parti.count == 3 else { return nil }
      return calendario.date(from: DateComponents(year: parti[0], month: parti[1], day: parti[2], hour: 12))
    }

    static func giorno(_ data: Date) -> String {
      let p = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: data)
      let due = { (n: Int) in n < 10 ? "0\(n)" : "\(n)" }
      return "\(p.year ?? 2000)-\(due(p.month ?? 1))-\(due(p.day ?? 1))"
    }
  }

  /// `Modifica` dal dettaglio (IOS-061/062): lo stesso form, in un foglio.
  struct ModificaDocumentoView: View {
    let documento: Documento
    let salvato: (Documento) -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var modulo: ModuloDocumento?
    @State private var titolari: [String] = []
    @State private var errori: [String: String] = [:]
    @State private var inCorso = false

    var body: some View {
      NavigationStack {
        Form {
          if let errore = errori["_"] {
            Text(errore).font(.footnote).foregroundStyle(Stile.brandTesto)
          }
          if modulo != nil {
            CampiDocumento(
              modulo: Binding(get: { modulo! }, set: { modulo = $0 }), titolari: titolari, errori: errori)
          } else {
            ProgressView()
          }
        }
        .scrollContentBackground(.hidden)
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle("Modifica")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .topBarLeading) {
            EditButton()
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Salva") { Task { await salva() } }
              .disabled(inCorso || !(modulo?.valido ?? false))
          }
        }
        .task {
          let client = sessione.client
          let tipi = (try? await client.tipiDocumento()) ?? []
          titolari = (try? await client.titolari()) ?? []
          modulo = ModuloDocumento(documento: documento, tipo: tipi.first { $0.id == documento.typeId })
        }
      }
    }

    private func salva() async {
      guard let modulo else { return }
      inCorso = true
      defer { inCorso = false }
      do {
        switch try await sessione.client.modificaDocumento(documento.id, modulo) {
        case .fatto(let nuovo):
          sessione.documentiCambiati += 1
          salvato(nuovo)
          chiudi()
        case .rifiutato(let messaggio):
          errori = [modulo.campo(di: messaggio) ?? "_": messaggio]
        }
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }
  }
#endif
