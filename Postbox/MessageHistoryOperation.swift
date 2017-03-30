import Foundation

enum MessageHistoryOperation {
    case InsertMessage(IntermediateMessage)
    case InsertHole(MessageHistoryHole)
    case Remove([(MessageIndex, Bool, MessageTags)])
    case UpdateReadState(CombinedPeerReadState)
    case UpdateEmbeddedMedia(MessageIndex, ReadBuffer)
    case UpdateTimestamp(MessageIndex, Int32)
}
