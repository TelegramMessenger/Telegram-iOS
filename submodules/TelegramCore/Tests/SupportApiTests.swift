import Foundation
import XCTest
import Postbox
import SwiftSignalKit
import TelegramApi
@testable import TelegramCore

final class SupportApiTests: XCTestCase {
    private static let logger: Logger = {
        let logger = Logger(rootPath: NSTemporaryDirectory(), basePath: NSTemporaryDirectory())
        logger.logToFile = false
        logger.logToConsole = false
        return logger
    }()

    override func setUp() {
        super.setUp()
        Logger.setSharedLogger(SupportApiTests.logger)
    }

    private let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1001))
    private let otherPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1002))

    private func context() -> SupportContext {
        return SupportContext(settings: .single(.default))
    }

    private func info(text: String = "note") -> SupportUserInfo {
        return SupportUserInfo(author: "agent", date: 1000, text: text, entities: [])
    }

    func testNameMapping() {
        XCTAssertEqual(supportName(.supportName(.init(name: "Agent"))), "Agent")
    }

    func testNameFallbackMatchesTDesktop() {
        XCTAssertEqual(supportNameFallback(installationTag: 18446744073709551615), "[rand^18446744073709551615]")
    }

    func testInstallationTagRoundTrip() {
        let tag = SupportInstallationTag(value: -5)
        XCTAssertEqual(PreferencesEntry(tag)?.get(SupportInstallationTag.self), tag)
    }

    func testEmptyInfoMapsToNothing() {
        XCTAssertNil(supportUserInfo(.userInfoEmpty))
    }

    func testEmptyTextMapsToNothing() {
        XCTAssertNil(supportUserInfo(.userInfo(.init(message: "", entities: [], author: "agent", date: 1000))))
    }

    func testInfoMapping() {
        let result = supportUserInfo(.userInfo(.init(message: "note", entities: [.messageEntityBold(.init(offset: 0, length: 4))], author: "agent", date: 1000)))
        XCTAssertEqual(result, SupportUserInfo(author: "agent", date: 1000, text: "note", entities: [MessageTextEntity(range: 0 ..< 4, type: .Bold)]))
    }

    func testTrimShiftsEntities() {
        let trimmed = supportTrimmedUserInfoText(text: " \n ab cd\n ", entities: [
            MessageTextEntity(range: 0 ..< 4, type: .Bold),
            MessageTextEntity(range: 3 ..< 5, type: .Italic),
            MessageTextEntity(range: 6 ..< 10, type: .Code),
            MessageTextEntity(range: 0 ..< 2, type: .Url)
        ])
        XCTAssertEqual(trimmed.text, "ab cd")
        XCTAssertEqual(trimmed.entities, [
            MessageTextEntity(range: 0 ..< 1, type: .Bold),
            MessageTextEntity(range: 0 ..< 2, type: .Italic),
            MessageTextEntity(range: 3 ..< 5, type: .Code)
        ])
    }

    func testTrimCountsUtf16() {
        let trimmed = supportTrimmedUserInfoText(text: " \u{1F600}a ", entities: [MessageTextEntity(range: 3 ..< 4, type: .Bold)])
        XCTAssertEqual(trimmed.text, "\u{1F600}a")
        XCTAssertEqual(trimmed.entities, [MessageTextEntity(range: 2 ..< 3, type: .Bold)])
    }

    func testTrimLeavesOnlyWhitespaceEmpty() {
        let trimmed = supportTrimmedUserInfoText(text: " \n ", entities: [MessageTextEntity(range: 0 ..< 3, type: .Bold)])
        XCTAssertEqual(trimmed.text, "")
        XCTAssertEqual(trimmed.entities, [])
    }

    func testApplyStoresAndRemoves() {
        let context = self.context()
        var values: [SupportUserInfo?] = []
        let disposable = context.userInfo(peerId: self.peerId).start(next: { value in
            values.append(value)
        })
        defer {
            disposable.dispose()
        }

        context.applyUserInfo(peerId: self.peerId, info: self.info())
        XCTAssertEqual(context.currentUserInfo(peerId: self.peerId), self.info())
        context.applyUserInfo(peerId: self.peerId, info: self.info())
        context.applyUserInfo(peerId: self.otherPeerId, info: self.info(text: "other"))
        context.applyUserInfo(peerId: self.peerId, info: nil)
        XCTAssertNil(context.currentUserInfo(peerId: self.peerId))
        XCTAssertEqual(values, [nil, self.info(), nil])
        XCTAssertEqual(context.currentUserInfo(peerId: self.otherPeerId), self.info(text: "other"))
    }

    func testSupportNameIsPublishedOnceSet() {
        let context = self.context()
        var values: [String] = []
        let disposable = context.supportName.start(next: { value in
            values.append(value)
        })
        defer {
            disposable.dispose()
        }

        XCTAssertEqual(values, [])
        context.setSupportName("Agent")
        XCTAssertEqual(values, ["Agent"])
    }

    func testSaveAppliesTheResult() {
        let context = self.context()
        var completed = false
        let disposable = context.saveUserInfo(peerId: self.peerId, text: "note", entities: [], request: .single(self.info())).start(completed: {
            completed = true
        })
        defer {
            disposable.dispose()
        }

        XCTAssertTrue(completed)
        XCTAssertEqual(context.currentUserInfo(peerId: self.peerId), self.info())
    }

    func testSameTextWhileSavingJoinsTheSave() {
        let context = self.context()
        let request = Promise<SupportUserInfo?>()
        var requestCount = 0
        let counted = Signal<SupportUserInfo?, SaveSupportUserInfoError> { subscriber in
            requestCount += 1
            return (request.get() |> castError(SaveSupportUserInfoError.self)).start(next: { value in
                subscriber.putNext(value)
                subscriber.putCompletion()
            })
        }
        var completions = 0
        let first = context.saveUserInfo(peerId: self.peerId, text: "note", entities: [], request: counted).start(completed: {
            completions += 1
        })
        let second = context.saveUserInfo(peerId: self.peerId, text: "note", entities: [], request: counted).start(completed: {
            completions += 1
        })
        defer {
            first.dispose()
            second.dispose()
        }

        XCTAssertEqual(requestCount, 1)
        request.set(.single(self.info()))
        XCTAssertEqual(completions, 2)
    }

    func testDifferentTextReplacesTheSave() {
        let context = self.context()
        var firstDisposed = false
        let pending = Signal<SupportUserInfo?, SaveSupportUserInfoError> { _ in
            return ActionDisposable {
                firstDisposed = true
            }
        }
        var firstCompleted = false
        let first = context.saveUserInfo(peerId: self.peerId, text: "old", entities: [], request: pending).start(completed: {
            firstCompleted = true
        })
        let second = context.saveUserInfo(peerId: self.peerId, text: "new", entities: [], request: .single(self.info(text: "new"))).start()
        defer {
            first.dispose()
            second.dispose()
        }

        XCTAssertTrue(firstDisposed)
        XCTAssertTrue(firstCompleted)
        XCTAssertEqual(context.currentUserInfo(peerId: self.peerId), self.info(text: "new"))
    }

    func testFailureIsReportedAndKeepsTheNote() {
        let context = self.context()
        context.applyUserInfo(peerId: self.peerId, info: self.info())
        var failed = false
        let disposable = context.saveUserInfo(peerId: self.peerId, text: "new", entities: [], request: .fail(.generic)).start(error: { _ in
            failed = true
        })
        defer {
            disposable.dispose()
        }

        XCTAssertTrue(failed)
        XCTAssertEqual(context.currentUserInfo(peerId: self.peerId), self.info())
    }

    func testSameTextAfterAFinishedSaveSendsAgain() {
        let context = self.context()
        var requestCount = 0
        let counted = Signal<SupportUserInfo?, SaveSupportUserInfoError> { subscriber in
            requestCount += 1
            subscriber.putNext(self.info())
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let first = context.saveUserInfo(peerId: self.peerId, text: "note", entities: [], request: counted).start()
        let second = context.saveUserInfo(peerId: self.peerId, text: "note", entities: [], request: counted).start()
        defer {
            first.dispose()
            second.dispose()
        }

        XCTAssertEqual(requestCount, 2)
    }

    func testTitleWarnsOnlyForAnotherUserWithANote() {
        XCTAssertTrue(supportChatTitleShowsWarning(peerId: self.peerId, accountPeerId: self.otherPeerId, hasUserInfo: true))
        XCTAssertFalse(supportChatTitleShowsWarning(peerId: self.peerId, accountPeerId: self.otherPeerId, hasUserInfo: false))
        XCTAssertFalse(supportChatTitleShowsWarning(peerId: self.peerId, accountPeerId: self.peerId, hasUserInfo: true))
        let group = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(1003))
        XCTAssertFalse(supportChatTitleShowsWarning(peerId: group, accountPeerId: self.otherPeerId, hasUserInfo: true))
    }

    func testSavedNoteDoesNotReachTheRequestLog() {
        let function = Api.functions.help.editUserInfo(userId: .inputUserSelf, message: "made-up note", entities: [.messageEntityTextUrl(.init(offset: 0, length: 4, url: "https://example.com/made-up"))])
        let description = apiFunctionDescription(of: function.0)
        XCTAssertTrue(description.hasPrefix("help.editUserInfo("))
        XCTAssertFalse(description.contains("made-up"))
    }

    func testFetchedNoteDoesNotReachTheResponseLog() {
        let result = Api.help.UserInfo.userInfo(.init(message: "made-up note", entities: [.messageEntityTextUrl(.init(offset: 0, length: 4, url: "https://example.com/made-up"))], author: "made-up agent", date: 1000))
        let description = BoxedMessage(result).description
        XCTAssertTrue(description.hasPrefix("help.UserInfo.userInfo"))
        XCTAssertFalse(description.contains("made-up"))
    }
}
