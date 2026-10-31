import Foundation
import XCTest
import TelegramCore
import WalletEngineFFI
@testable import WalletContext

/// A message widget's wallet calls (widget-sandbox v0.5.0, sdk-v1 §2.18, §5.13; the v0.5.0 plan's Task 5): TON Connect's
/// transaction as the widget's runtime checked it becomes the engine's send intent for the wallet's own transfer path
/// (`wallet.sendTransfer`), with the wallet's refusals as BAD_REQUEST; TON Connect's signData payload becomes the
/// engine's request, signed for `bot<bot_id>`, and its result TON Connect's.
final class WalletWidgetCallsTests: XCTestCase {
    private func friendly(_ byte: String, bounceable: Bool, testnet: Bool = false) -> String {
        return try! convertTonAddress(value: "0:" + String(repeating: byte, count: 32), format: .userFriendly(bounceable: bounceable, testnet: testnet))
    }

    private var wallet: String {
        return self.friendly("cd", bounceable: false)
    }

    private let now: Int64 = 1_800_000_000

    private func intent(_ json: String) throws -> WidgetTransactionIntent {
        return try widgetTransactionIntent(json: json, now: self.now, walletAddress: self.wallet)
    }

    private func refusal(_ json: String) -> WalletContext.WalletError? {
        do {
            _ = try self.intent(json)
            return nil
        } catch let error as WalletContext.WalletError {
            return error
        } catch {
            return .unavailable
        }
    }

    func testATransactionBecomesTheEnginesIntent() throws {
        let bounceable = self.friendly("ab", bounceable: true)
        let plain = self.friendly("ef", bounceable: false)
        // base64url without padding, as TON Connect allows: the engine gets standard base64.
        let json = "{\"valid_until\":1800000600,\"network\":\"-239\",\"from\":\"\(self.wallet)\",\"messages\":["
            + "{\"address\":\"\(bounceable)\",\"amount\":\"1500000000\",\"payload\":\"te6_-w\"},"
            + "{\"address\":\"\(plain)\",\"amount\":\"0\",\"stateInit\":\"AAAA\"}]}"
        let result = try self.intent(json)
        XCTAssertEqual(result.intent.expiration, .exact(unixTimestamp: 1_800_000_600))
        XCTAssertEqual(result.intent.messages.map(\.destination), [bounceable, plain])
        XCTAssertEqual(result.intent.messages.map(\.bounce), [true, false])
        XCTAssertEqual(result.intent.messages.map(\.amount), [.exact(nanograms: "1500000000"), .exact(nanograms: "0")])
        XCTAssertEqual(result.intent.messages.map(\.body), [.rawPayload(boc: "te6/+w=="), .empty])
        XCTAssertEqual(result.intent.messages.map(\.stateInit), [nil, "AAAA"])
        XCTAssertEqual(result.total, 1_500_000_000)
        XCTAssertEqual(result.firstDestination, bounceable)
    }

    func testWithoutValidUntilTheEnginesDefaultExpires() throws {
        let json = "{\"messages\":[{\"address\":\"\(self.friendly("ab", bounceable: true))\",\"amount\":\"1\"}]}"
        XCTAssertEqual(try self.intent(json).intent.expiration, .engineDefault)
    }

    /// The wallet's refusals (sdk-v1 §2.18's BAD_REQUEST): an expired transaction, another network or sender, a testnet or
    /// malformed destination, an amount past the wallet's, cells that are not base64.
    func testTheWalletsRefusals() {
        let destination = self.friendly("ab", bounceable: true)
        let message = "{\"address\":\"\(destination)\",\"amount\":\"1\"}"
        XCTAssertEqual(self.refusal("{\"valid_until\":\(self.now),\"messages\":[\(message)]}"), .preparedTransferExpired)
        XCTAssertEqual(self.refusal("{\"network\":\"-3\",\"messages\":[\(message)]}"), .walletKeyMismatch)
        XCTAssertEqual(self.refusal("{\"from\":\"\(self.friendly("ee", bounceable: true))\",\"messages\":[\(message)]}"), .walletKeyMismatch)
        XCTAssertEqual(self.refusal("{\"messages\":[{\"address\":\"\(self.friendly("ab", bounceable: true, testnet: true))\",\"amount\":\"1\"}]}"), .invalidAddress)
        XCTAssertEqual(self.refusal("{\"messages\":[{\"address\":\"EQ\(String(repeating: "a", count: 46))\",\"amount\":\"1\"}]}"), .invalidAddress)
        XCTAssertEqual(self.refusal("{\"messages\":[{\"address\":\"\(destination)\",\"amount\":\"99999999999999999999\"}]}"), .invalidAmount)
        XCTAssertEqual(self.refusal("{\"messages\":[{\"address\":\"\(destination)\",\"amount\":\"1\",\"payload\":\"***\"}]}"), .previewFailed)
        XCTAssertEqual(self.refusal("[]"), .previewFailed)
        // This wallet as the sender passes, raw or friendly.
        let raw = try! convertTonAddress(value: self.wallet, format: .raw)
        XCTAssertNil(self.refusal("{\"from\":\"\(raw)\",\"messages\":[\(message)]}"))
        XCTAssertNil(self.refusal("{\"from\":\"\(self.wallet)\",\"network\":\"-239\",\"messages\":[\(message)]}"))
    }

