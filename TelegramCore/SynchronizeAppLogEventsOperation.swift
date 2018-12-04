import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

private enum SynchronizeAppLogEventsOperationContentType: Int32 {
    case add
    case sync
}

enum SynchronizeAppLogEventsOperationContent: PostboxCoding {
    case add(time: Double, type: String, peerId: PeerId?, data: JSON)
    case sync
    
    init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case SynchronizeAppLogEventsOperationContentType.add.rawValue:
                var peerId: PeerId?
                if let id = decoder.decodeOptionalInt64ForKey("p") {
                    peerId = PeerId(id)
                }
                self = .add(time: decoder.decodeDoubleForKey("tm", orElse: 0.0), type: decoder.decodeStringForKey("t", orElse: ""), peerId: peerId, data: decoder.decodeObjectForKey("d", decoder: { JSON(decoder: $0) }) as! JSON)
            case SynchronizeAppLogEventsOperationContentType.sync.rawValue:
                self = .sync
            default:
                assertionFailure()
                self = .sync
        }
    }
    
    func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .add(time, type, peerId, data):
                encoder.encodeInt32(SynchronizeAppLogEventsOperationContentType.add.rawValue, forKey: "r")
                encoder.encodeDouble(time, forKey: "tm")
                encoder.encodeString(type, forKey: "t")
                if let peerId = peerId {
                    encoder.encodeInt64(peerId.toInt64(), forKey: "p")
                } else {
                    encoder.encodeNil(forKey: "p")
                }
                encoder.encodeObject(data, forKey: "d")
            case .sync:
                encoder.encodeInt32(SynchronizeAppLogEventsOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

final class SynchronizeAppLogEventsOperation: PostboxCoding {
    let content: SynchronizeAppLogEventsOperationContent
    
    init(content: SynchronizeAppLogEventsOperationContent) {
        self.content = content
    }
    
    init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeAppLogEventsOperationContent(decoder: $0) }) as! SynchronizeAppLogEventsOperationContent
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}

public func addAppLogEvent(postbox: Postbox, time: Double, type: String, peerId: PeerId?, data: JSON) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeAppLogEvents
    let peerId = PeerId(namespace: 0, id: 0)
    let _ = (postbox.transaction { transaction in
        transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeAppLogEventsOperation(content: .add(time: time, type: type, peerId: peerId, data: data)))
    }).start()
}

public func invokeAppLogEventsSynchronization(postbox: Postbox) {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeAppLogEvents
    let peerId = PeerId(namespace: 0, id: 0)
    
    let _ = (postbox.transaction { transaction in
        var topOperation: (SynchronizeSavedStickersOperation, Int32)?
        transaction.operationLogEnumerateEntries(peerId: peerId, tag: tag, { entry in
            if let operation = entry.contents as? SynchronizeSavedStickersOperation, case .sync = operation.content {
                topOperation = (operation, entry.tagLocalIndex)
            }
            return false
        })
        
        if let (_, topLocalIndex) = topOperation {
            let _ = transaction.operationLogRemoveEntry(peerId: peerId, tag: tag, tagLocalIndex: topLocalIndex)
        }
        
        transaction.operationLogAddEntry(peerId: peerId, tag: tag, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: SynchronizeAppLogEventsOperation(content: .sync))
    }).start()
}
