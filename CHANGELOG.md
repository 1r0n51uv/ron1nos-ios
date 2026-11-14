# Changelog

Cosa cambia in ogni versione dell'app, la più recente in alto. La versione è
`0.1.N`, con N il numero di commit di main: la calcola il builder del server
a ogni merge (IOSB-003 di ron1n). La sezione della versione finisce nelle
note di SideStore (IOSB-005).

Ogni PR aggiunge in cima la sua sezione `## 0.1.N · AAAA-MM-GG`, con N =
commit di main + 1 (il merge squash ne aggiunge uno), e righe brevi su cosa
cambia per chi usa l'app. Se il numero non torna, SideStore mostra i titoli
dei commit.

## 0.1.79 · 2026-11-14

- I pulsanti delle pagine (Nutrizione, Torrent, Spesa, Ricette, Piani) tornano in alto, sotto il titolo: in basso li copriva la barra delle schede. Nei fogli Salva e Genera restano in basso

## 0.1.78 · 2026-11-14

- Barra delle schede nuova: una capsula di vetro che galleggia in basso, con la scheda attiva evidenziata nel suo colore. Toccata di nuovo, torna all'inizio
- I pulsanti delle pagine sono scesi in basso, a portata di pollice: Spesa, Ricette, Piani, Torrent, la ricetta e il dettaglio del torrent. Nei fogli, Salva e Genera sono in basso
- Ogni tocco si vede e si sente: il pulsante si stringe e il telefono dà un colpetto
- I caricamenti si vedono: scheletri animati, la pillola Aggiorno nella Home e lo spinner nei pulsanti che aspettano il server. I dati entrano con un'animazione

## 0.1.77 · 2026-11-14

- Nuovo aspetto: ogni area ha il suo colore (Nutrizione verde, Download ambra, Server azzurro), icone su tessere colorate e schermate più compatte
- Home: il pasto di adesso con la foto in grande e la spunta, Server e Download affiancati
- Nutrizione: Piani, Ricette e Spesa sempre in vista sotto i giorni; anello delle kcal con i macro a colori
- Ricette in griglia con le foto; la ricetta si apre con uno zoom e la copertina si allunga tirando giù
- Torrent con gli anelli di avanzamento; Pausa e Riprendi in evidenza nel dettaglio
- Animazioni: card che compaiono in sequenza, anelli e barre che si riempiono, spunta con vibrazione
- L'accesso chiede il codice a 4 cifre di ron1nOS
- Icona nuova, che iOS non taglia più agli angoli

## 0.1.76 · 2026-11-13

- In Impostazioni › Notifiche, sotto gli avvisi dei download, c'è «Prova Mangiato e Rimanda»: dopo 10 secondi arriva un promemoria di prova con i due pulsanti (esci dall'app e tienilo premuto). «Mangiato» e «Rimanda» rispondono con un avviso, senza toccare nessun pasto vero.
- I pulsanti dei promemoria sono pronti già all'avvio dell'app, anche quando iOS la apre solo per un pulsante.
- La foto del pasto sta in cima alla card della Home, in una fascia larga.
- Le Impostazioni sono divise per categoria: Accesso, Pasti, Notifiche e Informazioni, ognuna con la sua pagina.

## 0.1.75 · 2026-11-12

- Una ricetta senza foto ha il pulsante «Genera foto»: l'agente Image Chef del dojo prepara un'immagine del piatto in circa un minuto, e puoi uscire dalla ricetta mentre lavora. Se non riesce, vedi il motivo e puoi riprovare.

## 0.1.74 · 2026-11-12

- I promemoria dei pasti hanno `Rimanda` di 15 minuti, e il tempo lo scegli nelle Impostazioni, sotto gli orari dei pasti.
- I messaggi dei promemoria cambiano da un giorno all'altro, con il nome del piatto.
- Ogni ricetta può avere delle azioni collegate, per esempio «scongela il pesce» il giorno prima alle 21:00: le aggiungi, le spegni o le togli dalla ricetta e arrivano come avviso.
- Nelle card dei pasti il pulsante `Mangiato` è un'icona a destra: le card sono più basse e la foto del piatto resta accanto al nome.

