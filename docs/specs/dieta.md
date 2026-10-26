# Dieta

ID: `IOS-030`…`049` · Label: `mod:dieta` · Parità: `NUT-001`…`024`

Il modulo Nutrizione del sito, nella scheda `Dieta`: diario dei 5 pasti,
ricerca alimenti, codice a barre con la fotocamera, ricette, piano,
template, spesa, tracker e andamento. Tutta la logica (quota, snapshot,
sincronizzazione YAZIO) resta nel backend: l'app mostra e invia, i numeri
sono gli stessi del sito.

In più, solo su iPhone: Apple Salute (NUT-018) e promemoria (NUT-019),
che le specifiche del sito rimandavano all'app.

Mockup: [canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

## Requisiti

### IOS-030 · Giorno

Stato: proposto · Parità: NUT-002, NUT-016 · Mockup: tavola 05

Accettazione:

- [ ] In alto la striscia dei giorni, scorrevole (10 indietro, 13 avanti,
      oggi selezionato); `Oggi` torna a oggi.
- [ ] Sotto, l'anello delle kcal sulla quota del giorno e tre barre per
      proteine, carboidrati e grassi, del giorno scelto.
- [ ] I 5 slot (`Colazione`, `Spuntino`, `Pranzo`, `Merenda`, `Cena`) in
      card: vuoto con `+`, pianificato con l'interruttore `Mangiato`,
      mangiato con gli alimenti e le kcal.
- [ ] Sotto gli slot i tracker (IOS-037) e i link a Ricette, Template,
      Spesa e Andamento.
- [ ] Dati da `GET /nutrition/day?date=`.

### IOS-031 · Registrare e correggere un pasto

Stato: proposto · Parità: NUT-003, NUT-004, NUT-007, NUT-023 · Mockup: tavole 06, 08

Accettazione:

- [ ] `+` su uno slot apre un foglio: campo di ricerca (da 2 caratteri),
      filtro `Solo Italia` acceso, risultati con la fonte (`OFF`, `USDA`,
      `YAZIO`, `mio`) e kcal per 100 g; in cima gli alimenti recenti.
- [ ] Scelto un alimento, i grammi si scrivono con il tastierino numerico
      e kcal e macro si aggiornano mentre si scrive; si aggiungono più
      alimenti prima di salvare.
- [ ] Lo slot proposto è quello dell'ora corrente.
- [ ] Toccare un pasto mangiato apre il dettaglio: si cambia la quantità
      di una riga, si toglie una riga scorrendo a sinistra, si aggiunge un
      alimento extra.
- [ ] Ogni riga mostra lo stato di YAZIO: inviata, in coda, errore,
      senza equivalente (NUT-023).

### IOS-032 · Codice a barre con la fotocamera

Stato: proposto · Parità: NUT-005 · Mockup: tavola 07

Accettazione:

- [ ] Nel foglio di ricerca il pulsante con l'icona del codice a barre
      apre la fotocamera (`DataScannerViewController` di VisionKit) con
      un riquadro guida; il primo EAN letto chiude la fotocamera.
- [ ] Il codice va a `GET /nutrition/foods/barcode/{code}`: trovato, si
      passa ai grammi; sconosciuto, si apre `Nuovo alimento` (IOS-033)
      con il codice già scritto.
- [ ] Senza permesso della fotocamera, il campo per scrivere il codice a
      mano e il link alle impostazioni di sistema.

### IOS-033 · Alimenti personali

Stato: proposto · Parità: NUT-006

Accettazione:

- [ ] Creare, modificare ed eliminare un alimento: nome, kcal e macro per
      100 g, marca, porzione e codice a barre facoltativi.
- [ ] L'elenco sta in Impostazioni › Moduli › Dieta, come sul sito.

### IOS-034 · Ricette e pianificazione

Stato: proposto · Parità: NUT-008, NUT-009 · Mockup: tavola 09

Accettazione:

- [ ] Elenco delle ricette con kcal e macro totali; dettaglio con gli
      alimenti e i grammi; creare, modificare, eliminare.
- [ ] Da una ricetta: `Registra` (in uno slot di oggi) o `Pianifica` (su
      giorno e slot, anche nel futuro).
- [ ] Un pasto pianificato si modifica finché non è mangiato;
      l'interruttore lo segna `mangiato` o `saltato` (NUT-009).

### IOS-035 · Template settimanale

Stato: proposto · Parità: NUT-010 · Mockup: tavola 10

Sul telefono la griglia 7 × 5 del sito non sta: si vede un giorno alla
volta.

Accettazione:

- [ ] Elenco dei template; nel template una fila di 7 giorni (`L M M G V
    S D`) e sotto i 5 slot del giorno scelto, ognuno con ricetta o
      alimento.
- [ ] `Applica a una settimana`: corrente, prossima o una data (sempre da
      lunedì), con il riepilogo di quanti pasti crea e sostituisce.

### IOS-036 · Lista della spesa

Stato: proposto · Parità: NUT-011 · Mockup: tavola 11

Accettazione:

- [ ] Voci con i grammi in mono, da spuntare con un tocco; si eliminano
      scorrendo.
- [ ] `Genera` dai pasti pianificati di un intervallo di giorni; `+` per
      una voce libera; `Togli le spuntate`.
- [ ] Pensata per il supermercato: righe alte, testo grande, la
      schermata non si spegne mentre è aperta.

### IOS-037 · Acqua, caffeina, integratori

Stato: proposto · Parità: NUT-012, NUT-013, NUT-014 · Mockup: tavola 05

Accettazione:

- [ ] Acqua: ml del giorno sulla quota, barra, `−` e `+` (250 ml); `−`
      annulla l'ultima voce.
- [ ] Caffeina: mg del giorno, `−` e `+` (espresso, 80 mg).
- [ ] Integratori: checklist del giorno, un tocco per spuntare. La
      gestione (aggiungere, disattivare) sta in Impostazioni › Moduli ›
      Dieta.
- [ ] Ogni tocco dà un leggero feedback aptico.

### IOS-038 · Andamento

Stato: proposto · Parità: NUT-017 · Mockup: tavola 12

Accettazione:

- [ ] Selettore `30 g` / `90 g`; grafico delle kcal al giorno (Swift
      Charts) con la linea dell'obiettivo, media e tendenza.
- [ ] Aderenza in percentuale, macro medi e il peso sullo stesso asse
      temporale.
- [ ] Dati da `GET /nutrition/report`, calcolati nel backend.

### IOS-039 · Obiettivi e YAZIO

Stato: proposto · Parità: NUT-015, NUT-020, NUT-023

Accettazione:

- [ ] In Impostazioni › Moduli › Dieta: stato del collegamento YAZIO,
      ultima sincronizzazione, `Sincronizza ora`, interruttore della
      sincronizzazione, alimenti senza equivalente da abbinare.
- [ ] Obiettivo in kcal, macro e acqua: in sola lettura con YAZIO
      collegato, modificabile senza.
- [ ] Le credenziali YAZIO non passano mai dall'app.

### IOS-040 · Apple Salute

Stato: proposto · Parità: NUT-018 · Solo iOS · Mockup: tavola 27

Da verificare prima di pianificarlo: la firma con Apple ID gratuito di
SideStore deve concedere l'entitlement HealthKit. Se non lo concede il
requisito diventa `rimosso`.

Accettazione:

- [ ] Interruttore in Impostazioni › Notifiche e Salute; al primo
      utilizzo iOS chiede i permessi, uno per tipo di dato.
- [ ] L'app scrive in Salute kcal e macro di ogni pasto registrato
      dall'iPhone o letto dal backend, senza doppioni.
- [ ] Legge da Salute peso, acqua ed energia attiva e li manda al backend
      (rotta nuova nell'API, vedi README), che li rende visibili anche al
      sito.
- [ ] Spento l'interruttore, l'app smette di leggere e scrivere; i dati
      già inviati restano.

### IOS-041 · Promemoria pasti e acqua

Stato: proposto · Parità: NUT-019 · Solo iOS · Mockup: tavole 27, 28

Accettazione:

- [ ] Notifica locale `Colazione?` vicino all'orario dello slot, se per
      quello slot non c'è un pasto mangiato; dalla notifica `Sì` segna il
      pasto pianificato come mangiato, `Rimanda` la ripropone fra 30
      minuti.
- [ ] Notifica dell'acqua a orari fissi se si è sotto la quota
      proporzionata all'ora.
- [ ] Gli orari degli slot e dell'acqua si cambiano in Impostazioni ›
      Notifiche e Salute e si salvano sul server (preferenze, vedi
      README).
- [ ] Si basa sulle notifiche locali di IOS-011.
