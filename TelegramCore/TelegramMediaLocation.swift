import Foundation
import Postbox

public protocol TelegramMediaLocation: Coding {
    var uniqueId: String { get }
    
    func equalsTo(_ other: TelegramMediaLocation) -> Bool
}

protocol TelegramCloudMediaLocation {
    var datacenterId: Int { get }
    var apiInputLocation: Api.InputFileLocation { get }
}

extension TelegramMediaLocation {
    var cloudLocation: TelegramCloudMediaLocation! {
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
