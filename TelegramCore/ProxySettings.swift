import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public final class ProxySettings: PreferencesEntry, Equatable {
    public let host: String
    public let port: Int32
    public let username: String?
    public let password: String?
    public let useForCalls: Bool
    public init(host: String, port: Int32, username: String?, password: String?, useForCalls: Bool) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.useForCalls = useForCalls
    }
    
    public init(decoder: PostboxDecoder) {
        self.host = decoder.decodeStringForKey("host", orElse: "")
        self.port = decoder.decodeInt32ForKey("port", orElse: 0)
        self.username = decoder.decodeOptionalStringForKey("username")
        self.password = decoder.decodeOptionalStringForKey("password")
        self.useForCalls = decoder.decodeInt32ForKey("useForCalls", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.host, forKey: "host")
        encoder.encodeInt32(self.port, forKey: "port")
        if let username = self.username {
            encoder.encodeString(username, forKey: "username")
        } else {
            encoder.encodeNil(forKey: "username")
        }
        if let password = self.password {
            encoder.encodeString(password, forKey: "password")
        } else {
            encoder.encodeNil(forKey: "password")
        }
        encoder.encodeInt32(self.useForCalls ? 1 : 0, forKey: "useForCalls")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? ProxySettings else {
            return false
        }
        
        return self == to
    }
    
    public static func ==(lhs: ProxySettings, rhs: ProxySettings) -> Bool {
        if lhs.host != rhs.host {
            return false
        }
        if lhs.port != rhs.port {
            return false
        }
        if lhs.username != rhs.username {
            return false
        }
        if lhs.password != rhs.password {
            return false
        }
        if lhs.useForCalls != rhs.useForCalls {
            return false
        }
        return true
    }

}

public func updateProxySettings(postbox:Postbox, _ f: @escaping (ProxySettings?)->ProxySettings?) -> Signal<Void, Void> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: PreferencesKeys.proxySettings, { current in
            return f(current as? ProxySettings)
        })
    }
}

public func applyProxySettings(postbox: Postbox, network: Network, settings: ProxySettings?) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: PreferencesKeys.proxySettings, { _ in
            return settings
        })
        
        network.context.updateApiEnvironment { current in
            return current?.withUpdatedSocksProxySettings(settings.flatMap { proxySettings -> MTSocksProxySettings? in
                return MTSocksProxySettings(ip: proxySettings.host, port: UInt16(proxySettings.port), username: proxySettings.username, password: proxySettings.password)
            })
        }
    }
}
