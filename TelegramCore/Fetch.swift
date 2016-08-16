import Foundation
import Postbox
import SwiftSignalKit

private func fetchCloudMediaLocation(account: Account, cloudLocation: TelegramCloudMediaLocation, size: Int, range: Range<Int>) -> Signal<Data, NoError> {
    if size <= 0 {
        return .never()
    }
    
    return multipartFetch(account: account, cloudLocation: cloudLocation, size: size, range: range)
}

func fetchResource(account: Account, resource: MediaResource, range: Range<Int>) -> Signal<Data, NoError> {
    if let resource = resource as? CloudFileMediaResource {
        if let location = resource.location as? TelegramCloudMediaLocation {
            return fetchCloudMediaLocation(account: account, cloudLocation: location, size: resource.size, range: range)
        }
    }
    return .never()
}
