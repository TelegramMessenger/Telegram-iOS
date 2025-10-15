import Foundation
import Postbox

final class MutableAccessChallengeDataView {
    var data: PostboxAccessChallengeData
    
    init(data: PostboxAccessChallengeData) {
        self.data = data
    }
    
    func replay(updatedData: PostboxAccessChallengeData?) -> Bool {
        var updated = false
        
        if let data = updatedData {
            if self.data != data {
                self.data = data
                updated = true
            }
        }
        
        return updated
    }
}

public final class AccessChallengeDataView: PostboxView {
    public let data: PostboxAccessChallengeData
    
    init(_ view: MutableAccessChallengeDataView) {
        self.data = view.data
    }
}
