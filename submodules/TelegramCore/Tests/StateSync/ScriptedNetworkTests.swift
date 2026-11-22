import Foundation
import XCTest
import SwiftSignalKit
import MtProtoKit
import TelegramApi
@testable import TelegramCore

/// The harness itself: a real `Network` over the scripted server, before any state manager exists.
final class ScriptedNetworkTests: StateSyncTestCase {
    func testRequestIsAnsweredFromScriptAndLogged() {
        self.server.on(Name.helpTest, .result(StateSyncApi.boolTrue()))

        let result = self.fixture.wait(self.network.request(Api.functions.help.test())
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        })

        guard let value = result ?? nil, case .boolTrue = value else {
            XCTFail("expected boolTrue, got \(String(describing: result))")
            return
        }
        XCTAssertEqual(self.server.requestNames, [Name.helpTest])
        XCTAssertTrue(self.server.unscripted.isEmpty)
    }

    func testUnscriptedRequestIsHeldNotAnswered() {
        let disposable = self.network.request(Api.functions.help.test()).start()
        defer {
            disposable.dispose()
        }

        XCTAssertTrue(self.server.waitForRequest(Name.helpTest))
        XCTAssertEqual(self.server.unscripted.map { $0.name }, [Name.helpTest])
        XCTAssertEqual(self.server.heldNames, [Name.helpTest])
    }

    /// With a delivery delay, an answer reaches the caller only after it, and `flush()` returns only once every
    /// scheduled delivery has been made.
    func testDelayedAnswerArrivesAfterTheDelayAndFlushWaitsForIt() {
        self.server.deliveryDelay = { _ in 0.3 }
        self.server.on(Name.helpTest, .result(StateSyncApi.boolTrue()))
        let answered = Atomic<Bool>(value: false)
        let started = Date()
        let disposable = self.network.request(Api.functions.help.test()).start(next: { _ in
            let _ = answered.swap(true)
        })
        defer {
            disposable.dispose()
        }

        XCTAssertTrue(self.server.waitForRequest(Name.helpTest))
        XCTAssertFalse(answered.with { $0 }, "answered before the delay")
        self.server.flush()

        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.3, "flush returned before the delayed delivery")
        self.fixture.eventually {
            return answered.with { $0 }
        }
    }

    func testScriptedErrorReachesTheCaller() {
        self.server.on(Name.helpTest, .error(code: 400, text: "TEST_ERROR"))

        let result = self.fixture.wait(self.network.request(Api.functions.help.test())
        |> map { _ -> String? in
            return nil
        }
        |> `catch` { error -> Signal<String?, NoError> in
            return .single(error.errorDescription)
        })

        XCTAssertEqual(result ?? nil, "TEST_ERROR")
    }
}
