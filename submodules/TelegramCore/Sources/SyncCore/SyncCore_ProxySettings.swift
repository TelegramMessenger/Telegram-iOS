import Foundation
import Postbox

public enum ProxyServerConnection: Equatable, Hashable, PostboxCoding {
    case socks5(username: String?, password: String?)
    case mtp(secret: Data)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_t", orElse: 0) {
            case 0:
                self = .socks5(username: decoder.decodeOptionalStringForKey("username"), password: decoder.decodeOptionalStringForKey("password"))
            case 1:
                self = .mtp(secret: decoder.decodeBytesForKey("secret")?.makeData() ?? Data())
            default:
                self = .socks5(username: nil, password: nil)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .socks5(username, password):
                encoder.encodeInt32(0, forKey: "_t")
                if let username = username {
                    encoder.encodeString(username, forKey: "username")
                } else {
                    encoder.encodeNil(forKey: "username")
                }
                if let password = password {
                    encoder.encodeString(password, forKey: "password")
                } else {
                    encoder.encodeNil(forKey: "password")
                }
            case let .mtp(secret):
                encoder.encodeInt32(1, forKey: "_t")
                encoder.encodeBytes(MemoryBuffer(data: secret), forKey: "secret")
        }
    }
}

public struct ProxyServerSettings: PostboxCoding, Equatable, Hashable {
    public let host: String
    public let port: Int32
    public let connection: ProxyServerConnection
    
    public init(host: String, port: Int32, connection: ProxyServerConnection) {
        self.host = host
        self.port = port
        self.connection = connection
    }
    
    public init(decoder: PostboxDecoder) {
        self.host = decoder.decodeStringForKey("host", orElse: "")
        self.port = decoder.decodeInt32ForKey("port", orElse: 0)
        if let username = decoder.decodeOptionalStringForKey("username") {
            self.connection = .socks5(username: username, password: decoder.decodeOptionalStringForKey("password"))
        } else {
            self.connection = decoder.decodeObjectForKey("connection", decoder: ProxyServerConnection.init(decoder:)) as? ProxyServerConnection ?? ProxyServerConnection.socks5(username: nil, password: nil)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.host, forKey: "host")
        encoder.encodeInt32(self.port, forKey: "port")
        encoder.encodeObject(self.connection, forKey: "connection")
    }
    
    public var hashValue: Int {
        var hash = self.host.hashValue
        hash = hash &* 31 &+ self.port.hashValue
        hash = hash &* 31 &+ self.connection.hashValue
        return hash
    }
}

public struct ProxySettings: PreferencesEntry, Equatable {
    public var enabled: Bool
    public var servers: [ProxyServerSettings]
    public var activeServer: ProxyServerSettings?
    public var useForCalls: Bool
    
    public static var defaultSettings: ProxySettings {
        return ProxySettings(enabled: false, servers: [], activeServer: nil, useForCalls: false)
    }
    
    public init(enabled: Bool, servers: [ProxyServerSettings], activeServer: ProxyServerSettings?, useForCalls: Bool) {
        self.enabled = enabled
        self.servers = servers
        self.activeServer = activeServer
        self.useForCalls = useForCalls
    }
    
    public init(decoder: PostboxDecoder) {
        if let _ = decoder.decodeOptionalStringForKey("host") {
            let legacyServer = ProxyServerSettings(decoder: decoder)
            if !legacyServer.host.isEmpty && legacyServer.port != 0 {
                self.enabled = true
                self.servers = [legacyServer]
            } else {
                self.enabled = false
                self.servers = []
            }
        } else {
            self.enabled = decoder.decodeInt32ForKey("enabled", orElse: 0) != 0
            self.servers = decoder.decodeObjectArrayWithDecoderForKey("servers")
        }
        self.activeServer = decoder.decodeObjectForKey("activeServer", decoder: ProxyServerSettings.init(decoder:)) as? ProxyServerSettings
        self.useForCalls = decoder.decodeInt32ForKey("useForCalls", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.enabled ? 1 : 0, forKey: "enabled")
        encoder.encodeObjectArray(self.servers, forKey: "servers")
        if let activeServer = self.activeServer {
            encoder.encodeObject(activeServer, forKey: "activeServer")
        } else {
            encoder.encodeNil(forKey: "activeServer")
        }
        encoder.encodeInt32(self.useForCalls ? 1 : 0, forKey: "useForCalls")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? ProxySettings else {
            return false
        }
        
        return self == to
    }
    
    public var effectiveActiveServer: ProxyServerSettings? {
        if self.enabled, let activeServer = self.activeServer {
            return activeServer
        } else {
            return nil
        }
    }
}
