import Foundation

/// La root della CA locale di Caddy sul server (infra/proxy dell'hub ron1n,
/// "Caddy Local Authority - 2026 ECC Root"), in DER. È pubblica: è la stessa
/// che si scarica da ca.ron1n.home. Se iOS non si fida da solo del
/// certificato, l'app la usa come ancora, solo per i nomi `ron1n.home`
/// (IOS-002): catena e nome host si verificano comunque per intero.
///
/// SHA-256 a4e2988799c98c6d5e00961e1272af3f04d39e683767321aeeab0b1309c8c626,
/// valida fino al 31 agosto 2036. Se Caddy rigenera la CA va aggiornata qui.
public enum CertificatoCaddy {
  static let rootBase64 =
    ""
    + "MIIBozCCAUmgAwIBAgIQSy+XT049yLAhb9CdqDDOszAKBggqhkjOPQQDAjAwMS4wLAYDVQQDEyVDYWRkeSBMb2NhbCBBdXRo"
    + "b3JpdHkgLSAyMDI2IEVDQyBSb290MB4XDTI2MTAyMzEzMjc1MFoXDTM2MDgzMTEzMjc1MFowMDEuMCwGA1UEAxMlQ2FkZHkg"
    + "TG9jYWwgQXV0aG9yaXR5IC0gMjAyNiBFQ0MgUm9vdDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABKxvvuYSklooBJxpdDWB"
    + "vgKPNiljPCiSKjztsj1HSX9ziOdl6yxZBsVay7e3auJYJ6KTBpd/4kfHBDnieA0iEamjRTBDMA4GA1UdDwEB/wQEAwIBBjAS"
    + "BgNVHRMBAf8ECDAGAQH/AgEBMB0GA1UdDgQWBBQOkM/5TH2kE/NiJ4D/LKtM5vdOLjAKBggqhkjOPQQDAgNIADBFAiA8hzU5"
    + "DrafhmyE6TYj28AAn05zPyU6M0zAXjpvS9vNfwIhANHCWB1JgPcgkMGJ0qlFOTNyip3u2+ijr3Kaspy+esTr"

  public static var rootDER: Data? { Data(base64Encoded: rootBase64) }

  /// Vale solo per `ron1n.home` e i suoi sottodomini.
  public static func vale(per host: String) -> Bool {
    let nome = host.lowercased()
    return nome == "ron1n.home" || nome.hasSuffix(".ron1n.home")
  }
}
