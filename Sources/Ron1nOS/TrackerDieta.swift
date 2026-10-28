#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit

  /// Acqua, caffeina e integratori del giorno (IOS-037): un tocco aggiunge
  /// o annulla, con un leggero feedback aptico.
  struct TrackerDieta: View {
    let giorno: GiornoDieta
    let data: String
    /// Chiamata col giorno aggiornato dal backend.
    let aggiornato: (GiornoDieta) -> Void
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        acqua
        Divider().overlay(Color.white.opacity(0.12))
        caffeina
        if !(giorno.supplements ?? []).isEmpty {
          Divider().overlay(Color.white.opacity(0.12))
          integratori
        }
      }
      .glassPanel()
    }

    @ViewBuilder
    private var acqua: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Acqua", systemImage: "drop")
            .font(.subheadline)
            .foregroundStyle(Stile.testoTenue)
          Spacer()
          Text(giorno.testoAcqua)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(Stile.testo)
          Pulsante(icona: "minus", etichetta: "Annulla l'ultima acqua") {
            await chiama { try await $0.annullaAcqua(giorno: data) }
          }
          Pulsante(icona: "plus", etichetta: "Aggiungi 250 ml d'acqua") {
            await chiama { try await $0.aggiungiAcqua(giorno: data) }
          }
        }
        if let avanzamento = giorno.avanzamentoAcqua {
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

    @ViewBuilder
    private var caffeina: some View {
      HStack {
        Label("Caffeina", systemImage: "cup.and.saucer")
          .font(.subheadline)
          .foregroundStyle(Stile.testoTenue)
        Spacer()
        Text(giorno.testoCaffeina)
          .font(.system(.subheadline, design: .monospaced))
          .foregroundStyle(Stile.testo)
        Pulsante(icona: "minus", etichetta: "Annulla l'ultima caffeina") {
          await chiama { try await $0.annullaCaffeina(giorno: data) }
        }
        Pulsante(icona: "plus", etichetta: "Aggiungi un espresso") {
          await chiama { try await $0.aggiungiCaffeina(giorno: data) }
        }
      }
    }

    @ViewBuilder
    private var integratori: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text("INTEGRATORI")
          .font(.system(.caption, design: .monospaced))
          .tracking(1.6)
          .foregroundStyle(Stile.testoTenue)
        ForEach(giorno.supplements ?? []) { integratore in
          Button {
            Task {
              await chiama {
                try await $0.spuntaIntegratore(
                  integratore.id, giorno: data, preso: !integratore.taken)
              }
            }
          } label: {
            HStack(spacing: 10) {
              Image(systemName: integratore.taken ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(integratore.taken ? Stile.testo : Stile.testoTenue)
              Text(integratore.name)
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
              Spacer()
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(integratore.taken ? [.isButton, .isSelected] : .isButton)
        }
      }
    }

    /// Un tocco: feedback aptico, chiamata e giorno aggiornato.
    private func chiama(_ azione: (APIClient) async throws -> GiornoDieta) async {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      do {
        aggiornato(try await azione(sessione.client))
      } catch {
        sessione.mostra(.nonSalvato)
      }
    }

    /// Il tondino `−` o `+` dei contatori.
    struct Pulsante: View {
      let icona: String
      let etichetta: String
      let azione: () async -> Void

      var body: some View {
        Button {
          Task { await azione() }
        } label: {
          Image(systemName: icona)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Stile.testo)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(etichetta)
      }
    }
  }
#endif
