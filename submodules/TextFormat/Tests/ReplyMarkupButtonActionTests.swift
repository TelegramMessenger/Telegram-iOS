import XCTest
import Postbox
import TelegramApi
import TelegramCore

/// Covers the two shared `Api` → `ReplyMarkupButtonAction` mappers introduced when the schema
/// collapsed 16 per-behaviour keyboard-button constructors into `keyboardButton` (ButtonType) and
/// `keyboardInlineButton` (InlineButtonType). The schema has since moved `keyboardInlineButton` into
/// its own `KeyboardInlineButton` type (with a matching `keyboardInlineButtonRow`), but the two
/// action mappers below are unaffected — `Api.ButtonType` and `Api.InlineButtonType` did not change.
///
/// Scope limit worth knowing: `ReplyMarkupButton(apiButton:)` and
/// `ReplyMarkupMessageAttribute(apiMarkup:)` are **internal** to TelegramCore, so the button-level
/// assembly (title + style + fwdText threading) is not reachable from this test module and is not
/// covered here. Only the `public` action mappers are. Widening TelegramCore's API surface purely
/// for a test was judged the wrong trade.
final class ReplyMarkupButtonActionTests: XCTestCase {
    private func postboxRoundTrip(_ action: ReplyMarkupButtonAction) -> ReplyMarkupButtonAction {
        let encoder = PostboxEncoder()
        action.encode(encoder)
        return ReplyMarkupButtonAction(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
    }

    private func inlineAction(_ type: Api.InlineButtonType) -> ReplyMarkupButtonAction {
        return ReplyMarkupButtonAction.from(apiType: type).action
    }

    private func keyboardAction(_ type: Api.ButtonType) -> ReplyMarkupButtonAction {
        return ReplyMarkupButtonAction.from(apiType: type).action
    }

    // MARK: - .disabled Postbox coding (discriminator 14)

    func test_disabled_postboxRoundTrip() {
        XCTAssertEqual(self.postboxRoundTrip(.disabled), .disabled)
    }

    /// Discriminator 14 must not collide with an existing tag. If it did, a stored `.disabled`
    /// would decode as something tappable — the exact failure this case exists to prevent.
    func test_disabled_doesNotCollideWithOtherTags() {
        XCTAssertNotEqual(self.postboxRoundTrip(.disabled), .text)
        XCTAssertNotEqual(self.postboxRoundTrip(.disabled), .payment)
        XCTAssertNotEqual(self.postboxRoundTrip(.disabled), .openWebApp)
        XCTAssertNotEqual(self.postboxRoundTrip(.disabled), .copyText(payload: ""))
    }

    /// Every pre-existing action must still survive its own round-trip — the new tag must not have
    /// disturbed the established numbering.
    func test_existingActions_stillRoundTrip() {
        XCTAssertEqual(self.postboxRoundTrip(.text), .text)
        XCTAssertEqual(self.postboxRoundTrip(.url("https://t.me")), .url("https://t.me"))
        XCTAssertEqual(self.postboxRoundTrip(.requestPhone), .requestPhone)
        XCTAssertEqual(self.postboxRoundTrip(.requestMap), .requestMap)
        XCTAssertEqual(self.postboxRoundTrip(.openWebApp), .openWebApp)
        XCTAssertEqual(self.postboxRoundTrip(.payment), .payment)
        XCTAssertEqual(self.postboxRoundTrip(.urlAuth(url: "https://a", buttonId: 7)),
                       .urlAuth(url: "https://a", buttonId: 7))
        XCTAssertEqual(self.postboxRoundTrip(.setupPoll(isQuiz: true)), .setupPoll(isQuiz: true))
        XCTAssertEqual(self.postboxRoundTrip(.setupPoll(isQuiz: nil)), .setupPoll(isQuiz: nil))
        XCTAssertEqual(self.postboxRoundTrip(.openWebView(url: "https://w", simple: true)),
                       .openWebView(url: "https://w", simple: true))
        XCTAssertEqual(self.postboxRoundTrip(.copyText(payload: "abc")), .copyText(payload: "abc"))
    }

    // MARK: - Api.InlineButtonType mapping (all 12 constructors)

    func test_inlineButtonType_url() {
        XCTAssertEqual(self.inlineAction(.inlineButtonTypeUrl(.init(url: "https://t.me"))), .url("https://t.me"))
    }

    func test_inlineButtonType_webView() {
        XCTAssertEqual(self.inlineAction(.inlineButtonTypeWebView(.init(url: "https://w"))),
                       .openWebView(url: "https://w", simple: false))
    }

    func test_inlineButtonType_copy() {
        XCTAssertEqual(self.inlineAction(.inlineButtonTypeCopy(.init(copyText: "payload"))),
                       .copyText(payload: "payload"))
    }

    func test_inlineButtonType_game_and_buy() {
        XCTAssertEqual(self.inlineAction(.inlineButtonTypeGame), .openWebApp)
        XCTAssertEqual(self.inlineAction(.inlineButtonTypeBuy), .payment)
    }

    func test_inlineButtonType_disabled() {
        XCTAssertEqual(self.inlineAction(.inlineButtonTypeDisabled), .disabled)
    }

    func test_inlineButtonType_userProfile() {
        let expected = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(42))
        XCTAssertEqual(self.inlineAction(.inlineButtonTypeUserProfile(.init(userId: 42))),
                       .openUserProfile(peerId: expected))
    }

