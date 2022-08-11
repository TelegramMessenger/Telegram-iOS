import Foundation

final class MutableIsContactView: MutablePostboxView {
    fileprivate let id: PeerId
    fileprivate var isContact: Bool

    init(postbox: PostboxImpl, id: PeerId) {
        self.id = id
        self.isContact = postbox.contactsTable.isContact(peerId: self.id)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if transaction.replaceContactPeerIds != nil {
            let isContact = postbox.contactsTable.isContact(peerId: self.id)
            if self.isContact != isContact {
                self.isContact = isContact
                updated = true
            }
        }
        if updated {
            return true
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return IsContactView(self)
    }
}

public final class IsContactView: PostboxView {
    public let isContact: Bool
    
    init(_ view: MutableIsContactView) {
        self.isContact = view.isContact
    }
}
