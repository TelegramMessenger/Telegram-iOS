import Foundation
import ObjectiveC
import XCTest

/// One finger of `performFingers`: down at `at` after `down` seconds, through `moves` (each a point and the second it is
/// reached), up after `up` seconds. Points are the readout's window coordinates, which are the screen's.
struct Finger {
    var at: CGPoint
    var down: TimeInterval
    var moves: [(CGPoint, TimeInterval)] = []
    var up: TimeInterval
}

enum MultiTouchError: Error {
    case missing(String)
    case failed(String)
}

/// Several fingers with independent timing (hold one, tap another), which XCUITest's public API cannot drive: it has
/// one-finger gestures and symmetric pinches only. This is XCUIAutomation's private event synthesis
/// (`XCSynthesizedEventRecord` of `XCPointerEventPath`s, sent through `XCUIDevice`'s `eventSynthesizer`), reached through
/// the runtime: a missing class or selector throws rather than crashing.
/// In a record of several fingers, one that goes down after offset 0 is pressed a second time at its point after its
/// lift, before the others lift: the app gets a new touch, began and ended (measured: a single late finger, or several
/// all starting at 0, get none). Start fingers together where their order does not matter; otherwise read a log up to
/// the late finger's first lift.
func performFingers(_ fingers: [Finger], in app: XCUIApplication) throws {
    try startFingers(fingers, in: app).wait()
}

/// Fingers sent and still playing (`startFingers`): a test reads the readout meanwhile, then waits for them.
final class FingersInFlight {
    fileprivate let done = XCTestExpectation(description: "fingers")
    fileprivate var failure: String?
    fileprivate let duration: TimeInterval

    fileprivate init(duration: TimeInterval) {
        self.duration = duration
    }

    /// Returns once the synthesizer has played every finger.
    func wait() throws {
        guard XCTWaiter.wait(for: [self.done], timeout: self.duration + 20.0) == .completed else {
            throw MultiTouchError.failed("timed out")
        }
        if let failure = self.failure {
            throw MultiTouchError.failed(failure)
        }
    }
}

/// `performFingers` without the wait: the fingers play while the test goes on.
func startFingers(_ fingers: [Finger], in app: XCUIApplication) throws -> FingersInFlight {
    // XCTest raises an Objective-C exception, which ends the runner, for a path whose offsets decrease (an event may
    // share its predecessor's offset; 0.3 + 0.6 is past 0.9).
    for finger in fingers {
        let offsets = [finger.down] + finger.moves.map(\.1) + [finger.up]
        guard zip(offsets, offsets.dropFirst()).allSatisfy({ $0 <= $1 }) else {
            throw MultiTouchError.failed("a finger's offsets must not decrease: \(offsets)")
        }
    }
    let record = try allocInit("XCSynthesizedEventRecord", "initWithName:interfaceOrientation:") { (object, selector, imp) in
        typealias Init = @convention(c) (AnyObject, Selector, NSString, Int) -> Unmanaged<AnyObject>
        return unsafeBitCast(imp, to: Init.self)(object, selector, "fingers" as NSString, UIInterfaceOrientation.portrait.rawValue)
    }
    for finger in fingers {
        let path = try allocInit("XCPointerEventPath", "initForTouchAtPoint:offset:") { (object, selector, imp) in
            typealias Init = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Unmanaged<AnyObject>
            return unsafeBitCast(imp, to: Init.self)(object, selector, finger.at, finger.down)
        }
        typealias Move = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Void
        let move = try method(path, "moveToPoint:atOffset:", as: Move.self)
        for (point, offset) in finger.moves {
            move.function(path, move.selector, point, offset)
        }
        typealias Lift = @convention(c) (AnyObject, Selector, Double) -> Void
        let lift = try method(path, "liftUpAtOffset:", as: Lift.self)
        lift.function(path, lift.selector, finger.up)
        typealias Add = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        let add = try method(record, "addPointerEventPath:", as: Add.self)
        add.function(record, add.selector, path)
    }
    let eventSynthesizer = NSSelectorFromString("eventSynthesizer")
    guard XCUIDevice.shared.responds(to: eventSynthesizer), let synthesizer = XCUIDevice.shared.perform(eventSynthesizer)?.takeUnretainedValue() else {
        throw MultiTouchError.missing("XCUIDevice.eventSynthesizer")
    }
    typealias Synthesize = @convention(c) (AnyObject, Selector, AnyObject, @escaping @convention(block) (Bool, NSError?) -> Void) -> Void
    let synthesize = try method(synthesizer, "synthesizeEvent:completion:", as: Synthesize.self)
    let inFlight = FingersInFlight(duration: fingers.map(\.up).max() ?? 0.0)
    synthesize.function(synthesizer, synthesize.selector, record, { result, error in
        if !result {
            inFlight.failure = error?.localizedDescription ?? "not synthesized"
        }
        inFlight.done.fulfill()
    })
    return inFlight
}

/// `[[class alloc] <initializer>]`: alloc's reference is the one the initializer consumes, and the result comes back +1.
private func allocInit(_ className: String, _ initializer: String, _ call: (AnyObject, Selector, IMP) -> Unmanaged<AnyObject>) throws -> AnyObject {
    guard let type = NSClassFromString(className) else {
        throw MultiTouchError.missing(className)
    }
    guard let allocated = (type as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() as? NSObject else {
        throw MultiTouchError.missing("\(className) alloc")
    }
    let selector = NSSelectorFromString(initializer)
    guard allocated.responds(to: selector) else {
        throw MultiTouchError.missing("\(className) \(initializer)")
    }
    return call(allocated, selector, allocated.method(for: selector)).takeRetainedValue()
}

private func method<Function>(_ object: AnyObject, _ name: String, as type: Function.Type) throws -> (function: Function, selector: Selector) {
    let selector = NSSelectorFromString(name)
    guard let object = object as? NSObject, object.responds(to: selector) else {
        throw MultiTouchError.missing(name)
    }
    return (unsafeBitCast(object.method(for: selector), to: type), selector)
}
