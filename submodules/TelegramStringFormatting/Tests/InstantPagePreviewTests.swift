import XCTest
import UIKit
import Postbox
import TelegramCore
import TextFormat
@testable import TelegramStringFormatting

final class InstantPagePreviewTests: XCTestCase {
    private func preview(_ blocks: [InstantPageBlock], media: [MediaId: Media] = [:]) -> NSAttributedString {
        return buildInstantPagePreview(blocks: blocks, environment: InstantPagePreviewEnvironment(label: { label in
            switch label {
            case .photo: return "Photo"
            case .video: return "Video"
            case .voice: return "Voice"
            case .music: return "Music"
            case .file: return "File"
            case .location: return "Location"
            case .formula: return "[formula]"
            case .table: return "[table]"
            case .unsupported: return "Unsupported"
            case .embeddedContent: return "Embedded content"
            case .channel: return "Channel"
            case let .photos(count): return "\(count) Photos"
            case let .videos(count): return "\(count) Videos"
            }
        }, formatDate: { _, _ in "FORMATTED" }, media: media))
    }

    private func caption(_ text: RichText = .empty) -> InstantPageCaption {
        return InstantPageCaption(text: text, credit: .empty)
    }

    private func photo(_ text: RichText = .empty) -> InstantPageBlock {
        return .image(id: MediaId(namespace: 0, id: 1), caption: caption(text), url: nil, webpageId: nil, spoiler: false)
    }

    func testCanonicalWhitespaceAndQuoteSeparators() {
        XCTAssertEqual(preview([.paragraph(.plain(" A\r\n\t B ")), .anchor("x"), .pullQuote(text: .plain("body"), caption: .plain("caption"))]).string, "A B body caption")
    }

    func testUnicodeBudget() {
        XCTAssertEqual(preview([.paragraph(.plain(String(repeating: "a", count: 200)))]).string, String(repeating: "a", count: 200))
        XCTAssertEqual(preview([.paragraph(.plain(String(repeating: "a", count: 201)))]).string, String(repeating: "a", count: 199) + "…")
        XCTAssertEqual(preview([.paragraph(.plain(String(repeating: "👨‍👩‍👧‍👦", count: 201)))]).string, String(repeating: "👨‍👩‍👧‍👦", count: 199) + "…")
    }

    func testTraversalAndTextInspectionBounds() {
        var block = InstantPageBlock.paragraph(.plain("unreachable"))
        for _ in 0 ..< 65 { block = .cover(block) }
        XCTAssertEqual(preview([block]).string, "…")
        XCTAssertEqual(preview(Array(repeating: .anchor(""), count: 4097)).string, "…")
        XCTAssertEqual(preview([.paragraph(.plain(String(repeating: " ", count: 16385) + "hidden"))]).string, "…")
    }

    func testAdjacentIcons() {
        let text = preview([.paragraph(.concat([.formula(latex: "x"), .formula(latex: "y")]))])
        XCTAssertEqual(text.string, "\u{fffc}\u{fffc}")
    }

    func testCollections() {
        for slideshow in [false, true] {
            func collection(_ blocks: [InstantPageBlock], _ text: RichText = .empty) -> InstantPageBlock {
                return slideshow ? .slideshow(items: blocks, caption: caption(text)) : .collage(items: blocks, caption: caption(text))
            }
            XCTAssertEqual(preview([collection([photo(), photo(), photo()])]).string, "3 Photos")
            XCTAssertEqual(preview([collection([photo()], .plain("Album"))]).string, "Album")
            XCTAssertEqual(preview([collection([photo(), photo(.plain("Beach"))])]).string, "Photo Photo Beach")
            XCTAssertEqual(preview([collection([.cover(photo()), collection([photo()])])]).string, "2 Photos")
            XCTAssertEqual(preview([collection([collection([photo()], .plain("Nested"))])]).string, "Nested")
            XCTAssertEqual(preview([collection([])]).string, "")
        }
    }

    func testContainersAndThinking() {
        XCTAssertEqual(preview([.thinking(.plain("Thinking")), .details(title: .plain("Title"), blocks: [.kicker(.plain("Answer"))], expanded: false)]).string, "Title Answer")
        XCTAssertEqual(preview([.thinking(.plain("Thinking"))]).string, "Thinking")
        XCTAssertEqual(preview([.unsupported]).string, "Unsupported")
    }