## 0.1.73 · 2026-11-11

- La pagina Nutrizione mostra un giorno alla volta, oggi all'apertura: con uno swipe a sinistra vai al giorno dopo, a destra a quello prima.
- In alto una barra con i giorni della settimana, con un puntino dove c'è qualcosa in programma, e un calendario per scegliere una data qualsiasi. `Oggi` ti riporta al giorno corrente.
- Nelle Ricette c'è una barra di ricerca: cerchi per nome o per ingrediente.

## 0.1.72 · 2026-11-11

- Le ricette dei preferiti di YAZIO hanno la loro foto: si vede in cima alla ricetta e in miniatura nell'elenco, nella scelta della ricetta di un piano, nel giorno e nella card del pasto in Home.
- Il procedimento delle ricette di YAZIO arriva già scritto, e l'import porta anche i preferiti (non solo le ricette create da te). Serve l'API di ron1nOS aggiornata.

## 0.1.71 · 2026-11-11

- Torna la Nutrizione, ora per programmare: scegli un piano (una settimana tipo di ricette) e programmalo da un giorno fino a una data. Aggiungi pasti solo dal piano, niente registrazione libera.
- Dalla Home spunti il pasto dell'ora (Mangiato), con l'obiettivo del giorno e quanto manca. La pagina Nutrizione mostra la settimana, il giorno e la ricetta con ingredienti, procedimento e note.
- Ricette da YAZIO (preferiti) o create nell'app, con ingredienti del catalogo YAZIO e procedimento a passi. C'è anche la lista della spesa dai pasti in programma.
- Un promemoria all'ora di ogni pasto, con Mangiato e Rimanda; gli orari si scelgono in Impostazioni.
- Serve l'API di ron1nOS aggiornata (procedimento, programmazione e settimana).

## 0.1.70 · 2026-11-11

- Gli avvisi dei download si vedono anche con l'app aperta, e toccandoli si apre la pagina Torrent. Prima iOS li nascondeva finché l'app era in primo piano.
- In Impostazioni c'è il pannello Avvisi: permesso di iOS, avvisi programmati e un pulsante Prova che ne manda uno fra 10 secondi.

## 0.1.69 · 2026-11-10

- Torna la pagina Torrent, nella barra in basso: i torrent in sezioni (In download, In coda, In seed, Fermi, Errori) con la velocità totale.
- Si può mettere in pausa, riprendere o eliminare un torrent: tieni premuta una riga, oppure tocca Scegli per farlo su più torrent insieme. Eliminando si sceglie se tenere i file.
- Un tocco su un torrent apre il dettaglio, con dimensione, rapporto, cartella e i file con l'avanzamento.
- Un avviso quando un download finisce, anche con l'app chiusa (iOS decide ogni quanto controllare).
- `Aggiungi` sta in basso, dove arriva il pollice; i pulsanti sono più grandi e le azioni riuscite danno una vibrazione. Con zero torrent la pagina dice cosa fare.
- Si aggiunge un torrent col wizard, da un file .torrent o un link magnet aperto da fuori, o dal magnet che hai copiato.

## 0.1.68 · 2026-11-10

- L'app è stata riscritta da zero, più semplice: una Home con lo stato del server e dei download, e le Impostazioni con il solo accesso.
- La barra in basso ha due icone, Home e Impostazioni. Dieta, Palestra, Documenti e Torrent escono dall'app, per ora.
- Aprire un file torrent o un link magnet dall'app non c'è più, per ora.
- Chi era già entrato resta entrato: la password e Face ID non cambiano.
- L'app ha la sua icona: il sigillo con la katana, lo stesso della dashboard.

## 0.1.67 · 2026-11-09

