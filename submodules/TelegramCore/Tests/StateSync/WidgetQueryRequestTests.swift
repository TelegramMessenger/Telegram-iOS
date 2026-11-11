import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// A message widget's request to its bot (widget-sandbox v0.2, W2 plan Task 1): `messages.getBotWidgetQueryAnswer`
/// through a real `Network` to the scripted server, its answer's bytes, the tag's error mapping, the 30 s guard and a
/// local message that never reaches the server. Since v0.5.0 (the wallet) each query names its type: a plain request,
/// one with the user's wallet card, a signature or a sent transaction.
final class WidgetQueryRequestTests: StateSyncTestCase {
    private func outcome(_ signal: Signal<Data?, BotWidgetQueryError>, timeout: Double = 5.0) -> Result<Data?, BotWidgetQueryError>? {
        return self.fixture.wait(signal
            |> map { Result<Data?, BotWidgetQueryError>.success($0) }
            |> `catch` { error -> Signal<Result<Data?, BotWidgetQueryError>, NoError> in .single(.failure(error)) }
            |> take(1), timeout: timeout)
    }

    private func request(_ messageId: MessageId, queryType: BotWidgetQueryType = .data(withWallet: false), timeout: Double = 30.0) -> Signal<Data?, BotWidgetQueryError> {
        return _internal_requestBotWidgetQueryAnswer(postbox: self.fixture.postbox, network: self.network, messageId: messageId, queryType: queryType, data: Data("ping".utf8), timeout: timeout)
    }

    /// The function as `Network` serializes it for the seeded user 200's message 7, with `queryType`.
    private func expectedPayload(_ queryType: Api.WidgetQueryType) -> Data {
        return Api.functions.messages.getBotWidgetQueryAnswer(peer: .inputPeerUser(.init(userId: 200, accessHash: 1)), msgId: 7, queryType: queryType, data: Buffer(data: Data("ping".utf8))).1.makeData()
    }

    private func sentPayload(_ queryType: BotWidgetQueryType) -> Data? {
        let user = self.seedUserChat(200)
        self.server.on("messages.getBotWidgetQueryAnswer", .result(Api.messages.BotWidgetQueryAnswer.botWidgetQueryAnswer(.init(flags: 1, result: "ok"))))
        XCTAssertEqual(self.outcome(self.request(self.messageId(user, 7), queryType: queryType)), .success(Data("ok".utf8)))
        return self.server.requests.first?.payload
    }

    private let card = EngineUserWallet(address: "UQ" + String(repeating: "a", count: 46), balance: 1_500_000_000, signing: EngineUserWallet.Signing(publicKey: Data([1, 2, 3]), stateInit: Data([4, 5])))

    func testAPlainRequestIsTheDataQueryWithoutTheWallet() {
        XCTAssertEqual(self.sentPayload(.data(withWallet: false)), self.expectedPayload(.widgetQueryTypeData(.init(flags: 0))), "arguments: \(self.server.requests.first?.arguments ?? "none")")
    }

    func testARequestForTheWalletSetsWithWallet() {
        XCTAssertEqual(self.sentPayload(.data(withWallet: true)), self.expectedPayload(.widgetQueryTypeData(.init(flags: 1 << 0))), "arguments: \(self.server.requests.first?.arguments ?? "none")")
    }

    func testASignatureCarriesTheCardAndTheResultAsJSON() {
        let json = "{\"signature\":\"c2ln\"}"
        let wallet = Api.UserWallet.userWallet(.init(flags: 1 << 0, address: self.card.address, balance: self.card.balance, publicKey: Buffer(data: Data([1, 2, 3])), stateInit: Buffer(data: Data([4, 5]))))
        XCTAssertEqual(self.sentPayload(.signData(wallet: self.card, json: json)), self.expectedPayload(.widgetQueryTypeSignData(.init(wallet: wallet, signData: .dataJSON(.init(data: json))))), "arguments: \(self.server.requests.first?.arguments ?? "none")")
    }

    func testASentTransactionCarriesTheCardAndTheHash() {
        let card = EngineUserWallet(address: self.card.address, balance: 0, signing: nil)
        let wallet = Api.UserWallet.userWallet(.init(flags: 0, address: card.address, balance: 0, publicKey: nil, stateInit: nil))
        XCTAssertEqual(self.sentPayload(.sentTransaction(wallet: card, msgHash: "aGFzaA==")), self.expectedPayload(.widgetQueryTypeSentTransaction(.init(wallet: wallet, msgHash: "aGFzaA=="))), "arguments: \(self.server.requests.first?.arguments ?? "none")")
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
