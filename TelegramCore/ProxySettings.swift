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

public struct ProxyServerSettings: PostboxCoding, Equatable {
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
}

public struct ProxySettings: PreferencesEntry, Equatable {
    public var servers: [ProxyServerSettings]
    public var activeServer: ProxyServerSettings?
    public var useForCalls: Bool
    
    public static var defaultSettings: ProxySettings {
        return ProxySettings(servers: [], activeServer: nil, useForCalls: false)
    }
    
    public init(servers: [ProxyServerSettings], activeServer: ProxyServerSettings?, useForCalls: Bool) {
        self.servers = servers
        self.activeServer = activeServer
        self.useForCalls = useForCalls
    }
    
    public init(decoder: PostboxDecoder) {
        self.servers = decoder.decodeObjectArrayWithDecoderForKey("servers")
        self.activeServer = decoder.decodeObjectForKey("activeServer", decoder: ProxyServerSettings.init(decoder:)) as? ProxyServerSettings
        self.useForCalls = decoder.decodeInt32ForKey("useForCalls", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
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
    
    public func withUpdatedActiveServer(_ activeServer: ProxyServerSettings?) -> ProxySettings {
        var servers = self.servers
        if let activeServer = activeServer, let index = servers.index(where: {$0 == activeServer}), index > 0 {
            servers.remove(at: index)
            servers.insert(activeServer, at: 0)
        }
        return ProxySettings(servers: servers, activeServer: activeServer, useForCalls: self.useForCalls)
    }
    
    public func withAddedServer(_ proxy: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        if servers.first(where: {$0 == proxy}) == nil {
            servers.append(proxy)
        }
        return ProxySettings(servers: servers, activeServer: self.activeServer, useForCalls: self.useForCalls)
    }
    
    public func withUpdatedServer(_ current: ProxyServerSettings, with updated: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        if let index = servers.index(where: {$0 == current}) {
            servers[index] = updated
        }
        return ProxySettings(servers: servers, activeServer: self.activeServer, useForCalls: self.useForCalls)
    }
    
    public func withUpdatedUseForCalls(_ enable: Bool) -> ProxySettings {
        return ProxySettings(servers: servers, activeServer: self.activeServer, useForCalls: enable)
    }
    
    public func withRemovedServer(_ proxy: ProxyServerSettings) -> ProxySettings {
        var servers = self.servers
        var activeServer = self.activeServer
        if let index = servers.index(where: {$0 == proxy}) {
            let current = servers.remove(at: index)
            if current == activeServer {
                activeServer = nil
            }
        }
        return ProxySettings(servers: servers, activeServer: activeServer, useForCalls: self.useForCalls)
    }
}

public func updateProxySettingsInteractively(postbox: Postbox, network: Network, _ f: @escaping (ProxySettings) -> ProxySettings) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        var updateNetwork = false
        var updatedSettings: ProxySettings?
        modifier.updatePreferencesEntry(key: PreferencesKeys.proxySettings, { current in
            let previous = (current as? ProxySettings) ?? ProxySettings.defaultSettings
            let updated = f(previous)
            updatedSettings = updated
            if updated.activeServer != previous.activeServer {
                updateNetwork = true
            }
            return updated
        })
        
        if updateNetwork, let updatedSettings = updatedSettings {
            network.context.updateApiEnvironment { current in
                return current?.withUpdatedSocksProxySettings(updatedSettings.activeServer.flatMap { activeServer -> MTSocksProxySettings? in
                    return MTSocksProxySettings(ip: activeServer.host, port: UInt16(activeServer.port), username: activeServer.username, password: activeServer.password)
                })
            }
        }
    }
}
