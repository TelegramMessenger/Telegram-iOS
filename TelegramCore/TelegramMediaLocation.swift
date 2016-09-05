import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public protocol TelegramMediaLocation: Coding {
    var uniqueId: String { get }
    
    func equalsTo(_ other: TelegramMediaLocation) -> Bool
}

public protocol TelegramCloudMediaLocation {
    var datacenterId: Int { get }
    var apiInputLocation: Api.InputFileLocation { get }
}

public extension TelegramMediaLocation {
    public var cloudLocation: TelegramCloudMediaLocation! {
        switch self {
            case let location as TelegramCloudFileLocation:
                return location
            case let location as TelegramCloudDocumentLocation:
                return location
            case _:
                assertionFailure("not supported")
                return nil
        }
    }
}
