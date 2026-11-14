import Foundation

/// Le aree dell'app (IOS-043): ognuna ha la sua tinta e il suo simbolo, gli
/// stessi nella barra in basso, nelle intestazioni e nelle tessere.
public enum Modulo: String, CaseIterable, Sendable {
  case home, nutrizione, server, torrent, impostazioni

  /// La tinta del modulo. La Home non ne ha una sua: usa il rosso del marchio.
  public var tinta: ColoreRGB {
    switch self {
    case .home: Palette.brandTesto
    case .nutrizione: Palette.nutrizione
    case .server: Palette.server
    case .torrent: Palette.torrent
    case .impostazioni: Palette.impostazioni
    }
  }

  /// Il simbolo SF del modulo.
  public var simbolo: String {
    switch self {
    case .home: "square.grid.2x2.fill"
    case .nutrizione: "fork.knife"
    case .server: "cpu.fill"
    case .torrent: "arrow.down.circle.fill"
    case .impostazioni: "gearshape.fill"
    }
  }
}
