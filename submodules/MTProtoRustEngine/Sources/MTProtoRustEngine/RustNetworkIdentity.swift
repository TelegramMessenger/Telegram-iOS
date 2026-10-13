import Foundation
import MtProtoKit
import MTProtoRustEngineMapping
#if os(macOS)
import SystemConfiguration
#else
import Network
#endif

enum RustNetworkIdentity {
    private static let saltKey = "mtproto.routeMemory.salt.v1"
    static let memoryKey = "mtproto.routeMemory.v1"

    static func currentKey(gateways: [RustEngineNetworkRouter] = []) -> Data {
        guard let fingerprint = rustEngineNetworkFingerprint(interfaces: RustNetworkIdentity.interfaces(), routers: RustNetworkIdentity.routers() + gateways), let salt = RustNetworkIdentity.salt() else {
            return Data()
        }
        var data = salt
        data.append(Data(fingerprint.utf8))
        return MTSha256(data).prefix(16)
    }

    static func storedMemory() -> Data? {
        return UserDefaults.standard.data(forKey: RustNetworkIdentity.memoryKey)
    }

    static func storeMemory(_ memory: Data) {
        UserDefaults.standard.set(memory, forKey: RustNetworkIdentity.memoryKey)
    }

    private static func salt() -> Data? {
        if let salt = UserDefaults.standard.data(forKey: RustNetworkIdentity.saltKey), salt.count == 16 {
            return salt
        }
        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        if status != errSecSuccess {
            return nil
        }
        UserDefaults.standard.set(salt, forKey: RustNetworkIdentity.saltKey)
        return salt
    }

    private static func interfaces() -> [RustEngineNetworkInterface] {
        var result: [RustEngineNetworkInterface] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else {
            return result
        }
        defer {
            freeifaddrs(list)
        }
        var cursor = list
        while let item = cursor {
            cursor = item.pointee.ifa_next
            let flags = Int32(item.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_RUNNING != 0, flags & IFF_LOOPBACK == 0, let address = item.pointee.ifa_addr, let netmask = item.pointee.ifa_netmask else {
                continue
            }
            let name = String(cString: item.pointee.ifa_name)
            switch Int32(address.pointee.sa_family) {
            case AF_INET:
                let addressBytes = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { RustNetworkIdentity.bytes(of: $0.pointee.sin_addr) }
                let maskBytes = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { RustNetworkIdentity.bytes(of: $0.pointee.sin_addr) }
                result.append(RustEngineNetworkInterface(name: name, address: addressBytes, netmask: maskBytes))
            case AF_INET6:
                let addressBytes = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { RustNetworkIdentity.bytes(of: $0.pointee.sin6_addr) }
                result.append(RustEngineNetworkInterface(name: name, address: addressBytes, netmask: []))
            default:
                continue
            }
        }
        return result
    }

    private static func bytes<T>(of value: T) -> [UInt8] {
        var value = value
        return withUnsafeBytes(of: &value) { Array($0) }
    }

    static func unresolvedRouters() -> [String] {
        return RustNetworkIdentity.serviceRouters().filter { service in
            return service.hardware == nil && rustEngineNetworkRouterCounts(RustEngineNetworkRouter(interface: service.interface, address: service.router))
        }.map { "\($0.interface) \($0.router)" }.sorted()
    }

    private static func routers() -> [RustEngineNetworkRouter] {
        return RustNetworkIdentity.serviceRouters().map { service in
            if let hardware = service.hardware {
                return RustEngineNetworkRouter(interface: service.interface, address: "\(service.router) \(hardware)")
            }
            return RustEngineNetworkRouter(interface: service.interface, address: service.router)
        }
    }

    private static func serviceRouters() -> [(interface: String, router: String, hardware: String?)] {
        #if os(macOS)
        guard let store = SCDynamicStoreCreate(nil, "Telegram" as CFString, nil, nil), let keys = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/[^/]+/IPv4" as CFString) as? [String] else {
            return []
        }
        return keys.compactMap { key in
            guard let service = SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any], let interface = service["InterfaceName"] as? String, let router = service["Router"] as? String else {
                return nil
            }
            let hardware = (service["ARPResolvedIPAddress"] as? String) == router ? service["ARPResolvedHardwareAddress"] as? String : nil
            return (interface, router, hardware)
        }
        #else
        return []
        #endif
    }
}

final class RustNetworkWatcher {
    private let queue: DispatchQueue
    private let changed: () -> Void
    #if os(macOS)
    private var store: SCDynamicStore?
    #else
    private let monitor = NWPathMonitor()
    #endif
    private(set) var gateways: [RustEngineNetworkRouter] = []
    private(set) var hasPath = false

    init(queue: DispatchQueue, changed: @escaping () -> Void) {
        self.queue = queue
        self.changed = changed
    }

    deinit {
        #if os(macOS)
        if let store = self.store {
            SCDynamicStoreSetDispatchQueue(store, nil)
        }
        #else
        self.monitor.cancel()
        #endif
    }

    func start() {
        #if os(macOS)
        var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        guard let store = SCDynamicStoreCreate(nil, "Telegram" as CFString, { _, _, info in
            guard let info = info else {
                return
            }
            Unmanaged<RustNetworkWatcher>.fromOpaque(info).takeUnretainedValue().changed()
        }, &context) else {
            return
        }
        let keys = ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] as CFArray
        let patterns = ["State:/Network/Interface/[^/]+/IPv4", "State:/Network/Interface/[^/]+/IPv6", "State:/Network/Service/[^/]+/IPv4"] as CFArray
        if SCDynamicStoreSetNotificationKeys(store, keys, patterns) && SCDynamicStoreSetDispatchQueue(store, self.queue) {
            self.store = store
        }
        #else
        self.monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else {
                return
            }
            let interface = path.availableInterfaces.first?.name ?? "gateway"
            self.gateways = path.gateways.compactMap { gateway in
                guard case let .hostPort(host, _) = gateway else {
                    return nil
                }
                return RustEngineNetworkRouter(interface: interface, address: "\(host)")
            }
            self.hasPath = true
            self.changed()
        }
        self.monitor.start(queue: self.queue)
        #endif
    }
}
