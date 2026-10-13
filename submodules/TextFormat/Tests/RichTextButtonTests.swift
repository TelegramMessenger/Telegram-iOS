import XCTest
import Postbox
import FlatBuffers
import FlatSerialization
import TelegramCore

/// `RichText.textButton` (Postbox discriminator 29). Inline rather than block-level, so the cases
/// that matter most are the ones where a button sits inside other rich text.
final class RichTextButtonTests: XCTestCase {
    private let sample = RichText.textButton(InstantPageButton(
        text: .plain("Open"),
        action: .url("https://t.me"),
        color: .primary
    ))

    private func postboxRoundTrip(_ text: RichText) -> RichText {
        let encoder = PostboxEncoder()
        encoder.encodeObject(text, forKey: "t")
        let decoder = PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData()))
        return decoder.decodeObjectForKey("t", decoder: { RichText(decoder: $0) }) as! RichText
    }

    private func flatBuffersRoundTrip(_ text: RichText) throws -> RichText {
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = text.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        var byteBuffer = ByteBuffer(data: builder.data)
        let object: TelegramCore_RichText = FlatBuffers_getRoot(byteBuffer: &byteBuffer)
        return try RichText(flatBuffersObject: object)
    }

    func test_postboxRoundTrip() {
        XCTAssertEqual(self.postboxRoundTrip(self.sample), self.sample)
    }

    func test_flatBuffersRoundTrip() throws {
        XCTAssertEqual(try self.flatBuffersRoundTrip(self.sample), self.sample)
    }

    /// plainText must surface the label so chat-list previews and accessibility are not blank.
    func test_plainTextIsTheLabel() {
        XCTAssertEqual(self.sample.plainText, "Open")
    }

    /// The defining inline case: a button mid-sentence must survive and contribute its label to the
    /// surrounding text's plainText in the right position.
    func test_nestedInConcatSurvivesAndContributesPlainText() throws {
        let nested = RichText.concat([.plain("before "), self.sample, .plain(" after")])
        XCTAssertEqual(self.postboxRoundTrip(nested), nested)
        XCTAssertEqual(try self.flatBuffersRoundTrip(nested), nested)
        XCTAssertEqual(nested.plainText, "before Open after")
    }

    /// A button label can carry formatting, and a button can sit inside formatting. Both nestings
    /// must round-trip, since RichText is mutually recursive with InstantPageButton now.
    func test_mutualNesting() throws {
        let boldButton = RichText.bold(self.sample)
        XCTAssertEqual(self.postboxRoundTrip(boldButton), boldButton)
        XCTAssertEqual(try self.flatBuffersRoundTrip(boldButton), boldButton)

        let formattedLabel = RichText.textButton(InstantPageButton(
            text: .concat([.bold(.plain("B")), .italic(.plain("i"))]),
            action: .copyText(payload: "x"),
            color: nil
        ))
        XCTAssertEqual(self.postboxRoundTrip(formattedLabel), formattedLabel)
        XCTAssertEqual(try self.flatBuffersRoundTrip(formattedLabel), formattedLabel)
    }

    /// Discriminator 29 must not disturb the 28 that came before it.
    func test_neighbouringDiscriminatorsUnaffected() {
        let date = RichText.textDate(text: .plain("today"), date: 12345, format: nil)
        XCTAssertEqual(self.postboxRoundTrip(date), date)
        let spoiler = RichText.textSpoiler(text: .plain("shh"))
        XCTAssertEqual(self.postboxRoundTrip(spoiler), spoiler)
    }

    /// Two buttons differing only in action or colour must not compare equal — otherwise a changed
    /// button would not trigger a re-layout.
    func test_equalityIsSensitiveToActionAndColor() {
        let a = RichText.textButton(InstantPageButton(text: .plain("x"), action: .url("https://a"), color: nil))
        let b = RichText.textButton(InstantPageButton(text: .plain("x"), action: .url("https://b"), color: nil))
        let c = RichText.textButton(InstantPageButton(text: .plain("x"), action: .url("https://a"), color: .danger))
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertEqual(a, RichText.textButton(InstantPageButton(text: .plain("x"), action: .url("https://a"), color: nil)))
    }
}
