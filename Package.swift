// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Ron1nOS",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    // xtool vuole un solo prodotto libreria: l'app.
    .library(name: "Ron1nOS", targets: ["Ron1nOS"])
  ],
  targets: [
    // Interfaccia SwiftUI. Su Linux compila vuota (#if canImport(SwiftUI)).
    .target(name: "Ron1nOS", dependencies: ["Ron1nKit"]),
    // Logica senza SwiftUI: client dell'API, modelli e testi. Gira anche su
    // Linux, dove la provano i test.
    .target(name: "Ron1nKit"),
    .testTarget(name: "Ron1nKitTests", dependencies: ["Ron1nKit"]),
  ]
)
