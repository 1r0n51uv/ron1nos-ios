# Piano di riscrittura dell'app iOS

_Bozza del 10 novembre 2026, da confermare. Sostituisce `ron1nOS/docs/piano-revisione.md` per la parte web, che è in pausa._

## Obiettivo

Stessa app (bundle `home.ron1n.ios`, source di SideStore, stile ron1nOS), riscritta da zero con **tre cose sole**:

1. **Home**
2. **Barra dell'app** con due icone: Home e Impostazioni
3. **Impostazioni**, che contengono **solo l'accesso**

Tutto il resto esce dall'app: Dieta, Palestra, Documenti, Torrent, Server come schede, Altro, notifiche, Salute, editor della Home.

## Cosa resta del codice

| Parte | Dimensione oggi | Destino |
|---|---|---|
| `APIClient`, `APIError`, `HTTPTransport`, `Carico` | ~420 righe in Kit | **Si tiene.** È già un modulo deep e testato. |
| Accesso: `LoginRon1n`, `Accesso`, `Account` | ~400 righe in Kit | **Si tiene e si riordina** in un solo modulo Accesso (vedi sotto). |
| `Stile`, `Palette`, `Card`, `Stati`, `Pillola` | ~400 righe | **Si tiene** (è lo stile ron1nOS). |
| Viste dei moduli, `Sessione`, `RadiceView`, `BarraPillola` | ~10.000 righe in `Ron1nOS` | **Si riscrive.** |
| Modelli e test dei moduli (Dieta, Palestra, Documenti, Torrent…) | ~6.500 righe in Kit | **Si toglie.** Restano nella storia di git e nel tag `pre-riscrittura`. |

Da ~17.500 righe a circa 3.000.

## Struttura

```
Ron1nKit/
  Rete/        APIClient · APIError · HTTPTransport · Carico
  Accesso/     Accesso (entra · esci · stato · client) · RinnovoSessione · archivi (cookie, password)
  Home/        modello di ciò che la Home mostra
Ron1nOS/
  Ron1nOSApp · RadiceView (barra con due icone)
  Home/        HomeView
  Impostazioni/ ImpostazioniView · AccessoView
  Stile/       Stile · Card · Stati
```

### Accesso: un modulo solo

È il candidato n. 1 del report di architettura. Oggi il ciclo di vita del login è sparso fra `Sessione`, `AccessoView` e `LoginRon1n`, e non ha test perché sta in una vista.

Il modulo ha un'interfaccia piccola:

- `entra(password:ricordaConFaceID:) -> EsitoAccesso`
- `esci()`
- `stato() -> StatoLogin`
- `client() -> APIClient`

Possiede i tre archivi e il rinnovo. La vista mostra soltanto lo stato e inoltra gli eventi. Con i transport e gli archivi finti, tutto si prova su Linux: login, logout, Face ID sì/no, "esci non chiede Face ID", rinnovo sul 401.

Con una sola sezione che dipende dalla sessione, i contatori di invalidazione di `Sessione` (candidato n. 2) non servono più: l'inconsistenza sparisce con i moduli.

## Cosa mostra la Home — da confermare

Ipotesi di partenza: una pagina **fissa**, senza modalità Modifica né layout salvato, con la testata di oggi (data, saluto, frase di stato) e due card di sola lettura:

- **Server**: CPU, RAM, disco, temperatura (spec SRV-001…003 del sito).
- **Download**: velocità e torrent in corso.

Senza accesso valido, la Home mostra il solo invito ad accedere.

## Fasi

Ogni fase è una PR con i suoi test e una riga in `CHANGELOG.md`, come da `CLAUDE.md`.

1. **Tag e branch.** Tag `pre-riscrittura` su `main`.
2. **Accesso in Kit.** Il modulo nuovo con i suoi test su Linux, sopra `APIClient` e `RinnovoSessione`. Ancora senza toccare l'interfaccia.
3. **Struttura nuova.** `RadiceView` con le due icone, `ImpostazioniView` con `AccessoView`, una `HomeView` vuota. Si tolgono tutte le viste e i modelli dei moduli e i loro test. Qui l'app compila ed è già usabile per accedere.
4. **Home.** Le due card sopra le rotte `/server` e `/downloads` già esistenti.
5. **Pulizia.** `Info.plist` perde i tipi di documento (CSV, torrent, magnet), i permessi fotocamera e Salute e il blocco dei Documenti. La specifica `docs/specs/` si riduce a `app`, `home` e `impostazioni`.

## Cosa non cambia

- Bundle, nome, icona, source di SideStore e build sul server (spec IOSB).
- L'API `/api/v1` di ron1nOS: l'app non ne chiede di nuove.
- Il tema scuro, l'accento rosso `#FF2A2A` come segnale, i numeri in monospazio, i testi brevi.

## Punti aperti

1. **Contenuto della Home.** Server e Download come sopra, oppure altro?
2. **Impostazioni**: oltre all'accesso, servono l'indirizzo del server e le informazioni sulla versione, o solo login e logout?
3. **Aprire un `.torrent` o un magnet dall'app**: oggi l'app lo accetta. Con i Torrent fuori, la funzione sparisce. Va bene?
