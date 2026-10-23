/// Le risorse del server lette da Glances, da `GET /api/v1/server/stats`
/// (modulo Server di ron1nOS). L'app non usa i container.
public struct StatoServer: Decodable, Equatable, Sendable {
  /// Percentuali da 0 a 100.
  public let cpu: Double
  public let ram: Double
  public let disk: Double
  /// °C; assente senza sensore.
  public let tempC: Double?
  public let uptimeSec: Int
  public let net: Rete?

  public init(
    cpu: Double, ram: Double, disk: Double, tempC: Double? = nil, uptimeSec: Int, net: Rete? = nil
  ) {
    self.cpu = cpu
    self.ram = ram
    self.disk = disk
    self.tempC = tempC
    self.uptimeSec = uptimeSec
    self.net = net
  }

  public struct Rete: Decodable, Equatable, Sendable {
    public let rxBps: Double
    public let txBps: Double

    public init(rxBps: Double, txBps: Double) {
      self.rxBps = rxBps
      self.txBps = txBps
    }
  }

  /// Oltre questa soglia una risorsa si segna in rosso.
  public static let soglia = 90.0

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
