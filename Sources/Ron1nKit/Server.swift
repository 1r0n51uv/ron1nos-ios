/// Le risorse del server lette da Glances, da `GET /api/v1/server/stats`
/// (modulo Server di ron1nOS).
public struct StatoServer: Decodable, Equatable, Sendable {
  /// Percentuali da 0 a 100.
  public let cpu: Double
  public let ram: Double
  public let disk: Double
  /// °C; assente senza sensore.
  public let tempC: Double?
  public let uptimeSec: Int
  public let net: Rete?
  /// Solo quelli in esecuzione; assente senza socket Docker.
  public let containers: [Container]?

  public init(
    cpu: Double, ram: Double, disk: Double, tempC: Double? = nil, uptimeSec: Int, net: Rete? = nil,
    containers: [Container]? = nil
  ) {
    self.cpu = cpu
    self.ram = ram
    self.disk = disk
    self.tempC = tempC
    self.uptimeSec = uptimeSec
    self.net = net
    self.containers = containers
  }

  public struct Rete: Decodable, Equatable, Sendable {
    public let rxBps: Double
    public let txBps: Double

    public init(rxBps: Double, txBps: Double) {
      self.rxBps = rxBps
      self.txBps = txBps
    }
  }

  public struct Container: Decodable, Equatable, Sendable {
    public let name: String
    /// Percentuale di un core: può superare 100.
    public let cpu: Double
    public let memBytes: Double

    public init(name: String, cpu: Double, memBytes: Double) {
      self.name = name
      self.cpu = cpu
      self.memBytes = memBytes
    }
  }

  /// Da questa soglia una risorsa si segna in rosso, come sul sito (SRV-005).
  public static let soglia = 80.0
  /// Da questa temperatura compare la pillola `CPU a 88 °C`.
  public static let sogliaTemperatura = 85.0

  /// I tre anelli della pagina Server (IOS-080): CPU, RAM, SSD.
  public var anelli: [Risorsa] {
    [("CPU", cpu), ("RAM", ram), ("SSD", disk)].map { nome, valore in
      Risorsa(
        nome: nome, valore: max(0, min(1, valore / 100)), testo: Formato.percento(valore),
        segnale: valore >= StatoServer.soglia)
    }
  }

  /// "CPU a 88 °C" da 85 °C in su.
  public var caldo: String? {
    guard let tempC, tempC >= StatoServer.sogliaTemperatura else { return nil }
    return "CPU a \(Formato.numero(tempC)) °C"
  }

  /// "52 °C · 41 g": la temperatura si omette senza sensore.
  public var temperaturaEUptime: String {
    [tempC.map { "\(Formato.numero($0)) °C" }, Formato.acceso(uptimeSec)]
      .compactMap { $0 }.joined(separator: " · ")
  }

  /// "↓ 12,4 MB/s · ↑ 800 kB/s".
  public var rete: String? {
    net.map { "↓ \(Formato.velocita($0.rxBps)) · ↑ \(Formato.velocita($0.txBps))" }
  }

  /// I container che consumano di più: CPU, poi memoria.
  public func piuPesanti(_ quanti: Int = 3) -> [Container] {
    let ordinati = (containers ?? []).sorted {
      $0.cpu != $1.cpu ? $0.cpu > $1.cpu : $0.memBytes > $1.memBytes
    }
    return Array(ordinati.prefix(quanti))
  }

  /// CPU, RAM e disco: nome, valore da 0 a 1 per la barra, testo, segnale.
  public var risorse: [Risorsa] {
    [("CPU", cpu), ("RAM", ram), ("Disco", disk)].map { nome, valore in
      Risorsa(
        nome: nome, valore: max(0, min(1, valore / 100)), testo: Formato.percento(valore),
        segnale: valore >= StatoServer.soglia)
    }
  }

  /// "52 °C · acceso da 3 g · ↓ 1,2 MB/s ↑ 80 kB/s", solo le parti che ci sono.
  public var riepilogo: String {
    [
      tempC.map { "\(Formato.numero($0)) °C" },
      "acceso da \(Formato.acceso(uptimeSec))",
      net.map { "↓ \(Formato.velocita($0.rxBps)) ↑ \(Formato.velocita($0.txBps))" },
    ].compactMap { $0 }.joined(separator: " · ")
  }
}

/// Una riga della card Server.
public struct Risorsa: Equatable, Sendable {
  public let nome: String
  public let valore: Double
  public let testo: String
  public let segnale: Bool
}

extension APIClient {
  /// `GET /server/stats`.
  public func statoServer() async throws(APIError) -> StatoServer {
    try await get("server/stats")
  }
}
