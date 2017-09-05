import Foundation
import Postbox

struct InstantPageManagedMediaId: ManagedMediaId {
    let media: InstantPageMedia
    
    init(media: InstantPageMedia) {
        self.media = media
    }
    
    var hashValue: Int {
        if let id = self.media.media.id {
            return id.hashValue
        } else {
            return 0
        }
    }
    
    func isEqual(to: ManagedMediaId) -> Bool {
        if let to = to as? InstantPageManagedMediaId {
            return self.media == to.media
        } else {
            return false
        }
    }
}

