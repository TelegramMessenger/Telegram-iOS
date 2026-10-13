import XCTest
import Postbox
import FlatBuffers
// The flatc-generated TelegramCore_* types live in this module, not in TelegramCore.
import FlatSerialization
import TelegramApi
import TelegramCore

/// `richButtonStyle#3c610bd flags:# bg_primary:flags.0?true bg_danger:flags.1?true
/// bg_success:flags.2?true link:flags.3?true`. `link` is stored as its own field rather than as a
/// fourth `ReplyMarkupButton.Style.Color` case, so `link` + a background bit round-trips losslessly
/// even though rendering makes `link` win.
final class InstantPageButtonLinkStyleTests: XCTestCase {
    private func postboxRoundTrip(_ button: InstantPageButton) -> InstantPageButton {
        let encoder = PostboxEncoder()
        button.encode(encoder)
        return InstantPageButton(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
    }

    private func flatBuffersRoundTrip(_ button: InstantPageButton) throws -> InstantPageButton {
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = button.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        var byteBuffer = ByteBuffer(data: builder.data)
        let object: TelegramCore_InstantPageButton = FlatBuffers_getRoot(byteBuffer: &byteBuffer)
        return try InstantPageButton(flatBuffersObject: object)
    }

    private func makeButton(color: ReplyMarkupButton.Style.Color?, isLink: Bool) -> InstantPageButton {
        return InstantPageButton(text: .plain("Go"), action: .url("https://t.me"), color: color, isLink: isLink)
    }

    // MARK: - Storage

    func testIsLinkSurvivesBothCodecs() throws {
        let button = makeButton(color: nil, isLink: true)
        XCTAssertTrue(self.postboxRoundTrip(button).isLink)
        XCTAssertTrue(try self.flatBuffersRoundTrip(button).isLink)
    }

    func testNotLinkSurvivesBothCodecs() throws {
        let button = makeButton(color: nil, isLink: false)
        XCTAssertFalse(self.postboxRoundTrip(button).isLink)
        XCTAssertFalse(try self.flatBuffersRoundTrip(button).isLink)
    }

    /// The point of storing the two facts separately: rendering makes `link` win, but the danger bit
    /// must still come back out.
    func testLinkAndBackgroundColourBothRoundTrip() throws {
        let button = makeButton(color: .danger, isLink: true)

        let viaPostbox = self.postboxRoundTrip(button)
        XCTAssertTrue(viaPostbox.isLink)
        XCTAssertEqual(viaPostbox.color, .danger)

        let viaFlatBuffers = try self.flatBuffersRoundTrip(button)
        XCTAssertTrue(viaFlatBuffers.isLink)
        XCTAssertEqual(viaFlatBuffers.color, .danger)
    }

    /// Synthesised `==` must pick the new field up, or a page whose only change is the link bit
    /// would compare equal and never re-render.
    func testEqualityDistinguishesLinkStyle() {
        XCTAssertNotEqual(makeButton(color: nil, isLink: true), makeButton(color: nil, isLink: false))
    }

    // MARK: - Backward compatibility

    /// A cached page written before this field existed. Replicates exactly what the old encoder
    /// wrote — text object, action, colour — and deliberately omits the "l" key.
    func testLegacyPostboxRecordDecodesAsNotLink() {
        let encoder = PostboxEncoder()
        encoder.encodeObject(RichText.plain("Go"), forKey: "t")
        ReplyMarkupButtonAction.url("https://t.me").encode(encoder)
        encoder.encodeInt32(ReplyMarkupButton.Style.Color.danger.rawValue, forKey: "c")

        let decoded = InstantPageButton(decoder: PostboxDecoder(buffer: MemoryBuffer(data: encoder.makeData())))
        XCTAssertFalse(decoded.isLink)
        XCTAssertEqual(decoded.color, .danger)
    }

    /// Same for FlatBuffers: a buffer built without the new field must read the schema default.
    func testLegacyFlatBuffersRecordDecodesAsNotLink() throws {
        var builder = FlatBufferBuilder(initialSize: 1024)
        let textOffset = RichText.plain("Go").encodeToFlatBuffers(builder: &builder)
        let actionOffset = ReplyMarkupButtonAction.url("https://t.me").encodeToFlatBuffers(builder: &builder)
        let start = TelegramCore_InstantPageButton.startInstantPageButton(&builder)
        TelegramCore_InstantPageButton.add(text: textOffset, &builder)
        TelegramCore_InstantPageButton.add(action: actionOffset, &builder)
        TelegramCore_InstantPageButton.add(color: -1, &builder)
        // No add(isLink:) — this is an old buffer.
        let offset = TelegramCore_InstantPageButton.endInstantPageButton(&builder, start: start)
        builder.finish(offset: offset)

        var byteBuffer = ByteBuffer(data: builder.data)
        let object: TelegramCore_InstantPageButton = FlatBuffers_getRoot(byteBuffer: &byteBuffer)
        XCTAssertFalse(try InstantPageButton(flatBuffersObject: object).isLink)
    }

    // MARK: - Api bit mapping, incoming

    func testIsLinkStyleReadsBitThree() {
        func style(_ flags: Int32) -> Api.RichButtonStyle {
            return .richButtonStyle(Api.RichButtonStyle.Cons_richButtonStyle(flags: flags))
        }
        XCTAssertTrue(InstantPageButton.isLinkStyle(style(1 << 3)))
        XCTAssertTrue(InstantPageButton.isLinkStyle(style((1 << 1) | (1 << 3))))
        XCTAssertFalse(InstantPageButton.isLinkStyle(style(0)))
        XCTAssertFalse(InstantPageButton.isLinkStyle(style(1 << 1)))
        XCTAssertFalse(InstantPageButton.isLinkStyle(nil))
    }

    // MARK: - Api bit mapping, outgoing

    /// The trap: the old `apiFlagsAndStyle()` early-returned `(0, nil)` whenever `color` was nil, so
    /// a link-only button would have serialised with NO style object at all and lost the bit.
    func testLinkOnlyButtonStillEmitsAStyleWord() {
        XCTAssertEqual(makeButton(color: nil, isLink: true).apiRichStyleFlagWord, 1 << 3)
    }

    func testFlagWordCombinesColourAndLink() {
        XCTAssertEqual(makeButton(color: .danger, isLink: true).apiRichStyleFlagWord, (1 << 1) | (1 << 3))
        XCTAssertEqual(makeButton(color: .danger, isLink: false).apiRichStyleFlagWord, 1 << 1)
        XCTAssertEqual(makeButton(color: nil, isLink: false).apiRichStyleFlagWord, 0)
    }
}
