# ron1nOS iOS

L'app iOS di [ron1nOS](https://github.com/1r0n51uv/ron1nOS), la dashboard
dell'homelab ron1n. Usa la stessa API `/api/v1` della dashboard web, su
`https://home.ron1n.space`, dietro Cloudflare Access.

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

Poi, da Safari sul telefono, `https://ios.ron1n.space/Ron1nOS.ipa` e
**Condividi → SideStore**.

## Accesso

Il backend sta dietro Cloudflare Access, e l'app entra con il service
token `ron1nos-ios`. Sul server è in `~/.cf-home/ron1nos-ios.json`:
copia il contenuto, poi nell'app tocca **Accesso → Incolla → Salva**. Il
token resta nel Portachiavi del telefono e scade dopo un anno.

Con il login di ron1nOS acceso serve anche il token di ron1nOS: nella
dashboard apri **Impostazioni › App iOS**, crea un token, copialo e
nell'app tocca **Accesso**, poi **Incolla → Salva** sotto "Token ron1nOS".
Vale finché non lo revochi dalla dashboard.
