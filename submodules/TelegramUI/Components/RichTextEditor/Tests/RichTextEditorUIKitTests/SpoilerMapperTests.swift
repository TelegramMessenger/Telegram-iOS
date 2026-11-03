#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpoilerMapperTests: XCTestCase {
    private let mapper = AttributedStringMapper()

    func test_attributesForSpoiler_setsMarkerOnly() {
        let attrs = mapper.attributes(for: CharacterAttributes(spoiler: true), style: .body)
        XCTAssertEqual(attrs[.rtSpoiler] as? Bool, true)
        XCTAssertNil(attrs[.backgroundColor])
    }

    func test_characterAttributesFromSpoilerDict_recoversFlag() {
        let attrs = mapper.attributes(for: CharacterAttributes(spoiler: true), style: .body)
        XCTAssertTrue(mapper.characterAttributes(from: attrs).spoiler)
    }

    func test_spoiler_isAdditive_coexistsWithBoldAndLink() {
        let ca = CharacterAttributes(bold: true, link: "https://x.y", spoiler: true)
        let back = mapper.characterAttributes(from: mapper.attributes(for: ca, style: .body))
        XCTAssertTrue(back.spoiler)
        XCTAssertTrue(back.bold)
        XCTAssertEqual(back.link, "https://x.y")
    }

    func test_nonSpoilerRun_readsBackFalse() {
        let back = mapper.characterAttributes(from: mapper.attributes(for: CharacterAttributes(), style: .body))
        XCTAssertFalse(back.spoiler)
    }

    func test_runsRoundTrip_preservesSpoiler() {
        let block = ParagraphBlock(id: BlockID("p1"), style: .body, runs: [
            TextRun(text: "ok "),
            TextRun(text: "secret", attributes: CharacterAttributes(spoiler: true)),
        ])
        let runs = mapper.runs(from: mapper.attributedString(for: block))
        XCTAssertEqual(runs.count, 2)
        XCTAssertFalse(runs[0].attributes.spoiler)
        XCTAssertTrue(runs[1].attributes.spoiler)
    }
}
#endif
