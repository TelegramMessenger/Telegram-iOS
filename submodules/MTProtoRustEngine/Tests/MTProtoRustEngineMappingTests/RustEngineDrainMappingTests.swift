import XCTest
import MTProtoRustEngineMapping

/// B3: the pure rules of a live engine switch's drain.
final class RustEngineDrainMappingTests: XCTestCase {
    func testTheReleasedFlagSaysWhetherTheRequestMayHaveRun() {
        XCTAssertTrue(rustEngineReleasedMayHaveRun(flags: 1))
        XCTAssertTrue(rustEngineReleasedMayHaveRun(flags: 3), "other bits are ignored")
        XCTAssertFalse(rustEngineReleasedMayHaveRun(flags: 0))
        XCTAssertFalse(rustEngineReleasedMayHaveRun(flags: 2))
        XCTAssertEqual(rustEngineReleasedMayHaveRunFlag, 1)
    }

    func testOnlyTheEnginesTemporaryKeysLeaveTheContextWithIt() {
        XCTAssertTrue(rustEngineMadeTemporaryKey(attributes: [rustEngineBoundToAttribute: NSNumber(value: 42)]))
        XCTAssertFalse(rustEngineMadeTemporaryKey(attributes: ["apiInitializationHash": "h"]), "MtProtoKit's own key stays")
        XCTAssertFalse(rustEngineMadeTemporaryKey(attributes: nil))
    }

    func testADrainingSessionLeavesTheUnknownKeyReportToItsReplacement() {
        XCTAssertEqual(rustEnginePermanentKeyReportAction(draining: true, keyAge: 3600.0, immunity: 60.0), .leaveToReplacement)
        XCTAssertEqual(rustEnginePermanentKeyReportAction(draining: true, keyAge: 1.0, immunity: 60.0), .leaveToReplacement)
        XCTAssertEqual(rustEnginePermanentKeyReportAction(draining: false, keyAge: 1.0, immunity: 60.0), .keepYoungKey)
        XCTAssertEqual(rustEnginePermanentKeyReportAction(draining: false, keyAge: 61.0, immunity: 60.0), .handle)
    }

    /// Flags: 1 network available, 2 connected, 4 updating the connection context, 32 awaiting the bind.
    func testLosingAnAnsweredConnectionStartsTheSilenceAgain() {
        let answered = RustEngineConnectionFlags(rawValue: 1 | 2)
        let binding = RustEngineConnectionFlags(rawValue: 1 | 2 | 4 | 32)
        let handshaking = RustEngineConnectionFlags(rawValue: 1 | 2 | 4)
        let down = RustEngineConnectionFlags(rawValue: 1)
        XCTAssertTrue(rustEngineHasAnsweredConnection(answered))
        XCTAssertTrue(rustEngineHasAnsweredConnection(binding))
        XCTAssertFalse(rustEngineHasAnsweredConnection(handshaking))
        XCTAssertFalse(rustEngineHasAnsweredConnection(down))
        XCTAssertTrue(rustEngineConnectionStateRestartsSilence(previous: down, current: answered), "an answered connection")
        XCTAssertTrue(rustEngineConnectionStateRestartsSilence(previous: answered, current: handshaking), "a key rotation's reconnect: it worked until now")
        XCTAssertTrue(rustEngineConnectionStateRestartsSilence(previous: binding, current: down))
        XCTAssertFalse(rustEngineConnectionStateRestartsSilence(previous: handshaking, current: down), "still never answered")
        XCTAssertFalse(rustEngineConnectionStateRestartsSilence(previous: down, current: handshaking))
        XCTAssertFalse(rustEngineConnectionStateRestartsSilence(previous: nil, current: handshaking))
        XCTAssertFalse(rustEngineConnectionStateRestartsSilence(previous: answered, current: binding), "still answered: the silence goes on from the last packet")
    }
}
