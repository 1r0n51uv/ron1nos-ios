# Home

ID: `IOS-020`…`029` · Label: `mod:home`

La Home è la prima pagina dell'app: la testata e lo stato di Server e
Torrent, in sola lettura. È fissa: non ha modalità Modifica né layout
salvato. La Home personalizzabile con i widget (IOS-020…024) è stata
rimossa con la riscrittura (IOS-100).

## Requisiti

### IOS-025 · Home fissa

Stato: in corso

Accettazione:

- [ ] In cima la data in monospazio e il saluto (`Buongiorno`,
      `Buon pomeriggio`, `Buonasera`).
- [ ] La card Server mostra CPU, RAM e disco con una barra, rossa oltre
      l'80%, poi temperatura, da quanto è acceso e la rete
      (`GET /server/stats`).
- [ ] La card Torrent mostra la velocità totale, i primi tre download
      attivi con barra e tempo rimanente e il riepilogo di coda e seed
      (`GET /downloads`).
- [ ] La Home si aggiorna ogni 5 secondi e con il gesto di tirare giù.
- [ ] Senza accesso valido (401) la Home mostra solo l'invito ad accedere
      da Impostazioni, al posto delle card.
- [ ] Una card in errore mostra il titolo dell'errore e il codice, senza
      bloccare l'altra.
