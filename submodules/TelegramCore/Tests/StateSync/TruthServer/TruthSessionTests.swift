import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Sessions against the truth server (TruthSession.swift): each runs its steps, brings the app to rest with every
/// chat filled, and expects the app to hold exactly what the server holds. The oracle's own two tests come first.
final class TruthSessionTests: XCTestCase {
    private let baseDate: Int32 = 1_700_000_000

    /// A driver that has run `steps` and brought the app to rest; the caller compares and closes it.
    private func convergedSession(seed: UInt64, steps: [TruthStep], ptsTotalLimit: Int32? = 10000, limits: TruthLimits = TruthLimits(), initialMessagesPerChat: ClosedRange<Int> = 3 ... 8, shape: TruthShape = .small, jitter: Bool = false, file: StaticString = #filePath, line: UInt = #line) -> TruthSessionDriver? {
        let world = TruthWorld(seed: seed, initialMessagesPerChat: initialMessagesPerChat, baseDate: self.baseDate, shape: shape)
        do {
            let driver = try TruthSessionDriver(world: world, limits: limits, ptsTotalLimit: ptsTotalLimit, seed: seed, jitter: jitter)
            driver.run(steps)
            driver.converge()
            return driver
        } catch {
            XCTFail("the session did not start: \(error)", file: file, line: line)
            return nil
        }
    }

    /// What the oracle found after `steps`; fails the test when the session's Postbox outlives it.
    private func session(seed: UInt64, steps: [TruthStep], ptsTotalLimit: Int32? = 10000, limits: TruthLimits = TruthLimits(), initialMessagesPerChat: ClosedRange<Int> = 3 ... 8, shape: TruthShape = .small, jitter: Bool = false, file: StaticString = #filePath, line: UInt = #line) -> (found: [TruthDiscrepancy], requests: [String]) {
        guard let driver = self.convergedSession(seed: seed, steps: steps, ptsTotalLimit: ptsTotalLimit, limits: limits, initialMessagesPerChat: initialMessagesPerChat, shape: shape, jitter: jitter, file: file, line: line) else {
            return ([], [])
        }
        let found = driver.compare()
        let requests = driver.server.requestNames
        if !found.isEmpty {
            print(driver.report(seed: seed, found: found))
            // A replay can ask for the whole report in a file (TRUTH_REPORT_DIR, a host directory): printed lines
            // can be split by other threads' log lines.
            if let directory = ProcessInfo.processInfo.environment["TRUTH_REPORT_DIR"] {
                let path = directory + "/seed-\(seed).txt"
                try? driver.report(seed: seed, found: found, detailed: true).write(toFile: path, atomically: true, encoding: .utf8)
            }
        }
        XCTAssertTrue(driver.close(), "the Postbox outlived the session", file: file, line: line)
        return (found, requests)
    }

    // MARK: - The oracle

    /// A message removed from the app's Postbox by hand after rest is reported missing, with its id.
    func testTheOracleCatchesAMissingMessage() {
        guard let driver = self.convergedSession(seed: 1, steps: []) else {
            return
        }
        let chat = TruthPeer.user(201)
        guard let target = driver.world.existing(chat).first else {
            XCTFail("the world's chat is empty")
            return
        }
        driver.fixture.transaction { transaction -> Void in
            transaction.deleteMessages([MessageId(peerId: chat.peerId, namespace: Namespaces.Message.Cloud, id: target.id)], forEachMedia: nil)
        }
        XCTAssertEqual(driver.compare(), [TruthDiscrepancy(kind: .missing, chat: chat, ids: [target.id], note: "")])
        XCTAssertTrue(driver.close())
    }