    func testNestedSpoilerEmojiFormula() {
        let text = preview([.paragraph(.textSpoiler(text: .concat([.plain("secret "), .textCustomEmoji(fileId: 42, alt: "🙂"), .formula(latex: "x")])) )])
        for offset in 0 ..< text.length {
            XCTAssertEqual(text.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: offset, effectiveRange: nil) as? Bool, true)
        }
        guard text.length > 7 else { return XCTFail("Missing emoji content") }
        let emoji = text.attribute(instantPagePreviewCustomEmoji, at: 7, effectiveRange: nil) as? ChatTextInputTextCustomEmojiAttribute
        XCTAssertEqual(emoji?.fileId, 42)
    }

    func testDateSubstitutionAndNilFormat() {
        let date = RichText.textDate(text: .plain("literal"), date: 123, format: .full(timeFormat: .short, dateFormat: .long, dayOfWeek: false))
        XCTAssertEqual(preview([.paragraph(.concat([date, .plain("🙂")]))]).string, "FORMATTED🙂")
        XCTAssertEqual(preview([.paragraph(.textDate(text: .plain("literal"), date: 123, format: nil))]).string, "literal")
    }

    func testRestylingPreservesSemantics() {
        let text = preview([.paragraph(.textSpoiler(text: .italic(.underline(.plain("secret")))))])
        let styled = styleInstantPagePreview(text, font: .systemFont(ofSize: 15), italicFont: .italicSystemFont(ofSize: 15), textColor: .red)
        XCTAssertEqual(styled.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, .italicSystemFont(ofSize: 15))
        XCTAssertEqual(styled.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int, NSUnderlineStyle.single.rawValue)
        XCTAssertEqual(styled.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
    }

    func testPlainTextProjection() {
        let text = preview([.paragraph(.concat([.formula(latex: "x"), .formula(latex: "y")]))])
        XCTAssertEqual(instantPagePreviewPlainText(text), "[formula][formula]")
        let long = preview([.paragraph(.concat([.plain(String(repeating: "a", count: 199)), .formula(latex: "x")]))])
        XCTAssertEqual(instantPagePreviewPlainText(long), String(repeating: "a", count: 199) + "…")
    }

    func testMixedCollectionMediaAndWhitespaceCaption() {
        let video = InstantPageBlock.video(id: MediaId(namespace: 0, id: 2), caption: caption(), autoplay: false, loop: false, spoiler: false)
        XCTAssertEqual(preview([.collage(items: [photo(), video], caption: caption(.plain(" \t")))]).string, "Photo, Video")
        XCTAssertEqual(preview([.slideshow(items: [photo(), .unsupported], caption: caption())]).string, "Photo Unsupported")
    }

    func testWhitespaceAtTruncationBoundary() {
        let prefix = String(repeating: "a", count: 200)
        let expected = String(repeating: "a", count: 199) + "…"
        XCTAssertEqual(preview([.paragraph(.plain(prefix + " \t b"))]).string, expected)
        XCTAssertEqual(preview([.paragraph(.concat([.plain(prefix + " "), .plain("b")]))]).string, expected)
        XCTAssertEqual(preview([.paragraph(.plain(prefix + "   "))]).string, prefix)
    }

    func testIconMaterializationIsIdempotentAndPreservesSpoiler() {
        let input = preview([.paragraph(.textSpoiler(text: .concat([.formula(latex: "x"), .formula(latex: "y")])) )])
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        let output = renderInstantPagePreviewIcons(input, font: .systemFont(ofSize: 15), textColor: .black, image: { _ in image })
        XCTAssertEqual(output.string, "\u{fffc}\u{fffc}")
        for index in 0 ..< output.length {
            XCTAssertNotNil(output.attribute(.attachment, at: index, effectiveRange: nil))
            XCTAssertEqual(output.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: index, effectiveRange: nil) as? Bool, true)
        }
        let composed = NSMutableAttributedString(string: String(repeating: "author", count: 50) + ": ")
        composed.append(output)
        let again = renderInstantPagePreviewIcons(composed, font: .systemFont(ofSize: 15), textColor: .red, image: { _ in nil })
        XCTAssertTrue(again.isEqual(to: composed))
        let missing = renderInstantPagePreviewIcons(input, font: .systemFont(ofSize: 15), textColor: .black, image: { _ in nil })
        XCTAssertEqual(missing.string, "[formula][formula]")
        XCTAssertEqual(missing.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 0, effectiveRange: nil) as? Bool, true)
    }

    func testAllTextWrappersPreserveContent() {
        let t = RichText.plain("text")
        let wrappers: [RichText] = [.bold(t), .italic(t), .underline(t), .strikethrough(t), .fixed(t), .subscript(t), .superscript(t), .marked(t), .url(text: t, url: "https://example.com", webpageId: nil), .email(text: t, email: "x@y.z"), .phone(text: t, phone: "123"), .anchor(text: t, name: "a"), .textAutoEmail(text: t), .textAutoPhone(text: t), .textAutoUrl(text: t), .textBankCard(text: t), .textTonAddress(text: t), .textBotCommand(text: t), .textCashtag(text: t), .textHashtag(text: t), .textMention(text: t), .textMentionName(text: t, peerId: 1), .textSpoiler(text: t), .textButton(InstantPageButton(text: t, action: .text, color: nil))]
        for wrapper in wrappers { XCTAssertEqual(preview([.paragraph(wrapper)]).string, "text") }
    }

    func testRemainingBlocks() {
        let t = RichText.plain("text")
        let id = MediaId(namespace: 0, id: 1)
        let cases: [(InstantPageBlock, String)] = [
            (.title(t), "text"), (.subtitle(t), "text"), (.header(t), "text"), (.subheader(t), "text"), (.heading(text: t, level: 2), "text"), (.footer(t), "text"), (.authorDate(author: t, date: 1), "text"), (.preformatted(text: t, language: "swift"), "text"),
            (.blockQuote(blocks: [.paragraph(t)], caption: .plain("caption"), collapsed: true), "text caption"),
            (.list(items: [.text(t, "1", nil), .text(t, nil, true), .blocks([.paragraph(t)], "", nil)], ordered: true), "1. text ☑︎ text text"),
            (.audio(id: id, caption: caption(t)), "Music text"), (.document(id: id, caption: caption(t)), "File text"),
            (.webEmbed(url: nil, html: "SECRET HTML", dimensions: nil, caption: caption(), stretchToWidth: false, allowScrolling: false, coverId: nil), "Embedded content"),
            (.postEmbed(url: "url", webpageId: nil, avatarId: nil, author: "Author", date: 0, blocks: [], caption: caption()), "Author"),
            (.channelBanner(nil), "Channel"), (.relatedArticles(title: t, articles: []), "text"),
            (.map(latitude: 0, longitude: 0, zoom: 1, dimensions: PixelDimensions(width: 10, height: 10), caption: caption(t)), "Location text"),
            (.buttonRow(alignment: .left, buttons: [InstantPageButton(text: t, action: .text, color: nil)]), "text"),
            (.table(title: t, rows: [], bordered: false, striped: false, compact: false), "\u{fffc} text")
        ]
        for (block, expected) in cases { XCTAssertEqual(preview([block]).string, expected) }
    }

    func testEmptyEmbedURLUsesLocalizedFallback() {
        let embed = InstantPageBlock.webEmbed(url: " \n", html: "<p>hidden</p>", dimensions: nil, caption: caption(), stretchToWidth: false, allowScrolling: false, coverId: nil)
        XCTAssertEqual(preview([embed]).string, "Embedded content")
    }

    func testDateRangeAfterSubstitutionAndEmojiAtomicClipping() {
        let date = RichText.textDate(text: .plain("x"), date: 123, format: .full(timeFormat: .short, dateFormat: .long, dayOfWeek: false))
        let result = preview([.paragraph(.concat([.plain("🙂"), date, .textSpoiler(text: .plain("after"))]))])
        XCTAssertEqual(result.string, "🙂FORMATTEDafter")
        XCTAssertEqual(result.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Date), at: 2, effectiveRange: nil) as? Int32, 123)
        XCTAssertEqual(result.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 11, effectiveRange: nil) as? Bool, true)
        let clipped = preview([.paragraph(.concat([.plain(String(repeating: "a", count: 198)), .textCustomEmoji(fileId: 42, alt: "long-alt")]))])
        XCTAssertEqual(clipped.string, String(repeating: "a", count: 198) + "…")
        let empty = preview([.paragraph(.textCustomEmoji(fileId: 42, alt: ""))])
        XCTAssertEqual(instantPagePreviewPlainText(empty), "�")
    }

    func testMediaCaptionSpoilersAndIncompleteCollectionCount() {
        let id = MediaId(namespace: 0, id: 1)
        let plain = preview([.image(id: id, caption: caption(.plain("caption")), url: nil, webpageId: nil, spoiler: true)])
        XCTAssertEqual(plain.string, "Photo caption")
        XCTAssertNil(plain.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 6, effectiveRange: nil))
        let hidden = preview([photo(.textSpoiler(text: .plain("caption")))])
        XCTAssertEqual(hidden.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler), at: 6, effectiveRange: nil) as? Bool, true)
        let collection = InstantPageBlock.collage(items: Array(repeating: photo(), count: 4097), caption: caption())
        XCTAssertEqual(preview([collection]).string, "Photo…")
    }

    func testAdjacentIconsKeepIndividualFonts() {
        let input = NSMutableAttributedString(attributedString: preview([.paragraph(.concat([.formula(latex: "x"), .formula(latex: "y")]))]))
        input.addAttribute(.font, value: UIFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: 1))
        input.addAttribute(.font, value: UIFont.systemFont(ofSize: 20), range: NSRange(location: 1, length: 1))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        let result = renderInstantPagePreviewIcons(input, font: .systemFont(ofSize: 15), textColor: .black, image: { _ in image })
        XCTAssertEqual((result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 12)
        XCTAssertEqual((result.attribute(.font, at: 1, effectiveRange: nil) as? UIFont)?.pointSize, 20)
    }

    func testUnresolvedEmojiRemainsReadableInEntityRenderer() {
        let text = preview([.paragraph(.textCustomEmoji(fileId: 42, alt: "🙂"))])
        let styled = styleInstantPagePreview(text, font: .systemFont(ofSize: 15), italicFont: .italicSystemFont(ofSize: 15), textColor: .black)
        XCTAssertEqual(styled.string, "🙂")
        // The entity renderer replaces customEmoji runs by an attachment even if
        // resolution fails; absent media must therefore remain ordinary text.
        XCTAssertNil(styled.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil))
    }

    func testNestedThinkingIsOnlyAFallback() {
        XCTAssertEqual(preview([.cover(.thinking(.plain("Thinking"))), .paragraph(.plain("Answer"))]).string, "Answer")
        XCTAssertEqual(preview([.cover(.thinking(.plain("Thinking")))]).string, "Thinking")
    }

    func testResolvedEmojiRetainsRenderableFile() {
        let id = MediaId(namespace: Namespaces.Media.CloudFile, id: 42)
        let file = TelegramMediaFile(fileId: id, partialReference: nil, resource: LocalFileMediaResource(fileId: 42), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: nil, attributes: [], alternativeRepresentations: [])
        let text = preview([.paragraph(.textCustomEmoji(fileId: 42, alt: "🙂"))], media: [id: file])
        let emoji = text.attribute(ChatTextInputAttributes.customEmoji, at: 0, effectiveRange: nil) as? ChatTextInputTextCustomEmojiAttribute
        XCTAssertTrue(emoji?.file === file)
        XCTAssertEqual(emoji?.fileId, 42)
    }

    func testMissingIconFallbackRespectsBodyBudget() {
        let input = preview([.paragraph(.concat([.plain(String(repeating: "a", count: 199)), .formula(latex: "x")]))])
        let result = renderInstantPagePreviewIcons(input, font: .systemFont(ofSize: 15), textColor: .black, image: { _ in nil })
        XCTAssertEqual(result.string, String(repeating: "a", count: 199) + "…")
    }
}
