# App

Prefisso ID: `IOS` · Label: `mod:app`

L'involucro dell'app: progetto, build, installazione e collegamento al
server. I moduli (Download, Server, Nutrizione…) arrivano dopo, ognuno con
la sua specifica.

## Requisiti

### IOS-001 · App di prova

Stato: in corso (#2)

Una prima app, minima, che prova tutta la catena: build su Linux con
xtool, installazione con SideStore, rete Tailscale, nomi `*.ron1n.home` e
certificato di Caddy sul telefono.

Accettazione:

- [ ] Pacchetto SwiftPM per xtool (`Package.swift`, `xtool.yml`), iOS 17
      o successivo, bundle id `home.ron1n.ios`, nome sull'icona
      "ron1nOS", versione 0.1.0. Si compila con il builder dell'hub
      (`build` di IOSB-001) in un'IPA non firmata.
- [x] Una schermata, nello stile ron1nOS (nero, vetro, un solo accento
      rosso, numeri in monospazio), che chiama
      `GET https://ron1n.home/api/v1/health` all'apertura e quando la si
      trascina in basso.
- [x] Mostra lo stato del backend (raggiungibile o no) e quello del
      database (`ok`, `starting`, `disabled`, `unavailable`), in italiano,
      con l'ora dell'ultimo controllo.
- [x] Se la chiamata fallisce dice perché, in parole semplici: server non
      raggiungibile (Tailscale spento?), certificato non attendibile (CA di
      Caddy non installata?), risposta inattesa.
- [x] La logica (client HTTP, decodifica, messaggi) sta in un target
      separato senza SwiftUI, con test unitari che girano su Linux con
      `swift test`.
- [x] CI su ogni PR: formato e lint con `swift format`, `swift build` e
      `swift test`, su Linux. La build dell'IPA non gira in CI: l'SDK di
      Apple sta solo sul server.
- [x] Niente login: `/health` non lo chiede. I token per dispositivo
      (AUTH-005 di ron1nOS) arrivano con il primo modulo vero.

### IOS-002 · Diagnosi degli errori di rete

Stato: in corso (#4)

Sul telefono l'app può dire "non raggiungibile" mentre Safari apre
`https://ron1n.home`: per esempio se il profilo della CA di Caddy è
installato ma non attivato, Safari lascia entrare dopo l'avviso e l'app
no. Il pannello d'errore deve bastare a capire cosa non va, senza log.

Accettazione:

- [ ] Il pannello d'errore mostra, in monospazio e in tono tenue, il
      codice preciso: `URLError <codice>` per gli errori di rete,
      `HTTP <codice>` per quelli del server. Per gli errori TLS anche il
      codice di Secure Transport sottostante (`TLS -98xx`), quando c'è:
      distingue una root non attendibile da un rifiuto di App Transport
      Security o da un handshake fallito.
- [ ] L'app valuta il certificato con la fiducia di sistema di iOS, la
      stessa di Safari (`SecTrustEvaluateWithError`). Sul telefono di prova
      iOS rifiuta nelle app la root di Caddy ("non è autorizzato"), anche
      con il profilo installato e attivato, mentre Safari la accetta.
      Quindi, se la fiducia di sistema non basta e il nome è `ron1n.home`
      o un suo sottodominio, l'app rivaluta con la root di Caddy come
      ancora. La root è inclusa nell'app: è pubblica, la stessa di
      `ca.ron1n.home`, e l'impronta SHA-256 è nel codice. Catena e nome host
      si verificano comunque per intero. Se neanche così passa, il pannello
      mostra il motivo dato da iOS. Nessuna eccezione ad App Transport
      Security. Se Caddy rigenera la CA, la root va aggiornata nell'app.
- [ ] Il suggerimento per il certificato indica il percorso giusto di
      iOS: Impostazioni › Generali › Info › Impostazioni certificati
      attendibili, con l'interruttore della CA di Caddy acceso.
- [ ] Il suggerimento per il server non raggiungibile ricorda che iOS
      tiene accesa una sola VPN: con la VPN di SideStore attiva,
      Tailscale è spento.
- [ ] Gli errori di certificato di URLSession (`-1200`, `-1201`…`-1206`)
      diventano tutti "certificato non attendibile". Test unitari su
      Linux per la mappatura e i testi.

### IOS-003 · Card in Liquid Glass

Stato: pianificato (#5)

Una prova del materiale Liquid Glass di iOS 26 sulle due card della
schermata iniziale (stato ed errore), al posto del vetro sfocato.

Accettazione:

- [ ] Su iOS 26 o successivo le due card usano `glassEffect` con la stessa
      forma arrotondata di oggi (raggio 20), raccolte in un
      `GlassEffectContainer`. La card d'errore ha una tinta rossa leggera
      (`#FF2A2A`), l'unico accento.
- [ ] Su iOS 17–25 resta il pannello di oggi (`ultraThinMaterial` con
      bordo): il requisito minimo non cambia.
- [ ] Sotto le card c'è uno sfondo scuro con un alone appena visibile, così
      la rifrazione del vetro si vede anche sul nero.
- [ ] Si compila con il builder dell'hub (SDK iOS 27). Prova a mano sul
      telefono: il vetro si vede e i testi restano leggibili.
