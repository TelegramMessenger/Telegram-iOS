import XCTest
@testable import TelegramCore

final class ProxySettingsTests: XCTestCase {
    func testExistingProxyDiscriminatorsRemainStable() throws {
        let socks = ProxyServerConnection.socks5(username: "user", password: "pass")
        let mtp = ProxyServerConnection.mtp(secret: Data(repeating: 1, count: 16))
        XCTAssertEqual(try discriminator(socks), 0)
        XCTAssertEqual(try discriminator(mtp), 1)

        let oldSocks = Data(#"{"_t":0,"username":"user","password":"pass"}"#.utf8)
        let oldMtp = Data(#"{"_t":1,"secret":"AAECAwQFBgcICQoLDA0ODw=="}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: oldSocks), socks)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: oldMtp), .mtp(secret: Data(0 ..< 16)))

        let unknown = Data(#"{"_t":999}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: unknown), .socks5(username: nil, password: nil))
    }

    func testWebProxyRoundTrip() throws {
        let secret = Data((0 ..< 16).map(UInt8.init))
        let settings = ProxyServerSettings(host: "proxy.example.com", port: 8443, connection: .web(secret: secret, path: ""))
        XCTAssertEqual(settings.port, 443)
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerSettings.self, from: data), settings)
        XCTAssertEqual(try discriminator(settings.connection), 2)

        let mtSettings = settings.mtProxySettings
        XCTAssertEqual(mtSettings.ip, "proxy.example.com")
        XCTAssertEqual(mtSettings.port, 443)
        XCTAssertEqual(mtSettings.secret, secret)
        XCTAssertTrue(mtSettings.webProxy)
    }

    func testWebProxyWithBasePathUsesItsOwnDiscriminator() throws {
        let secret = Data((0 ..< 16).map(UInt8.init))
        let rooted = ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: secret, path: ""))
        let prefixed = ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: secret, path: "dobry-cola-super-app"))

        XCTAssertEqual(try discriminator(prefixed.connection), 3)
        XCTAssertNotEqual(rooted, prefixed)
        XCTAssertNotEqual(prefixed, ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: secret, path: "other-app")))

        let data = try JSONEncoder().encode(prefixed)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerSettings.self, from: data), prefixed)
        XCTAssertEqual(prefixed.port, 443)
        XCTAssertEqual(prefixed.webProxyAddress, "proxy.example.com/dobry-cola-super-app")
        XCTAssertEqual(rooted.webProxyAddress, "proxy.example.com")

        let legacy = Data(#"{"_t":2,"secret":"AAECAwQFBgcICQoLDA0ODw=="}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(ProxyServerConnection.self, from: legacy), .web(secret: secret, path: ""))

        XCTAssertEqual(prefixed.mtProxySettings.ip, "proxy.example.com")
        XCTAssertEqual(prefixed.mtProxySettings.port, 443)
    }

    func testWebProxyValidationAndNormalization() throws {
        let settings = try XCTUnwrap(makeWebProxySettings(address: "PROXY.EXAMPLE.COM", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertEqual(settings.host, "proxy.example.com")
        XCTAssertEqual(settings.port, 443)
        XCTAssertNil(makeWebProxySettings(address: "proxy.example.com:8443", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(makeWebProxySettings(address: "proxy.example.com", secret: "00"))

        // Hand entry takes a plain secret with a base path. Only a *link* must carry the
        // marked form - see testWebProxyLinksCarryTheBasePath - because only a link can be
        // handed to a client that does not understand base paths.
        let prefixed = try XCTUnwrap(makeWebProxySettings(address: "Proxy.Example.COM/My-App/", secret: "000102030405060708090a0b0c0d0e0f"))
        XCTAssertEqual(prefixed.host, "proxy.example.com")
        XCTAssertEqual(prefixed.webProxyAddress, "proxy.example.com/My-App")
        XCTAssertNil(makeWebProxySettings(address: "proxy.example.com//My-App", secret: "000102030405060708090a0b0c0d0e0f"))
    }

    func testWebProxyLinksAreStrictAndCanonical() throws {
        let secret = "000102030405060708090a0b0c0d0e0f"
        let settings = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=PROXY.EXAMPLE.COM&secret=\(secret)"))
        XCTAssertEqual(settings.host, "proxy.example.com")
        XCTAssertEqual(settings.port, 443)
        XCTAssertEqual(webProxySettingsLink(settings), "https://t.me/webproxy?server=proxy.example.com&secret=\(secret)")
        XCTAssertEqual(parseWebProxySettingsLink(try XCTUnwrap(webProxySettingsLink(settings))), settings)

        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?server=proxy.example.com&server=other.example.com&secret=\(secret)"))
        // Unknown items and a trailing "&" are ignored rather than making the link dead.
        XCTAssertEqual(parseWebProxySettingsLink("https://t.me/webproxy?server=proxy.example.com&secret=\(secret)&extra=1"), settings)
        XCTAssertEqual(parseWebProxySettingsLink("https://t.me/webproxy?server=proxy.example.com&secret=\(secret)&"), settings)
        XCTAssertNil(parseWebProxySettingsLink("https://t.me:8443/webproxy?server=proxy.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://user@t.me/webproxy?server=proxy.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2F%2Fpath&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2Fpa.th&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=00"))

        let idna = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=BÜCHER.example&secret=\(secret)"))
        XCTAssertEqual(idna.host, "xn--bcher-kva.example")
    }

    func testWebProxyLinkIsDistinguishableFromAnMtpLink() throws {
        let secret = "000102030405060708090a0b0c0d0e0f"
        let web = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=\(secret)"))
        guard case .web = web.connection else {
            return XCTFail("expected .web, got \(web.connection)")
        }
        // A regular proxy link must never resolve through the WEB parser.
        XCTAssertNil(parseWebProxySettingsLink("tg://proxy?server=proxy.example.com&port=443&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/proxy?server=proxy.example.com&port=443&secret=\(secret)"))
    }

    func testWebProxyLinkAcceptsADdPaddedSecret() throws {
        let secret = "dd000102030405060708090a0b0c0d0e0f"
        let web = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=\(secret)"))
        XCTAssertEqual(web.connection, .web(secret: Data([0xdd] + (0 ..< 16).map(UInt8.init)), path: ""))
    }

    /// ANDROID.md: "`host` is accepted as a legacy input alias, but generated links
    /// always use `server`." Real deployments emit the `host` form.
    func testWebProxyLinkAcceptsHostAsALegacyAliasForServer() throws {
        let secret = "dddeb5753b0a4ee7043f5ad53c9da03cee"
        let viaHost = try XCTUnwrap(parseWebProxySettingsLink("https://t.me/webproxy?host=tproxy.remindbot.ai&secret=\(secret)"))
        XCTAssertEqual(viaHost.host, "tproxy.remindbot.ai")
        XCTAssertEqual(viaHost.port, 443)
        XCTAssertEqual(viaHost.connection, .web(secret: try XCTUnwrap(parseWebProxySecret(secret)), path: ""))
        XCTAssertEqual(webProxySecretString(try XCTUnwrap(parseWebProxySecret(secret))), secret)

        let viaServer = try XCTUnwrap(parseWebProxySettingsLink("https://t.me/webproxy?server=tproxy.remindbot.ai&secret=\(secret)"))
        XCTAssertEqual(viaHost, viaServer)

        // tg:// form too.
        XCTAssertEqual(parseWebProxySettingsLink("tg://webproxy?host=tproxy.remindbot.ai&secret=\(secret)"), viaHost)

        // Emitted links still use `server`, never `host`.
        XCTAssertEqual(webProxySettingsLink(viaHost), "https://t.me/webproxy?server=tproxy.remindbot.ai&secret=\(secret)")

        // The alias must not loosen the one-address rule the other tests pin.
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?host=a.example.com&server=b.example.com&secret=\(secret)"))
        XCTAssertNil(parseWebProxySettingsLink("https://t.me/webproxy?host=a.example.com&host=b.example.com&secret=\(secret)"))
        XCTAssertEqual(parseWebProxySettingsLink("https://t.me/webproxy?host=a.example.com&secret=\(secret)&extra=1")?.host, "a.example.com")
    }

    func testWebProxyLinksCarryTheBasePath() throws {
        let plain = "000102030405060708090a0b0c0d0e0f"
        let marked = "cAABAgMEBQYHCAkKCwwNDg8"
        let settings = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=PROXY.EXAMPLE.COM%2Fdobry-cola-super-app&secret=\(marked)"))
        XCTAssertEqual(settings.webProxyAddress, "proxy.example.com/dobry-cola-super-app")
        XCTAssertEqual(settings.port, 443)
        XCTAssertEqual(settings.connection, .web(secret: Data(0 ..< 16), path: "dobry-cola-super-app"))
        XCTAssertEqual(
            webProxySettingsLink(settings),
            "https://t.me/webproxy?server=proxy.example.com%2Fdobry-cola-super-app&secret=\(marked)"
        )
        XCTAssertEqual(parseWebProxySettingsLink(try XCTUnwrap(webProxySettingsLink(settings))), settings)

        let cased = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2FMy-App&secret=\(marked)"))
        XCTAssertEqual(cased.webProxyAddress, "proxy.example.com/My-App")
        XCTAssertNotEqual(cased, settings)

        // A path-bearing link must use the marked form; the plain hex there is rejected so
        // that no link exists which an older client would take for a pathless proxy on an
        // empty host (BASE_PATH.md §3).
        XCTAssertNil(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com%2Fdobry-cola-super-app&secret=\(plain)"))
        // A root link keeps the plain secret, and still accepts the marked form.
        XCTAssertEqual(
            webProxySettingsLink(try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=proxy.example.com&secret=\(marked)"))),
            "https://t.me/webproxy?server=proxy.example.com&secret=\(plain)"
        )
    }

    /// Regression: `UrlHandling` had its own laxer loop, so a link carrying both `server`
    /// and `host` was rejected by the proxy editor and accepted from a chat, resolving to
    /// whichever came last. Both now share `parseWebProxyLinkQueryItems`.
    func testTheQueryRuleIsStrictForEveryEntryPoint() throws {
        let secret = "000102030405060708090a0b0c0d0e0f"
        let accepted = try XCTUnwrap(parseWebProxyLinkQueryItems([
            URLQueryItem(name: "server", value: "proxy.example.com"),
            URLQueryItem(name: "secret", value: secret)
        ]))
        XCTAssertEqual(accepted.host, "proxy.example.com")
        XCTAssertEqual(parseWebProxyLinkQueryItems([
            URLQueryItem(name: "host", value: "proxy.example.com"),
            URLQueryItem(name: "secret", value: secret)
        ])?.host, "proxy.example.com")

        // Unknown items are ignored: a tracking parameter, or the empty-name item
        // URLComponents produces for a trailing "&", must not make a shared link dead.
        for items in [
            [URLQueryItem(name: "server", value: "a.example.com"), URLQueryItem(name: "secret", value: secret), URLQueryItem(name: "extra", value: "1")],
            [URLQueryItem(name: "utm_source", value: "x"), URLQueryItem(name: "server", value: "a.example.com"), URLQueryItem(name: "secret", value: secret)],
            try XCTUnwrap(URLComponents(string: "tg://webproxy?server=a.example.com&secret=\(secret)&")?.queryItems)
        ] {
            XCTAssertEqual(parseWebProxyLinkQueryItems(items)?.host, "a.example.com", "\(items)")
        }

        // Duplicated or missing address/secret items are still rejected.
        for items in [
            [URLQueryItem(name: "server", value: "a.example.com"), URLQueryItem(name: "secret", value: secret), URLQueryItem(name: "host", value: "evil.example.com")],
            [URLQueryItem(name: "server", value: "a.example.com"), URLQueryItem(name: "server", value: "evil.example.com"), URLQueryItem(name: "secret", value: secret)],
            [URLQueryItem(name: "server", value: "a.example.com"), URLQueryItem(name: "secret", value: secret), URLQueryItem(name: "secret", value: secret)],
            [URLQueryItem(name: "server", value: "a.example.com")],
            [URLQueryItem(name: "secret", value: secret)],
            []
        ] {
            XCTAssertNil(parseWebProxyLinkQueryItems(items), "\(items)")
        }
    }

    /// The exact derivation `deploy/install.sh` performs, pinned by BASE_PATH.md §3.
    func testMarkedSecretVector() throws {
        let settings = try XCTUnwrap(parseWebProxySettingsLink("tg://webproxy?server=example.com%2Fphcf2vfe7zgbrslg&secret=cIVhlEBk_HMMv6RHNWLY7Fk"))
        XCTAssertEqual(settings.webProxyAddress, "example.com/phcf2vfe7zgbrslg")
        guard case let .web(secret, _) = settings.connection else {
            return XCTFail("expected .web, got \(settings.connection)")
        }
        XCTAssertEqual(webProxySecretString(secret), "8561944064fc730cbfa4473562d8ec59")
    }

    func testMarkedSecretDecoding() throws {
        // 0x70 || 16-byte secret, and 0x70 || dd || 16-byte secret.
        XCTAssertEqual(parseWebProxySecret("cAABAgMEBQYHCAkKCwwNDg8"), Data(0 ..< 16))
        XCTAssertEqual(parseWebProxySecret("cN0AAQIDBAUGBwgJCgsMDQ4P"), Data([0xdd] + (0 ..< 16).map(UInt8.init)))
        // Unmarked forms still decode as themselves.
        XCTAssertEqual(parseWebProxySecret("000102030405060708090a0b0c0d0e0f"), Data(0 ..< 16))
        XCTAssertEqual(parseWebProxySecret("AAECAwQFBgcICQoLDA0ODw"), Data(0 ..< 16))
        // 0xDD is never the marker: a 17-byte dd secret stays a 17-byte dd secret.
        XCTAssertEqual(parseWebProxySecret("dd000102030405060708090a0b0c0d0e0f")?.count, 17)
        // The transport carries neither an `ee` secret nor a stray marker with the wrong length.
        XCTAssertNil(parseWebProxySecret("ee000102030405060708090a0b0c0d0e0f"))
        XCTAssertNil(parseWebProxySecret("70000102030405060708090a0b0c0d"))
    }

    private func discriminator(_ connection: ProxyServerConnection) throws -> Int {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(connection)) as? [String: Any])
        return try XCTUnwrap(object["_t"] as? Int)
    }
}
