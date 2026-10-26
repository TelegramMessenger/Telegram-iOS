import XCTest
import TelegramCore
@testable import SettingsUI

final class ProxyServerSettingsControllerTests: XCTestCase {
    private let secretHex = "000102030405060708090a0b0c0d0e0f"

    private var webSecret: Data {
        return Data((0 ..< 16).map(UInt8.init))
    }

    func testModeDerivationCoversEveryConnection() {
        XCTAssertEqual(proxyServerSettingsControllerMode(for: .socks5(username: "u", password: "p")), .socks5)
        XCTAssertEqual(proxyServerSettingsControllerMode(for: .mtp(secret: Data(repeating: 1, count: 16))), .mtp)
        XCTAssertEqual(proxyServerSettingsControllerMode(for: .web(secret: self.webSecret, path: "")), .web)
    }

    /// Regression: a saved WEB server used to load as .mtp and be rewritten to .mtp on save.
    func testEditingAWebServerWithoutChangesPreservesIt() throws {
        let original = ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: self.webSecret, path: ""))
        let state = ProxyServerSettingsControllerState(
            mode: proxyServerSettingsControllerMode(for: original.connection),
            host: original.host,
            port: "\(original.port)",
            username: "",
            password: "",
            secret: webProxySecretString(self.webSecret)
        )
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved, original)
        XCTAssertEqual(saved.connection, .web(secret: self.webSecret, path: ""))
    }

    /// The editor's server field carries the whole `host/base-path` address, so a
    /// prefixed relay survives a no-change edit too (BASE_PATH.md §1).
    func testEditingAWebServerWithABasePathPreservesIt() throws {
        let original = ProxyServerSettings(host: "proxy.example.com", port: 443, connection: .web(secret: self.webSecret, path: "dobry-cola-super-app"))
        let state = ProxyServerSettingsControllerState(
            mode: proxyServerSettingsControllerMode(for: original.connection),
            host: try XCTUnwrap(original.webProxyAddress),
            port: "\(original.port)",
            username: "",
            password: "",
            secret: webProxySecretString(self.webSecret)
        )
        XCTAssertTrue(state.isComplete)
        XCTAssertEqual(proxyServerSettings(with: state), original)
    }

    func testWebModeAcceptsAnAddressWithABasePath() throws {
        let state = ProxyServerSettingsControllerState(mode: .web, host: "PROXY.EXAMPLE.COM/My-App/", port: "", username: "", password: "", secret: self.secretHex)
        XCTAssertTrue(state.isComplete)
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved.host, "proxy.example.com")
        XCTAssertEqual(saved.webProxyAddress, "proxy.example.com/My-App")
    }

    /// Regression: switching a base-path WEB server to another mode used to save a SOCKS5
    /// or MTProxy entry whose host still contained the `/base-path`.
    func testSwitchingAwayFromWebDropsTheBasePath() throws {
        let web = ProxyServerSettingsControllerState(mode: .web, host: "proxy.example.com/My-App", port: "443", username: "", password: "", secret: self.secretHex)
        for mode in [ProxyServerSettingsControllerMode.socks5, .mtp] {
            let switched = web.withMode(mode)
            XCTAssertEqual(switched.host, "proxy.example.com", "\(mode)")
            XCTAssertFalse(switched.host.contains("/"), "\(mode)")
        }
        // Staying on .web keeps it, and a bare host is untouched either way.
        XCTAssertEqual(web.withMode(.web).host, "proxy.example.com/My-App")
        let plain = ProxyServerSettingsControllerState(mode: .socks5, host: "proxy.example.com", port: "1080", username: "u", password: "p", secret: "")
        XCTAssertEqual(plain.withMode(.mtp).host, "proxy.example.com")
    }

    func testWebModeIgnoresPortAndPinsIt() throws {
        let state = ProxyServerSettingsControllerState(mode: .web, host: "proxy.example.com", port: "", username: "", password: "", secret: self.secretHex)
        XCTAssertTrue(state.isComplete)
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved.port, 443)
    }

    func testWebModeNormalizesTheHost() throws {
        let state = ProxyServerSettingsControllerState(mode: .web, host: "PROXY.EXAMPLE.COM", port: "", username: "", password: "", secret: self.secretHex)
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved.host, "proxy.example.com")
    }

    func testWebModeAcceptsADdPaddedSecret() throws {
        let state = ProxyServerSettingsControllerState(mode: .web, host: "proxy.example.com", port: "", username: "", password: "", secret: "dd" + self.secretHex)
        XCTAssertTrue(state.isComplete)
        XCTAssertNotNil(proxyServerSettings(with: state))
    }

    /// MTProxySecret.parse accepts these; WebProxyConfiguration.isValidSecret does not.
    func testWebModeRejectsSecretsTheTransportCannotUse() {
        for secret in ["ee" + self.secretHex, "00", ""] {
            let state = ProxyServerSettingsControllerState(mode: .web, host: "proxy.example.com", port: "", username: "", password: "", secret: secret)
            XCTAssertFalse(state.isComplete, "expected \(secret) to be rejected")
            XCTAssertNil(proxyServerSettings(with: state))
        }
    }

    func testWebModeRejectsNonCanonicalHosts() {
        for host in ["proxy.example.com:8443", "user@proxy.example.com", "127.0.0.1", "", "proxy.example.com//a", "proxy.example.com/a.b", "/slug"] {
            let state = ProxyServerSettingsControllerState(mode: .web, host: host, port: "", username: "", password: "", secret: self.secretHex)
            XCTAssertFalse(state.isComplete, "expected \(host) to be rejected")
            XCTAssertNil(proxyServerSettings(with: state))
        }
    }

    func testSocks5AndMtpModesStillRequireAPort() {
        let socks = ProxyServerSettingsControllerState(mode: .socks5, host: "proxy.example.com", port: "", username: "u", password: "p", secret: "")
        XCTAssertFalse(socks.isComplete)
        let mtp = ProxyServerSettingsControllerState(mode: .mtp, host: "proxy.example.com", port: "", username: "", password: "", secret: self.secretHex)
        XCTAssertFalse(mtp.isComplete)
    }

    func testMtpModeIsUnaffected() throws {
        let state = ProxyServerSettingsControllerState(mode: .mtp, host: "proxy.example.com", port: "443", username: "", password: "", secret: self.secretHex)
        let saved = try XCTUnwrap(proxyServerSettings(with: state))
        XCTAssertEqual(saved.host, "proxy.example.com")
        XCTAssertEqual(saved.port, 443)
        guard case .mtp = saved.connection else {
            return XCTFail("expected .mtp, got \(saved.connection)")
        }
    }
}
