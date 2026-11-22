#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class AttributedStringMapperLinkTests: XCTestCase {
    let mapper = AttributedStringMapper()

    func test_attributes_link_addsVisibleStyling() {
        let dict = mapper.attributes(for: CharacterAttributes(link: "https://x.com"), style: .body)
        XCTAssertEqual(dict[.link] as? String, "https://x.com")
        // 6a: links render blue only — no underline (updated from single.rawValue assertion)
        XCTAssertNil(dict[.underlineStyle], "links must not be underlined in 6a")
        XCTAssertNotNil(dict[.foregroundColor], "links render with an explicit foreground color")
    }

    func test_readback_link_suppressesForegroundAndUnderline() {
        let dict: [NSAttributedString.Key: Any] = [
            .link: "https://x.com",
            .foregroundColor: UIColor.link,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 16),
        ]
        let ca = mapper.characterAttributes(from: dict)
        XCTAssertEqual(ca.link, "https://x.com")
        XCTAssertFalse(ca.underline, "underline from link styling must not leak into the model")
        XCTAssertNil(ca.foreground, "blue from link styling must not leak into the model")
    }

    func test_readback_noLink_stillReadsForegroundAndUnderline() {
        let dict: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.red,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.systemFont(ofSize: 16),
        ]
        let ca = mapper.characterAttributes(from: dict)
        XCTAssertNil(ca.link)
        XCTAssertTrue(ca.underline, "underline is still read when there is no link")
        XCTAssertNotNil(ca.foreground, "foreground is still read when there is no link")
    }

    func test_roundTrip_linkOnly() {
        let dict = mapper.attributes(for: CharacterAttributes(link: "https://x.com"), style: .body)
        let ca = mapper.characterAttributes(from: dict)
        XCTAssertEqual(ca.link, "https://x.com")
        XCTAssertFalse(ca.underline)
        XCTAssertNil(ca.foreground)
    }

    func test_runs_fromAttributedString_linkRoundTripsAndSuppressesStyling() {
        let block = ParagraphBlock(id: BlockID("p"), runs: [
            TextRun(text: "see "),
            TextRun(text: "here", attributes: CharacterAttributes(link: "https://x.com")),
        ])
        let runs = mapper.runs(from: mapper.attributedString(for: block))
        let linked = runs.first { $0.attributes.link != nil }
        XCTAssertEqual(linked?.text, "here")
        XCTAssertEqual(linked?.attributes.link, "https://x.com")
        XCTAssertEqual(linked?.attributes.underline, false)
        XCTAssertNil(linked?.attributes.foreground)
    }

    func test_runs_fromAttributedString_urlValuedLink_normalizesAndSuppresses() {
        let s = NSAttributedString(string: "tap", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .link: URL(string: "https://x.com")!,
            .foregroundColor: UIColor.link,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
        let back = mapper.runs(from: s).first
        XCTAssertEqual(back?.attributes.link, "https://x.com")
        XCTAssertEqual(back?.attributes.underline, false)
        XCTAssertNil(back?.attributes.foreground)
    }

    func test_link_isBlue_withoutUnderline() {
        let m = AttributedStringMapper()
        let attrs = m.attributes(for: CharacterAttributes(link: "https://x.com"), style: .body)
        XCTAssertEqual(attrs[.foregroundColor] as? UIColor, UIColor.link)
        XCTAssertNil(attrs[.underlineStyle], "links must not be underlined in 6a")
    }
}
#endif