    func testSignDataPayloadsBecomeTheEnginesRequest() throws {
        XCTAssertEqual(try widgetSignDataRequest(json: "{\"type\":\"text\",\"text\":\"I agree\"}", walletAddress: self.wallet),
                       WalletEngineFFI.TonConnectSignDataRequest(payload: .text(text: "I agree"), network: nil, from: nil))
        XCTAssertEqual(try widgetSignDataRequest(json: "{\"type\":\"binary\",\"bytes\":\"AAAA\",\"network\":\"-239\"}", walletAddress: self.wallet),
                       WalletEngineFFI.TonConnectSignDataRequest(payload: .binary(bytes: "AAAA"), network: "-239", from: nil))
        XCTAssertEqual(try widgetSignDataRequest(json: "{\"type\":\"cell\",\"schema\":\"x#_ = X;\",\"cell\":\"te6\",\"from\":\"\(self.wallet)\"}", walletAddress: self.wallet),
                       WalletEngineFFI.TonConnectSignDataRequest(payload: .cell(schema: "x#_ = X;", cell: "te6"), network: nil, from: self.wallet))
        XCTAssertThrowsError(try widgetSignDataRequest(json: "{\"type\":\"text\",\"text\":\"x\",\"network\":\"-3\"}", walletAddress: self.wallet))
        XCTAssertThrowsError(try widgetSignDataRequest(json: "{\"type\":\"text\",\"text\":\"x\",\"from\":\"\(self.friendly("ee", bounceable: true))\"}", walletAddress: self.wallet))
        XCTAssertThrowsError(try widgetSignDataRequest(json: "{\"type\":\"x\"}", walletAddress: self.wallet))
    }

    /// TON Connect's `signData` result: the signature in base64, the wallet's raw address, the timestamp, the domain and
    /// the payload as the widget sent it.
    func testTheSignDataResponseIsTonConnects() throws {
        let raw = "0:" + String(repeating: "cd", count: 32)
        let json = widgetSignDataResponse(signature: Data([0xfb, 0xff, 0x01]), rawAddress: raw, timestamp: 1_800_000_000, domain: "bot42", payloadJson: "{\"type\":\"text\",\"text\":\"I agree\"}")
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(object["signature"] as? String, "+/8B")
        XCTAssertEqual(object["address"] as? String, raw)
        XCTAssertEqual(object["timestamp"] as? Int, 1_800_000_000)
        XCTAssertEqual(object["domain"] as? String, "bot42")
        XCTAssertEqual(object["payload"] as? [String: String], ["type": "text", "text": "I agree"])
        XCTAssertEqual(Set(object.keys), ["signature", "address", "timestamp", "domain", "payload"])
    }

    func testTheRequesterNamesTheBot() {
        let requester = WalletContext.WidgetWalletRequester(botId: 42, name: "Shop", username: "shop_bot")
        XCTAssertEqual(requester.signDomain, "bot42")
        // The request's domain is the part a bot cannot choose (the window shows the name beside it, from the peer).
        XCTAssertEqual(requester.displayDomain, "@shop_bot")
        XCTAssertEqual(WalletContext.WidgetWalletRequester(botId: 7, name: "Shop", username: nil).displayDomain, "Shop")
    }

    /// sdk-v1 §5.13: the user's decline is REJECTED, the wallet's refusal BAD_REQUEST, anything else FAILED; the balance is
    /// the top-up's, before the window and after it; after the confirmation only an expired transaction is still the
    /// wallet's refusal.
    func testFailuresMapAsTheSpecSays() {
        typealias E = WalletContext.WalletError
        let prepare: [(E, WalletContext.WidgetWalletFailure)] = [
            (.authorizationCancelled, .rejected), (.preparedTransferExpired, .badRequest), (.walletKeyMismatch, .badRequest),
            (.invalidAddress, .badRequest), (.invalidAmount, .badRequest), (.previewFailed, .badRequest), (.previewIncomplete, .badRequest),
            (.insufficientBalance(required: 5), .insufficientBalance), (.engine("cells"), .badRequest), (.unavailable, .failed), (.noWallet, .failed),
            (.operationInProgress, .failed), (.network, .failed),
        ]
        for (error, failure) in prepare {
            XCTAssertEqual(WalletContext.widgetPrepareFailure(error), failure, "\(error)")
        }
        let submit: [(E, WalletContext.WidgetWalletFailure)] = [
            (.authorizationCancelled, .rejected), (.preparedTransferExpired, .badRequest), (.insufficientBalance(required: 5), .insufficientBalance),
            (.engine("send"), .failed), (.network, .failed), (.walletKeyMismatch, .failed), (.unavailable, .failed),
        ]
        for (error, failure) in submit {
            XCTAssertEqual(WalletContext.widgetSubmitFailure(error), failure, "\(error)")
        }
    }
}
