import Foundation

/// Single source of truth for the gramsrv backend.
///
/// This is the macOS counterpart of WebA's gramsrv mode (telegram-tt-master),
/// living in the telegram-ios submodule (TelegramCore) used by Telegram for
/// macOS (TelegramMessenger/telegram-macos):
/// - WebA: `loadLocalGramsrvServerInfo()` fetches `/owpengram/server-info` from
///   `location.origin` (web.tose.top) at startup, validates `dc_id`, registers the
///   server RSA key, and only then creates the TelegramClient (`set_dc` must happen
///   before the first `connect()`).
/// - macOS: `initializedNetwork` calls `GramsrvConfig.fetchServerInfo()` before the
///   first MTProto connection is created, registers the fetched RSA key into the
///   `MTContext`, and seeds DC 2 from the values below. The fetched key is also
///   passed to the Rust engine (the default engine on macOS) through the
///   `NetworkEngineFactory.makeEngine(context:isAppExtension:serverPublicKeys:)`
///   overload, because the Rust engine otherwise falls back to the compiled-in
///   defaults in `MTDatacenterAuthMessageService.m`.
///
/// The values below are the *fallback* used only when the server-info fetch fails.
/// They must never point at Telegram's official servers: no official DC address
/// and no official RSA key may ever appear here. A fallback is always logged
/// explicitly at the call site; there is no silent fallback to official Telegram.
enum GramsrvConfig {
    /// NOTE: gram.tose.top does NOT serve /owpengram/server-info (404); the
    /// endpoint lives on web.tose.top, which reverse-proxies it to gramsrv.
    static let serverInfoURL = URL(string: "https://web.tose.top/owpengram/server-info")!
    static let fallbackHost = "13.140.210.172"
    static let fallbackPort: Int = 2398
    static let dcId = 2
    static let apiId: Int32 = 2040
    /// api_hash is not validated by gramsrv (no app registry); 32 zeroes are the
    /// placeholder verified usable against gramsrv, same as WebA gramsrv mode
    /// (api_id / api_hash may be 0 / '' there).
    static let apiHash = "00000000000000000000000000000000"
    /// Same set WebA validates against (DC_IDS = [1, 2, 3, 4, 5]).
    static let supportedDcIds: Set<Int> = [1, 2, 3, 4, 5]

    /// Live RSA public key of the gramsrv server, fallback only. It is identical
    /// to the hardcoded keys in MTDatacenterAuthMessageService.m, so a failed
    /// fetch still handshakes with the current server. If the server rotates its
    /// key, a successful fetch picks the new one up without a client release.
    /// Fingerprint SHA1 7820e4d0… (verified 2026-11-10 from server-info).
    static let fallbackRsaPublicKeyPem = """
    -----BEGIN RSA PUBLIC KEY-----
    MIIBCgKCAQEA6tnthT4PbhIln8RVBOsYPTOlV0xx/NV0uKzdECUNCTQjegWccZFj
    CQhY1is8IXNwM8fHrKOIfiZFADRoX3ycr/+hybhWj90HjJG4Bw0HvBGOZjW2iyOu
    q9G8YZnK9rnbsX8mWP4A1998lkcfz6ThrfJ/o2t5oUKV7xXgTpqz46hCMEBFAEOJ
    aJ2cb1lDGj/WwM/BcB6kWix4TAHaiLdDJwwU28Jp49CQ8ZhhrA3E0+XwFyAdB5F7
    Jq0K7SDwpfs4bzfAwUmNtSS9A1eYoNrsUSHl+gIMbnM4J3YwASP4JQ+x/sqkncbC
    TLkC+ldj44f4W+u/dTb6ygigEnvcRtM3hQIDAQAB
    -----END RSA PUBLIC KEY-----
    """

    struct ServerInfo: Decodable {
        let dc_id: Int
        let rsa_public_key_pem: String
    }

    private static let cacheLock = NSLock()
    private static var cachedServerInfo: ServerInfo?

    private final class ServerInfoBox {
        var value: ServerInfo?
    }

    /// Fetch server-info synchronously. Called on the network-init queue, before
    /// the first MTProto connection exists — the same ordering WebA uses before
    /// `TelegramClient.connect()`. Returns the cached value on repeat calls and
    /// `nil` on any failure (network, non-200, bad JSON, unsupported dc_id, or a
    /// malformed RSA PEM). The caller must fall back to `dcId` /
    /// `fallbackRsaPublicKeyPem` and log that it did so.
    static func fetchServerInfo(timeout: TimeInterval = 10) -> ServerInfo? {
        cacheLock.lock()
        if let cached = cachedServerInfo {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        var request = URLRequest(url: serverInfoURL, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let semaphore = DispatchSemaphore(value: 0)
        let box = ServerInfoBox()
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let data = data,
                  let info = try? JSONDecoder().decode(ServerInfo.self, from: data),
                  supportedDcIds.contains(info.dc_id),
                  info.rsa_public_key_pem.contains("-----BEGIN RSA PUBLIC KEY-----"),
                  info.rsa_public_key_pem.contains("-----END RSA PUBLIC KEY-----") else {
                return
            }
            box.value = info
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout + 2)

        if let fetched = box.value {
            cacheLock.lock()
            cachedServerInfo = fetched
            cacheLock.unlock()
            return fetched
        }
        return nil
    }
}
