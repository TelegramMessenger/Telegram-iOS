import Foundation
import TelegramCore
import AccountContext

/// The composer state after a support template goes in at `range`, or at the selection when `range` is nil. A chat's
/// composer starts with no blocks at all until something is typed, and `replacingFlatRange` leaves content without
/// blocks unchanged, so the template goes into one empty paragraph there.
public func supportTemplateInputState(_ current: ChatTextInputState, inserting text: NSAttributedString, replacing range: NSRange?) -> ChatTextInputState {
    let replaced = range ?? NSRange(location: current.selectionRange.lowerBound, length: current.selectionRange.count)
    if current.content.blocks.isEmpty {
        let base = ChatTextInputState(content: ChatInputContent(blocks: [.paragraph(ChatInputParagraph())]), selectionRange: 0 ..< 0)
        return base.replacingFlatRange(NSRange(location: 0, length: 0), with: text)
    }
    return current.replacingFlatRange(replaced, with: text)
}