    /// A message the world never had, stored by hand after rest, is reported as a ghost.
    func testTheOracleCatchesAGhost() {
        guard let driver = self.convergedSession(seed: 1, steps: []) else {
            return
        }
        let chat = TruthPeer.user(202)
        driver.fixture.storeMessage(peerId: chat.peerId, id: 9999, timestamp: self.baseDate, authorId: chat.peerId, text: "never sent", location: .Random)
        XCTAssertEqual(driver.compare(), [TruthDiscrepancy(kind: .ghost, chat: chat, ids: [9999], note: "")])
        XCTAssertTrue(driver.close())
    }

    /// A chat the server lists that the app's chat list lacks is reported as unlisted.
    func testTheOracleCatchesAChatMissingFromTheChatList() {
        guard let driver = self.convergedSession(seed: 1, steps: []) else {
            return
        }
        let chat = TruthPeer.user(202)
        driver.fixture.transaction { transaction -> Void in
            transaction.updatePeerChatListInclusion(chat.peerId, inclusion: .notIncluded)
        }
        XCTAssertEqual(driver.compare(), [TruthDiscrepancy(kind: .unlisted, chat: chat, ids: [], note: "")])
        XCTAssertTrue(driver.close())
    }

    /// A chat listed with another top than the server's is reported with both ids, the app's first.
    func testTheOracleCatchesAWrongTopInTheChatList() {
        guard let driver = self.convergedSession(seed: 1, steps: []) else {
            return
        }
        let chat = TruthPeer.user(203)
        let messages = driver.world.existing(chat)
        guard messages.count >= 2, let top = messages.last else {
            XCTFail("the world's chat has fewer than two messages")
            return
        }
        driver.fixture.transaction { transaction -> Void in
            transaction.deleteMessages([MessageId(peerId: chat.peerId, namespace: Namespaces.Message.Cloud, id: top.id)], forEachMedia: nil)
        }
        let previous = messages[messages.count - 2].id
        XCTAssertEqual(driver.compare(), [
            TruthDiscrepancy(kind: .missing, chat: chat, ids: [top.id], note: ""),
            TruthDiscrepancy(kind: .wrongTop, chat: chat, ids: [previous, top.id], note: "")
        ])
        XCTAssertTrue(driver.close())
    }

    /// A fill that never answers is reported at once as no convergence for its chat, which is not filled again: waiting
    /// out 50 fills of 30 s each would outlast a long run's test timeout. The first fill `converge` makes (every chat
    /// starts with a hole over its whole history) is held for good.
    func testAFillThatNeverAnswersIsNoConvergenceAtOnce() {
        let world = TruthWorld(seed: 1, initialMessagesPerChat: 3 ... 8, baseDate: self.baseDate)
        guard let driver = try? TruthSessionDriver(world: world, ptsTotalLimit: 10000, seed: 1) else {
            XCTFail("the session did not start")
            return
        }
        driver.fillTimeout = 0.5
        let chat = world.chats()[0]
        driver.server.on("messages.getHistory", .hold)

        let started = Date()
        driver.converge()
        let found = driver.compare()

        XCTAssertLessThan(Date().timeIntervalSince(started), 20.0, "converge waited out the fill")
        XCTAssertTrue(found.contains(where: { $0.kind == .noConvergence && $0.chat == chat }), "\(found)")
        let fillsOfTheChat = driver.server.requests.filter { request in
            if request.name == "messages.getHistory", case let .getHistory(peer, _, _, _, _, _) = decodeTruthRequest(name: request.name, payload: request.payload) {
                return peer == chat
            }
            return false
        }
        XCTAssertEqual(fillsOfTheChat.count, 1, "the chat was filled again after its fill timed out")
        XCTAssertTrue(driver.close())
    }

