#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI

  /// Impostazioni › Moduli › Documenti (IOS-063): i tipi di documento, da
  /// creare, modificare ed eliminare se nessun documento li usa.
  struct ImpostazioniDocumentiView: View {
    @EnvironmentObject private var sessione: Sessione
    @State private var stato: Carico<[TipoDocumento]> = .inCorso
    @State private var aperto: TipoAperto?

    /// Il tipo nel foglio di modifica, o uno nuovo.
    struct TipoAperto: Identifiable {
      let id: String
      let tipo: TipoDocumento?
    }

    var body: some View {
      List {
        Section {
          Toggle("Chiedi Face ID", isOn: faceID).tint(Stile.brand)
        } footer: {
          Text("Entrando nei Documenti. Lo sblocco vale fino a 1 minuto in background.")
        }
        .listRowBackground(Color.white.opacity(0.06))
        Section {
          switch stato {
          case .inCorso:
            Scheletro(righe: 3)
          case .spento:
            ModuloSpento()
          case .fallito(let errore):
            SezioneErrore(errore: errore)
          case .pronto(let tipi):
            ForEach(tipi) { tipo in
              Button {
                aperto = TipoAperto(id: tipo.id, tipo: tipo)
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: IconaDocumento.simbolo(tipo.icon))
                    .foregroundStyle(Stile.testoTenue)
                    .frame(width: 28)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(tipo.name).foregroundStyle(Stile.testo)
                    Text(dettaglio(tipo))
                      .font(.footnote)
                      .foregroundStyle(Stile.testoTenue)
                  }
                }
              }
              .swipeActions(edge: .trailing) {
                if tipo.documents == 0 {
                  Button("Elimina", role: .destructive) { Task { await elimina(tipo) } }
                }
              }
            }
            Button("Nuovo tipo", systemImage: "plus") { aperto = TipoAperto(id: "nuovo", tipo: nil) }
          }
        } header: {
          Text("Tipi di documento")
        } footer: {
          Text("Si elimina solo un tipo che nessun documento usa.")
        }
        .listRowBackground(Color.white.opacity(0.06))
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Documenti")
      .sheet(item: $aperto) { aperto in
        ModuloTipoView(tipo: aperto.tipo) { await carica() }
          .environmentObject(sessione)
      }
      .refreshable { await carica() }
      .task { await carica() }
    }

    private var faceID: Binding<Bool> {
      Binding(
        get: { sessione.blocco.attivo },
        set: { attivo in
          sessione.blocco.attivo = attivo
          UserDefaults.standard.set(attivo, forKey: BloccoDocumenti.chiave)
        })
    }

    /// "Già pronto · 6 campi · 2 documenti".
    private func dettaglio(_ tipo: TipoDocumento) -> String {
      var parti = [tipo.fields.count == 1 ? "1 campo" : "\(tipo.fields.count) campi"]
      if tipo.preset { parti.insert("Già pronto", at: 0) }
      if tipo.documents > 0 {
        parti.append(tipo.documents == 1 ? "1 documento" : "\(tipo.documents) documenti")
      }
      return parti.joined(separator: " · ")
    }

    private func carica() async {
      let client = sessione.client
      stato = await Carico.da { try await client.tipiDocumento() }
    }

    private func elimina(_ tipo: TipoDocumento) async {
      do {
        if let messaggio = try await sessione.client.eliminaTipo(tipo.id) {
          sessione.mostra(Avviso(messaggio))
        }
        await carica()
      } catch {
        sessione.mostra(.nonSalvato) { Task { await elimina(tipo) } }
      }
    }
  }

  /// Il foglio di un tipo: nome, icona e campi da aggiungere, rinominare,
  /// riordinare e togliere.
  struct ModuloTipoView: View {
    let tipo: TipoDocumento?
    let salvato: () async -> Void
    @EnvironmentObject private var sessione: Sessione
    @Environment(\.dismiss) private var chiudi
    @State private var modulo = ModuloTipo()
    @State private var errore: String?
    @State private var inCorso = false

    var body: some View {
      NavigationStack {
        Form {
          if let errore {
            Text(errore).font(.footnote).foregroundStyle(Stile.brandTesto)
          }
          Section {
            TextField("Nome", text: $modulo.nome)
            Picker("Icona", selection: $modulo.icona) {
              ForEach(ModuloTipo.icone, id: \.self) { icona in
                Image(systemName: IconaDocumento.simbolo(icona)).tag(icona)
              }
            }
          }
          Section {
            ForEach(modulo.campi.indices, id: \.self) { indice in
              VStack(alignment: .leading, spacing: 8) {
                TextField("Etichetta", text: $modulo.campi[indice].label)
                HStack {
                  Picker("Genere", selection: $modulo.campi[indice].kind) {
                    ForEach(ModuloTipo.generi, id: \.self) { genere in
                      Text(ModuloTipo.nomeGenere(genere)).tag(genere)
                    }
                  }
                  .labelsHidden()
                  Spacer()
                  Toggle("Copiabile", isOn: $modulo.campi[indice].copyable)
                    .tint(Stile.brand)
                    .fixedSize()
                }
                .font(.footnote)
              }
            }
            .onDelete { modulo.campi.remove(atOffsets: $0) }
            .onMove { modulo.campi.move(fromOffsets: $0, toOffset: $1) }
            Button("Aggiungi campo", systemImage: "plus") { modulo.campi.append(CampoTipo(label: "")) }
          } header: {
            Text("Campi")
          } footer: {
            Text("Togliendo un campo, i suoi valori restano come campi liberi sui documenti.")
          }
          if let problema = modulo.problema, !modulo.nome.isEmpty {
            Text(problema).font(.footnote).foregroundStyle(Stile.brandTesto)
          }
        }
        .scrollContentBackground(.hidden)
        .background(SfondoConAlone().ignoresSafeArea())
        .navigationTitle(tipo == nil ? "Nuovo tipo" : "Modifica tipo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Annulla") { chiudi() }
          }
          ToolbarItem(placement: .topBarLeading) { EditButton() }
          ToolbarItem(placement: .confirmationAction) {
            Button("Salva") { Task { await salva() } }
              .disabled(inCorso || modulo.problema != nil)
          }
        }
        .onAppear {
          if let tipo, modulo == ModuloTipo() { modulo = ModuloTipo(tipo: tipo) }
        }
      }
    }

    private func salva() async {
      inCorso = true
      defer { inCorso = false }
      do {
        let client = sessione.client
        let esito: Esito<TipoDocumento>
        if let tipo {
          esito = try await client.modificaTipo(tipo.id, modulo)
        } else {
          esito = try await client.creaTipo(modulo)
        }
        switch esito {
        case .fatto:
          sessione.documentiCambiati += 1
          await salvato()
          chiudi()
        case .rifiutato(let messaggio):
          errore = messaggio
        }
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }
  }
#endif
