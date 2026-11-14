# Specifiche di ron1nOS iOS

L'app iOS di ron1nOS, sulla stessa API `/api/v1` del backend ron1nOS. Il
flusso (specifica → issue → PR → build) è quello di
[ron1n](https://github.com/1r0n51uv/ron1n/blob/main/docs/flusso-sviluppo.md);
la build gira sul server di casa con xtool
([IOSB](https://github.com/1r0n51uv/ron1n/blob/main/docs/specs/ios-build.md)).

## Riscrittura

Dal 2026-11-10 l'app è stata riscritta da zero (IOS-100): ha una Home, una
barra con due icone e le Impostazioni con il solo accesso. Palestra, Documenti e
Server come schede sono usciti. Le loro specifiche e il
loro codice restano nella storia di git, nel tag `pre-riscrittura`. Un
modulo torna nell'app solo quando se ne decide la versione minima.

I Torrent (IOS-070…076) e la Nutrizione come programmazione (IOS-030…037)
sono tornati con pagine nuove.

## Moduli

| Modulo       | File                               | ID              | Label              |
| ------------ | ---------------------------------- | --------------- | ------------------ |
| App          | [app.md](app.md)                   | `IOS-001`…`019`, `IOS-043`…`045`, `IOS-100` | `mod:app`          |
| Home         | [home.md](home.md)                 | `IOS-020`…`029` | `mod:home`         |
| Nutrizione   | [nutrizione.md](nutrizione.md)     | `IOS-030`…`039` | `mod:nutrizione`   |
| Torrent      | [torrent.md](torrent.md)           | `IOS-070`…`079` | `mod:torrent`      |
| Impostazioni | [impostazioni.md](impostazioni.md) | `IOS-090`…`099` | `mod:impostazioni` |

Un solo prefisso, `IOS`, con un blocco di numeri per modulo. Gli ID non si
riusano.

## Stati dei requisiti

`proposto` → `pianificato (#issue)` → `in corso (#issue)` → `fatto (#PR)`,
oppure `rimosso`. Gli ID non si riusano.
