# CLAUDE.md

App iOS di ron1nOS. Documentazione, commenti e testi dell'interfaccia in
italiano.

- Niente Mac e niente Xcode: il progetto è un pacchetto SwiftPM che xtool
  compila su Linux (`Package.swift`, `xtool.yml`). Non aggiungere progetti
  `.xcodeproj` né dipendenze che richiedono Xcode.
- La compilazione avviene sempre in un container, e l'app la compila sempre
  xtool: la CI usa `swift:6.4.1-noble` (formato, lint, build e test della
  logica), il builder sul server usa xtool per l'IPA. Sul computer di
  sviluppo `swift build` può non partire (manca la libc): non cercare di
  ripararlo, controlla la CI.
- La build dell'IPA gira sul server con il builder dell'hub ron1n
  (`infra/ios`, spec IOSB). La CI su GitHub fa formato, lint, build e test
  su Linux.
- La logica sta in `Sources/Ron1nKit` (Foundation, niente SwiftUI) con i
  test in `Tests/Ron1nKitTests`: deve compilare e passare su Linux. In
  `Sources/Ron1nOS` solo SwiftUI, racchiuso in `#if canImport(SwiftUI)`.
- Stessa API della dashboard web: `/api/v1` di ron1nOS, descritta in
  `api/openapi.yaml` di quel repo. Una funzione nuova che serve all'app va
  prima nell'API, non duplicata qui.
- Stile ron1nOS (IOS-043): nero, vetro neutro e una tinta per modulo
  (`Modulo` e `Palette` in Ron1nKit: Nutrizione verde, Server azzurro,
  Torrent ambra, Impostazioni ardesia). La tinta va su tessere, anelli,
  barre, azione principale e voce attiva della barra; il resto è neutro. Il
  rosso `#FF2A2A` resta marchio e allarme. Numeri in monospazio. Componenti
  in `Componenti.swift`, token in `Stile.swift`: card a 20, tessere e foto
  a 12, azioni a capsula, spazi da 4. Movimento con `Stile.molla`, sempre
  con la variante per Riduci movimento. Le azioni di una pagina vanno in
  basso con `azioniInBasso` e `AzioneBarra` (IOS-044), non nella barra in
  alto; i pulsanti usano `StilePremuto` (stretta e colpetto), i dati nuovi
  si assegnano dentro `withAnimation(Stile.molla)`. Testi brevi e calmi, niente punti
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
- Per disegnare o rifinire una schermata c'è anche `mobile-app-ui-design`
  (`.agents/skills/`, griglia da 8, zona del pollice, stati vuoti, bersagli
  da 44pt, gerarchia dei valori). Dove non concorda con lo stile ron1nOS
  vince lo stile: tema scuro, una tinta per modulo, rosso per marchio e
  allarmi, numeri in monospazio, testi calmi.
- Altre skill in `.agents/skills/`: `ios-design` (HIG e anti-slop) e
  quelle di Emil Kowalski per il movimento (`animate`,
  `review-animations`, `gestures`, `write-swift`…). Sono pensate anche per
  il web: si prende il principio, non il codice CSS.
