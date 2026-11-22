import Foundation
import XCTest
import AccountContext
import ChatMediaSend

final class ChatCameraRoutingTests: XCTestCase {
    func testCameraRoutingPolicy() {
        let table: [(flagOn: Bool, entry: ChatCameraEntry, expected: Bool)] = [
            (false, .attachMenu, false),
            (false, .inlineCell, false),
            (false, .placeholder, false),
            (false, .storyReply, false),
            (false, .shortcut, false),
            (true, .attachMenu, true),
            (true, .inlineCell, true),
            (true, .placeholder, true),
            (true, .storyReply, true),
            (true, .shortcut, true)
        ]
        XCTAssertEqual(table.count, 2 * ChatCameraEntry.allCases.count)
        for row in table {
            XCTAssertEqual(chatMediaV2Routing(flagOn: row.flagOn, entry: row.entry.chatMediaV2Entry), row.expected, "\(row)")
        }
    }

    func testBansAndActiveCallGating() {
        let table: [(photoBanned: Bool, videoBanned: Bool, call: Bool, expected: ChatCameraModes?)] = [
            (false, false, false, ChatCameraModes(allowPhoto: true, allowVideo: true, hasAudio: true)),
            (false, false, true, ChatCameraModes(allowPhoto: true, allowVideo: false, hasAudio: false)),
            (true, false, false, ChatCameraModes(allowPhoto: false, allowVideo: true, hasAudio: true)),
            (true, false, true, nil),
            (false, true, false, ChatCameraModes(allowPhoto: true, allowVideo: false, hasAudio: true)),
            (false, true, true, ChatCameraModes(allowPhoto: true, allowVideo: false, hasAudio: false)),
            (true, true, false, nil),
            (true, true, true, nil)
        ]
        for row in table {
            XCTAssertEqual(chatCameraModes(isPhotoBanned: row.photoBanned, isVideoBanned: row.videoBanned, hasActiveCall: row.call), row.expected, "\(row)")
        }
    }

    func testEditMessageIsSingleShot() {
        let editing = chatCameraSessionOptions(entry: .attachMenu, isEditingMessage: true)
        XCTAssertEqual(editing, ChatCameraSessionOptions(isSingleShot: true, mediaGrouping: false))

        for entry in [ChatCameraEntry.attachMenu, .inlineCell, .placeholder] {
            XCTAssertEqual(chatCameraSessionOptions(entry: entry, isEditingMessage: true), editing, "\(entry)")
            XCTAssertEqual(chatCameraSessionOptions(entry: entry, isEditingMessage: false), ChatCameraSessionOptions(isSingleShot: false, mediaGrouping: true), "\(entry)")
        }
        XCTAssertEqual(chatCameraSessionOptions(entry: .storyReply, isEditingMessage: false), ChatCameraSessionOptions(isSingleShot: false, mediaGrouping: true))
        XCTAssertEqual(chatCameraSessionOptions(entry: .shortcut, isEditingMessage: false), ChatCameraSessionOptions(isSingleShot: false, mediaGrouping: true))

        XCTAssertFalse(chatCameraReviewHasCameraButton(isEditingMessage: true, isSingleShot: true))
        XCTAssertFalse(chatCameraReviewHasCameraButton(isEditingMessage: true, isSingleShot: false))
        XCTAssertFalse(chatCameraReviewHasCameraButton(isEditingMessage: false, isSingleShot: true))
        XCTAssertTrue(chatCameraReviewHasCameraButton(isEditingMessage: false, isSingleShot: false))

        let hasScheduleTable: [(scheduled: Bool, secret: Bool, paid: Bool, editing: Bool, expected: Bool)] = [
            (false, false, false, false, true),
            (true, false, false, false, false),
            (false, true, false, false, false),
            (false, false, true, false, false),
            (false, false, false, true, false)
        ]
        for row in hasScheduleTable {
            XCTAssertEqual(chatCameraHasSchedule(isScheduledMessages: row.scheduled, isSecretChat: row.secret, hasPaidMessageStars: row.paid, isEditingMessage: row.editing), row.expected, "\(row)")
        }
    }
}
