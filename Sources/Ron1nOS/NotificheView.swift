#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit
  import UserNotifications

  /// Impostazioni › Notifiche (IOS-011): un interruttore per gruppo. Il
  /// permesso di iOS si chiede al primo interruttore acceso.
  struct NotificheView: View {
    @ObservedObject var centro: CentroNotifiche
    @EnvironmentObject private var sessione: Sessione

    var body: some View {
      List {
        Section {
          ForEach(GruppoNotifiche.allCases, id: \.self) { gruppo in
            Toggle(gruppo.titolo, isOn: interruttore(gruppo))
              .tint(Stile.brand)
              .foregroundStyle(Stile.testo)
              .listRowBackground(Color.white.opacity(0.06))
          }
        } footer: {
          Text("Le notifiche le programma questo iPhone e si aggiornano ogni volta che apri l'app.")
            .foregroundStyle(Stile.testoTenue)
        }

        if centro.permesso == .denied {
          Section {
            VStack(alignment: .leading, spacing: 8) {
              Text("Le notifiche di ron1nOS sono spente nelle impostazioni di iOS.")
                .font(.subheadline)
                .foregroundStyle(Stile.testo)
              Button("Apri le impostazioni di iOS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                  UIApplication.shared.open(url)
                }
              }
              .foregroundStyle(Stile.brand)
            }
            .listRowBackground(Color.white.opacity(0.06))
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Notifiche")
      .task { await centro.leggiPermesso() }
    }

    private func interruttore(_ gruppo: GruppoNotifiche) -> Binding<Bool> {
      Binding(
        get: { centro.scelte.acceso(gruppo) },
        set: { acceso in
          let client = sessione.client
          Task { await centro.imposta(gruppo, acceso: acceso, client: client) }
        })
    }
  }
#endif
