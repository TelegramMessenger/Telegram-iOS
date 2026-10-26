import Foundation
import TelegramCore
import AccountContext
import ChatPresentationInterfaceState
import ChatInputTextNode

/// **The chat's inserts on the user's behalf, decided in ONE place.**
///
/// Two of the chat's own edits insert text into the composer from outside it: an emoji tapped on the
/// chat's emoji keyboard (`ChatControllerLoadDisplayNode`'s `insertText`) and the avatar context
/// menu's Mention (`ChatController`). Both used to transform the flat `NSAttributedString` projection
/// of the composer and hand it back through `updateTextInputStateAndMode`, which on the rich editor
/// retyped every heading, list, table and pull-quote author as a body paragraph, and put the text at
/// the end of the composer when the caret was in a table cell (composer harness p18,
/// `HarnessChatInsertStructureTests`).
///
/// The input node is asked first (`ChatRichTextInputNode.insertTextOnUsersBehalf`): the rich-text
/// engine inserts at its own selection, as one undo step, keeping every block. A node that declines —
/// the legacy backend, whose flat state is its whole content — keeps the old transform, unchanged.
///
/// These are free functions rather than closure bodies so the chat and the composer harness run the
/// same code: the harness cannot link `TelegramUI`, and a copy of a closure drifts.

/// The chat's emoji keyboard: inserts `text` (a static emoji, or a custom one carrying
/// `ChatTextInputAttributes.customEmoji`) at the composer's selection.
public func chatComposerInsertTextOnUsersBehalf(_ text: NSAttributedString, richTextInputNode: ChatRichTextInputNode?, interfaceInteraction: ChatPanelInterfaceInteraction) {
    if let richTextInputNode, richTextInputNode.insertTextOnUsersBehalf(text) {
        return
    }
    interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
        return (chatTextInputStateInsertingText(textInputState, text: text), inputMode)
    }
}

/// The avatar context menu's Mention: inserts `peer`'s mention at the composer's selection and brings
/// the keyboard up (`.none` → `.text`).
public func chatComposerInsertMention(_ peer: EnginePeer, richTextInputNode: ChatRichTextInputNode?, interfaceInteraction: ChatPanelInterfaceInteraction?) {
    if let richTextInputNode, let mention = chatTextInputMentionText(peer: peer), richTextInputNode.insertTextOnUsersBehalf(mention) {
        // The text is in; only the input mode is left. Handing back the state unchanged pushes nothing
        // into the composer, whether or not the chat has caught up with the insert yet.
        interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
            return (current, inputMode == .none ? .text : inputMode)
        }
        return
    }
    interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
        var inputMode = inputMode
        if inputMode == .none {
            inputMode = .text
        }
        return (chatTextInputAddMentionAttribute(current, peer: peer), inputMode)
    }
}
