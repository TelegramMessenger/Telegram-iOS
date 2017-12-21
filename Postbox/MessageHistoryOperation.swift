import Foundation

enum MessageHistoryOperation {
    case InsertMessage(IntermediateMessage)
    case InsertHole(MessageHistoryHole)
    case Remove([(MessageIndex, Bool, MessageTags)])
    case UpdateReadState(PeerId, CombinedPeerReadState)
    case UpdateEmbeddedMedia(MessageIndex, ReadBuffer)
    case UpdateTimestamp(MessageIndex, Int32)
    case UpdateGroupInfos([MessageId: MessageGroupInfo])
}
