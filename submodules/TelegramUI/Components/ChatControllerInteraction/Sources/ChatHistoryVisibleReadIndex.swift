import Foundation
import CoreGraphics
import TelegramCore

// A message row the chat history has on screen: its frame in the list's coordinates and the messages it shows (an
// album shows several).
public struct ChatHistoryVisibleReadRow {
    public var frame: CGRect
    public var messages: [EngineMessage.Index]

    public init(frame: CGRect, messages: [EngineMessage.Index]) {
        self.frame = frame
        self.messages = messages
    }
}

// The newest message the chat reads from the rows on screen, or nil when no row counts. Frames and `topInset` are in list
// space: in the rotated chat history the list's top inset is the input panel at the bottom of the screen. A row hidden
// under the top inset does not count; one that starts up to 100 points above it does, as does a taller one holding
// `lastMessageId`, the newest message of a history that is loaded to its end. In a thread (`isThread`: a forum topic, a
// reply thread, a monoforum thread) the read goes up to a cloud message id, so a row holding a message of another
// namespace is left out.
public func chatHistoryMaxVisibleReadIndex(rows: [ChatHistoryVisibleReadRow], topInset: CGFloat, lastMessageId: EngineMessage.Id?, isThread: Bool) -> EngineMessage.Index? {
    var maxMessage: EngineMessage.Index?
    for row in rows {
        if row.frame.maxY < topInset {
            continue
        }
        var matches = false
        if row.frame.minY >= topInset - 100.0 {
            matches = true
        } else if let lastMessageId, row.messages.contains(where: { $0.id == lastMessageId }) {
            matches = true
        }
        if matches && isThread && row.messages.contains(where: { $0.id.namespace != Namespaces.Message.Cloud }) {
            matches = false
        }
        if matches, let maxItemIndex = row.messages.max() {
            if let maxMessageValue = maxMessage {
                if maxMessageValue < maxItemIndex {
                    maxMessage = maxItemIndex
                }
            } else {
                maxMessage = maxItemIndex
            }
        }
    }
    return maxMessage
}
