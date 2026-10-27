# Palestra

ID: `IOS-050`…`059` · Label: `mod:palestra` · Parità: `GYM-001`…`014`

Il modulo Allenamento del sito, nella scheda `Palestra`: storico dal CSV
di Liftin', sessioni, esercizi, record, volume per gruppo muscolare e
costanza. Come sul sito, fatto soprattutto di immagini (foto in bianco e
nero, scurite) e con pochi numeri. Su iPhone il CSV arriva direttamente
da Liftin' con il foglio di condivisione.

Mockup: [canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

## Requisiti

### IOS-050 · Pagina Palestra

Stato: fatto (#85) · Parità: GYM-002, GYM-007, GYM-010, GYM-013 · Mockup: tavola 13

Accettazione:

- [x] In cima l'ultimo allenamento a tutta larghezza: foto del primo
      esercizio, routine, giorno, durata.
- [x] Sotto, due numeri grandi: allenamenti questa settimana e giorni di
      fila, con il grafico a barre delle ultime 12 settimane (corrente in
      rosso).
- [x] Una fila scorrevole in orizzontale con i 6 esercizi più allenati:
      foto, nome, miglior 1RM stimato.
- [x] I record degli ultimi 30 giorni (al massimo 3), poi lo storico
      (IOS-052). Volume per gruppo e elenco esercizi sono link, non
      sezioni aperte.
- [x] Senza dati, solo l'invito a importare il CSV (IOS-051).

### IOS-051 · Import del CSV di Liftin'

Stato: fatto (#86) · Parità: GYM-003 · Mockup: tavola 16

Accettazione:

- [x] L'app si registra per i file `.csv` (`CFBundleDocumentTypes`): da
      Liftin', **Condividi → ron1nOS** apre l'import. In più, `Importa
  CSV` nella pagina apre il selettore di File.
- [x] Il file va a `POST /workout/import/preview`; il foglio mostra
      l'anteprima del server (allenamenti nuovi, aggiornati, righe
      scartate, periodo). `Importa` applica, `Annulla` non scrive niente.
- [x] Gli errori del server (file vuoto, colonne mancanti…) si mostrano
      con il loro testo.

### IOS-052 · Storico e dettaglio di una sessione

Stato: fatto (#87) · Parità: GYM-004, GYM-005, GYM-006 · Mockup: tavola 14

Accettazione:

- [x] Storico dalla più recente: miniature dei primi tre esercizi,
      routine, giorno, durata. Filtro per routine; si carica a pagine da
      20 scorrendo.
- [x] Dettaglio: in testata routine, giorno, durata e volume; le barre
      del volume per esercizio (il più pesante in rosso); una card per
      esercizio con foto e serie `peso × reps`, riscaldamento tratteggiato,
      record segnati.
- [x] `Elimina sessione` nel menu `⋯`, con conferma.

### IOS-053 · Esercizi e record

Stato: pianificato (#46) · Parità: GYM-008, GYM-009, GYM-010 · Mockup: tavola 15

Accettazione:

- [ ] Elenco degli esercizi in griglia a due colonne con foto, nome,
      gruppo; ricerca e filtro `Da completare`.
- [ ] Pagina dell'esercizio: foto grande, nome e gruppo; tre numeri (1RM
      stimato, peso più alto, sessioni); un grafico per volta con il
      selettore `1RM stimato` / `Volume` (o durate) e il periodo; le
      ultime 3 volte; i record.

### IOS-054 · Gruppo muscolare e immagine

Stato: pianificato (#47) · Parità: GYM-011, GYM-014

Accettazione:

- [ ] Dalla pagina dell'esercizio si sceglie il gruppo da un menu con
      l'elenco fisso.
- [ ] `Scegli immagine` apre un foglio con ricerca nel catalogo e griglia
      di foto; la scelta vale per tutto lo storico.

### IOS-055 · Volume per gruppo muscolare

Stato: pianificato (#48) · Parità: GYM-012

Accettazione:

- [ ] Barre impilate delle ultime 12 settimane in toni di grigio (Swift
      Charts), selettore `Volume` / `Serie`, legenda sotto, `Non
  assegnato` tratteggiato.
