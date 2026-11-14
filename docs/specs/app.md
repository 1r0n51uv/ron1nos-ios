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

Stato: sostituito da IOS-019 (il token non c'è più)

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

Stato: fatto (#64) · Scelta del proprietario il 2026-10-26 · Mockup: tavole 01, 25, 29

Accettazione:

- [x] In basso la TabBar nativa di iOS 26 (`TabView`), in Liquid Glass
      di sistema: flottante, staccata dai bordi, rifrange il contenuto
      che le scorre sotto. Richiesta del proprietario il 2026-10-26.
      Da IOS-015 la barra di sistema è nascosta e al suo posto c'è la
      pillola di vetro; voci e comportamento restano questi.
- [x] 5 voci: `Home`, `Dieta`, `Palestra`, `Documenti`, `Altro`, con
      icona e nome. La voce attiva è tinta di rosso (`#FF2A2A`), l'unico
      accento della barra.
- [x] Scorrendo in basso la barra si riduce
      (`tabBarMinimizeBehavior(.onScrollDown)`) e torna intera scorrendo
      in su: lascia spazio ai contenuti. Tolto con IOS-015: la pillola
      resta sempre intera.
- [x] Barre di navigazione, fogli e menu usano lo stesso Liquid Glass di
      sistema. Le card restano col velo di IOS-003: il vetro vero sta solo
      sui controlli che galleggiano sopra i contenuti.
- [x] Su iOS prima della 26 la TabBar standard, senza adattamenti.
- [x] `Altro` apre un elenco con `Torrent`, `Server`, `Impostazioni` e i
      moduli che non stanno nelle prime quattro voci.
- [x] L'ordine dei moduli segue Impostazioni › Navigazione del sito
      (SET-006): i primi tre moduli dopo Dashboard prendono le voci 2…4,
      gli altri finiscono in `Altro`. Home resta prima, `Altro` ultima.
- [x] Un modulo spento (SET-005) sparisce dalla TabBar e da `Altro`.
- [x] Ogni scheda tiene la sua pila di navigazione; toccare la voce già
      attiva torna alla radice.
- [x] La schermata di Accesso (IOS-004, IOS-005) passa in Impostazioni ›
      Accesso (IOS-090); al primo avvio, senza token, l'app apre
      direttamente quella.

### IOS-010 · Aspetto e formati condivisi

Stato: fatto (#65) · Parità: SET-002, SET-003, SET-010 · Mockup: tavola 01

Le preferenze sono una per tutti i dispositivi (decisione di
settings.md): l'app le legge da `GET /preferences` all'avvio e le applica.

Accettazione:

- [x] Sfondo: la sfumatura scelta o l'immagine caricata
      (`/preferences/background`), scurita come sul sito.
- [x] Vetro `leggero`, `medio`, `intenso`: cambia il velo delle card
      (4%, 6%, 10%) e l'intensità del bordo di luce. Niente sfocatura,
      come in IOS-003.
- [x] Densità `comoda` o `compatta`: padding delle card 20 o 14 pt,
      spazio fra le card 14 o 10 pt.
- [x] Unità di peso ed energia e fuso orario come sul sito; i dati
      restano in kg e kcal.
- [x] Finché le preferenze non arrivano valgono le ultime salvate sul
      telefono, poi i predefiniti: niente sfarfallio all'avvio.

### IOS-011 · Notifiche locali

Stato: fatto (#67) · Solo iOS · Mockup: tavole 27, 28

Con SideStore e un Apple ID gratuito le notifiche push non ci sono: le
notifiche le programma l'app sul telefono (`UNUserNotificationCenter`),
a partire dai dati letti dall'API. Servono a IOS-041 e IOS-065.

Accettazione:

- [x] Il permesso si chiede la prima volta che si accende una notifica in
      Impostazioni › Notifiche, mai all'avvio.
- [x] Impostazioni › Notifiche ha un interruttore per gruppo: `Pasti`,
      `Acqua`, `Scadenze documenti`. Spento il permesso di iOS, lo dice
      con il link alle impostazioni di sistema.
- [x] Le notifiche si ricalcolano a ogni apertura dell'app e con
      l'aggiornamento in background di iOS (`BGAppRefreshTask`), quando
      iOS lo concede: se l'app non si apre per giorni restano quelle già
      programmate.
- [x] I testi seguono lo stile: brevi, senza punti esclamativi, con `·`.
- [x] La logica che sceglie quali notifiche programmare sta in Ron1nKit,
      con test su Linux.

### IOS-012 · Stati comuni delle schermate

Stato: fatto (#66) · Parità: skeleton ed errori dei widget del sito

Accettazione:

- [x] Primo caricamento: skeleton delle card, senza spinner a schermo
      intero.
- [x] Trascinando in basso si ricarica la schermata.
- [x] Errore: la card o la sezione mostra il titolo e il codice in
      monospazio (IOS-002), senza bloccare le altre sezioni.
- [x] Modulo spento (404 `module_disabled`): la pagina dice `Modulo
  spento` con il link a Impostazioni › Moduli.
- [x] Torrent e Server si aggiornano ogni 5 secondi solo con l'app in
      primo piano e la schermata visibile.
- [x] Le azioni che cambiano dati mostrano l'esito con un toast in basso,
      sopra la TabBar (`Salvato`, `Copiato`, `Non salvato · Riprova`).

### IOS-013 · Build dell'interfaccia in CI

Stato: fatto (#63) · Origine: implementazione di IOS-009…094

Su Linux `Sources/Ron1nOS` compila vuoto, quindi un errore nelle schermate
SwiftUI si vedeva solo nella build sul server, dopo il merge. Con decine di
schermate nuove serve un controllo prima.

Accettazione:

- [x] La CI ha un job `interfaccia` che compila il target `Ron1nOS` per iOS
      (`xcodebuild`, destinazione generica, senza firma) su un runner
      macOS di GitHub, gratuito per i repository pubblici.
- [x] Solo un controllo: niente IPA, niente firma, niente `.xcodeproj`. La
      build vera resta quella del server (IOSB).

### IOS-014 · Contrasto e rosso come segnale

Stato: fatto (#108) · Origine: revisione con la skill `apple-design` del
2026-10-28, richiesta del proprietario

La revisione ha trovato il rosso del marchio (`#FF2A2A`) usato per testi
piccoli, dove sul velo delle card sopra l'alone dello sfondo `brace` scende
a 2,8:1, e usato anche per cose che non sono segnali (record, voce
spuntata, settimana in corso). Il tema resta solo scuro: è la scelta di
ron1nOS.

Accettazione:

- [x] I colori stanno in `Palette` di Ron1nKit, con i test di contrasto
      WCAG che girano su Linux. `Stile` li legge da lì.
- [x] I testi e i simboli rossi usano `brandTesto` (`#FF8A8A`, lo stesso
      `--brand-text` del sito): almeno 4,5:1 anche sul fondo peggiore,
      una pillola dentro una card sopra l'alone `brace`. Il `brand` resta
      per barre, bordi, punti, interruttori e la voce attiva della TabBar.
- [x] Il testo secondario passa dal 55% al 60% di bianco: sul fondo
      peggiore arriva a 4,9:1 (prima 4,4:1).
- [x] Il rosso è solo un segnale (errore, scaduto, oltre l'obiettivo,
      in errore). Diventano bianchi: record degli esercizi e la sigla
      `RECORD`, la settimana in corso nel grafico della Palestra, la linea
      del grafico di un esercizio, gli integratori presi, le voci della
      spesa spuntate, i file scelti di un torrent, lo sfondo scelto nelle
      Impostazioni. `questo iPhone` nelle sessioni diventa tenue.

### IOS-015 · TabBar a pillola in vetro

Stato: fatto (#109) · Richiesta del proprietario il 2026-10-28

La TabBar diventa una pillola flottante con l'effetto vetro di iOS 26.
Cambia solo la forma: voci e comportamento restano quelli di IOS-009.

Accettazione:

- [x] La barra di sistema della `TabView` è nascosta; al suo posto una
      pillola staccata dai bordi (16 pt) e dal fondo, alta 62 pt, larga al
      massimo 440 pt e centrata.
- [x] Su iOS 26 la pillola è Liquid Glass (`glassEffect`, interattivo);
      prima della 26 materiale sfocato con il bordo di luce. Con "Riduci
      trasparenza" diventa un grigio pieno.
- [x] Le stesse 5 voci, con icona e nome. La voce attiva ha una bolla di
      vetro e icona e nome in `brandTesto` (IOS-014); le altre sono
      bianche. La bolla scorre da una voce all'altra, senza animazione con
      "Riduci movimento". Ogni cambio di voce dà un tocco aptico leggero.
- [x] Ogni voce misura almeno 44×44 pt anche sullo schermo più stretto
      (test in Ron1nKit, `BarraSchede`).
- [x] Accessibilità: ogni voce ha il nome come etichetta e lo stato
      selezionato; tenendola premuta con il testo grande si ingrandisce
      (Large Content Viewer).
- [x] I contenuti di ogni scheda e delle pagine sotto lasciano in fondo lo
      spazio della pillola, che non copre l'ultima riga. Il toast sta
      sopra la pillola. Con la tastiera aperta la pillola resta sotto.
- [x] Non si riduce più scorrendo (`tabBarMinimizeBehavior` vale solo per
      la barra di sistema).

### IOS-016 · CHANGELOG e note su SideStore

Stato: fatto (#111) · Richiesta del proprietario il 2026-10-28

Ogni versione dice cosa cambia, nel repo e in SideStore.

Accettazione:

- [x] `CHANGELOG.md` con una sezione per versione, `## 0.1.N · AAAA-MM-GG`,
      la più recente in alto, ricostruito dalla storia di main: N è il
      numero di commit di main a quel merge, come lo calcola il builder
      (IOSB-003 di ron1n).
- [x] Ogni PR aggiunge in cima la sua sezione, con N = commit di main + 1,
      e righe brevi su cosa cambia per chi usa l'app.
- [x] Il builder copia la sezione nelle note della versione su SideStore
      (IOSB-005 di ron1n); se la versione non c'è, mostra i titoli dei
      commit.


### IOS-019 · Login con la password e Face ID

Stato: da fare · Parità: AUTH-001, AUTH-002, AUTH-004

L'app entra nel login di ron1nOS come il sito: con la password della
dashboard (`POST /auth/login`), non più con un token creato a mano. Il
token dell'app (IOS-005) sparisce.

Accettazione:

- [ ] In Accesso si scrive la password e si tocca `Entra`. La sessione
      (cookie `ron1nos_session`, 30 giorni) sta nel Portachiavi e va in
      ogni richiesta insieme agli header di Access. Password errata,
      login spento e troppi tentativi (429) hanno un messaggio loro.
- [ ] `Ricorda con Face ID` (acceso di default) tiene la password nel
      Portachiavi dietro Face ID, con il codice del telefono come riserva.
      Quando la sessione scade o viene chiusa, un 401 la rifà da sola:
      Face ID compare una volta sola anche con più richieste insieme, e
      dopo un tentativo andato male non si richiede per 30 secondi.
- [ ] `Esci` chiude la sessione sul server e toglie sessione e password dal
      telefono, senza chiedere Face ID.
- [ ] La riga Login dice: sessione valida, spento, da accedere, sessione
      scaduta. Un 401 diventa "Manca l'accesso a ron1nOS" o "Sessione
      ron1nOS scaduta".
- [ ] Impostazioni › Account mostra anche la sessione di questo iPhone,
      segnata, senza `Chiudi`; `Chiudi le altre` usa
      `DELETE /auth/sessions/others`.
- [ ] Spariscono la voce Impostazioni › App iOS, i token e il loro
      salvataggio nel Portachiavi.
- [ ] Test unitari su Linux per il cookie, l'accesso (200, 401, 409, 429),
      il rinnovo sul 401 e la pausa dopo un tentativo fallito.

### IOS-043 · Restyle: una tinta per modulo, più compatta, in movimento

Stato: fatto

L'app resta scura e di vetro, ma ogni area ha la sua tinta e le card si
stringono: più cose in una schermata, riconoscibili a colpo d'occhio. Il
rosso del marchio resta per il marchio e gli allarmi (IOS-014 vale ancora per
i testi rossi). Prende il posto del "solo rosso come segnale".

Accettazione:

- [x] Tinte in `Palette` e `Modulo` di Ron1nKit: Nutrizione verde
      `#34D399`, Server azzurro `#38BDF8`, Torrent ambra `#FBBF24`,
      Impostazioni ardesia `#A5B4CB`; macro azzurro, giallo e rosa. Test su
      Linux: ogni tinta regge 4,5:1 sul fondo peggiore e il simbolo nero
      sopra di sé regge 4,5:1.
- [x] La voce attiva della barra, lo sfondo con gli aloni e i controlli della
      pagina prendono la tinta del modulo.
- [x] Componenti condivisi: tessera con simbolo, intestazione di card,
      anello, barra a colori, dato, stato vuoto con azione, spunta del pasto.
      Card a 20, tessere e foto a 12, azioni a capsula, spazi da 4.
- [x] Home compatta: il pasto di adesso con la foto in grande e la spunta,
      Server (tre anelli) e Download affiancati, poi i torrent attivi.
- [x] Nutrizione: Piani, Ricette e Spesa sempre in vista sotto la barra dei
      giorni, non più in un menu; anello delle kcal con i macro a colori; un
      simbolo per ogni pasto. Ricette in griglia di foto.
- [x] Spesa e ricette vuote mostrano l'azione che le riempie (genera,
      importa da YAZIO); Modifica della ricetta è un pulsante.
- [x] Torrent: anelli di avanzamento con il simbolo dello stato; pausa e
      ripresa piene nel dettaglio.
- [x] Movimento: comparsa a cascata delle card, anelli e barre che si
      riempiono con una molla, tocchi che si stringono, spunta con rimbalzo
      e vibrazione, zoom dalla foto alla ricetta (iOS 18), copertina che si
      allunga, sfondo che si sposta piano. Con Riduci movimento restano le
      sole dissolvenze.
- [x] L'accesso chiede il codice a 4 cifre della dashboard.
- [x] Icona: il sigillo a tutto campo, senza cornice, dentro la maschera di
      iOS.

### IOS-044 · Tatto, caricamenti e azioni a portata di pollice

Stato: fatto

L'app si usa con una mano: i pulsanti in alto costringevano a stirare il
pollice, i tocchi non si sentivano e i dati comparivano di colpo.

Accettazione:

- [x] Barra delle schede fluttuante, una capsula di vetro liquido (vetro di
      sistema da iOS 26, materiale sottile prima) con bordo di luce e
      ombra; la scheda attiva ha una pillola nella sua tinta che scivola tra
      le voci. Toccare di nuovo la scheda attiva torna alla prima pagina.
- [x] Le azioni delle pagine stanno in una barra di vetro in basso, sopra
      quella delle schede: Nutrizione (Oggi, Piani, Ricette, Spesa,
      calendario), Ricette (Nuova, Importa), ricetta (Modifica, Elimina),
      Spesa (Aggiungi, Genera, Togli le spuntate), Piani (Nuovo), Torrent
      (Aggiungi, Scegli e le azioni sulla selezione), dettaglio del torrent
      (Pausa o Riprendi, Elimina). Nei fogli la conferma è un pulsante pieno
      in basso; Annulla resta in alto.
- [x] Ogni pulsante sotto il dito si stringe, si schiarisce e dà un colpetto
      leggero; cambiare scheda o giorno dà il tic della selezione.
- [x] Caricamenti visibili: scheletri con un riflesso che scorre, la
      pillola Aggiorno nella Home, lo spinner dentro la spunta del pasto e
      dentro i pulsanti che aspettano il server. I dati nuovi entrano con una
      molla e i numeri scorrono, invece di comparire di colpo.
- [x] Riduci movimento: niente riflessi né spostamenti, restano le
      dissolvenze.

### IOS-100 · Riscrittura: Home, barra e accesso

Stato: in corso

L'app si riscrive da zero con tre cose: la Home (IOS-025), la barra con le
icone di Home e Impostazioni, e le Impostazioni con il solo accesso
(IOS-090). Stessa app: bundle, nome e source di SideStore non cambiano.

Accettazione:

- [x] Il ciclo di vita del login sta in un solo modulo di Ron1nKit,
      `Autenticazione` (`entra`, `esci`, `stato`, `client`), con test su
      Linux: login, logout, Face ID sì o no, uscita senza rinnovo e
      rinnovo sul 401.
- [ ] La barra ha due voci, Home e Impostazioni. Niente schede di moduli,
      niente `Altro`.
- [ ] Escono dall'app i modelli, le viste e i test di Dieta, Palestra,
      Documenti, Torrent (wizard, `.torrent` e magnet), notifiche, Salute,
      preferenze del sito e layout della Home.
- [ ] `Info.plist` perde i tipi di documento, lo schema `magnet`, la
      fotocamera e i task in background.
- [ ] L'app ha l'icona del sigillo con la katana (`Icon.png`, `iconPath`
      in `xtool.yml`).
- [ ] Prima di togliere il codice, il tag `pre-riscrittura` su `main`.
