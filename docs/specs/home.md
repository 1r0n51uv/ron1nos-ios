# Home

ID: `IOS-020`…`029` · Label: `mod:home` · Parità: `DASH-001`…`009`

La Home dell'app è la dashboard personalizzabile del sito, nella forma
della schermata Home di iOS: widget in una colonna o affiancati due a
due, che in modalità Modifica tremano e si spostano col dito. Il layout è
quello del dispositivo `iphone`, separato dal desktop e salvato sullo
stesso backend (DASH-007), con le stesse rotte.

Scelta del proprietario il 2026-10-26: "Come la home di iOS".

Non fa, per ora: widget nella Home di iOS fuori dall'app (WidgetKit
richiede un'estensione, da valutare con xtool), più pagine di widget.

Mockup: [canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

## Requisiti

### IOS-020 · Home con i widget

Stato: fatto (#68) · Parità: DASH-003, DASH-006 · Mockup: tavola 01

Accettazione:

- [x] La Home legge `GET /dashboard/layouts/iphone` e mostra i widget
      nell'ordine salvato, su una griglia di 4 colonne: `piccolo` occupa
      mezza riga (2×2), `medio` una riga (4×2), `grande` una riga alta
      (4×4). Due piccoli vicini stanno affiancati.
- [x] In cima la testata del sito (DASH-006) nella forma salvata:
      `completa` (data in mono, saluto, frase di stato), `una riga` o
      `nascosta`.
- [x] Toccare un widget apre la pagina del suo modulo nella sua scheda
      (per esempio il widget Dieta apre la scheda Dieta).
- [x] Senza layout salvato vale il predefinito dell'iPhone: Dieta
      grande, Palestra medio, Server e Torrent piccoli, Documenti medio.
- [x] I widget di un modulo spento non compaiono e restano nel layout
      (DASH-007).

### IOS-021 · Catalogo dei widget

Stato: fatto (#69) · Parità: DASH-001, DASH-002 · Mockup: tavola 03

Accettazione:

- [x] Gli stessi id del catalogo del sito (`nutrition.calories`,
      `server.metric`…), ognuno con le misure che ha senso avere su
      iPhone, dichiarate nel catalogo del backend per il layout `iphone`.
- [x] Primi widget: `nutrition.summary`, `nutrition.calories`,
      `nutrition.next-meal`, `nutrition.supplements`, `workout.summary`,
      `documents.summary`, `downloads.summary`, `downloads.speed`,
      `server.summary`, `server.metric`. Gli altri moduli quando sono veri.
- [x] Ogni widget legge dalla stessa rotta della pagina del suo modulo,
      senza rotte nuove.
- [x] Le card di IOS-006…008 diventano `nutrition.summary`,
      `downloads.summary` e `server.summary`.

### IOS-022 · Modalità Modifica

Stato: pianificato (#28) · Parità: DASH-004, DASH-009 · Mockup: tavola 02

Accettazione:

- [ ] Si entra con il pulsante `Modifica` in alto a destra o tenendo
      premuto un widget; si esce con `Fine`. La modalità non si ricorda.
- [ ] In Modifica i widget tremano come nella Home di iOS e hanno in alto
      a sinistra il pulsante `−` per toglierli; si trascinano per
      cambiare ordine e gli altri si spostano per fare posto.
- [ ] Toccare un widget in Modifica apre le sue opzioni (IOS-023).
- [ ] `Rimuovi` toglie subito il widget e mostra il toast `Widget rimosso
  · Annulla` per 8 secondi.
- [ ] In alto compaiono `+` (Aggiungi widget) e il menu della forma della
      testata.
- [ ] `Aggiungi widget` apre un foglio con il catalogo diviso per modulo,
      con anteprima viva e le misure scorrevoli; il widget scelto entra in
      cima.
- [ ] VoiceOver: ogni widget ha le azioni `Sposta su`, `Sposta giù`,
      `Rimuovi`, `Opzioni`.

### IOS-023 · Opzioni del widget

Stato: pianificato (#29) · Parità: DASH-005 · Mockup: tavola 04

Accettazione:

- [ ] Un foglio con l'anteprima del widget in alto e sotto: misura,
      variante `compatta`/`dettagliata` se il widget le ha, dati mostrati
      (per esempio la risorsa di `server.metric`, le macro di
      `nutrition.summary`, quanti download).
- [ ] Ogni cambio si vede subito nell'anteprima e si salva con il layout.

### IOS-024 · Salvataggio del layout

Stato: fatto (#70) · Parità: DASH-007, DASH-008

Accettazione:

- [x] L'app salva da sola con `PUT /dashboard/layouts/iphone` un secondo
      dopo l'ultima modifica. Se il backend rifiuta o non risponde
      compare `Layout non salvato · Riprova` e il layout resta quello
      sullo schermo.
- [x] `Ripristina layout predefinito` sta in Impostazioni › Dashboard
      (IOS-091), con conferma.
- [x] La logica del layout (ordine, misure, posto nella griglia di 4
      colonne, validazione prima dell'invio) sta in Ron1nKit, con test su
      Linux.
