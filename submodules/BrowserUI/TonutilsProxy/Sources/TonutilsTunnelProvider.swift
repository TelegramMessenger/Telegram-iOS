//
//  Created by Adam Stragner
//

import NetworkExtension

@available(iOS 13.0, *)
open class TonproxyTunnelProvider: NEPacketTunnelProvider {
    // MARK: Open

    open var preferredPort: UInt16 {
        9090
    }

    open override func startTunnel(options: [String: NSObject]? = nil) async throws {
        let tunnel = TonutilsProxy.shared
        let parameters = try await tunnel.start(preferredPort)

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: parameters.host)

        settings.mtu = NSNumber(value: 1500)
        settings.ipv4Settings = NEIPv4Settings(
            addresses: ["127.0.0.1"],
            subnetMasks: ["255.255.255.255"]
        )

        settings.proxySettings = {
            let proxySettings = NEProxySettings()
            proxySettings.httpEnabled = true
            proxySettings.httpServer = NEProxyServer(
                address: parameters.host,
                port: Int(parameters.port)
            )
            
            proxySettings.httpsEnabled = false
            proxySettings.excludeSimpleHostnames = false
            proxySettings.matchDomains = TonutilsProxy.SupportedDomain.allCases.map({
                ".\($0.rawValue)"
            })

            proxySettings.autoProxyConfigurationEnabled = true
            return proxySettings
        }()

        do {
            try await setTunnelNetworkSettings(settings)
        } catch {
            await _stop()
            throw TonutilsTunnelError.unableUpdateNetworkSettings(underlyingError: error)
        }
    }

    open override func stopTunnel(with reason: NEProviderStopReason) async {
        await _stop()
    }

    open override func handleAppMessage(_ messageData: Data) async -> Data? {
        if let string = String(data: messageData, encoding: .utf8) {
            print("[TonproxyTunnelProvider]: Did handle a message - \(string)")
        }

        return nil
    }

    // MARK: Private

    private func _stop() async {
        let tunnel = TonutilsProxy.shared
        do {
            try await tunnel.stop()
        } catch {
            print("\(error)")
        }
    }
}
