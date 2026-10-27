# Torrent

ID: `IOS-070`…`079` · Label: `mod:torrent` · Parità: `DL-001`…`009`

Il modulo Download del sito, dentro `Altro › Torrent`: cosa sta
scaricando il server e il wizard per aggiungere un torrent. Le credenziali
di qBittorrent restano sul server (DL-009): l'app parla solo con
`/api/v1/downloads`.

Mockup: [canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

## Requisiti

### IOS-070 · Pagina Torrent

Stato: fatto (#98) · Parità: DL-001, DL-002 · Mockup: tavola 21

Sul sito c'è solo il widget; su iPhone serve una pagina, in sola lettura
come il widget.

Accettazione:

- [x] In testata la velocità totale di download, grande, in mono.
- [x] I torrent in download, i più vicini alla fine per primi: nome,
      barra, percentuale, velocità e tempo rimanente. Sotto, in righe più
      piccole, quelli in coda e in seed (`Mostra tutto` oltre i 5).
- [x] Aggiornamento ogni 5 secondi in primo piano (IOS-012).
- [x] qBittorrent non raggiungibile o accesso non riuscito: lo dice con
      la StatusPill `offline`, e `Aggiungi` resta disattivato.

### IOS-071 · Aggiungere un torrent

Stato: fatto (#82) · Parità: DL-003…DL-008 · Mockup: tavole 22, 23

Accettazione:

- [x] `Aggiungi` apre il wizard in un foglio a tutta altezza, con i 4
      passi del sito: sorgente, lettura dei contenuti, scelta dei file,
      riepilogo e avvio. Stesse regole e stessi testi.
- [x] Sorgente: `File` apre il selettore di File; `Link` ha il campo e
      `Incolla`, che si propone da solo se negli appunti c'è un magnet o
      un URL.
- [x] L'app si registra per i file `.torrent` e per i link `magnet:`:
      toccando un magnet in Safari o aprendo un `.torrent` con
      **Condividi → ron1nOS**, il wizard parte già al passo 2.
- [x] Scelta dei file ad albero, cartelle che si aprono, `Tutti` /
      `Nessuno`, il totale fisso in fondo sopra `Avanti`.
- [x] Chiudere il foglio prima di `Avvia` annulla la bozza
      (`DELETE /downloads/drafts/{id}`), come `Annulla` sul sito.