- Si entra in ron1nOS con la password della dashboard, come sul sito: niente più token da creare e incollare (IOS-019).
- Con "Ricorda con Face ID" la password resta nel Portachiavi e, quando la sessione scade, l'app la rifà da sola con Face ID.
- Accesso ha il pulsante "Esci", che chiude la sessione e toglie la password dal telefono.
- Impostazioni › Account mostra anche questo iPhone tra le sessioni; "Chiudi le altre" lo lascia aperto.
- Impostazioni › App iOS non c'è più. Dopo l'aggiornamento serve entrare una volta con la password.

## 0.1.66 · 2026-11-09

- L'app torna a installarsi: dal 28 ottobre le versioni non uscivano più perché la build falliva su Foto e Anteprima dei documenti (IOS-018).
- Dentro ci sono anche le correzioni della 0.1.63: meno errori "URLError -999" e un nuovo tentativo sul 401.

## 0.1.63 · 2026-11-09

- Meno errori "URLError -999" cambiando pagina o aggiornando: la richiesta non si interrompe più a metà, e se iOS la annulla si riprova da sola.
- Se il server risponde un 401 passeggero, l'app riprova una volta prima di dire "Token ron1nOS rifiutato".
- Le richieste riusano la stessa connessione: pagine più veloci.

## 0.1.62 · 2026-10-28

- Le novità di ogni versione si leggono in SideStore, sotto l'aggiornamento (IOS-016, [#111](https://github.com/1r0n51uv/ron1nos-ios/pull/111)).
- Questo CHANGELOG, con tutte le versioni uscite finora.

## 0.1.61 · 2026-10-28

