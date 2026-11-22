import UIKit
import XCTest
@testable import MessageWidget

/// Four arcade games the user found broken (2026-10-22; Fixtures 11–14): each boots, starts on a tap, answers a held
/// button by changing its picture, with no uncaught error and no stop. All four stopped at their first line until
/// `devicePixelRatio` existed.
final class GamesTests: MessageWidgetTestCase {
    /// Each game and a button that changes its picture while held: Tetris drops its piece, the invaders' cannon and
    /// Pac-Man move left, Mario runs right (nothing on his first screen moves by itself).
    static let games: [(name: String, control: String)] = [
        ("11-tetris", "[data-k=h]"),
        ("12-invaders", "[data-k=l]"),
        ("13-mario-super-lite", "[data-k=r]"),
        ("14-pacman", "[data-k='1']"),
    ]

    /// The canvas's pixels, as the widget's renderer draws them.
    private func canvasPixels(_ instance: MessageWidgetInstance) -> Data? {
        guard let box = self.borderBox(instance, "canvas"), let image = self.rendererImage(instance, rect: box, scale: 1.0) else {
            return nil
        }
        return image.dataProvider?.data as Data?
    }

    private func frames(_ instance: MessageWidgetInstance, _ count: Int) {
        for _ in 0 ..< count {
            self.pump(0.017)
            self.deliverFrame(instance)
        }
    }

    /// The whole widget as a PNG in the test's undeclared outputs, to look at.
    private func keepImage(_ instance: MessageWidgetInstance, size: CGSize, _ name: String) {
        guard let directory = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"],
              let image = self.rendererImage(instance, rect: CGRect(origin: .zero, size: size), scale: 2.0),
              let data = UIImage(cgImage: image).pngData() else {
            return
        }
        try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name).png"))
    }

    private func tap(_ instance: MessageWidgetInstance, _ point: CGPoint) {
        instance.touch(action: 0, at: point, pointer: 0, primary: true)
        instance.touch(action: 2, at: point, pointer: 0, primary: true)
    }

    func testEveryGameStartsAndAnswersItsButtons() {
        self.play(scale: 1.0)
    }

    /// On a phone devicePixelRatio is 3, so every canvas holds nine times the pixels and its drawing costs as much more:
    /// each game must still keep every task well inside its slice (a quarter of it at most).
    func testEveryGamePlaysAtThreeTimes() {
        self.play(scale: 3.0)
    }

    private func play(scale: CGFloat) {
        for game in GamesTests.games {
            let (instance, view) = self.booted(self.fixture(game.name), scale: scale)
            defer {
                instance.destroy()
            }
            self.frames(instance, 10)
            // The ratio is the scale the widget's tiles are drawn at, and the canvas's backing store follows it.
            XCTAssertEqual(instance.evaluateForTesting("devicePixelRatio + ',' + document.querySelector('canvas').width"),
                           "\(Int(scale)),\(360 * Int(scale))", game.name)
            XCTAssertFalse(instance.failedToStart, game.name)
            XCTAssertNil(instance.lastError, game.name)
            XCTAssertNil(instance.deadReason, game.name)
            self.keepImage(instance, size: view.bounds.size, "\(game.name)-\(Int(scale))x-title")
            guard let canvas = self.borderBox(instance, "canvas"), let control = self.borderBox(instance, game.control) else {
                XCTFail("\(game.name): no canvas or no \(game.control)")
                continue
            }
            // Every game starts on a tap on its canvas (Mario on any tap); Pac-Man shows READY! for two seconds first.
            self.tap(instance, CGPoint(x: canvas.midX, y: canvas.midY))
            self.frames(instance, 150)
            let before = self.canvasPixels(instance)
            let press = CGPoint(x: control.midX, y: control.midY)
            instance.touch(action: 0, at: press, pointer: 0, primary: true)
            self.frames(instance, 30)
            instance.touch(action: 2, at: press, pointer: 0, primary: true)
            self.frames(instance, 10)
            let after = self.canvasPixels(instance)
            self.keepImage(instance, size: view.bounds.size, "\(game.name)-\(Int(scale))x-playing")
            let bootCpu = instance.largestTaskCpuMillisecondsForTesting(.boot), frameCpu = instance.largestTaskCpuMillisecondsForTesting(.frame)
            print(String(format: "%@ at %dx: boot %.1f ms of CPU, largest frame %.1f ms, error %@, stopped %@, canvas changed %@", game.name, Int(scale), bootCpu, frameCpu, instance.lastError ?? "none", instance.deadReason ?? "no", before != after ? "true" : "false"))
            XCTAssertNotNil(before, game.name)
            XCTAssertNotEqual(before, after, "\(game.name): holding \(game.control) did not change the canvas")
            XCTAssertNil(instance.lastError, game.name)
            XCTAssertNil(instance.deadReason, game.name)
            // Well inside their slices (500 ms): a quarter at most.
            XCTAssertLessThan(bootCpu, 125.0, game.name)
            XCTAssertLessThan(frameCpu, 125.0, game.name)
        }
    }
}
