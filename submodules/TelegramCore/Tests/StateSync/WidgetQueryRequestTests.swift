import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// A message widget's request to its bot (widget-sandbox v0.2, W2 plan Task 1): `messages.getBotWidgetQueryAnswer`
/// through a real `Network` to the scripted server, its answer's bytes, the tag's error mapping, the 30 s guard and a
/// local message that never reaches the server.
final class WidgetQueryRequestTests: StateSyncTestCase {
    private func outcome(_ signal: Signal<Data?, BotWidgetQueryError>, timeout: Double = 5.0) -> Result<Data?, BotWidgetQueryError>? {
        return self.fixture.wait(signal
            |> map { Result<Data?, BotWidgetQueryError>.success($0) }
            |> `catch` { error -> Signal<Result<Data?, BotWidgetQueryError>, NoError> in .single(.failure(error)) }
            |> take(1), timeout: timeout)
    }

    private func request(_ messageId: MessageId, timeout: Double = 30.0) -> Signal<Data?, BotWidgetQueryError> {
        return _internal_requestBotWidgetQueryAnswer(postbox: self.fixture.postbox, network: self.network, messageId: messageId, data: Data("ping".utf8), timeout: timeout)
    }

    func testTheAnswerComesBackAsItsBytes() {
        let user = self.seedUserChat(200)
        self.server.on("messages.getBotWidgetQueryAnswer", .result(Api.messages.BotWidgetQueryAnswer.botWidgetQueryAnswer(.init(flags: 1, result: "pong"))))
        let result = self.outcome(self.request(self.messageId(user, 7)))
        XCTAssertEqual(result, .success(Data("pong".utf8)))
        XCTAssertEqual(self.server.requestNames, ["messages.getBotWidgetQueryAnswer"])
    }

    func testAnAnswerWithoutAResultIsNil() {
        let user = self.seedUserChat(200)
        self.server.on("messages.getBotWidgetQueryAnswer", .result(Api.messages.BotWidgetQueryAnswer.botWidgetQueryAnswer(.init(flags: 0, result: nil))))
        XCTAssertEqual(self.outcome(self.request(self.messageId(user, 7))), .success(nil))
    }

    func testAServerErrorIsMapped() {
        let user = self.seedUserChat(200)
        self.server.on("messages.getBotWidgetQueryAnswer", .error(code: 400, text: "WIDGET_RESPONSE_TIMEOUT"))
        XCTAssertEqual(self.outcome(self.request(self.messageId(user, 7))), .failure(.timeout))
    }

    /// No answer within the guard: the request completes as failed, so the widget's gate is never left busy.
    func testNoAnswerWithinTheGuardFails() {
        let user = self.seedUserChat(200)
        self.server.on("messages.getBotWidgetQueryAnswer", .hold)
        let started = CFAbsoluteTimeGetCurrent()
        XCTAssertEqual(self.outcome(self.request(self.messageId(user, 7), timeout: 0.3)), .failure(.failed))
        XCTAssertLessThan(CFAbsoluteTimeGetCurrent() - started, 2.0)
    }

    /// The DEBUG insertion's local messages mean nothing to the server (design §4 call 9).
    func testALocalMessageFailsWithoutARequest() {
        let user = self.seedUserChat(200)
        let local = MessageId(peerId: user, namespace: Namespaces.Message.Local, id: 7)
        XCTAssertEqual(self.outcome(self.request(local)), .failure(.failed))
        XCTAssertFalse(self.server.requestNames.contains("messages.getBotWidgetQueryAnswer"))
    }
}
