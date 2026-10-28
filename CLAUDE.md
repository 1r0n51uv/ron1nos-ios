# CLAUDE.md

App iOS di ron1nOS. Documentazione, commenti e testi dell'interfaccia in
italiano.

- Niente Mac e niente Xcode: il progetto è un pacchetto SwiftPM che xtool
  compila su Linux (`Package.swift`, `xtool.yml`). Non aggiungere progetti
  `.xcodeproj` né dipendenze che richiedono Xcode.
- La build dell'IPA gira sul server con il builder dell'hub ron1n
  (`infra/ios`, spec IOSB). La CI su GitHub fa formato, lint, build e test
  su Linux.
- La logica sta in `Sources/Ron1nKit` (Foundation, niente SwiftUI) con i
  test in `Tests/Ron1nKitTests`: deve compilare e passare su Linux. In
  `Sources/Ron1nOS` solo SwiftUI, racchiuso in `#if canImport(SwiftUI)`.
- Stessa API della dashboard web: `/api/v1` di ron1nOS, descritta in
  `api/openapi.yaml` di quel repo. Una funzione nuova che serve all'app va
  prima nell'API, non duplicata qui.
- Stile ron1nOS: nero, vetro, un solo accento rosso `#FF2A2A` usato come
  segnale, numeri in monospazio. Testi brevi e calmi, niente punti
  esclamativi né emoji, separatore `·`.
- Ogni PR porta i suoi test. Non disattivare né saltare test per far
  passare la CI.
- Ogni PR aggiunge in cima a `CHANGELOG.md` la sezione
  `## 0.1.N · AAAA-MM-GG`, con N = commit di main + 1, e righe su cosa
  cambia per chi usa l'app: diventano le note della versione su SideStore.
- Branch con l'id del requisito, per esempio `ios-001-app-prova-xtool`.
- Per rivedere un'interfaccia o una PR con UI usa la skill `apple-design`
  in `.claude/skills/`. Dove non concorda con lo stile ron1nOS (per esempio
  il tema solo scuro) vince lo stile. Si aggiorna con
  `npx skills update -p`.
