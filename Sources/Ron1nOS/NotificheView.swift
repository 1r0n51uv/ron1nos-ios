#if canImport(SwiftUI)
  import Ron1nKit
  import SwiftUI
  import UIKit
  import UserNotifications

  /// Impostazioni › Notifiche e Salute (IOS-011, IOS-094): un interruttore
  /// per gruppo con gli orari, lo stato del permesso di iOS e Apple Salute.
  /// Il permesso si chiede al primo interruttore acceso.
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

        OrariPromemoriaView(pasti: centro.scelte.acceso(.pasti), acqua: centro.scelte.acceso(.acqua))

        Section {
          HStack {
            Text("Notifiche").foregroundStyle(Stile.testo)
            Spacer()
            Text(permesso.testo)
              .font(.system(.subheadline, design: .monospaced))
              .foregroundStyle(permesso.segnale ? Stile.brand : Stile.testoTenue)
          }
          .listRowBackground(Color.white.opacity(0.06))
          Button("Apri le impostazioni di iOS") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
          .foregroundStyle(permesso.segnale ? Stile.brand : Stile.testo)
          .listRowBackground(Color.white.opacity(0.06))
        } header: {
          Text("Permesso di iOS")
        } footer: {
          Text(permesso.spiegazione).foregroundStyle(Stile.testoTenue)
        }

        Section {
          Toggle("Apple Salute", isOn: .constant(false))
            .disabled(true)
            .foregroundStyle(Stile.testoTenue)
            .listRowBackground(Color.white.opacity(0.06))
        } footer: {
          Text(
            "In attesa di sapere se la firma di SideStore concede HealthKit. "
              + "Quando c'è, qui si accende la lettura e la scrittura di peso, acqua e pasti."
          )
          .foregroundStyle(Stile.testoTenue)
        }
      }
      .scrollContentBackground(.hidden)
      .background(SfondoConAlone().ignoresSafeArea())
      .navigationTitle("Notifiche e Salute")
      .task { await centro.leggiPermesso() }
    }

    private var permesso: PermessoNotifiche {
      switch centro.permesso {
      case .notDetermined: .nonChiesto
      case .denied: .negato
      default: .concesso
      }
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