    /// The driver runs the app's channel revalidation as an open chat does (`validateChannels`): a post the server does
    /// not have, stored by hand below the channel's `invalidatedPts` after `converge`, is reported (a ghost: converge's
    /// own validation has run) and is gone after another validation, which asked the server about it.
    func testValidationDeletesAChannelGhostBelowTheInvalidationPts() {
        guard let driver = self.convergedSession(seed: 1, steps: []) else {
            return
        }
        let chat = TruthPeer.channel(301)
        let peerId = chat.peerId
        let pts = driver.fixture.channelState(peerId)?.pts ?? 0
        driver.fixture.transaction { transaction -> Void in
            transaction.setPeerChatState(peerId, state: ChannelState(pts: pts, invalidatedPts: pts, synchronizedUntilMessageId: nil))
        }
        driver.fixture.storeMessage(peerId: peerId, id: 999, timestamp: self.baseDate + 999, authorId: nil, text: "deleted on the server", location: .Random)
        let top = driver.world.existing(chat).last?.id ?? 0
        XCTAssertEqual(driver.compare(), [
            TruthDiscrepancy(kind: .ghost, chat: chat, ids: [999], note: ""),
            TruthDiscrepancy(kind: .wrongTop, chat: chat, ids: [999, top], note: "")
        ], "precondition: the oracle sees the ghost, the channel's top in the app's chat list")
        let requestsBefore = driver.server.requests.count

        driver.validateChannels()

        XCTAssertEqual(driver.compare(), [])
        XCTAssertNil(driver.fixture.message(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: 999)))
        XCTAssertTrue(driver.server.requests[requestsBefore...].contains(where: { $0.name == "messages.getHistory" || $0.name == "channels.getMessages" }), "the revalidation sent nothing: \(driver.server.requestNames[requestsBefore...])")
        XCTAssertTrue(driver.close())
    }

    /// Seed 111 of the long run, shrunk: a channel post edited on the server and never delivered, below the channel's
    /// `invalidatedPts`, has its new text after the app's revalidation, which takes an edit from its `edit_date`.
    func testValidationRefreshesAChannelPostEditedBelowTheInvalidationPts() {
        guard let driver = self.convergedSession(seed: 1, steps: []) else {
            return
        }
        let chat = TruthPeer.channel(301)
        let peerId = chat.peerId
        guard let post = driver.world.existing(chat).first else {
            XCTFail("the world's channel is empty")
            return
        }
        let _ = driver.world.edit(chat, post.id, text: "edited on the server")
        driver.fixture.transaction { transaction -> Void in
            transaction.setPeerChatState(peerId, state: ChannelState(pts: driver.world.channelPts[301] ?? 0, invalidatedPts: driver.world.channelPts[301] ?? 0, synchronizedUntilMessageId: nil))
        }
        XCTAssertEqual(driver.compare(), [TruthDiscrepancy(kind: .stale, chat: chat, ids: [post.id], note: "")], "precondition: the app has the old text")

        driver.validateChannels()

        XCTAssertEqual(driver.compare(), [])
        XCTAssertTrue(driver.close())
    }

    /// An account of realistic size (`TruthShape.large`, 129 chats) offline past the total limit: the reset lists the
    /// first dialogs page, the chat list's hole brings the rest, the long chats fill in pages, are opened at a message
    /// and scrolled; the app ends holding what the server holds.
    func testALargeAccountResetsAndConverges() {
        var steps: [TruthStep] = [.goOffline]
        let chats: [TruthPeer] = [.user(201), .user(250), .user(323), .chat(801), .chat(802), .channel(301), .channel(304)]
        for index in 0 ..< 30 {
            steps.append(.receive(chats[index % chats.count]))
        }
        steps.append(contentsOf: [.goOnline, .openChatAt(.user(201)), .scrollOlder(.user(201)), .openChatAt(.channel(301)), .deliverPushes])
        let result = self.session(seed: 1, steps: steps, ptsTotalLimit: 10, shape: .large)
        XCTAssertEqual(result.found, [])
        XCTAssertGreaterThanOrEqual(result.requests.filter { $0 == "messages.getDialogs" }.count, 2, "the chat list was not paged: \(result.requests.filter { $0 == "messages.getDialogs" })")
    }

    /// Large-world seeds 698 and 916 of the long run: a private chat's message deleted while the app was offline, the
    /// reset's first dialogs page not holding the chat, and the chat-list fill of the next page storing its top. The
    /// fill now leaves the message under a hole, and the chat's history fill deletes it
    /// (`testChatListFillLeavesMessagesAboveATopUnderAHoleTheNextHistoryFillConfirms`).
    func testTheLargeWorldGhostTailSeedsEndExact() {
        for seed: UInt64 in [698, 916] {
            let session = makeTruthSession(seed: seed, shape: .large)
            let result = self.session(seed: seed, steps: session.steps, ptsTotalLimit: session.ptsTotalLimit, shape: .large)
            XCTAssertEqual(result.found, [], "seed \(seed)")
        }
    }

    /// Large-world seed 1667 of the long run: channel 301 opened at its first post, an around fill that asked with
    /// `min_id` 1 and closed the hole over the post it left out (`testAroundFillAnchoredAtTheFirstMessageAsksForIt`).
    func testTheLargeWorldFirstPostSeedEndsExact() {
        let session = makeTruthSession(seed: 1667, shape: .large)
        let result = self.session(seed: 1667, steps: session.steps, ptsTotalLimit: session.ptsTotalLimit, shape: .large)
        XCTAssertEqual(result.found, [])
    }

    // MARK: - Fixed sessions

    func testOnlinePushesOnly() {
        let result = self.session(seed: 2, steps: [
            .receive(.user(201)), .receive(.chat(801)), .receive(.channel(301)), .receive(.channel(302)), .deliverPushes,
            .edit(.user(201)), .delete(.channel(302), count: 1), .sendFromOtherDevice(.chat(801)), .deliverPushes
        ])
        XCTAssertEqual(result.found, [])
    }

    func testOfflineThenLaunchDifference() {
        let result = self.session(seed: 3, steps: [
            .goOffline,
            .receive(.user(201)), .receive(.user(202)), .receive(.chat(801)), .receive(.channel(302)), .sendFromOtherDevice(.user(203)),
            .edit(.chat(801)), .delete(.user(202), count: 2),
            .goOnline
        ])
        XCTAssertEqual(result.found, [])
    }

    /// 25 events offline with `pts_total_limit` 10: the launch getDifference is answered too long, and the reset
    /// brings the app in step.
    func testOfflineLongerThanTheTotalLimitResets() {
        var steps: [TruthStep] = [.goOffline]
        for index in 0 ..< 25 {
            steps.append(.receive([TruthPeer.user(201), .user(202), .chat(801)][index % 3]))
        }
        steps.append(.goOnline)
        let result = self.session(seed: 4, steps: steps, ptsTotalLimit: 10)
        XCTAssertEqual(result.found, [])
        XCTAssertTrue(result.requests.contains("messages.getDialogs"), "no reset: \(result.requests)")
    }

    func testHistoryClearedWhileOffline() {
        let result = self.session(seed: 5, steps: [
            .openChat(.user(201)),
            .goOffline, .clearHistory(.user(201)), .receive(.user(202)),
            .goOnline
        ])
        XCTAssertEqual(result.found, [])
    }

    /// The same clear, offline past the total limit: the reset meets the cleared chat's service-message top.
    func testHistoryClearedWhileOfflinePastTheTotalLimit() {
        var steps: [TruthStep] = [.openChat(.user(201)), .goOffline, .clearHistory(.user(201))]
        for _ in 0 ..< 15 {
            steps.append(.receive(.user(202)))
        }
        steps.append(.goOnline)
        let result = self.session(seed: 6, steps: steps, ptsTotalLimit: 10)
        XCTAssertEqual(result.found, [])
    }

    func testDeletionsWhileOfflineInAChannel() {
        let result = self.session(seed: 7, steps: [
            .openChat(.channel(301)),
            .goOffline, .delete(.channel(301), count: 2), .receive(.channel(301)), .edit(.channel(301)),
            .goOnline
        ])
        XCTAssertEqual(result.found, [])
    }

    /// Seeds of `testRandomSessionsLong` that ended with an edited message's old text (the run report, section 5): a
    /// message under a hole is edited while the fill bringing it is in flight. 1540 and 4967 were the branch's two
    /// regressions (after a reset; 1540 after a retried fill too), 887 a private chat's on master as well, 1443 a
    /// channel's. Each keeps its edit (`RecentEditTests`).
    func testTheEditRaceSeedsKeepTheirEdits() {
        for seed: UInt64 in [887, 1443, 1540, 4967] {
            let session = makeTruthSession(seed: seed)
            let result = self.session(seed: seed, steps: session.steps, ptsTotalLimit: session.ptsTotalLimit)
            XCTAssertEqual(result.found.filter { $0.kind != .validationPending }, [], "seed \(seed)")
        }
    }

    func testRestartMidSession() {
        let result = self.session(seed: 8, steps: [
            .receive(.user(201)), .deliverPushes, .openChat(.user(201)),
            .restartApp,
            .receive(.user(201)), .delete(.user(201), count: 1), .deliverPushes
        ])
        XCTAssertEqual(result.found, [])
    }
    // MARK: - Found by random sessions

    /// Seed 148, shrunk: while the app is offline user201 gets messages 1 and 2 (the world starts empty) and enough
    /// else happens to pass `pts_total_limit`, so the relaunch resets and message 1 was never stored. The reset stores the top message, 2, above a hole over `1 ... 1`,
    /// which a view asks for as `.range(start: 1, end: 1)`. Until the fix that fill asked for nothing and closed the
    /// hole: message 1 missing (HistoryFillRangeBoundsTests).
    func testSeed148ATopMessageOfTwoAfterAResetKeepsMessageOne() {
        var steps: [TruthStep] = [.goOffline, .receive(.user(201)), .receive(.user(201))]
        for _ in 0 ..< 12 {
            steps.append(.receive(.user(202)))
        }
        steps.append(.goOnline)
        let result = self.session(seed: 148, steps: steps, ptsTotalLimit: 10, initialMessagesPerChat: 0 ... 0)
        XCTAssertEqual(result.found, [])
        XCTAssertTrue(result.requests.contains("messages.getDialogs"), "no reset: \(result.requests)")
    }

    // MARK: - Faults

    /// Each fault on its own, in a session that would otherwise be clean.
    func testEachFaultStepOnItsOwn() {
        let sessions: [(String, [TruthStep])] = [
            ("dropNextPush", [.receive(.user(201)), .receive(.user(201)), .dropNextPush, .deliverPushes, .receive(.user(201)), .deliverPushes]),
            ("dropNextPush in a channel", [.openChat(.channel(302)), .receive(.channel(302)), .receive(.channel(302)), .dropNextPush, .deliverPushes, .receive(.channel(302)), .deliverPushes]),
            ("duplicateNextPush", [.receive(.chat(801)), .duplicateNextPush, .deliverPushes, .delete(.chat(801), count: 1), .duplicateNextPush, .deliverPushes]),
            ("swapNextTwoPushes", [.receive(.user(202)), .delete(.user(202), count: 1), .swapNextTwoPushes, .deliverPushes]),
            ("failNext getDifference", [.failNext("updates.getDifference", code: 500, text: "INTERNAL_SERVER_ERROR"), .restartApp, .receive(.user(201)), .deliverPushes]),
            ("failNext getHistory", [.failNext("messages.getHistory", code: 420, text: "FLOOD_WAIT_1"), .openChat(.user(203))]),
            ("holdNextFill", [.holdNextFill(.user(201)), .delete(.user(201), count: 2), .receive(.user(201)), .deliverPushes, .releaseHeld]),
            ("holdNextConfirmation", [.openChat(.chat(801)), .goOffline, .delete(.chat(801), count: 2), .goOnline, .holdNextConfirmation(.chat(801)), .receive(.chat(801)), .deliverPushes, .releaseHeld])
        ]
        for (index, (name, steps)) in sessions.enumerated() {
            let result = self.session(seed: UInt64(100 + index), steps: steps)
            XCTAssertEqual(result.found, [], name)
        }
    }

    /// Seeds 1…25: every random session ends with the app holding what the server holds. A channel message left for
    /// the app's history validation (`validationPending`) is reported, not failed.
    func testRandomSessionsSmoke() {
        var failures: [String] = []
        for seed in UInt64(1) ... 25 {
            let session = makeTruthSession(seed: seed)
            let result = self.session(seed: seed, steps: session.steps, ptsTotalLimit: session.ptsTotalLimit)
            if result.found.contains(where: { $0.kind != .validationPending }) {
                failures.append("seed \(seed): \(result.found.prefix(3)) (replay: TRUTH_REPLAY_SEED=\(seed))")
            }
        }
        XCTAssertEqual(failures, [])
    }
    /// Seeds 1…3 with every answer and push 0…50 ms late: pushes land while requests are in flight and answers
    /// overtake each other; each session still ends with the app holding what the server holds.
    func testJitteredSessionsSmoke() {
        var failures: [String] = []
        for seed in UInt64(1) ... 3 {
            let session = makeTruthSession(seed: seed)
            let result = self.session(seed: seed, steps: session.steps, ptsTotalLimit: session.ptsTotalLimit, jitter: true)
            if !result.found.isEmpty {
                failures.append("seed \(seed): \(result.found.prefix(3))")
            }
        }
        XCTAssertEqual(failures, [])
    }

    /// The long run (`docs/superpowers/plans/2026-10-25-state-sync-truth-server/run-truth.sh`): seeds
    /// `TRUTH_SEEDS=<first>-<last>` from the test environment, skipped without it. One line per seed,
    /// `TRUTH seed=<n> steps=<k> result=ok|<discrepancies>`, then a summary; fails when a seed found anything but
    /// validation-pending channel messages. `TRUTH_SHAPE=large` runs the large world (`TruthShape.large`),
    /// `TRUTH_TIMING=jitter` delivers answers and pushes late (`TruthSessionDriver(jitter:)`).
    func testRandomSessionsLong() throws {
        let range = ProcessInfo.processInfo.environment["TRUTH_SEEDS"]?.split(separator: "-").compactMap { UInt64($0) } ?? []
        try XCTSkipIf(range.count != 2 || range[0] > range[1], "TRUTH_SEEDS=<first>-<last> is not set")
        let shape: TruthShape = ProcessInfo.processInfo.environment["TRUTH_SHAPE"] == "large" ? .large : .small
        let jitter = ProcessInfo.processInfo.environment["TRUTH_TIMING"] == "jitter"
        var counts: [String: Int] = [:]
        var failing: [UInt64] = []
        for seed in range[0] ... range[1] {
            let session = makeTruthSession(seed: seed, shape: shape)
            let result = self.session(seed: seed, steps: session.steps, ptsTotalLimit: session.ptsTotalLimit, shape: shape, jitter: jitter)
            let summary = result.found.isEmpty ? "ok" : result.found.map { $0.description }.joined(separator: "; ")
            print("TRUTH seed=\(seed) steps=\(session.steps.count) result=\(summary)")
            for found in result.found {
                counts[found.kind.rawValue, default: 0] += 1
            }
            if result.found.contains(where: { $0.kind != .validationPending }) {
                failing.append(seed)
            }
        }
        print("TRUTH summary seeds=\(range[0])-\(range[1]) failing=\(failing.count) kinds=\(counts.sorted(by: { $0.key < $1.key }))")
        XCTAssertEqual(failing, [])
    }
}
