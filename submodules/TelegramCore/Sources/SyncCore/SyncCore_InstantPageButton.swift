import Foundation
import Postbox
import FlatBuffers
import FlatSerialization

/// An inline button inside an InstantPage — the shared model behind both `RichText.textButton` and
/// `InstantPageBlock.buttonRow`. The schema gives `textButton` and `pageButton` identical shape
/// (`text: RichText`, `type: InlineButtonType`, `style: flags.0?RichButtonStyle`), so one type
/// serves both.
public struct InstantPageButton: PostboxCoding, Equatable {
    public let text: RichText

    /// Only the 10 actions reachable from `Api.InlineButtonType` can occur here. The type is the
    /// shared `ReplyMarkupButtonAction` so that a page-button tap can reuse the whole bot-button
    /// dispatch (`ChatMessageItemView.performMessageButtonAction`) rather than growing a parallel
    /// one. It is therefore nominally wider than the schema allows: `text`, `requestPhone`,
    /// `requestMap`, `setupPoll` and `requestPeer` come only from `Api.ButtonType` and cannot
    /// appear on a page button. The narrowing is documented rather than encoded — see
    /// docs/instantpage-richtext.md, "Inline buttons & document blocks".
    public let action: ReplyMarkupButtonAction

    /// `richButtonStyle`'s bg_primary / bg_danger / bg_success, which map exactly onto the
    /// reply-markup colour palette.
    public let color: ReplyMarkupButton.Style.Color?

    /// `richButtonStyle`'s `link:flags.3`. Stored separately from `color` rather than as a fourth
    /// `Style.Color` case: that enum is shared with bot reply markups, whose `keyboardButtonStyle`
    /// has no link bit. Keeping the two facts independent also means `link` + `bg_danger`
    /// round-trips losslessly, even though the renderer makes `link` win.
    public let isLink: Bool

    public init(text: RichText, action: ReplyMarkupButtonAction, color: ReplyMarkupButton.Style.Color?, isLink: Bool = false) {
        self.text = text
        self.action = action
        self.color = color
        self.isLink = isLink
    }

    public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText
        self.action = ReplyMarkupButtonAction(decoder: decoder)
        let rawColor = decoder.decodeInt32ForKey("c", orElse: -1)
        self.color = rawColor == -1 ? nil : ReplyMarkupButton.Style.Color(rawValue: rawColor)
        // `orElse: 0` is what makes cached pages written before this field decode as not-a-link.
        self.isLink = decoder.decodeInt32ForKey("l", orElse: 0) != 0
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.text, forKey: "t")
        self.action.encode(encoder)
        encoder.encodeInt32(self.color?.rawValue ?? -1, forKey: "c")
        encoder.encodeInt32(self.isLink ? 1 : 0, forKey: "l")
    }
}

