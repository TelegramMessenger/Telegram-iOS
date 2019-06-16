import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif
import TelegramApi

public struct PeerStatusSettings: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let canReport = PeerStatusSettings(rawValue: 1 << 1)
    public static let canShareContact = PeerStatusSettings(rawValue: 1 << 2)
    public static let canBlock = PeerStatusSettings(rawValue: 1 << 3)
    public static let canAddContact = PeerStatusSettings(rawValue: 1 << 4)
    public static let addExceptionWhenAddingContact = PeerStatusSettings(rawValue: 1 << 5)
}

extension PeerStatusSettings {
    init(apiSettings: Api.PeerSettings) {
        switch apiSettings {
            case let .peerSettings(flags):
                var result = PeerStatusSettings()
                if (flags & (1 << 1)) != 0 {
                    result.insert(.canAddContact)
                }
                if (flags & (1 << 0)) != 0 {
                    result.insert(.canReport)
                }
                if (flags & (1 << 2)) != 0 {
                    result.insert(.canBlock)
                }
                if (flags & (1 << 3)) != 0 {
                    result.insert(.canShareContact)
                }
                if (flags & (1 << 4)) != 0 {
                    result.insert(.addExceptionWhenAddingContact)
                }
                self = result
        }
    }
}
