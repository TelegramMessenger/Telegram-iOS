import Foundation
import TelegramCore
import AccountContext
import TextFormat

/// The composer input state carrying a `ComposedRichMessage` result back into the chat text input.
/// `.rich` keeps its structure via `ChatInputContent` — the same `InstantPage → ChatInputContent`
/// hop the edit-a-rich-message path uses — while `.plain` goes through the entity-applied
/// attributed string.
func chatTextInputState(fromComposedRichMessage message: ComposedRichMessage) -> ChatTextInputState {
    switch message {
    case let .rich(instantPage):
        let content = chatInputContent(fromInstantPage: instantPage)
        return ChatTextInputState(content: content, selectionRange: content.length ..< content.length)
    case let .plain(text, entities):
        return ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(text, entities: entities))
    case .empty:
        return ChatTextInputState(inputText: NSAttributedString(string: ""))
    }
}
