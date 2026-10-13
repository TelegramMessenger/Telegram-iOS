import Foundation
import Postbox
import TelegramApi

public extension ReplyMarkupButton.Style.Color {
    /// `richButtonStyle flags:# bg_primary:flags.0?true bg_danger:flags.1?true bg_success:flags.2?true`
    /// maps onto the reply-markup colour palette, which already has exactly these three values.
    init?(apiRichStyle: Api.RichButtonStyle) {
        switch apiRichStyle {
        case let .richButtonStyle(data):
            if data.flags & (1 << 0) != 0 {
                self = .primary
            } else if data.flags & (1 << 1) != 0 {
                self = .danger
            } else if data.flags & (1 << 2) != 0 {
                self = .success
            } else {
                return nil
            }
        }
    }

    var apiRichStyleFlags: Int32 {
        switch self {
        case .primary:
            return 1 << 0
        case .danger:
            return 1 << 1
        case .success:
            return 1 << 2
        }
    }
}

public extension InstantPageButtonRowAlignment {
    /// `pageBlockButtonRow#6d640318 flags:# align_left:flags.0?true align_center:flags.1?true
    /// align_right:flags.2?true`. No bit set means justified — the layout every row had before the
    /// bits were honoured.
    ///
    /// A malformed row that sets several bits resolves left > center > right, mirroring
    /// `ReplyMarkupButton.Style.Color.init(apiRichStyle:)` above, so the result is deterministic
    /// rather than dependent on evaluation order.
    ///
    /// This lives here, public, rather than inline in `InstantPageBlock.init(apiBlock:)`: that
    /// initialiser is internal to TelegramCore, so the bit mapping would otherwise be untestable.
    init(apiFlags: Int32) {
        if apiFlags & (1 << 0) != 0 {
            self = .left
        } else if apiFlags & (1 << 1) != 0 {
            self = .center
        } else if apiFlags & (1 << 2) != 0 {
            self = .right
        } else {
            self = .justify
        }
    }

    var apiFlags: Int32 {
        switch self {
        case .justify:
            return 0
        case .left:
            return 1 << 0
        case .center:
            return 1 << 1
        case .right:
            return 1 << 2
        }
    }
}

extension ReplyMarkupButtonAction {
    /// Outgoing direction for page buttons. Only the inline-reachable cases are representable; the
    /// five keyboard-only cases collapse onto `inlineButtonTypeDisabled`, mirroring the FlatBuffers
    /// codec in SyncCore_InstantPageButton.swift.
    func apiInlineButtonType() -> Api.InlineButtonType {
        switch self {
        case let .url(url):
            return .inlineButtonTypeUrl(Api.InlineButtonType.Cons_inlineButtonTypeUrl(url: url))
        case let .urlAuth(url, buttonId):
            return .inlineButtonTypeUrlAuth(Api.InlineButtonType.Cons_inlineButtonTypeUrlAuth(flags: 0, fwdText: nil, url: url, buttonId: buttonId))
        case let .openWebView(url, _):
            return .inlineButtonTypeWebView(Api.InlineButtonType.Cons_inlineButtonTypeWebView(url: url))
        case let .callback(requiresPassword, data):
            return .inlineButtonTypeCallback(Api.InlineButtonType.Cons_inlineButtonTypeCallback(
                flags: requiresPassword ? (1 << 0) : 0,
                data: Buffer(data: data.makeData())
            ))
        case .openWebApp:
            return .inlineButtonTypeGame
        case .payment:
            return .inlineButtonTypeBuy
        case let .switchInline(samePeer, query, _):
            return .inlineButtonTypeSwitchInline(Api.InlineButtonType.Cons_inlineButtonTypeSwitchInline(
                flags: samePeer ? (1 << 0) : 0,
                query: query,
                peerTypes: nil
            ))
        case let .openUserProfile(peerId):
            return .inlineButtonTypeUserProfile(Api.InlineButtonType.Cons_inlineButtonTypeUserProfile(userId: peerId.id._internalGetInt64Value()))
        case let .copyText(payload):
            return .inlineButtonTypeCopy(Api.InlineButtonType.Cons_inlineButtonTypeCopy(copyText: payload))
        case .disabled, .text, .requestPhone, .requestMap, .setupPoll, .requestPeer:
            return .inlineButtonTypeDisabled
        }
    }
}

public extension InstantPageButton {
    /// `richButtonStyle#3c610bd flags:# … link:flags.3?true`.
    ///
    /// Public — like `InstantPageButtonRowAlignment.init(apiFlags:)` and for the same reason —
    /// because `InstantPageButton.init(apiButton:)` is internal to TelegramCore, so the bit mapping
    /// would otherwise be untestable.
    static func isLinkStyle(_ apiRichStyle: Api.RichButtonStyle?) -> Bool {
        guard let apiRichStyle else {
            return false
        }
        switch apiRichStyle {
        case let .richButtonStyle(data):
            return data.flags & (1 << 3) != 0
        }
    }

    /// The `richButtonStyle` flag word this button serialises to. `0` means "send no style object".
    ///
    /// Split out of `apiFlagsAndStyle()` so the bit composition is testable, and because the
    /// composition is where the interesting failure lives: the flags are accumulated and THEN
    /// checked, so a link-only button (no background bit) still emits a style.
    var apiRichStyleFlagWord: Int32 {
        var result: Int32 = 0
        if let color = self.color {
            result |= color.apiRichStyleFlags
        }
        if self.isLink {
            result |= 1 << 3
        }
        return result
    }
}

extension InstantPageButton {
    init(apiButton: Api.PageButton) {
        switch apiButton {
        case let .pageButton(data):
            self.init(
                text: RichText(apiText: data.text),
                action: ReplyMarkupButtonAction.from(apiType: data.type).action,
                color: data.style.flatMap(ReplyMarkupButton.Style.Color.init(apiRichStyle:)),
                isLink: InstantPageButton.isLinkStyle(data.style)
            )
        }
    }

    /// `textButton` and `pageButton` carry identical fields, so the flags/style computation is
    /// shared and each caller wraps it in its own constructor.
    ///
    /// Accumulate-then-check, NOT `guard let color = self.color`: the old shape early-returned
    /// whenever there was no background colour, which would drop the style object entirely for a
    /// link-only button and lose `flags.3` on the way out.
    func apiFlagsAndStyle() -> (flags: Int32, style: Api.RichButtonStyle?) {
        let styleFlags = self.apiRichStyleFlagWord
        guard styleFlags != 0 else {
            return (0, nil)
        }
        return (1 << 0, .richButtonStyle(Api.RichButtonStyle.Cons_richButtonStyle(flags: styleFlags)))
    }

    func apiPageButton() -> Api.PageButton {
        let (flags, style) = self.apiFlagsAndStyle()
        return .pageButton(Api.PageButton.Cons_pageButton(
            flags: flags,
            text: self.text.apiRichText(),
            type: self.action.apiInlineButtonType(),
            style: style
        ))
    }
}
