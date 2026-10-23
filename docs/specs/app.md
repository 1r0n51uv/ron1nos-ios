# App

Prefisso ID: `IOS` · Label: `mod:app`

L'involucro dell'app: progetto, build, installazione e collegamento al
server. I moduli (Download, Server, Nutrizione…) arrivano dopo, ognuno con
la sua specifica.

## Requisiti

### IOS-001 · App di prova

Stato: proposto

Una prima app, minima, che prova tutta la catena: build su Linux con
xtool, installazione con SideStore, rete Tailscale, nomi `*.ron1n.home` e
certificato di Caddy sul telefono.

Accettazione:

- [ ] Pacchetto SwiftPM per xtool (`Package.swift`, `xtool.yml`), iOS 17
      o successivo, bundle id `home.ron1n.ios`, nome sull'icona
      "ron1nOS", versione 0.1.0. Si compila con il builder dell'hub
      (`build` di IOSB-001) in un'IPA non firmata.
- [ ] Una schermata, nello stile ron1nOS (nero, vetro, un solo accento
      rosso, numeri in monospazio), che chiama
      `GET https://ron1n.home/api/v1/health` all'apertura e quando la si
      trascina in basso.
- [ ] Mostra lo stato del backend (raggiungibile o no) e quello del
      database (`ok`, `starting`, `disabled`, `unavailable`), in italiano,
      con l'ora dell'ultimo controllo.
- [ ] Se la chiamata fallisce dice perché, in parole semplici: server non
      raggiungibile (Tailscale spento?), certificato non attendibile (CA di
      Caddy non installata?), risposta inattesa.
- [ ] La logica (client HTTP, decodifica, messaggi) sta in un target
      separato senza SwiftUI, con test unitari che girano su Linux con
      `swift test`.
- [ ] CI su ogni PR: formato e lint con `swift format`, `swift build` e
      `swift test`, su Linux. La build dell'IPA non gira in CI: l'SDK di
      Apple sta solo sul server.
- [ ] Niente login: `/health` non lo chiede. I token per dispositivo
      (AUTH-005 di ron1nOS) arrivano con il primo modulo vero.