/// FlatBuffers codec for `ReplyMarkupButtonAction`. It exists solely to serve `InstantPageButton`
/// (InstantPage is FlatBuffers-serialized; reply markups are Postbox-only), which is why it lives
/// here beside its consumer rather than next to the action type itself.
public extension ReplyMarkupButtonAction {
    init(flatBuffersObject: TelegramCore_InstantPageButtonAction) throws {
        switch flatBuffersObject.valueType {
        case .instantpagebuttonactionUrl:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageButtonAction_Url.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .url(value.url)
        case .instantpagebuttonactionUrlauth:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageButtonAction_UrlAuth.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .urlAuth(url: value.url, buttonId: value.buttonId)
        case .instantpagebuttonactionOpenwebview:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageButtonAction_OpenWebView.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .openWebView(url: value.url, simple: value.simple)
        case .instantpagebuttonactionCallback:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageButtonAction_Callback.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .callback(requiresPassword: value.requiresPassword, data: MemoryBuffer(data: Data(value.data)))
        case .instantpagebuttonactionOpenwebapp:
            self = .openWebApp
        case .instantpagebuttonactionPayment:
            self = .payment
        case .instantpagebuttonactionSwitchinline:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageButtonAction_SwitchInline.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .switchInline(samePeer: value.samePeer, query: value.query, peerTypes: PeerTypes(rawValue: value.peerTypes))
        case .instantpagebuttonactionOpenuserprofile:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageButtonAction_OpenUserProfile.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .openUserProfile(peerId: PeerId(value.peerId))
        case .instantpagebuttonactionCopytext:
            guard let value = flatBuffersObject.value(type: TelegramCore_InstantPageButtonAction_CopyText.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .copyText(payload: value.payload)
        case .instantpagebuttonactionDisabled:
            self = .disabled
        case .none_:
            throw FlatBuffersError.invalidUnionType
        }
    }

    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_InstantPageButtonAction_Value
        let offset: Offset

        switch self {
        case let .url(url):
            valueType = .instantpagebuttonactionUrl
            let urlOffset = builder.create(string: url)
            let start = TelegramCore_InstantPageButtonAction_Url.startInstantPageButtonAction_Url(&builder)
            TelegramCore_InstantPageButtonAction_Url.add(url: urlOffset, &builder)
            offset = TelegramCore_InstantPageButtonAction_Url.endInstantPageButtonAction_Url(&builder, start: start)
        case let .urlAuth(url, buttonId):
            valueType = .instantpagebuttonactionUrlauth
            let urlOffset = builder.create(string: url)
            let start = TelegramCore_InstantPageButtonAction_UrlAuth.startInstantPageButtonAction_UrlAuth(&builder)
            TelegramCore_InstantPageButtonAction_UrlAuth.add(url: urlOffset, &builder)
            TelegramCore_InstantPageButtonAction_UrlAuth.add(buttonId: buttonId, &builder)
            offset = TelegramCore_InstantPageButtonAction_UrlAuth.endInstantPageButtonAction_UrlAuth(&builder, start: start)
        case let .openWebView(url, simple):
            valueType = .instantpagebuttonactionOpenwebview
            let urlOffset = builder.create(string: url)
            let start = TelegramCore_InstantPageButtonAction_OpenWebView.startInstantPageButtonAction_OpenWebView(&builder)
            TelegramCore_InstantPageButtonAction_OpenWebView.add(url: urlOffset, &builder)
            TelegramCore_InstantPageButtonAction_OpenWebView.add(simple: simple, &builder)
            offset = TelegramCore_InstantPageButtonAction_OpenWebView.endInstantPageButtonAction_OpenWebView(&builder, start: start)
        case let .callback(requiresPassword, data):
            valueType = .instantpagebuttonactionCallback
            let dataOffset = builder.createVector([UInt8](data.makeData()))
            let start = TelegramCore_InstantPageButtonAction_Callback.startInstantPageButtonAction_Callback(&builder)
            TelegramCore_InstantPageButtonAction_Callback.addVectorOf(data: dataOffset, &builder)
            TelegramCore_InstantPageButtonAction_Callback.add(requiresPassword: requiresPassword, &builder)
            offset = TelegramCore_InstantPageButtonAction_Callback.endInstantPageButtonAction_Callback(&builder, start: start)
        case .openWebApp:
            valueType = .instantpagebuttonactionOpenwebapp
            let start = TelegramCore_InstantPageButtonAction_OpenWebApp.startInstantPageButtonAction_OpenWebApp(&builder)
            offset = TelegramCore_InstantPageButtonAction_OpenWebApp.endInstantPageButtonAction_OpenWebApp(&builder, start: start)
        case .payment:
            valueType = .instantpagebuttonactionPayment
            let start = TelegramCore_InstantPageButtonAction_Payment.startInstantPageButtonAction_Payment(&builder)
            offset = TelegramCore_InstantPageButtonAction_Payment.endInstantPageButtonAction_Payment(&builder, start: start)
        case let .switchInline(samePeer, query, peerTypes):
            valueType = .instantpagebuttonactionSwitchinline
            let queryOffset = builder.create(string: query)
            let start = TelegramCore_InstantPageButtonAction_SwitchInline.startInstantPageButtonAction_SwitchInline(&builder)
            TelegramCore_InstantPageButtonAction_SwitchInline.add(query: queryOffset, &builder)
            TelegramCore_InstantPageButtonAction_SwitchInline.add(samePeer: samePeer, &builder)
            TelegramCore_InstantPageButtonAction_SwitchInline.add(peerTypes: peerTypes.rawValue, &builder)
            offset = TelegramCore_InstantPageButtonAction_SwitchInline.endInstantPageButtonAction_SwitchInline(&builder, start: start)
        case let .openUserProfile(peerId):
            valueType = .instantpagebuttonactionOpenuserprofile
            let start = TelegramCore_InstantPageButtonAction_OpenUserProfile.startInstantPageButtonAction_OpenUserProfile(&builder)
            TelegramCore_InstantPageButtonAction_OpenUserProfile.add(peerId: peerId.toInt64(), &builder)
            offset = TelegramCore_InstantPageButtonAction_OpenUserProfile.endInstantPageButtonAction_OpenUserProfile(&builder, start: start)
        case let .copyText(payload):
            valueType = .instantpagebuttonactionCopytext
            let payloadOffset = builder.create(string: payload)
            let start = TelegramCore_InstantPageButtonAction_CopyText.startInstantPageButtonAction_CopyText(&builder)
            TelegramCore_InstantPageButtonAction_CopyText.add(payload: payloadOffset, &builder)
            offset = TelegramCore_InstantPageButtonAction_CopyText.endInstantPageButtonAction_CopyText(&builder, start: start)
        case .disabled, .text, .requestPhone, .requestMap, .setupPoll, .requestPeer:
            // The five keyboard-only cases cannot reach a page button (see `action` above), so they
            // collapse onto disabled. Keeping the codec total rather than trapping means a future
            // caller that does construct one gets an inert button, not a crash.
            valueType = .instantpagebuttonactionDisabled
            let start = TelegramCore_InstantPageButtonAction_Disabled.startInstantPageButtonAction_Disabled(&builder)
            offset = TelegramCore_InstantPageButtonAction_Disabled.endInstantPageButtonAction_Disabled(&builder, start: start)
        }

        return TelegramCore_InstantPageButtonAction.createInstantPageButtonAction(&builder, valueType: valueType, valueOffset: offset)
    }
}

public extension InstantPageButton {
    init(flatBuffersObject: TelegramCore_InstantPageButton) throws {
        self.text = try RichText(flatBuffersObject: flatBuffersObject.text)
        self.action = try ReplyMarkupButtonAction(flatBuffersObject: flatBuffersObject.action)
        let rawColor = flatBuffersObject.color
        self.color = rawColor == -1 ? nil : ReplyMarkupButton.Style.Color(rawValue: rawColor)
        self.isLink = flatBuffersObject.isLink
    }

    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let textOffset = self.text.encodeToFlatBuffers(builder: &builder)
        let actionOffset = self.action.encodeToFlatBuffers(builder: &builder)
        let start = TelegramCore_InstantPageButton.startInstantPageButton(&builder)
        TelegramCore_InstantPageButton.add(text: textOffset, &builder)
        TelegramCore_InstantPageButton.add(action: actionOffset, &builder)
        TelegramCore_InstantPageButton.add(color: self.color?.rawValue ?? -1, &builder)
        TelegramCore_InstantPageButton.add(isLink: self.isLink, &builder)
        return TelegramCore_InstantPageButton.endInstantPageButton(&builder, start: start)
    }
}
