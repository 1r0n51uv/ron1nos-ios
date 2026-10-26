# Impostazioni

ID: `IOS-090`…`099` · Label: `mod:impostazioni` · Parità: `SET-001`…`012`, `AUTH-001`…`005`

Le impostazioni del sito, dentro `Altro › Impostazioni`, nella forma di
un elenco raggruppato come le Impostazioni di iOS. Le preferenze sono le
stesse del sito (`/preferences`); in più ci sono le voci che riguardano
solo il telefono: Accesso, Notifiche e Salute.

Mockup: [canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

## Requisiti

### IOS-090 · Elenco delle sezioni e Accesso

Stato: proposto · Parità: SET-001 · Mockup: tavole 26, 29

Accettazione:

- [ ] Gruppi: **Questo iPhone** (Accesso, Notifiche e Salute), **ron1nOS**
      (Aspetto, Dashboard, Moduli, Navigazione, Formati), **Account**
      (Account, App iOS), **Sistema** (Integrazioni, Backup
      configurazione, Informazioni).
- [ ] Ogni riga mostra a destra lo stato in breve (`collegato`, `medio`,
      `5 accesi`…).
- [ ] Accesso è la schermata di IOS-004 e IOS-005 (service token di
      Cloudflare, token ron1nOS), con lo stato di ognuno.
- [ ] Ogni modifica si salva da sola; l'errore accanto al campo.

### IOS-091 · Aspetto, Dashboard, Moduli, Navigazione, Formati

Stato: proposto · Parità: SET-003…SET-006, SET-010

Accettazione:

- [ ] Aspetto: sfondo (sfumature o immagine dalla libreria Foto), vetro,
      densità, con l'anteprima di una card.
- [ ] Dashboard: forma della testata, widget presenti con `Rimuovi` e
      `Opzioni`, `Ripristina layout predefinito` (layout `iphone`).
- [ ] Moduli: interruttori e link alle impostazioni di Dieta e Documenti.
- [ ] Navigazione: elenco riordinabile con le maniglie di iOS; mostra
      quali moduli finiscono nella TabBar e quali in `Altro` (IOS-009).
- [ ] Formati: fuso, peso, energia; lingua mostrata e non modificabile.

### IOS-092 · Account e App iOS

Stato: proposto · Parità: SET-007, SET-008, AUTH-002, AUTH-005

Accettazione:

- [ ] Account: sessioni web attive con `Chiudi` e `Chiudi le altre`;
      come cambiare la password (spiegazione, come sul sito).
- [ ] App iOS: i token con nome e ultimo uso, quello di questo telefono
      segnato; `Revoca` con conferma. `Nuovo token` crea un token e lo
      salva direttamente nel Portachiavi, senza copia e incolla.
- [ ] `Esci da questo iPhone` revoca il token del telefono e lo toglie dal
      Portachiavi.

### IOS-093 · Integrazioni, Backup, Informazioni

Stato: proposto · Parità: SET-009, SET-011, SET-012

Accettazione:

- [ ] Integrazioni: una riga per servizio con stato e ora del controllo;
      `Verifica`; per i servizi non configurati, le variabili da
      impostare.
- [ ] Backup: `Esporta` passa il JSON al foglio di condivisione;
      `Importa` lo legge da File, mostra cosa cambia e chiede conferma.
- [ ] Informazioni: versione dell'app (`0.1.N` del builder) e del
      backend, stato di backend e database, uptime, link al repository.

### IOS-094 · Notifiche e Salute

Stato: proposto · Solo iOS · Mockup: tavola 27

Accettazione:

- [ ] Interruttori `Pasti`, `Acqua`, `Scadenze documenti` (IOS-011) con
      gli orari dei pasti e dell'acqua (IOS-041).
- [ ] Interruttore `Apple Salute` (IOS-040) con i dati letti e scritti.
- [ ] Stato del permesso di iOS e link alle impostazioni di sistema.
