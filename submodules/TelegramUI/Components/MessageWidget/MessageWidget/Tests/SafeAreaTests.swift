import XCTest
@testable import MessageWidget

/// widget-sandbox v0.4.0 through the facade (sdk-v1 §2.17, §5.12): the content safe area goes in before the boot, so
/// the first height has the band, and a change goes in as a layout change main waits for, with its event; an equal
/// value is nothing.
final class SafeAreaTests: MessageWidgetTestCase {
    private let band = MessageWidgetContentSafeArea(bottom: 24.0, cornerRight: 64.0)

    /// An unstyled widget (the UA layer pads its body by the band), taller than the bubble's 50 pt floor, that counts its
    /// events.
    private let page = "<!doctype html><div style=\"height:100px\">text</div><script>window.events = 0;"
        + "TelegramWidget.onEvent('contentSafeAreaChanged', () => window.events++);"
        + "window.atBoot = TelegramWidget.contentSafeAreaInset.bottom;</script>"

    func testTheBandIsInTheFirstHeight() {
        let plain = self.make(self.page)
        let banded = self.make(self.page)
        banded.contentSafeArea = self.band
        let without = plain.layout(width: 300.0)
        let with = banded.layout(width: 300.0)
        XCTAssertEqual(with.height - without.height, 24.0)
        XCTAssertEqual(banded.evaluateForTesting("[window.atBoot, window.events].join()"), "24,0")
        plain.destroy()
        banded.destroy()
    }

    func testAChangeRelayoutsAndFiresOnce() {
        let instance = self.make(self.page)
        let before = instance.layout(width: 300.0)
        instance.contentSafeArea = self.band
        let after = instance.layout(width: 300.0)
        XCTAssertEqual(after.height - before.height, 24.0)
        XCTAssertEqual(instance.evaluateForTesting("[TelegramWidget.contentSafeAreaInset.bottom, TelegramWidget.contentSafeAreaInset.cornerRight, window.events].join()"), "24,64,1")
        // Back to none: the band goes, one more event.
        instance.contentSafeArea = .none
        XCTAssertEqual(instance.layout(width: 300.0).height, before.height)
        XCTAssertEqual(instance.evaluateForTesting("window.events"), "2")
        instance.destroy()
    }

    /// A frozen widget takes no change: main queues no layout task for it (the core would drop it).
    func testAFrozenWidgetQueuesNoChange() {
        let instance = self.make(self.page + "<script>for (;;) {}</script>")
        _ = instance.layout(width: 300.0)
        XCTAssertNotNil(instance.deadReason)
        let layouts = instance.queuedForTesting[.layout]?.waited ?? 0
        instance.contentSafeArea = self.band
        _ = instance.layout(width: 300.0)
        XCTAssertEqual(instance.queuedForTesting[.layout]?.waited ?? 0, layouts)
        instance.destroy()
    }

    func testAnEqualValueQueuesNothing() {
        let instance = self.make(self.page)
        instance.contentSafeArea = self.band
        _ = instance.layout(width: 300.0)
        let layouts = instance.queuedForTesting[.layout]?.waited ?? 0
        instance.contentSafeArea = MessageWidgetContentSafeArea(bottom: 24.0, cornerRight: 64.0)
        _ = instance.layout(width: 300.0)
        XCTAssertEqual(instance.queuedForTesting[.layout]?.waited ?? 0, layouts)
        XCTAssertEqual(instance.evaluateForTesting("window.events"), "0")
        instance.destroy()
    }
}
