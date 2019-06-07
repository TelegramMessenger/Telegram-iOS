import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct PeerStatusSettings: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let isHidden = PeerStatusSettings(rawValue: 1 << 0)
    public static let canReport = PeerStatusSettings(rawValue: 1 << 1)
    public static let canShareContact = PeerStatusSettings(rawValue: 1 << 2)
}

extension PeerStatusSettings {
    init(apiSettings: Api.PeerSettings) {
        switch apiSettings {
            case let .peerSettings(flags):
                var result = PeerStatusSettings()
                if (flags & (1 << 1)) != 0 {
                    result.insert(.isHidden)
                }
                if (flags & (1 << 0)) != 0 {
                    result.insert(.canReport)
                }
                if (flags & (1 << 2)) != 0 {
                    result.insert(.canShareContact)
                }
                self = result
        }
    }
}
