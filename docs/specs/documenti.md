# Documenti

ID: `IOS-060`…`069` · Label: `mod:documenti` · Parità: `DOC-001`…`016`

Il modulo Documenti del sito, nella scheda `Documenti`: documenti con
tipo, file con info e file liberi, campi da copiare con un tocco,
allegati, scadenze. I dati restano cifrati sul server (DOC-015) e l'app
non tiene copie: legge, mostra e dimentica.

Solo su iPhone: Face ID per entrare, scansione dei documenti con la
fotocamera e avvisi di scadenza con le notifiche locali.

Mockup: [canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

## Requisiti

### IOS-060 · Elenco dei documenti

Stato: fatto (#92) · Parità: DOC-002, DOC-008, DOC-010 · Mockup: tavola 18

Accettazione:

- [x] In cima i documenti fissati in card grandi con la miniatura;
      sotto, quelli in scadenza o scaduti (lo scaduto in rosso); poi gli
      altri raggruppati per tipo, in righe semplici.
- [x] Ricerca per titolo e tag nella barra di navigazione; filtri per
      tipo e titolare in un menu.
- [x] `+` in alto apre il nuovo documento (IOS-062).

### IOS-061 · Dettaglio e copia

Stato: fatto (#93) · Parità: DOC-004, DOC-009, DOC-012, DOC-013 · Mockup: tavola 19

Accettazione:

- [x] Allegati in alto, scorrevoli in orizzontale; un tocco apre
      l'immagine o il PDF a schermo intero (Quick Look).
- [x] Sotto, i campi: etichetta piccola, valore in mono. Un tocco sul
      campo lo copia, con toast `Copiato` e feedback aptico. Gli appunti
      scadono dopo 2 minuti (`UIPasteboard` con scadenza) e restano su
      questo telefono (`localOnly`).
- [x] Tenendo premuta un'immagine: `Copia immagine`, `Condividi`.
- [x] Menu `⋯`: `Modifica`, `Fissa` / `Togli dall'evidenza`, `Copia
  tutto`, `PDF di riepilogo` (foglio di condivisione, con l'avviso che
      il file è in chiaro), `Elimina` con conferma.
- [x] Allegati e PDF passano da file temporanei cancellati alla chiusura.

### IOS-062 · Nuovo documento

Stato: fatto (#94) · Parità: DOC-005, DOC-006, DOC-007, DOC-011 · Mockup: tavola 20

Accettazione:

- [x] Si parte dal file, con quattro sorgenti: `Scansiona` (scanner di
      VisionKit, ritaglio e raddrizzamento automatici, più pagine),
      `Foto`, `File`, `Senza file`.
- [x] Poi si sceglie cosa è: `Documento` (con il tipo), `File con info`,
      `File libero`; il form è quello del sito, a una colonna, con i
      campi del tipo da `GET /documents/types`.
- [x] Titolare scelto tra quelli usati o scritto; campi liberi da
      aggiungere, riordinare, eliminare.
- [x] Caricamento con barra di avanzamento per file; un errore su un file
      non blocca gli altri. Gli errori di validazione sul campo.

### IOS-063 · Tipi personalizzati

Stato: pianificato (#52) · Parità: DOC-016

Accettazione:

- [ ] In Impostazioni › Moduli › Documenti: elenco dei tipi, creare,
      modificare (campi da aggiungere, rinominare, riordinare, togliere),
      eliminare solo se nessun documento lo usa.

### IOS-064 · Face ID

Stato: pianificato (#53) · Solo iOS · Mockup: tavola 17

Accettazione:

- [ ] Entrando nella scheda Documenti l'app chiede Face ID
      (`LocalAuthentication`), con il codice del telefono come riserva.
- [ ] Lo sblocco vale finché l'app resta in primo piano e fino a 1 minuto
      in background; poi si richiede.
- [ ] Nel selettore delle app i Documenti sono coperti da un velo con il
      sigillo, così i dati non si vedono nell'anteprima.
- [ ] Il widget Documenti della Home mostra solo tipo, titolo e
      scadenza, come sul sito, senza chiedere Face ID.
- [ ] Interruttore in Impostazioni › Moduli › Documenti, acceso di
      default.

### IOS-065 · Avvisi di scadenza

Stato: pianificato (#54) · Parità: DOC-010 · Solo iOS · Mockup: tavola 28

Accettazione:

- [ ] Per ogni documento con scadenza, una notifica locale per ogni
      preavviso attivo (90, 30, 7 giorni) e il giorno dopo la scadenza,
      alle 9:00.
- [ ] Il testo non contiene numeri né nomi, solo tipo e data:
      `Passaporto · scade tra 30 giorni`.
- [ ] Toccare la notifica apre il documento, dopo Face ID.
- [ ] Si basa sulle notifiche locali di IOS-011.
