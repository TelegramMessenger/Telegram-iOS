import Foundation
#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public enum PostboxAuthorizationChallenge {
    case numericPassword(length: Int32)
    case arbitraryPassword
}

public enum PostboxAccess {
    case unlocked
    case locked(PostboxAuthorizationChallenge)
}

private final class PostboxAccessHelper {
    let queue: Queue
    let valueBox: ValueBox
    let metadataTable: MetadataTable
    
    init(queue: Queue, basePath: String) {
        self.queue = queue
        self.valueBox = SqliteValueBox(basePath: basePath + "/db", queue: self.queue)
        self.metadataTable = MetadataTable(valueBox: self.valueBox, table: MetadataTable.tableSpec(0))
    }
}

public func accessPostbox(basePath: String, password: String?) -> Signal<PostboxAccess, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        
        queue.async {
            let postbox = PostboxAccessHelper(queue: queue, basePath: basePath)
            let challengeData = postbox.metadataTable.accessChallengeData()
            switch challengeData {
                case .none:
                    subscriber.putNext(.unlocked)
                    subscriber.putCompletion()
                case let .numericalPassword(text):
                    if text == password {
                        subscriber.putNext(.unlocked)
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(.locked(.numericPassword(length: Int32(text.characters.count))))
                        subscriber.putCompletion()
                    }
                case let .plaintextPassword(text):
                    if text == password {
                        subscriber.putNext(.unlocked)
                        subscriber.putCompletion()
                    } else {
                        subscriber.putNext(.locked(.arbitraryPassword))
                        subscriber.putCompletion()
                    }
            }
        }
        
        return ActionDisposable {
        }
    }
}
