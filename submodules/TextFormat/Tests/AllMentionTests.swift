import XCTest
import UIKit
import Postbox
import TelegramCore
@testable import TextFormat

final class AllMentionTests: XCTestCase {
    private func collectiveEntities(_ text: NSAttributedString) -> [MessageTextEntity] {
        return generateChatInputTextEntities(text).filter {
            if case let .Custom(type) = $0.type {
                return type == ApplicationSpecificEntityType.AllMention
            }
            return false
        }
    }

    func testLiteralTextDoesNotCreateProductionCollectiveEntity() {
        XCTAssertTrue(collectiveEntities(NSAttributedString(string: "@all встречаемся в семь")).isEmpty)
    }

    func testSelectedAtomUsesUTF16OffsetsAndSurvivesInlineFormatting() {
        let text = NSMutableAttributedString(string: "👋 ")
        text.append(allMentionInputString())
        text.append(NSAttributedString(string: ", встречаемся!"))
        text.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 4, length: 2))

        XCTAssertEqual(allMentionRanges(in: text), [NSRange(location: 3, length: 4)])
        let entities = collectiveEntities(text)
        XCTAssertEqual(entities.count, 1)
        XCTAssertEqual(entities.first?.range, 3 ..< 7)
        XCTAssertEqual(allMentionRanges(in: attributedString(from: chatInputContent(from: text))), [NSRange(location: 3, length: 4)])
    }

    func testEditedAtomsAndIdentifierBoundariesAreRejected() {
        for text in ["@alligator", "a@all", "@@all", "@all_", "@all2", "@allя", "я@all", "@all\u{301}"] {
            let range = (text as NSString).range(of: "@all")
            XCTAssertFalse(isValidAllMentionRange(in: text, range: range), text)
            let attributed = NSMutableAttributedString(string: text)
            attributed.addAttribute(ChatTextInputAttributes.allMention, value: true as NSNumber, range: range)
            XCTAssertTrue(collectiveEntities(attributed).isEmpty, text)
        }
        XCTAssertTrue(isValidAllMentionRange(in: "(@all), 👋", range: NSRange(location: 1, length: 4)))
    }

    func testMalformedRangesAreRejected() {
        for range in [NSRange(location: NSNotFound, length: 4), NSRange(location: -1, length: 4), NSRange(location: 0, length: 3), NSRange(location: 1, length: 4), NSRange(location: Int.max, length: 4)] {
            XCTAssertFalse(isValidAllMentionRange(in: "@all", range: range))
        }
    }

    func testLocalDemoRawPromotionFindsOnlyStandaloneTokens() {
        let text = "👋 @all, @alligator a@all @@all (@all) @ALL @all\u{301}"
        XCTAssertEqual(allMentionTextRanges(in: text), [NSRange(location: 3, length: 4), NSRange(location: 33, length: 4)])
        XCTAssertTrue(allMentionTextRanges(in: "").isEmpty)
    }

    func testRawMentionsInsideCodeAndQuotesDoNotBecomeCalls() {
        for type: MessageTextEntityType in [.Code, .Pre(language: "swift"), .BlockQuote(isCollapsed: false), .BlockQuote(isCollapsed: true)] {
            let formatting = MessageTextEntity(range: 0 ..< 4, type: type)
            XCTAssertTrue(allMentionTextRanges(in: "@all", entities: [formatting]).isEmpty)
            XCTAssertEqual(allMentionEntitiesForLocalDemo(text: "@all", entities: [formatting], isEnabled: true), [formatting])
        }
    }

    func testMixedUTF16MessageOnlyCallsFromUnprotectedText() {
        let text = "👋 @all | @all | @all | @all"
        let formatting = [
            MessageTextEntity(range: 10 ..< 14, type: .Code),
            MessageTextEntity(range: 17 ..< 21, type: .BlockQuote(isCollapsed: false))
        ]
        let normalized = allMentionEntitiesForLocalDemo(text: text, entities: formatting, isEnabled: true)
        XCTAssertEqual(normalized.filter { $0.type == .Custom(type: ApplicationSpecificEntityType.AllMention) }.map { $0.range }, [3 ..< 7, 24 ..< 28])
        XCTAssertEqual(Array(normalized.prefix(2)), formatting)
    }

    func testSelectedAtomMovedIntoProtectedFormattingLosesCollectiveIdentity() {
        let blocks: [Any] = [
            ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: false),
            ChatTextInputTextQuoteAttribute(kind: .quote, isCollapsed: true),
            ChatTextInputTextQuoteAttribute(kind: .code(language: "swift"), isCollapsed: false)
        ]
        for block in blocks {
            let text = NSMutableAttributedString(attributedString: allMentionInputString())
            text.addAttribute(ChatTextInputAttributes.block, value: block, range: NSRange(location: 0, length: 4))
            XCTAssertTrue(allMentionRanges(in: text).isEmpty)
            XCTAssertTrue(collectiveEntities(text).isEmpty)
            XCTAssertFalse(generateChatInputTextEntities(text).isEmpty, "Keep the quote/code formatting")
        }
        let inlineCode = NSMutableAttributedString(attributedString: allMentionInputString())
        inlineCode.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: NSRange(location: 2, length: 1))
        XCTAssertTrue(collectiveEntities(inlineCode).isEmpty, "Even partial protected formatting excludes the complete token")
    }

    func testSendBoundaryRemovesStaleSelectedAtomInsideCode() {
        let code = MessageTextEntity(range: 0 ..< 4, type: .Pre(language: nil))
        let stale = MessageTextEntity(range: 0 ..< 4, type: .Custom(type: ApplicationSpecificEntityType.AllMention))
        XCTAssertEqual(allMentionEntitiesForLocalDemo(text: "@all", entities: [code, stale], isEnabled: true), [code])
        let partialCode = MessageTextEntity(range: 2 ..< 3, type: .Code)
        XCTAssertEqual(allMentionEntitiesForLocalDemo(text: "@all", entities: [partialCode, stale], isEnabled: true), [partialCode])
    }

    func testAutocompleteRejectsProtectedAndInvalidQueryRanges() {
        let text = NSMutableAttributedString(string: "@al")
        let range = NSRange(location: 0, length: 3)
        XCTAssertTrue(isAllMentionContextAllowed(in: text, range: range))
        text.addAttribute(ChatTextInputAttributes.monospace, value: true as NSNumber, range: range)
        XCTAssertFalse(isAllMentionContextAllowed(in: text, range: range))
        for invalid in [NSRange(location: NSNotFound, length: 1), NSRange(location: -1, length: 1), NSRange(location: 0, length: 0), NSRange(location: 2, length: 2), NSRange(location: Int.max, length: Int.max)] {
            XCTAssertFalse(isAllMentionContextAllowed(in: text, range: invalid))
        }
    }

    func testLinksAndExplicitPersonalMentionsKeepTheirMeaning() {
        let text = "https://example.com/@all @all"
        XCTAssertEqual(allMentionTextRanges(in: text), [(text as NSString).range(of: "@all", options: .backwards)])
        for type: MessageTextEntityType in [.TextUrl(url: "https://example.com"), .TextMention(peerId: EnginePeer.Id(123))] {
            let original = MessageTextEntity(range: 0 ..< 4, type: type)
            XCTAssertEqual(allMentionEntitiesForLocalDemo(text: "@all", entities: [original], isEnabled: true), [original])
        }
        let link = NSMutableAttributedString(attributedString: allMentionInputString())
        link.addAttribute(ChatTextInputAttributes.textUrl, value: ChatTextInputTextUrlAttribute(url: "https://example.com"), range: NSRange(location: 0, length: 4))
        XCTAssertTrue(collectiveEntities(link).isEmpty)
    }

    func testSendBoundaryStillHonorsPermissionAndOrdinaryMentions() {
        let personal = MessageTextEntity(range: 5 ..< 11, type: .Mention)
        let stale = MessageTextEntity(range: 0 ..< 4, type: .Custom(type: ApplicationSpecificEntityType.AllMention))
        let generic = MessageTextEntity(range: 0 ..< 4, type: .Mention)
        XCTAssertEqual(allMentionEntitiesForLocalDemo(text: "@all @alice", entities: [stale, generic, personal], isEnabled: false), [personal])
        XCTAssertEqual(allMentionEntitiesForLocalDemo(text: "@all @alice", entities: [generic, personal], isEnabled: true), [personal, stale])
    }

    func testTypedContentAndPostboxDraftRoundTrip() throws {
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: [
            ChatInputRun(text: "@all", attributes: ChatInputInlineAttributes(entity: .allMention)),
            ChatInputRun(text: " встречаемся в семь")
        ]))])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
        let data = try AdaptedPostboxEncoder().encode(content)
        XCTAssertEqual(try AdaptedPostboxDecoder().decode(ChatInputContent.self, from: data), content)
    }

    func testEditingAtomIntoUsernameRemovesCollectiveIdentity() {
        let text = NSMutableAttributedString(attributedString: allMentionInputString())
        text.append(NSAttributedString(string: "igator"))
        let roundTrip = attributedString(from: chatInputContent(from: text))
        XCTAssertTrue(allMentionRanges(in: roundTrip).isEmpty)
        XCTAssertTrue(collectiveEntities(roundTrip).isEmpty)
        XCTAssertEqual(roundTrip.string, "@alligator")
    }

    func testMessageEntityRestoresComposerIdentityWithoutPeerMention() {
        let text = chatInputStateStringWithAppliedEntities("@all привет", entities: [MessageTextEntity(range: 0 ..< 4, type: .Custom(type: ApplicationSpecificEntityType.AllMention))])
        XCTAssertEqual(allMentionRanges(in: text), [NSRange(location: 0, length: 4)])
        XCTAssertNil(text.attribute(ChatTextInputAttributes.textMention, at: 0, effectiveRange: nil))
        XCTAssertTrue(allMentionRanges(in: chatInputStateStringWithAppliedEntities("@alice", entities: [MessageTextEntity(range: 0 ..< 4, type: .Custom(type: ApplicationSpecificEntityType.AllMention))])).isEmpty)
    }

    func testNativeMessageRenderingUsesDedicatedBlueAttribute() {
        let font = UIFont.systemFont(ofSize: 17.0)
        let text = stringWithAppliedEntities("@all привет", entities: [MessageTextEntity(range: 0 ..< 4, type: .Custom(type: ApplicationSpecificEntityType.AllMention))], baseColor: .black, linkColor: .blue, baseFont: font, linkFont: font, boldFont: font, italicFont: font, boldItalicFont: font, fixedFont: font, blockQuoteFont: font, message: nil)
        XCTAssertEqual(text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .blue)
        XCTAssertNotNil(text.attribute(NSAttributedString.Key(TelegramTextAttributes.AllMention), at: 0, effectiveRange: nil))
        XCTAssertNil(text.attribute(NSAttributedString.Key(TelegramTextAttributes.PeerMention), at: 0, effectiveRange: nil))
        XCTAssertNil(text.attribute(NSAttributedString.Key(TelegramTextAttributes.PeerTextMention), at: 0, effectiveRange: nil))
    }

    func testPersonalMentionsAndDatesRetainTheirExistingIdentity() {
        let peerId = EnginePeer.Id(123)
        let content = ChatInputContent(blocks: [.paragraph(ChatInputParagraph(runs: [
            ChatInputRun(text: "Мария", attributes: ChatInputInlineAttributes(entity: .mention(peerId))),
            ChatInputRun(text: " "),
            ChatInputRun(text: "завтра", attributes: ChatInputInlineAttributes(entity: .date(1_800_000_000)))
        ]))])
        XCTAssertEqual(chatInputContent(from: attributedString(from: content)), content)
        XCTAssertTrue(collectiveEntities(attributedString(from: content)).isEmpty)
    }

    func testNativeEditorMarkerIsExactAndDistinctFromUserLinks() {
        if case .allMention = classifyChatLink(allMentionMarkdownURL()) {} else { XCTFail("Expected collective marker") }
        let attribute = chatInputLinkAttribute(forLink: allMentionMarkdownURL())
        XCTAssertEqual(attribute.key, ChatTextInputAttributes.allMention)
        for url in ["tg://all-mention?user=1", "https://example.com/@all", "tg://all-mentions"] {
            if case let .url(value) = classifyChatLink(url) { XCTAssertEqual(value, url) } else { XCTFail("Unexpected marker: \(url)") }
        }
    }
}
