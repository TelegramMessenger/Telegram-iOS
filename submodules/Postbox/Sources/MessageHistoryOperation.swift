import Foundation

enum MessageHistoryOperation {
    case InsertMessage(IntermediateMessage)
    case Remove([(MessageIndex, MessageTags)])
    case UpdateReadState(PeerId, CombinedPeerReadState)
    case UpdateEmbeddedMedia(MessageIndex, ReadBuffer)
    case UpdateTimestamp(MessageIndex, Int32)
    case UpdateGroupInfos([MessageId: MessageGroupInfo])
}