    /// The input variant carries an InputUser the client cannot resolve, so it degenerates to id 0.
    /// Preserved from the pre-unification behaviour deliberately.
    func test_inlineButtonType_inputUserProfile_degeneratesToZero() {
        let zero = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(0))
        XCTAssertEqual(self.inlineAction(.inputInlineButtonTypeUserProfile(.init(userId: .inputUserEmpty))),
                       .openUserProfile(peerId: zero))
    }

    func test_inlineButtonType_callback_carriesDataAndPasswordFlag() {
        guard case let .callback(requiresPassword, data) = self.inlineAction(
            .inlineButtonTypeCallback(.init(flags: 1 << 0, data: Buffer(data: Data([1, 2, 3]))))
        ) else {
            return XCTFail("expected callback")
        }
        XCTAssertTrue(requiresPassword)
        XCTAssertEqual(data.makeData(), Data([1, 2, 3]))
    }

    func test_inlineButtonType_callback_withoutPasswordFlag() {
        guard case let .callback(requiresPassword, _) = self.inlineAction(
            .inlineButtonTypeCallback(.init(flags: 0, data: Buffer(data: Data())))
        ) else {
            return XCTFail("expected callback")
        }
        XCTAssertFalse(requiresPassword)
    }

    func test_inlineButtonType_switchInline_samePeerAndPeerTypes() {
        guard case let .switchInline(samePeer, query, peerTypes) = self.inlineAction(
            .inlineButtonTypeSwitchInline(.init(flags: 1 << 0, query: "q", peerTypes: [.inlineQueryPeerTypeBotPM]))
        ) else {
            return XCTFail("expected switchInline")
        }
        XCTAssertTrue(samePeer)
        XCTAssertEqual(query, "q")
        XCTAssertTrue(peerTypes.contains(.bots))
    }

    func test_inlineButtonType_switchInline_nilPeerTypesIsEmpty() {
        guard case let .switchInline(samePeer, _, peerTypes) = self.inlineAction(
            .inlineButtonTypeSwitchInline(.init(flags: 0, query: "", peerTypes: nil))
        ) else {
            return XCTFail("expected switchInline")
        }
        XCTAssertFalse(samePeer)
        XCTAssertTrue(peerTypes.isEmpty)
    }

    // MARK: - fwd_text, which now lives only on the urlAuth constructors

    func test_urlAuth_carriesFwdText() {
        let result = ReplyMarkupButtonAction.from(apiType: .inlineButtonTypeUrlAuth(
            .init(flags: 1 << 0, fwdText: "Forwarded label", url: "https://a", buttonId: 7)))
        XCTAssertEqual(result.action, .urlAuth(url: "https://a", buttonId: 7))
        XCTAssertEqual(result.fwdText, "Forwarded label")
    }

    func test_urlAuth_absentFwdTextIsNil() {
        let result = ReplyMarkupButtonAction.from(apiType: .inlineButtonTypeUrlAuth(
            .init(flags: 0, fwdText: nil, url: "https://a", buttonId: 3)))
        XCTAssertEqual(result.action, .urlAuth(url: "https://a", buttonId: 3))
        XCTAssertNil(result.fwdText)
    }

    /// The input variant has no buttonId on the wire; 0 is the established stand-in.
    func test_inputUrlAuth_buttonIdIsZeroAndFwdTextSurvives() {
        let result = ReplyMarkupButtonAction.from(apiType: .inputInlineButtonTypeUrlAuth(
            .init(flags: 0, fwdText: "Label", url: "https://a", bot: .inputUserEmpty)))
        XCTAssertEqual(result.action, .urlAuth(url: "https://a", buttonId: 0))
        XCTAssertEqual(result.fwdText, "Label")
    }

    /// No non-urlAuth inline constructor may invent a fwdText.
    func test_nonUrlAuthInlineTypes_haveNoFwdText() {
        XCTAssertNil(ReplyMarkupButtonAction.from(apiType: .inlineButtonTypeUrl(.init(url: "u"))).fwdText)
        XCTAssertNil(ReplyMarkupButtonAction.from(apiType: .inlineButtonTypeDisabled).fwdText)
        XCTAssertNil(ReplyMarkupButtonAction.from(apiType: .inlineButtonTypeGame).fwdText)
    }

    // MARK: - Api.ButtonType mapping (all 7 constructors)

    /// The old plain `keyboardButton` is now `keyboardButton type=buttonTypeDefault`.
    func test_buttonTypeDefault_isPlainText() {
        XCTAssertEqual(self.keyboardAction(.buttonTypeDefault), .text)
    }

    func test_buttonType_phoneAndLocation() {
        XCTAssertEqual(self.keyboardAction(.buttonTypeRequestPhone), .requestPhone)
        XCTAssertEqual(self.keyboardAction(.buttonTypeRequestGeoLocation), .requestMap)
    }

    /// `buttonTypeSimpleWebView` is the only ButtonType producing openWebView, and it is always
    /// simple: true — the distinction from the inline webView constructor.
    func test_buttonType_simpleWebView_isSimple() {
        XCTAssertEqual(self.keyboardAction(.buttonTypeSimpleWebView(.init(url: "https://s"))),
                       .openWebView(url: "https://s", simple: true))
    }

    func test_buttonType_requestPoll_quizFlagVariants() {
        XCTAssertEqual(self.keyboardAction(.buttonTypeRequestPoll(.init(flags: 1 << 0, quiz: .boolTrue))),
                       .setupPoll(isQuiz: true))
        XCTAssertEqual(self.keyboardAction(.buttonTypeRequestPoll(.init(flags: 1 << 0, quiz: .boolFalse))),
                       .setupPoll(isQuiz: false))
        XCTAssertEqual(self.keyboardAction(.buttonTypeRequestPoll(.init(flags: 0, quiz: nil))),
                       .setupPoll(isQuiz: nil))
    }

    func test_buttonType_requestPeer_user() {
        guard case let .requestPeer(peerType, buttonId, maxQuantity) = self.keyboardAction(
            .buttonTypeRequestPeer(.init(
                flags: 0,
                buttonId: 5,
                peerType: .requestPeerTypeUser(.init(flags: 0, bot: .boolTrue, premium: nil)),
                maxQuantity: 3))
        ) else {
            return XCTFail("expected requestPeer")
        }
        XCTAssertEqual(buttonId, 5)
        XCTAssertEqual(maxQuantity, 3)
        guard case let .user(user) = peerType else {
            return XCTFail("expected user peer type")
        }
        XCTAssertEqual(user.isBot, true)
        XCTAssertNil(user.isPremium)
    }

    /// The input variant must map identically — the two arms used to be duplicated verbatim and are
    /// now one initializer, so this guards the de-duplication.
    func test_inputButtonType_requestPeer_matchesNonInputVariant() {
        let peerType = Api.RequestPeerType.requestPeerTypeBroadcast(.init(
            flags: 1 << 0, hasUsername: .boolTrue, userAdminRights: nil, botAdminRights: nil))

        let plain = self.keyboardAction(.buttonTypeRequestPeer(.init(
            flags: 0, buttonId: 9, peerType: peerType, maxQuantity: 1)))
        let input = self.keyboardAction(.inputButtonTypeRequestPeer(.init(
            flags: 0, buttonId: 9, peerType: peerType, maxQuantity: 1)))

        XCTAssertEqual(plain, input)
    }

    func test_buttonType_requestPeer_groupFlags() {
        guard case let .requestPeer(peerType, _, _) = self.keyboardAction(
            .buttonTypeRequestPeer(.init(
                flags: 0,
                buttonId: 1,
                peerType: .requestPeerTypeChat(.init(
                    flags: (1 << 0) | (1 << 5),
                    hasUsername: nil,
                    forum: .boolTrue,
                    userAdminRights: nil,
                    botAdminRights: nil)),
                maxQuantity: 1))
        ) else {
            return XCTFail("expected requestPeer")
        }
        guard case let .group(group) = peerType else {
            return XCTFail("expected group peer type")
        }
        XCTAssertTrue(group.isCreator)
        XCTAssertTrue(group.botParticipant)
        XCTAssertEqual(group.isForum, true)
        XCTAssertNil(group.hasUsername)
    }

    /// No ButtonType constructor may produce fwdText — fwd_text is inline-only in the new schema.
    func test_buttonTypes_neverProduceFwdText() {
        XCTAssertNil(ReplyMarkupButtonAction.from(apiType: .buttonTypeDefault).fwdText)
        XCTAssertNil(ReplyMarkupButtonAction.from(apiType: .buttonTypeRequestPhone).fwdText)
        XCTAssertNil(ReplyMarkupButtonAction.from(apiType: .buttonTypeSimpleWebView(.init(url: "u"))).fwdText)
    }
}
