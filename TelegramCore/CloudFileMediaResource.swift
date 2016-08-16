import Foundation
import Postbox

class CloudFileMediaResource: MediaResource {
    var id: String {
        return self.location.uniqueId
    }
    var location: TelegramMediaLocation
    let size: Int
    
    init(location: TelegramMediaLocation, size: Int) {
        self.location = location
        self.size = size
    }
}
