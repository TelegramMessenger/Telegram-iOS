import Foundation

enum MessageHistoryOperation {
    case InsertMessage(IntermediateMessage)
    case InsertHole(MessageHistoryHole)
    case Remove([MessageIndex])
    case UpdateReadState(CombinedPeerReadState)
    case UpdateEmbeddedMedia(MessageIndex, ReadBuffer)
}
