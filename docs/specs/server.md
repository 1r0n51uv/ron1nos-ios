# Server

ID: `IOS-080`…`089` · Label: `mod:server` · Parità: `SRV-001`…`008`

Il modulo Server del sito, dentro `Altro › Server`: quanto lavora il mini
PC, da `GET /server/stats`.

Mockup: [canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

## Requisiti

### IOS-080 · Pagina Server

Stato: fatto (#99) · Parità: SRV-001…SRV-007 · Mockup: tavola 24

Accettazione:

- [x] Tre anelli grandi `CPU`, `RAM`, `SSD` con la percentuale in mono;
      rosso da 80% in su (SRV-005).
- [x] Sotto, una riga sola: temperatura e uptime (`52 °C · 41 g`), poi
      la rete (`↓ 12,4 MB/s · ↑ 0,8 MB/s`).
- [x] I 3 container che consumano di più: nome, CPU, RAM.
- [x] Da 85 °C la StatusPill `alert` `CPU a 88 °C` sotto il titolo.
- [x] Glances non raggiungibile: StatusPill `offline`; una parte che
      manca si omette senza fermare il resto.
- [x] Aggiornamento ogni 5 secondi in primo piano (IOS-012), senza far
      lampeggiare gli anelli: i valori scorrono con un'animazione breve.
