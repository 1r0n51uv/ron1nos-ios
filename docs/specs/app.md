# App

Prefisso ID: `IOS` · Label: `mod:app`

L'involucro dell'app: progetto, build, installazione, collegamento al
server, navigazione e parti comuni a tutti i moduli. I moduli hanno
ognuno la sua specifica (vedi [README](README.md)).

Le card della home di IOS-006…008 sono la prima versione: con la Home
personalizzabile (IOS-020…024) diventano widget del catalogo.

## Requisiti

### IOS-001 · App di prova

Stato: fatto (#3)

Nata su Tailscale e `ron1n.home`; da IOS-004 l'app passa da Cloudflare.

Una prima app, minima, che prova tutta la catena: build su Linux con
xtool, installazione con SideStore, rete Tailscale, nomi `*.ron1n.home` e
certificato di Caddy sul telefono.

Accettazione:

- [x] Pacchetto SwiftPM per xtool (`Package.swift`, `xtool.yml`), iOS 17
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

Stato: fatto (#6)

Il pannello d'errore deve bastare a capire cosa non va, senza log. Nato
quando l'app rifiutava la CA locale di Caddy (`-1200`/`-9802`) mentre
Safari la accettava; con il passaggio a Cloudflare (SETUP-008 dell'hub) il
certificato è pubblico e sul telefono non si installa più niente.

Accettazione:

- [x] Il pannello d'errore mostra, in monospazio e in tono tenue, il
      codice preciso: `URLError <codice>` per gli errori di rete,
      `HTTP <codice>` per quelli del server. Per gli errori TLS anche il
      codice di Secure Transport sottostante (`TLS -98xx`), quando c'è:
      distingue una root non attendibile da un rifiuto di App Transport
      Security o da un handshake fallito.
- [x] L'app valuta il certificato con la fiducia di sistema di iOS, la
      stessa di Safari (`SecTrustEvaluateWithError`). Se iOS lo rifiuta, il
      pannello mostra il motivo dato da iOS. Nessuna eccezione ad App
      Transport Security e nessuna CA inclusa nell'app.
- [x] Il suggerimento per il certificato dice di controllare data e ora
      del telefono: il certificato di Cloudflare è pubblico.
- [x] Il suggerimento per il server non raggiungibile dice di controllare
      la connessione del telefono e che sul server siano accesi ron1nOS e
      il tunnel Cloudflare. Niente più Tailscale.
- [x] Gli errori di certificato di URLSession (`-1200`, `-1201`…`-1206`)
      diventano tutti "certificato non attendibile". Test unitari su
      Linux per la mappatura e i testi.

### IOS-003 · Card trasparenti

Stato: fatto (#7)

Le due card della schermata iniziale (stato ed errore) diventano quasi
trasparenti: si vede lo sfondo, il vetro resta come velo e bordo di luce.
Nella prima prova con Liquid Glass di iOS 26 (`glassEffect`, anche nella
variante `.clear`) le card risultavano opache sul nero, quindi il
materiale non si usa.

Accettazione:

- [x] Le card hanno solo un velo bianco al 6%, senza sfocatura, su ogni
      versione di iOS (del tutto trasparenti erano troppo).
      Hanno la forma arrotondata di oggi (raggio 20) e un bordo di 1 pt a
      gradiente, più chiaro in alto a sinistra, come un riflesso.
- [x] Il bordo della card d'errore è rosso (`#FF2A2A`), l'unico accento.
- [x] Sotto le card c'è uno sfondo nero con due aloni tenui, così le card
      si distinguono.
- [x] Si compila con il builder dell'hub (SDK iOS 27). Prova a mano sul
      telefono: le card sono trasparenti e i testi restano leggibili.

### IOS-004 · Accesso con Cloudflare Access

Stato: fatto (#9)

Con SETUP-008 dell'hub il backend sta su `https://home.ron1n.space`,
pubblicato da Cloudflare Tunnel e protetto da Cloudflare Access: il
browser entra con un codice via email, l'app con un service token. Niente
più Tailscale né CA da installare.

Accettazione:

- [x] L'indirizzo predefinito è `https://home.ron1n.space/api/v1`.
- [x] Ogni richiesta porta gli header `CF-Access-Client-Id` e
      `CF-Access-Client-Secret` del service token `ron1nos-ios`, se l'app
      ne ha uno. Il token sta nel Portachiavi di iOS, leggibile solo su
      quel telefono dopo il primo sblocco, mai nel codice né nell'IPA.
- [x] Un pulsante "Accesso" apre una schermata dove si incolla il token:
      vanno bene il JSON di Cloudflare (`client_id`, `client_secret`), le
      due righe di header o due righe con id e secret. Si salva e si
      elimina; il secret non si rilegge a schermo.
- [x] L'app non segue i redirect. Un redirect verso il login di Access
      (`*.cloudflareaccess.com`) diventa "Manca l'accesso" senza token e
      "Accesso rifiutato" con un token salvato (scaduto o revocato), con il
      suggerimento di incollarne uno nuovo.
- [x] Test unitari su Linux per la lettura del token, gli header e il
      redirect di Access.

### IOS-005 · Token di ron1nOS

Stato: fatto (#12)

Con il login di ron1nOS acceso le rotte dei moduli rispondono 401 senza
sessione. L'app entra con un token creato nella dashboard (AUTH-005 e
SET-008 di ron1nOS), oltre al service token di Access.

Accettazione:

- [x] In Accesso si incolla il token (`r1n_…`, anche con `Bearer `
      davanti), si salva e si elimina. Sta nel Portachiavi, in una voce
      separata da quella di Access; non si rilegge a schermo.
- [x] Ogni richiesta porta `Authorization: Bearer <token>` insieme agli
      header di Access.
- [x] La schermata di stato ha una riga Login (`GET /auth/me`): token
      valido, spento, manca il token, token rifiutato. Un 401 diventa
      "Manca il token ron1nOS" o "Token ron1nOS rifiutato", con il
      suggerimento di crearne uno in Impostazioni › App iOS.
- [x] Test unitari su Linux per la lettura del token, gli header, il 401 e
      lo stato del login.

### IOS-006 · Card Dieta

Stato: fatto (#14)

La prima card della home, sotto lo stato del server: la dieta di oggi da
`GET /nutrition/day`, la stessa del widget della dashboard.

Accettazione:

- [x] La card "Dieta · oggi" mostra le kcal mangiate sulla quota del
      giorno (`1.450 / 2.200 kcal`, numeri in monospazio all'italiana),
      una barra sottile e quante kcal mancano. Oltre la quota barra e
      testo diventano rossi.
- [x] Sotto, proteine, carboidrati e grassi in grammi sull'obiettivo.
      Senza obiettivo solo i valori mangiati.
- [x] Si aggiorna con lo stato, trascinando in basso. Con il modulo
      spento nelle Impostazioni (404) la card non c'è; con un errore
      mostra il titolo e il codice.
- [x] Le parti comuni alle card (stato di caricamento, formato dei
      numeri) stanno in Ron1nKit, con test su Linux.

### IOS-007 · Card Torrent

Stato: fatto (#17)

La card dei download da `GET /downloads`, come il widget Download della
dashboard.

Accettazione:

- [x] La card "Torrent" mostra la velocità totale di download
      (`2,4 MB/s`) e i primi tre torrent che scaricano: nome su una riga,
      barra, percentuale, velocità e tempo rimanente.
- [x] Sotto, il riepilogo degli altri: `+2 attivi · 1 in coda · 4 in
  seed`. Senza download attivi lo dice.
- [x] Con qBittorrent non raggiungibile (503) o il modulo spento vale
      quanto detto per le card in IOS-006. Test su Linux.

### IOS-008 · Card Server

Stato: fatto (#18)

La card delle risorse del server da `GET /server/stats` (Glances), come
il widget Server della dashboard.

Accettazione:

- [x] La card "Server" mostra CPU, RAM e disco in percentuale, ognuno con
      una barra; dal 90% in su barra rossa.
- [x] Sotto, in una riga: temperatura (se c'è il sensore), da quanto è
      acceso e la rete in ingresso e uscita (se Glances la dà).
- [x] Con Glances non raggiungibile (503) o il modulo spento vale quanto
      detto per le card in IOS-006. Test su Linux.

### IOS-009 · Navigazione a schede

Stato: pianificato (#22) · Scelta del proprietario il 2026-10-26 · Mockup: tavole 01, 25, 29

Accettazione:

- [ ] In basso la TabBar nativa di iOS 26 (`TabView`), in Liquid Glass
      di sistema: flottante, staccata dai bordi, rifrange il contenuto
      che le scorre sotto. Richiesta del proprietario il 2026-10-26.
- [ ] 5 voci: `Home`, `Dieta`, `Palestra`, `Documenti`, `Altro`, con
      icona e nome. La voce attiva è tinta di rosso (`#FF2A2A`), l'unico
      accento della barra.
- [ ] Scorrendo in basso la barra si riduce
      (`tabBarMinimizeBehavior(.onScrollDown)`) e torna intera scorrendo
      in su: lascia spazio ai contenuti.
- [ ] Barre di navigazione, fogli e menu usano lo stesso Liquid Glass di
      sistema. Le card restano col velo di IOS-003: il vetro vero sta solo
      sui controlli che galleggiano sopra i contenuti.
- [ ] Su iOS prima della 26 la TabBar standard, senza adattamenti.
- [ ] `Altro` apre un elenco con `Torrent`, `Server`, `Impostazioni` e i
      moduli che non stanno nelle prime quattro voci.
- [ ] L'ordine dei moduli segue Impostazioni › Navigazione del sito
      (SET-006): i primi tre moduli dopo Dashboard prendono le voci 2…4,
      gli altri finiscono in `Altro`. Home resta prima, `Altro` ultima.
- [ ] Un modulo spento (SET-005) sparisce dalla TabBar e da `Altro`.
- [ ] Ogni scheda tiene la sua pila di navigazione; toccare la voce già
      attiva torna alla radice.
- [ ] La schermata di Accesso (IOS-004, IOS-005) passa in Impostazioni ›
      Accesso (IOS-090); al primo avvio, senza token, l'app apre
      direttamente quella.

### IOS-010 · Aspetto e formati condivisi

Stato: pianificato (#23) · Parità: SET-002, SET-003, SET-010 · Mockup: tavola 01

Le preferenze sono una per tutti i dispositivi (decisione di
settings.md): l'app le legge da `GET /preferences` all'avvio e le applica.

Accettazione:

- [ ] Sfondo: la sfumatura scelta o l'immagine caricata
      (`/preferences/background`), scurita come sul sito.
- [ ] Vetro `leggero`, `medio`, `intenso`: cambia il velo delle card
      (4%, 6%, 10%) e l'intensità del bordo di luce. Niente sfocatura,
      come in IOS-003.
- [ ] Densità `comoda` o `compatta`: padding delle card 20 o 14 pt,
      spazio fra le card 14 o 10 pt.
- [ ] Unità di peso ed energia e fuso orario come sul sito; i dati
      restano in kg e kcal.
- [ ] Finché le preferenze non arrivano valgono le ultime salvate sul
      telefono, poi i predefiniti: niente sfarfallio all'avvio.

### IOS-011 · Notifiche locali

Stato: pianificato (#24) · Solo iOS · Mockup: tavole 27, 28

Con SideStore e un Apple ID gratuito le notifiche push non ci sono: le
notifiche le programma l'app sul telefono (`UNUserNotificationCenter`),
a partire dai dati letti dall'API. Servono a IOS-041 e IOS-065.

Accettazione:

- [ ] Il permesso si chiede la prima volta che si accende una notifica in
      Impostazioni › Notifiche, mai all'avvio.
- [ ] Impostazioni › Notifiche ha un interruttore per gruppo: `Pasti`,
      `Acqua`, `Scadenze documenti`. Spento il permesso di iOS, lo dice
      con il link alle impostazioni di sistema.
- [ ] Le notifiche si ricalcolano a ogni apertura dell'app e con
      l'aggiornamento in background di iOS (`BGAppRefreshTask`), quando
      iOS lo concede: se l'app non si apre per giorni restano quelle già
      programmate.
- [ ] I testi seguono lo stile: brevi, senza punti esclamativi, con `·`.
- [ ] La logica che sceglie quali notifiche programmare sta in Ron1nKit,
      con test su Linux.

### IOS-012 · Stati comuni delle schermate

Stato: pianificato (#25) · Parità: skeleton ed errori dei widget del sito

Accettazione:

- [ ] Primo caricamento: skeleton delle card, senza spinner a schermo
      intero.
- [ ] Trascinando in basso si ricarica la schermata.
- [ ] Errore: la card o la sezione mostra il titolo e il codice in
      monospazio (IOS-002), senza bloccare le altre sezioni.
- [ ] Modulo spento (404 `module_disabled`): la pagina dice `Modulo
  spento` con il link a Impostazioni › Moduli.
- [ ] Torrent e Server si aggiornano ogni 5 secondi solo con l'app in
      primo piano e la schermata visibile.
- [ ] Le azioni che cambiano dati mostrano l'esito con un toast in basso,
      sopra la TabBar (`Salvato`, `Copiato`, `Non salvato · Riprova`).
