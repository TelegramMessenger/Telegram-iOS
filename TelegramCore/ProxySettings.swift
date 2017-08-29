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

public final class ProxySettings: PreferencesEntry {
    public let host: String
    public let port: Int32
    public let username: String?
    public let password: String?
    
    public init(host: String, port: Int32, username: String?, password: String?) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }
    
    public init(decoder: PostboxDecoder) {
        self.host = decoder.decodeStringForKey("host", orElse: "")
        self.port = decoder.decodeInt32ForKey("port", orElse: 0)
        self.username = decoder.decodeOptionalStringForKey("username")
        self.password = decoder.decodeOptionalStringForKey("password")
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
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? ProxySettings else {
            return false
        }
        
        if self.host != to.host {
            return false
        }
        if self.port != to.port {
            return false
        }
        if self.username != to.username {
            return false
        }
        if self.password != to.password {
            return false
        }
        
        return true
    }
}

public func applyProxySettings(postbox: Postbox, network: Network, settings: ProxySettings?) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        modifier.updatePreferencesEntry(key: PreferencesKeys.proxySettings, { _ in
            return settings
        })
        
        network.context.updateApiEnvironment { current in
            return current?.withUpdatedSocksProxySettings(settings.flatMap { proxySettings -> MTSocksProxySettings! in
                return MTSocksProxySettings(ip: proxySettings.host, port: UInt16(proxySettings.port), username: proxySettings.username, password: proxySettings.password)
            })
        }
    }
}