- La barra delle schede diventa una pillola di vetro flottante, staccata dai bordi, con le stesse 5 voci (IOS-015, [#109](https://github.com/1r0n51uv/ron1nos-ios/pull/109)).
- La voce attiva ha una bolla di vetro; cambiando scheda c'è un tocco aptico leggero.
- La pillola non si riduce più scorrendo.

## 0.1.60 · 2026-10-28

- Testi rossi più chiari e leggibili anche sul vetro, testo grigio un po' più chiaro (IOS-014, [#108](https://github.com/1r0n51uv/ron1nos-ios/pull/108)).
- Il rosso resta solo per errori e avvisi: record, spesa spuntata, integratori presi e settimana in corso tornano bianchi.

## 0.1.59 · 2026-10-28

- Skill apple-design nel repo ([#105](https://github.com/1r0n51uv/ron1nos-ios/pull/105))

## 0.1.58 · 2026-10-27

- Notifiche e Salute nelle Impostazioni (IOS-094) ([#88](https://github.com/1r0n51uv/ron1nos-ios/pull/88))

## 0.1.57 · 2026-10-27

- Integrazioni, Backup, Informazioni (IOS-093) ([#103](https://github.com/1r0n51uv/ron1nos-ios/pull/103))

## 0.1.56 · 2026-10-27

- Account e App iOS nelle Impostazioni (IOS-092) ([#102](https://github.com/1r0n51uv/ron1nos-ios/pull/102))

## 0.1.55 · 2026-10-27

- Aspetto, Dashboard, Moduli, Navigazione, Formati (IOS-091) ([#101](https://github.com/1r0n51uv/ron1nos-ios/pull/101))

## 0.1.54 · 2026-10-27

- Sezioni delle Impostazioni e Accesso (IOS-090) ([#100](https://github.com/1r0n51uv/ron1nos-ios/pull/100))

## 0.1.53 · 2026-10-27

- Pagina Server (IOS-080) ([#99](https://github.com/1r0n51uv/ron1nos-ios/pull/99))

## 0.1.52 · 2026-10-27

- Aggiungere un torrent (IOS-071) ([#82](https://github.com/1r0n51uv/ron1nos-ios/pull/82))

## 0.1.51 · 2026-10-27

- Pagina Torrent (IOS-070) ([#98](https://github.com/1r0n51uv/ron1nos-ios/pull/98))

## 0.1.50 · 2026-10-27

- Avvisi di scadenza dei documenti (IOS-065) ([#97](https://github.com/1r0n51uv/ron1nos-ios/pull/97))

## 0.1.49 · 2026-10-27

- Face ID per i Documenti (IOS-064) ([#96](https://github.com/1r0n51uv/ron1nos-ios/pull/96))

## 0.1.48 · 2026-10-27

- Tipi di documento personalizzati (IOS-063) ([#95](https://github.com/1r0n51uv/ron1nos-ios/pull/95))

## 0.1.47 · 2026-10-27

- Nuovo documento e modifica (IOS-062) ([#94](https://github.com/1r0n51uv/ron1nos-ios/pull/94))

## 0.1.46 · 2026-10-27

- Dettaglio di un documento e copia dei campi (IOS-061) ([#93](https://github.com/1r0n51uv/ron1nos-ios/pull/93))

## 0.1.45 · 2026-10-27

- Elenco dei documenti (IOS-060) ([#92](https://github.com/1r0n51uv/ron1nos-ios/pull/92))

## 0.1.44 · 2026-10-27

- Volume per gruppo muscolare (IOS-055) ([#91](https://github.com/1r0n51uv/ron1nos-ios/pull/91))

## 0.1.43 · 2026-10-27

- Gruppo muscolare e immagine di un esercizio (IOS-054) ([#90](https://github.com/1r0n51uv/ron1nos-ios/pull/90))

## 0.1.42 · 2026-10-27

- Esercizi e record (IOS-053) ([#89](https://github.com/1r0n51uv/ron1nos-ios/pull/89))

## 0.1.41 · 2026-10-27

- Storico e dettaglio di una sessione (IOS-052) ([#87](https://github.com/1r0n51uv/ron1nos-ios/pull/87))

## 0.1.40 · 2026-10-27

- Import del CSV di Liftin' (IOS-051) ([#86](https://github.com/1r0n51uv/ron1nos-ios/pull/86))

## 0.1.39 · 2026-10-27

- Pagina Palestra (IOS-050) ([#85](https://github.com/1r0n51uv/ron1nos-ios/pull/85))

## 0.1.38 · 2026-10-27

- Promemoria dei pasti e dell'acqua (IOS-041) ([#84](https://github.com/1r0n51uv/ron1nos-ios/pull/84))

## 0.1.37 · 2026-10-27

- Obiettivo e YAZIO nelle Impostazioni (IOS-039) ([#83](https://github.com/1r0n51uv/ron1nos-ios/pull/83))

## 0.1.36 · 2026-10-27

- Andamento della Dieta (IOS-038) ([#81](https://github.com/1r0n51uv/ron1nos-ios/pull/81))

## 0.1.35 · 2026-10-27

- Lista della spesa (IOS-036) ([#80](https://github.com/1r0n51uv/ron1nos-ios/pull/80))

## 0.1.34 · 2026-10-27

- Template settimanale (IOS-035) ([#79](https://github.com/1r0n51uv/ron1nos-ios/pull/79))

## 0.1.33 · 2026-10-27

- Acqua, caffeina e integratori del giorno (IOS-037) ([#78](https://github.com/1r0n51uv/ron1nos-ios/pull/78))

## 0.1.32 · 2026-10-27

- Ricette e pianificazione (IOS-034) ([#77](https://github.com/1r0n51uv/ron1nos-ios/pull/77))

## 0.1.31 · 2026-10-27

- Codice a barre con la fotocamera (IOS-032) ([#76](https://github.com/1r0n51uv/ron1nos-ios/pull/76))

## 0.1.30 · 2026-10-27

- Alimenti personali (IOS-033) ([#75](https://github.com/1r0n51uv/ron1nos-ios/pull/75))

## 0.1.29 · 2026-10-27

- Registrare e correggere un pasto (IOS-031) ([#74](https://github.com/1r0n51uv/ron1nos-ios/pull/74))

## 0.1.25 · 2026-10-27

- Pagina della Dieta con il giorno (IOS-030) ([#73](https://github.com/1r0n51uv/ron1nos-ios/pull/73))

## 0.1.24 · 2026-10-27

- Opzioni del widget della Home (IOS-023) ([#72](https://github.com/1r0n51uv/ron1nos-ios/pull/72))

## 0.1.23 · 2026-10-27

- Modalità Modifica della Home (IOS-022) ([#71](https://github.com/1r0n51uv/ron1nos-ios/pull/71))

## 0.1.22 · 2026-10-27

- Salvataggio del layout della Home (IOS-024) ([#70](https://github.com/1r0n51uv/ron1nos-ios/pull/70))

## 0.1.21 · 2026-10-27

- Catalogo dei widget della Home (IOS-021) ([#69](https://github.com/1r0n51uv/ron1nos-ios/pull/69))

## 0.1.20 · 2026-10-27

- Home con i widget (IOS-020) ([#68](https://github.com/1r0n51uv/ron1nos-ios/pull/68))

## 0.1.19 · 2026-10-27

- Notifiche locali (IOS-011) ([#67](https://github.com/1r0n51uv/ron1nos-ios/pull/67))

## 0.1.18 · 2026-10-27

- Stati comuni delle schermate (IOS-012) ([#66](https://github.com/1r0n51uv/ron1nos-ios/pull/66))

## 0.1.17 · 2026-10-27

- Aspetto e formati condivisi con il sito (IOS-010) ([#65](https://github.com/1r0n51uv/ron1nos-ios/pull/65))

## 0.1.16 · 2026-10-27

- Navigazione a schede (IOS-009) ([#64](https://github.com/1r0n51uv/ron1nos-ios/pull/64))

## 0.1.15 · 2026-10-27

- CI: build dell'interfaccia SwiftUI su macOS (IOS-013) ([#63](https://github.com/1r0n51uv/ron1nos-ios/pull/63))

## 0.1.14 · 2026-10-27

- Specifiche dell'app iOS: parità con il sito (IOS-009…094) ([#21](https://github.com/1r0n51uv/ron1nos-ios/pull/21))

## 0.1.13 · 2026-10-24

- README: aggiornamenti da SideStore e versione dal builder ([#20](https://github.com/1r0n51uv/ron1nos-ios/pull/20))

## 0.1.12 · 2026-10-24

- IOS-008 fatto ([#19](https://github.com/1r0n51uv/ron1nos-ios/pull/19))

## 0.1.11 · 2026-10-24

- Card Server nella home (IOS-008) ([#18](https://github.com/1r0n51uv/ron1nos-ios/pull/18))

## 0.1.10 · 2026-10-24

- Card Torrent nella home (IOS-007) ([#17](https://github.com/1r0n51uv/ron1nos-ios/pull/17))

## 0.1.9 · 2026-10-24

- Card Dieta nella home (IOS-006) ([#14](https://github.com/1r0n51uv/ron1nos-ios/pull/14))

## 0.1.8 · 2026-10-24

- Token di ron1nOS nel Portachiavi (IOS-005) ([#12](https://github.com/1r0n51uv/ron1nos-ios/pull/12))

## 0.1.7 · 2026-10-23

- IOS-001, IOS-003 e IOS-004 fatti ([#10](https://github.com/1r0n51uv/ron1nos-ios/pull/10))

## 0.1.6 · 2026-10-23

- Accesso con Cloudflare Access (IOS-004) ([#9](https://github.com/1r0n51uv/ron1nos-ios/pull/9))

## 0.1.5 · 2026-10-23

- Card della home trasparenti (IOS-003) ([#7](https://github.com/1r0n51uv/ron1nos-ios/pull/7))

## 0.1.4 · 2026-10-23

- Diagnosi degli errori di rete (IOS-002) ([#6](https://github.com/1r0n51uv/ron1nos-ios/pull/6))

## 0.1.3 · 2026-10-23

- App di prova: stato del server da /api/v1/health (IOS-001) ([#3](https://github.com/1r0n51uv/ron1nos-ios/pull/3))

## 0.1.2 · 2026-10-23

- Spec dell'app iOS: IOS-001 app di prova con xtool ([#1](https://github.com/1r0n51uv/ron1nos-ios/pull/1))

## 0.1.1 · 2026-10-23

- Initial commit

