import Foundation
import Postbox
import SwiftSignalKit

/// Messages whose references (a reply target, a story) a history fill found missing and is fetching. A fill
/// registers the messages it stored that reference something missing, in the transaction that stores them, so their
/// first draw already sees it, and releases them when its follow-up has finished, whatever came back; the follow-up
/// then rewrites those same messages, so the set that draws skeletons is the set that is redrawn. Layout reads
/// `hasLoadingReferences` to draw a skeleton in place of a missing reference that is on its way (and today's look for
/// one that is simply missing). Counted, because two fills can store the same message. In memory only.
public final class PendingMessageReferences {
    final class Registration {
        let sourceIds: Set<MessageId>
        fileprivate let isReleased = Atomic<Bool>(value: false)
        
        fileprivate init(sourceIds: Set<MessageId>) {
            self.sourceIds = sourceIds
        }
    }
    
    private let counts = Atomic<[MessageId: Int]>(value: [:])
    
    init() {
    }
    
    func register(sourceIds: Set<MessageId>) -> Registration? {
        if sourceIds.isEmpty {
            return nil
        }
        let _ = self.counts.modify { counts in
            var counts = counts
            for id in sourceIds {
                counts[id, default: 0] += 1
            }
            return counts
        }
        return Registration(sourceIds: sourceIds)
    }
    
    func release(_ registration: Registration) {
        let wasReleased = registration.isReleased.swap(true)
        if wasReleased {
            return
        }
        let _ = self.counts.modify { counts in
            var counts = counts
            for id in registration.sourceIds {
                if let count = counts[id], count > 1 {
                    counts[id] = count - 1
                } else {
                    counts.removeValue(forKey: id)
                }
            }
            return counts
        }
    }
    
    /// Whether a fill that stored this message is still fetching what it references: a missing reply target or
    /// story of it draws as a skeleton.
    public func hasLoadingReferences(messageId: EngineMessage.Id) -> Bool {
        return self.counts.with { $0[messageId] != nil }
    }
}
