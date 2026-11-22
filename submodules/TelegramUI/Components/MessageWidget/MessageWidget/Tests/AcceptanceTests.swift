import XCTest
@testable import MessageWidget

class AcceptanceTests: MessageWidgetTestCase {
    /// WebKit's heights for the committed fixtures (macOS 27 WKWebView, system font, 2026-10-13).
    /// twidget lays its ported corpus out within 4 pt of WebKit; so must we.
    static let webKit: [(String, CGFloat, CGFloat)] = [
        ("01-weather-card", 319, 336),
        ("02-split-bill", 327, 327),
        ("03-faq-accordion", 314, 328),
        ("04-poll", 302, 323),
        ("05-countdown", 169, 169),
    ]

    func testFixturesLayOutWithinFourPointsOfWebKit() throws {
        for (name, at360, at240) in Self.webKit {
            for (width, expected) in [(CGFloat(360.0), at360), (CGFloat(240.0), at240)] {
                let instance = self.make(self.fixture(name))
                let size = instance.layout(width: width)
                XCTAssertEqual(size.height, expected, accuracy: 4.0, "\(name) at \(width)")
                instance.destroy()
            }
        }
    }

    func testCountdownTicksAtAStableHeight() throws {
        let instance = self.make(self.fixture("05-countdown"))
        let height = instance.layout(width: 360.0).height
        let first = self.renderedHTML(instance)
        self.pump(1.2)
        XCTAssertNotEqual(self.renderedHTML(instance), first)   // it ticked
        XCTAssertEqual(instance.layout(width: 360.0).height, height)
        instance.destroy()
    }
}
