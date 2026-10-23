# ron1nOS iOS

L'app iOS di [ron1nOS](https://github.com/1r0n51uv/ron1nOS), la dashboard
dell'homelab ron1n. Usa la stessa API `/api/v1` della dashboard web, via
Tailscale.

Si compila su Linux con [xtool](https://github.com/xtool-org/xtool), sul
server di casa, e si installa con SideStore: niente Mac. Builder e pagina
di download sono nell'hub, in
[`infra/ios`](https://github.com/1r0n51uv/ron1n/tree/main/infra/ios).

Specifiche in [`docs/specs/`](docs/specs/).

## Sviluppo

Serve solo Swift 6.4 per Linux (o il container `swift:6.4.1-noble`):

```sh
swift format --in-place -r Sources Tests Package.swift   # formato
swift format lint --strict -r Sources Tests Package.swift
swift build && swift test                                # logica, su Linux
```

Su Linux `Sources/Ron1nOS` (SwiftUI) compila vuoto: l'interfaccia si
compila solo con l'SDK iOS, cioè con il builder sul server:

```sh
cd /opt/ron1n
docker compose -f infra/ios/compose.yaml run --rm ios-builder build
```

Poi, dal telefono nella tailnet, `https://ios.ron1n.home/Ron1nOS.ipa` e
**Condividi → SideStore**.
