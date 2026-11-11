# Torrent

ID: `IOS-070`…`079` · Label: `mod:torrent` · Parità: `DL-001`…`DL-011`

La pagina Torrent gestisce i download di qBittorrent dal telefono: elenco in
sezioni per stato, pausa, ripresa ed eliminazione (anche di più torrent
insieme), dettaglio con i file, aggiunta guidata e avviso a download
finito. Le rotte sono quelle di `/api/v1/downloads` di ron1nOS (DL-001…DL-011).

Non fa, per ora: limiti di velocità, categorie o cartella di destinazione,
priorità di coda, cambio di priorità dei file dopo l'avvio, peer e tracker.

## Requisiti

### IOS-070 · Elenco in sezioni

Stato: in corso · Parità: DL-001, DL-002

Accettazione:

- [ ] In testata la velocità totale di download, grande, in mono.
- [ ] I torrent sono in sezioni: In download, In coda, In seed, Fermi,
      Errori, ognuna solo se non è vuota e con il numero dei torrent. In
      seed è chiusa finché non si apre; le altre sono aperte.
- [ ] Ogni riga ha nome, barra, avanzamento, velocità e tempo rimanente;
      in seed solo lo stato.
- [ ] Aggiornamento ogni 5 secondi in primo piano e con il gesto di tirare
      giù. Se qBittorrent non risponde dopo il primo caricamento restano i
      dati e compare la pillola `offline`.
- [ ] La card Torrent della Home apre questa pagina.

### IOS-071 · Aggiungere un torrent

Stato: in corso · Parità: DL-003…DL-008

Accettazione:

- [ ] `Aggiungi` apre il wizard in un foglio a tutta altezza, con i 4 passi
      del sito: sorgente (File o Link), contenuti, scelta dei file ad
      albero, riepilogo con lo spazio libero.
- [ ] Chiudere il foglio prima di `Avvia` annulla la bozza.
- [ ] Il wizard è come prima della riscrittura (IOS-100): stessi passi,
      stessi messaggi.

### IOS-072 · Pausa, ripresa ed eliminazione

Stato: in corso · Parità: DL-010

Accettazione:

- [ ] Tenendo premuta una riga: `Pausa` o `Riprendi`, ed `Elimina…`.
- [ ] `Elimina` chiede sempre conferma e offre `Elimina e tieni i file`
      (la scelta di default, senza dire altro) ed `Elimina anche i file`.
- [ ] Un toast dice l'esito: `Messo in pausa`, `Ripreso`, `Eliminato`; un
      errore mostra il titolo dell'errore.

### IOS-073 · Selezione multipla

Stato: in corso

Accettazione:

- [ ] `Scegli` in alto a sinistra apre la selezione: ogni riga ha una
      spunta, ogni sezione `Tutti`, in seed compresa. `Fine` esce.
- [ ] In basso `Pausa`, `Riprendi` ed `Elimina`: `Pausa` solo se tra i
      scelti c'è un torrent non fermo, `Riprendi` solo se c'è un torrent
      fermo, `Elimina` se ne è scelto uno. L'eliminazione chiede la stessa
      conferma di IOS-072.
- [ ] Dopo un aggiornamento restano scelti solo i torrent che ci sono
      ancora; `Aggiungi` è spento durante la selezione.

### IOS-074 · Dettaglio di un torrent

Stato: in corso · Parità: DL-011

Accettazione:

- [ ] Un tocco su una riga apre il dettaglio: nome, barra e stato,
      dimensione, scaricato, rapporto, velocità di download e upload,
      cartella e data di aggiunta.
- [ ] Sotto, i file con l'avanzamento; i file esclusi dal download sono in
      tono tenue, con `escluso`.
- [ ] `Pausa` o `Riprendi` ed `Elimina` (stessa conferma di IOS-072);
      dopo l'eliminazione si torna all'elenco.
- [ ] Aggiornamento ogni 5 secondi. Un torrent sparito dice `Il torrent non
      c'è più`.

### IOS-075 · Avviso a download finito

Stato: in corso

Con SideStore e un Apple ID gratuito le push non ci sono: le notifiche sono
locali. Il telefono programma una notifica all'ora di fine prevista di ogni
download, più 60 secondi di margine, e la rifà a ogni lettura.

Accettazione:

- [ ] Ogni volta che l'app legge i download (Home, Torrent, aggiornamento in
      background) programma `Download in arrivo a fine` per ogni download
      con un tempo stimato, con identificatore per torrent, e toglie quelle
      di chi non è più in download.
- [ ] Un download che era in corso alla lettura precedente e adesso è
      completo manda subito `Download finito`; uno eliminato o fermo a metà
      no.
- [ ] Il permesso di iOS si chiede la prima volta che si apre la pagina
      Torrent, mai all'avvio. Senza permesso non si manda niente.
- [ ] Finché c'è un download in corso, l'app chiede a iOS un aggiornamento
      in background ogni 15 minuti (non garantito da iOS) per rileggere i
      download.
- [ ] Con l'app aperta la notifica si vede lo stesso, come banner in alto;
      un tocco su una notifica apre la pagina Torrent.
- [ ] Test unitari su Linux del piano: fine prevista con margine, finito,
      fermo a metà, eliminato, già in seed.

### IOS-076 · Aprire un torrent o un magnet da fuori

Stato: in corso

Accettazione:

- [ ] L'app si registra per i file `.torrent` e per i link `magnet:`:
      dal foglio di condivisione, da File e da Safari apre il wizard nella
      pagina Torrent.
- [ ] Aprendo la pagina Torrent, se negli appunti c'è un magnet valido
      compare `Magnet negli appunti` con `Aggiungi` e `Ignora`. `Ignora` o
      `Aggiungi` non lo riproporranno finché il testo copiato è lo stesso.
