import Foundation
import Postbox
import TelegramCore
import RichTextEditorCore

/// The ONE place `ReplyMarkupButtonAction` and `RichTextEditorCore.ButtonAction` are translated.
/// Both directions live here so they cannot drift — the `MentionDateMarkers.swift` precedent.
///
/// `RichTextEditorCore` is Telegram-free, so it can name only the actions the editor can author or
/// meaningfully describe (`url`, `copyText`, `disabled`). Everything else is preserved verbatim as
/// `.unsupported(kind:payload:)`, whose `payload` is the base64 of the action's own Postbox blob.
/// Nothing outside this file may read or construct those two fields.

/// Discriminates blobs this codec produced. A `Document` can arrive from a newer build (via `.rtdoc`
/// or the clipboard) carrying a kind this build does not know, so the decode side checks it.
private let unsupportedActionKind = "replyMarkupButtonAction"

public func buttonAction(from action: ReplyMarkupButtonAction) -> ButtonAction {
    switch action {
    case let .url(url):
        return .url(url)
    case let .copyText(payload):
        return .copyText(payload)
    case .disabled:
        return .disabled
    case .callback, .urlAuth, .openWebView, .switchInline, .openUserProfile, .openWebApp, .payment,
         .text, .requestPhone, .requestMap, .setupPoll, .requestPeer:
        // `ReplyMarkupButtonAction` is deliberately WIDER than the page-button schema: the last five
        // come only from `Api.ButtonType` and cannot occur on a page button. They are handled anyway
        // because the type admits them.
        let encoder = PostboxEncoder()
        action.encode(encoder)
        return .unsupported(kind: unsupportedActionKind, payload: encoder.makeData().base64EncodedString())
    }
}

public func replyMarkupButtonAction(from action: ButtonAction) -> ReplyMarkupButtonAction {
    switch action {
    case let .url(url):
        return .url(url)
    case let .copyText(payload):
        return .copyText(payload: payload)
    case .disabled:
        return .disabled
    case let .unsupported(kind, payload):
        // An unknown kind, or a payload this build cannot decode, degrades to `.disabled` rather than
        // crashing or trapping on a malformed buffer.
        guard kind == unsupportedActionKind, let data = Data(base64Encoded: payload), !data.isEmpty else {
            return .disabled
        }
        return ReplyMarkupButtonAction(decoder: PostboxDecoder(buffer: MemoryBuffer(data: data)))
    }
}

public func buttonColor(from color: ReplyMarkupButton.Style.Color?) -> ButtonColor? {
    guard let color else {
        return nil
    }
    switch color {
    case .primary: return .primary
    case .danger:  return .danger
    case .success: return .success
    }
}

public func replyMarkupColor(from color: ButtonColor?) -> ReplyMarkupButton.Style.Color? {
    guard let color else {
        return nil
    }
    switch color {
    case .primary: return .primary
    case .danger:  return .danger
    case .success: return .success
    }
}

public func buttonRowAlignment(from alignment: InstantPageButtonRowAlignment) -> ButtonRowAlignment {
    switch alignment {
    case .justify: return .justify
    case .left:    return .left
    case .center:  return .center
    case .right:   return .right
    }
}

public func instantPageRowAlignment(from alignment: ButtonRowAlignment) -> InstantPageButtonRowAlignment {
    switch alignment {
    case .justify: return .justify
    case .left:    return .left
    case .center:  return .center
    case .right:   return .right
    }
}

// MARK: - ChatInputButton <-> ButtonRef

/// A pill label's runs. A custom emoji in a label degrades to its plain alt text: a label is edited as
/// plain text in the host property sheet, and registering an emoji here would need a host resolver
/// this codec deliberately does not take. Documented as an accepted limitation in the design spec.
private func labelRuns(fromChatInputRuns runs: [ChatInputRun]) -> [TextRun] {
    return runs.map { run in
        var attributes = CharacterAttributes.plain
        attributes.bold = run.attributes.bold
        attributes.italic = run.attributes.italic
        attributes.inlineCode = run.attributes.monospace
        attributes.strikethrough = run.attributes.strikethrough
        attributes.underline = run.attributes.underline
        attributes.spoiler = run.attributes.spoiler
        if case let .url(url)? = run.attributes.entity {
            attributes.link = url
        }
        return TextRun(text: run.text, attributes: attributes)
    }
}

private func chatInputLabelRuns(fromRuns runs: [TextRun]) -> [ChatInputRun] {
    return runs.map { run in
        var attributes = ChatInputInlineAttributes(
            bold: run.attributes.bold,
            italic: run.attributes.italic,
            monospace: run.attributes.inlineCode,
            strikethrough: run.attributes.strikethrough,
            underline: run.attributes.underline,
            spoiler: run.attributes.spoiler,
            formula: nil,
            entity: nil
        )
        if let link = run.attributes.link {
            attributes.entity = .url(link)
        }
        return ChatInputRun(text: run.text, attributes: attributes)
    }
}

public func buttonRef(fromChatInputButton button: ChatInputButton) -> ButtonRef {
    return ButtonRef(
        label: labelRuns(fromChatInputRuns: button.label),
        action: buttonAction(from: button.action),
        color: buttonColor(from: button.color),
        isLink: button.isLink
    )
}

public func chatInputButton(fromButtonRef button: ButtonRef) -> ChatInputButton {
    return ChatInputButton(
        label: chatInputLabelRuns(fromRuns: button.label),
        action: replyMarkupButtonAction(from: button.action),
        color: replyMarkupColor(from: button.color),
        isLink: button.isLink
    )
}
