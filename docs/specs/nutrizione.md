# Nutrizione

ID: `IOS-030`…`039` · Label: `mod:nutrizione` · Parità: `NUT-008`…`NUT-011`, `NUT-030`…`NUT-032`

La Nutrizione dell'app serve a **programmare**, non a registrare: si sceglie
un piano (una settimana tipo di ricette), lo si programma da un giorno fino a
una data e poi si conferma ciò che si è mangiato. Niente aggiunta di pasti
fuori piano, né acqua, caffeina, integratori o codici a barre: la vecchia
Dieta (IOS-030…049 prima della riscrittura) era troppo complicata.

Le ricette vengono dai preferiti di YAZIO o si creano qui; gli ingredienti
sono sempre del catalogo YAZIO. Spuntare un pasto lo segna `mangiato` e la
sincronizzazione che c'è già lo scrive su YAZIO. Un pasto non spuntato è
`saltato` se il giorno è passato e `in programma` se è oggi o futuro: lo
decide l'app, il server non cambia stato da solo.

Non fa, per ora: registrare pasti liberi, alimenti personali, ricerca per
codice a barre, integratori, acqua e caffeina, andamento.

## Requisiti

### IOS-030 · Ricette con procedimento

Stato: in corso · Parità: NUT-008, NUT-030

Accettazione:

- [ ] La pagina Ricette elenca le ricette (nome, kcal e peso); `Importa da
      YAZIO` porta i preferiti e dice quante ne ha create e aggiornate.
- [ ] Una ricetta mostra kcal e macro, gli ingredienti coi grammi, il
      procedimento a passi numerati e le note.
- [ ] Si crea e si corregge: nome, ingredienti scelti solo dal catalogo
      YAZIO (da due lettere) coi grammi, passi del procedimento da aggiungere,
      togliere e riscrivere, note. Le kcal si aggiornano mentre si scrive.
- [ ] Si elimina con conferma; i pasti già programmati restano.

### IOS-031 · Piani e programmazione

Stato: in corso · Parità: NUT-010, NUT-031

Accettazione:

- [ ] La pagina Piani elenca le settimane tipo; si crea e si corregge: un
      nome e, per ogni giorno da lunedì a domenica, la ricetta di ognuno dei 5
      pasti. Le caselle con un alimento solo (senza ricetta) non si rifanno
      nell'app.
- [ ] `Programma` sceglie il giorno di partenza e, a scelta, una data finale:
      la settimana tipo si ripete fino a quel giorno (al massimo un anno);
      senza data vale fino a domenica.
- [ ] I pasti ancora in programma di quei giorni si rifanno col piano;
      mangiati e saltati restano. Un toast dice quanti pasti sono stati
      programmati.

### IOS-032 · La settimana

Stato: in corso · Parità: NUT-032

Accettazione:

- [ ] Nutrizione è la seconda voce della barra. Mostra la settimana da lunedì
      con le frecce per cambiarla e `Oggi` per tornare; un pannello per giorno
      coi 5 pasti, ricetta e stato (mangiato, saltato, in programma), e le
      kcal del giorno.
- [ ] Il giorno di oggi è segnato; senza niente in programma la pagina invita
      a scegliere un piano.
- [ ] Il menu apre Piani, Ricette e Spesa.

### IOS-033 · Dettaglio del giorno e conferma

Stato: in corso · Parità: NUT-001, NUT-016

Accettazione:

- [ ] Un tocco su un giorno apre i suoi pasti: in cima kcal mangiate su
      obiettivo, barra, quanto manca e i macro.
- [ ] Ogni pasto mostra ricetta e kcal; un tocco apre la ricetta.
- [ ] `Mangiato` segna il pasto, `Annulla` lo rimette in programma; si spunta
      fino a oggi, un giorno futuro resta in programma.

### IOS-034 · Lista della spesa

Stato: in corso · Parità: NUT-011

Accettazione:

- [ ] La spesa si genera dai pasti in programma di un periodo (al massimo 31
      giorni), si spunta con un tocco, si aggiungono voci a mano e si
      tolgono le spuntate. Lo schermo resta acceso finché è aperta.

### IOS-035 · Promemoria dei pasti

Stato: in corso · Parità: NUT-019

Accettazione:

- [ ] All'orario di ogni pasto ancora in programma dei prossimi giorni
      arriva una notifica locale con `Mangiato` e `Rimanda 30 min`; un tocco
      apre la pagina Nutrizione. Al massimo 40 notifiche programmate.
- [ ] I promemoria si rifanno a ogni apertura, dopo ogni conferma o
      programmazione e dall'aggiornamento in background.
- [ ] Il permesso di iOS si chiede la prima volta che si apre la pagina
      Nutrizione, mai all'avvio.

### IOS-036 · Il pasto di adesso nella Home

Stato: in corso

Accettazione:

- [ ] La Home ha una card col pasto che corrisponde all'ora: l'ultimo il cui
      orario è passato, la colazione prima della colazione. Mostra ricetta e
      kcal e il pulsante `Mangiato`; dopo la spunta, `Mangiato`.
- [ ] Sotto, l'obiettivo del giorno: barra, kcal mangiate su obiettivo e
      quanto manca (o di quanto si è oltre).
- [ ] `Settimana` apre la pagina Nutrizione. Con il modulo spento la card non
      c'è.

### IOS-037 · Orari dei pasti

Stato: in corso · Parità: NUT-019

Accettazione:

- [ ] In Impostazioni, un selettore d'ora per ognuno dei 5 pasti; si salva
      da solo nelle preferenze di ron1nOS e rifà i promemoria.
