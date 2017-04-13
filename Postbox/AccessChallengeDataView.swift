import Foundation

final class MutableAccessChallengeDataView: MutablePostboxView {
    var data: PostboxAccessChallengeData
    
    init(postbox: Postbox) {
        self.data = postbox.metadataTable.accessChallengeData()
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if let data = transaction.updatedAccessChallengeData {
            if self.data != data {
                self.data = data
                updated = true
            }
        }
        
        return updated
    }
    
    func immutableView() -> PostboxView {
        return AccessChallengeDataView(self)
    }
}

public final class AccessChallengeDataView: PostboxView {
    public let data: PostboxAccessChallengeData
    
    init(_ view: MutableAccessChallengeDataView) {
        self.data = view.data
    }
}
