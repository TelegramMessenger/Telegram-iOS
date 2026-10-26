import XCTest
import UIKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import TextFormat
import AppBundle
import ObjectiveC
@testable import ChatListUI

final class ChatListRichTextPreviewTests: XCTestCase {
    // An unhosted XCTest runner has no app localization resources. Redirect only
    // these resource lookups to the test bundle; leave production bundle code intact.
    override class func setUp() {
        super.setUp()
        exchangeResourceLookups()
    }

    override class func tearDown() {
        exchangeResourceLookups()
        super.tearDown()
    }

    private class func exchangeResourceLookups() {
        for (original, replacement) in [
            (#selector(Bundle.path(forResource:ofType:)), #selector(Bundle.previewResourcePath(_:ofType:))),
            (#selector(Bundle.path(forResource:ofType:inDirectory:forLocalization:)), #selector(Bundle.previewLocalizedResourcePath(_:ofType:inDirectory:forLocalization:)))
        ] {
            method_exchangeImplementations(class_getInstanceMethod(Bundle.self, original)!, class_getInstanceMethod(Bundle.self, replacement)!)
        }
    }

    private let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(123))
    private let dateFormat = PresentationDateTimeFormat(timeFormat: .military, dateFormat: .dayFirst, dateSeparator: ".", dateSuffix: "", requiresFullYear: false, decimalSeparator: ".", groupingSeparator: "")

    private func message(_ text: String = "", blocks: [InstantPageBlock]? = nil, media: [EngineMedia] = [], extraAttributes: [MessageAttribute] = []) -> EngineMessage {
        let attributes: [MessageAttribute] = blocks.map { [RichTextMessageAttribute(instantPage: InstantPage(blocks: $0, media: [:], isComplete: true, rtl: false, url: "", views: nil), fullInstantPage: nil)] } ?? []
        return EngineMessage(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 0, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: nil, text: text, attributes: attributes + extraAttributes, media: media, peers: [:], associatedMessages: [:], associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:])
    }

    private func selected(_ messages: [EngineMessage]) -> (String, NSAttributedString?) {
        let value = chatListItemStrings(strings: defaultPresentationStrings, nameDisplayOrder: .firstLast, dateTimeFormat: dateFormat, contentSettings: .default, messages: messages, chatPeer: EngineRenderedPeer(peerId: peerId, peers: [:], associatedMedia: [:]), accountPeerId: peerId)
        return (value.messageText, value.richTextPreview)
    }

    func testLocalizationResourcesAvailable() {
        XCTAssertNotNil(getAppBundle().path(forResource: "PresentationStrings", ofType: "data"))
        XCTAssertNotNil(getAppBundle().path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en"))
    }

    func testFirstNonemptyCandidateWins() {
        let rich = message(blocks: [.paragraph(.textSpoiler(text: .plain("first")))])
        for second in [message("second"), message(blocks: [.paragraph(.plain("second"))])] {
            let value = selected([rich, second])
            XCTAssertEqual(value.0, "first")
            XCTAssertEqual(value.1?.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
        }
        let plain = selected([message("plain"), rich])
        XCTAssertEqual(plain.0, "plain")
        XCTAssertNil(plain.1)
    }

    func testEmptyRichFallsBackToMessageText() {
        XCTAssertEqual(selected([message("fallback", blocks: [])]).0, "fallback")
        XCTAssertEqual(selected([message(blocks: []), message("later")]).0, "later")
    }

    func testOverrideDiscardsPreviewEvenWhenTextMatches() {
        let media = EngineMedia(TelegramMediaAction(action: .customText(text: "same", entities: [], additionalAttributes: nil)))
        let result = selected([message(blocks: [.paragraph(.textSpoiler(text: .plain("same")))], media: [media])])
        XCTAssertEqual(result.0, "same")
        XCTAssertNil(result.1)
    }

    func testSameTextDifferentAttributesAndSpoilerOverlay() {
        let plain = NSAttributedString(string: "code 12345")
        let rich = NSMutableAttributedString(attributedString: plain)
        rich.addAttribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), value: true, range: NSRange(location: 0, length: 4))
        func compose(_ text: NSAttributedString) -> NSAttributedString {
            return chatListRichTextPreview(text, font: .systemFont(ofSize: 15), italicFont: .italicSystemFont(ofSize: 15), textColor: .black, additionalSpoilers: [NSRange(location: 5, length: 5), NSRange(location: Int.max, length: Int.max)])
        }
        let a = compose(plain)
        let b = compose(rich)
        XCTAssertNil(a.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil))
        XCTAssertEqual(b.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
        XCTAssertEqual(b.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 5, effectiveRange: nil) as? Bool, true)
    }

    func testAccessibilityIconProjection() {
        let result = selected([message(blocks: [.formula(latex: "x")])])
        XCTAssertEqual(result.0, "\u{fffc}")
        XCTAssertEqual(result.1.map(instantPagePreviewPlainText), "[formula]")
        XCTAssertEqual(result.1?.string, "\u{fffc}")
    }

    func testSharedDescriptionPrefersRichContentOverFallbackText() {
        let message = message("fallback", blocks: [.paragraph(.textSpoiler(text: .plain("rich")))])
        let (text, _, isPlainText) = descriptionStringForMessage(contentSettings: .default, message: message, strings: defaultPresentationStrings, nameDisplayOrder: .firstLast, dateTimeFormat: dateFormat, accountPeerId: peerId)
        XCTAssertEqual(text.string, "rich")
        XCTAssertFalse(isPlainText)
        XCTAssertEqual(text.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
    }

    func testRestrictionOverridesRichContent() {
        let restricted = message("fallback", blocks: [.paragraph(.plain("rich"))], extraAttributes: [RestrictedContentMessageAttribute(rules: [RestrictionRule(platform: "ios", reason: "copyright", text: "Restricted")])])
        let result = selected([restricted])
        XCTAssertEqual(result.0, "Restricted")
        XCTAssertNil(result.1)
        let description = descriptionStringForMessage(contentSettings: .default, message: restricted, strings: defaultPresentationStrings, nameDisplayOrder: .firstLast, dateTimeFormat: dateFormat, accountPeerId: peerId)
        XCTAssertEqual(description.0.string, "Restricted")
    }
}

private extension Bundle {
    @objc func previewResourcePath(_ name: String?, ofType type: String?) -> String? {
        if name == "PresentationStrings", type == "data", self == getAppBundle() {
            return Bundle(for: ChatListRichTextPreviewTests.self).previewResourcePath(name, ofType: type)
        }
        return self.previewResourcePath(name, ofType: type)
    }

    @objc func previewLocalizedResourcePath(_ name: String?, ofType type: String?, inDirectory directory: String?, forLocalization localization: String?) -> String? {
        if name == "Localizable", type == "strings", self == getAppBundle() {
            return Bundle(for: ChatListRichTextPreviewTests.self).previewLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
        }
        return self.previewLocalizedResourcePath(name, ofType: type, inDirectory: directory, forLocalization: localization)
    }
}
