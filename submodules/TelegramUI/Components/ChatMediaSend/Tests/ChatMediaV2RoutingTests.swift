import Foundation
import XCTest
import AccountContext
import ChatMediaSend

final class ChatMediaV2RoutingTests: XCTestCase {
    func testFlagOffRoutesEveryEntryToLegacy() {
        XCTAssertTrue(ChatMediaV2Entry.allCases.allSatisfy { !chatMediaV2Routing(flagOn: false, entry: $0) })
    }

    func testSignupAvatarNeverRoutes() {
        XCTAssertFalse(chatMediaV2Routing(flagOn: false, entry: .signupAvatar))
        XCTAssertFalse(chatMediaV2Routing(flagOn: true, entry: .signupAvatar))
    }

    func testStage5RoutingTable() {
        let expected: [ChatMediaV2Entry: Bool] = [
            .attachMenuCamera: true,
            .inlineCameraCell: true,
            .placeholderCamera: true,
            .storyReplyCamera: true,
            .shortcutCamera: true,
            .pickerGallery: true,
            .messageMediaEditor: true,
            .animatedFileEditor: true,
            .wallpaperEditor: true,
            .wallpaperPhotoPicker: true,
            .qrPhotoPicker: true,
            .filePicker: true,
            .suggestedAvatar: true,
            .videoChatAvatar: true,
            .passport: true,
            .signupAvatar: false
        ]
        XCTAssertEqual(Set(expected.keys), Set(ChatMediaV2Entry.allCases))
        for entry in ChatMediaV2Entry.allCases {
            XCTAssertEqual(chatMediaV2Routing(flagOn: true, entry: entry), expected[entry], "\(entry)")
        }
    }

    func testKillswitchOverridesLegacyOverride() {
        XCTAssertTrue(chatMediaEditorV2Enabled(legacyOverride: false, killswitchPresent: false))
        XCTAssertFalse(chatMediaEditorV2Enabled(legacyOverride: true, killswitchPresent: false))
        XCTAssertFalse(chatMediaEditorV2Enabled(legacyOverride: false, killswitchPresent: true))
        XCTAssertFalse(chatMediaEditorV2Enabled(legacyOverride: true, killswitchPresent: true))
    }

    func testCameraEntriesMapToTable() {
        let mapping: [ChatCameraEntry: ChatMediaV2Entry] = [
            .attachMenu: .attachMenuCamera,
            .inlineCell: .inlineCameraCell,
            .placeholder: .placeholderCamera,
            .storyReply: .storyReplyCamera,
            .shortcut: .shortcutCamera
        ]
        XCTAssertEqual(Set(mapping.keys), Set(ChatCameraEntry.allCases))
        for entry in ChatCameraEntry.allCases {
            XCTAssertEqual(entry.chatMediaV2Entry, mapping[entry], "\(entry)")
        }
    }
}
