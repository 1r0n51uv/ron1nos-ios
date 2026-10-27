# Specifiche di ron1nOS iOS

L'app iOS di ron1nOS: le stesse funzioni della dashboard web, sulla stessa
API `/api/v1` del backend ron1nOS. Il flusso (specifica → issue → PR →
build) è quello di [ron1n](https://github.com/1r0n51uv/ron1n/blob/main/docs/flusso-sviluppo.md);
la build gira sul server di casa con xtool
([IOSB](https://github.com/1r0n51uv/ron1n/blob/main/docs/specs/ios-build.md)).

## Parità con il sito

Dal 2026-10-26 l'app ha come obiettivo la parità con il sito: ogni modulo
vero della dashboard (Dashboard, Nutrizione, Allenamento, Documenti,
Download, Server, Impostazioni) ha la sua specifica qui. I requisiti non
ripetono quelli del sito: dicono come la stessa funzione si presenta su
iPhone e rimandano agli ID web (`NUT-003`, `DOC-009`…), che restano la
fonte di verità per regole e testi. In più ci sono le funzioni che solo
l'iPhone può avere: fotocamera, Face ID, notifiche locali, Apple Salute.

Stile delle schermate (proprietario, 2026-10-26): meno dense del sito.
Una schermata risponde a una domanda e mostra pochi numeri grandi; il
resto sta un tocco più in là (dettaglio, foglio, `Mostra tutto`). Molto
spazio tra le card, una card per riga salvo i widget piccoli. Il vetro
vero è il Liquid Glass di iOS 26 sui controlli che galleggiano (TabBar,
barre, fogli); le card restano il velo di IOS-003.

Mockup di tutte le schermate:
[canvas ron1nOS iOS · App completa](https://claude.ai/artifact/QoqDRszV34UMYaHGBJ8bFd).

Restano fuori i moduli che sul sito sono ancora solo un mock (Peso, Casa,
Container, Note): arrivano nell'app quando il sito li collega a una
sorgente vera.

## Moduli

| Modulo       | File                               | ID              | Label              |
| ------------ | ---------------------------------- | --------------- | ------------------ |
| App          | [app.md](app.md)                   | `IOS-001`…`019` | `mod:app`          |
| Home         | [home.md](home.md)                 | `IOS-020`…`029` | `mod:home`         |
| Dieta        | [dieta.md](dieta.md)               | `IOS-030`…`049` | `mod:dieta`        |
| Palestra     | [palestra.md](palestra.md)         | `IOS-050`…`059` | `mod:palestra`     |
| Documenti    | [documenti.md](documenti.md)       | `IOS-060`…`069` | `mod:documenti`    |
| Torrent      | [torrent.md](torrent.md)           | `IOS-070`…`079` | `mod:torrent`      |
| Server       | [server.md](server.md)             | `IOS-080`…`089` | `mod:server`       |
| Impostazioni | [impostazioni.md](impostazioni.md) | `IOS-090`…`099` | `mod:impostazioni` |

Un solo prefisso, `IOS`, con un blocco di numeri per modulo. Gli ID non si
riusano.

## Cosa serve nell'API

Regola del repo: una funzione nuova che serve all'app va prima nell'API di
ron1nOS. Queste parti non ci sono ancora: sono specificate e pianificate
nel repo ron1nOS e vanno fatte prima dei requisiti iOS che le usano.

| Serve a     | Cosa manca nell'API                                                                                                                                                                   |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| IOS-020…024 | DASH-010 ([ron1nOS#208](https://github.com/1r0n51uv/ron1nOS/issues/208)): catalogo del layout `iphone`: griglia di 4 colonne e misure `piccolo` (2×2), `medio` (4×2), `grande` (4×4). |
| IOS-040     | NUT-026 ([ron1nOS#209](https://github.com/1r0n51uv/ron1nOS/issues/209)): rotte per i dati di Apple Salute: peso, acqua ed energia attiva inviati dall'app.                            |
| IOS-041     | NUT-027 ([ron1nOS#210](https://github.com/1r0n51uv/ron1nOS/issues/210)): orari dei 5 pasti e degli avvisi dell'acqua nelle preferenze (`/preferences`).                               |

## Stati dei requisiti

`proposto` → `pianificato (#issue)` → `in corso (#issue)` → `fatto (#PR)`,
oppure `rimosso`. Gli ID non si riusano.
