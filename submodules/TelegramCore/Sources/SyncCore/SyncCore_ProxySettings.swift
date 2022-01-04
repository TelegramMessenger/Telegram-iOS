import Foundation
import Postbox

public enum ProxyServerConnection: Equatable, Hashable, Codable {
    case socks5(username: String?, password: String?)
    case mtp(secret: Data)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch try container.decode(Int32.self, forKey: "_t") {
            case 0:
                self = .socks5(username: try container.decodeIfPresent(String.self, forKey: "username"), password: try container.decodeIfPresent(String.self, forKey: "password"))
            case 1:
                self = .mtp(secret: try container.decode(Data.self, forKey: "secret"))
            default:
                self = .socks5(username: nil, password: nil)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
            case let .socks5(username, password):
                try container.encode(0 as Int32, forKey: "_t")
                try container.encodeIfPresent(username, forKey: "username")
                try container.encodeIfPresent(password, forKey: "password")
            case let .mtp(secret):
                try container.encode(1 as Int32, forKey: "_t")
                try container.encode(secret, forKey: "secret")
        }
    }
}

public struct ProxyServerSettings: Codable, Equatable, Hashable {
    public let host: String
    public let port: Int32
    public let connection: ProxyServerConnection
    
    public init(host: String, port: Int32, connection: ProxyServerConnection) {
        self.host = host
        self.port = port
        self.connection = connection
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.host = (try? container.decode(String.self, forKey: "host")) ?? ""
        self.port = (try? container.decode(Int32.self, forKey: "port")) ?? 0
        if let username = try container.decodeIfPresent(String.self, forKey: "username") {
            self.connection = .socks5(username: username, password: try container.decodeIfPresent(String.self, forKey: "password"))
        } else {
            self.connection = (try? container.decodeIfPresent(ProxyServerConnection.self, forKey: "connection")) ?? ProxyServerConnection.socks5(username: nil, password: nil)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.host, forKey: "host")
        try container.encode(self.port, forKey: "port")
        try container.encode(self.connection, forKey: "connection")
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.host)
        hasher.combine(self.port)
        hasher.combine(self.connection)
    }
}

public struct ProxySettings: Codable, Equatable {
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.enabled = ((try? container.decode(Int32.self, forKey: "enabled")) ?? 0) != 0
        self.servers = try container.decode([ProxyServerSettings].self, forKey: "servers")
        self.activeServer = try container.decodeIfPresent(ProxyServerSettings.self, forKey: "activeServer")
        self.useForCalls = ((try? container.decode(Int32.self, forKey: "useForCalls")) ?? 0) != 0
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode((self.enabled ? 1 : 0) as Int32, forKey: "enabled")
        try container.encode(self.servers, forKey: "servers")
        try container.encodeIfPresent(self.activeServer, forKey: "activeServer")
        try container.encode((self.useForCalls ? 1 : 0) as Int32, forKey: "useForCalls")
    }
    
    public var effectiveActiveServer: ProxyServerSettings? {
        if self.enabled, let activeServer = self.activeServer {
            return activeServer
        } else {
            return nil
        }
    }
}
