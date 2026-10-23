# Specifiche di ron1nOS iOS

L'app iOS di ron1nOS: le stesse funzioni della dashboard web, sulla stessa
API `/api/v1` del backend ron1nOS. Il flusso (specifica → issue → PR →
build) è quello di [ron1n](https://github.com/1r0n51uv/ron1n/blob/main/docs/flusso-sviluppo.md);
la build gira sul server di casa con xtool
([IOSB](https://github.com/1r0n51uv/ron1n/blob/main/docs/specs/ios-build.md)).

## Moduli

| Modulo | File             | Prefisso ID | Label     |
| ------ | ---------------- | ----------- | --------- |
| App    | [app.md](app.md) | `IOS`       | `mod:app` |

## Stati dei requisiti

`proposto` → `pianificato (#issue)` → `in corso (#issue)` → `fatto (#PR)`,
oppure `rimosso`. Gli ID non si riusano.
