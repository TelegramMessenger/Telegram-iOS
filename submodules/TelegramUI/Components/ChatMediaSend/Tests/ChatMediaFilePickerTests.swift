import Foundation
import XCTest
import ChatMediaSend

final class ChatMediaFilePickerTests: XCTestCase {
    func testRichTextAsFileIsFile() {
        XCTAssertTrue(mediaPickerSubjectIsFile(isFilesMode: false, pollAsFile: false, richTextAsFile: true, filePickerOn: true))
        XCTAssertFalse(mediaPickerSubjectIsFile(isFilesMode: false, pollAsFile: false, richTextAsFile: true, filePickerOn: false))
        for filePickerOn in [false, true] {
            XCTAssertTrue(mediaPickerSubjectIsFile(isFilesMode: true, pollAsFile: false, richTextAsFile: false, filePickerOn: filePickerOn))
            XCTAssertTrue(mediaPickerSubjectIsFile(isFilesMode: false, pollAsFile: true, richTextAsFile: false, filePickerOn: filePickerOn))
            XCTAssertFalse(mediaPickerSubjectIsFile(isFilesMode: false, pollAsFile: false, richTextAsFile: false, filePickerOn: filePickerOn))
        }
    }

    func testFileModeNeverAsksHeicConversion() {
        for asFile in [false, true] {
            for hasHeic in [false, true] {
                XCTAssertFalse(mediaPickerAsksHeicConversion(asFile: asFile, hasHeic: hasHeic, isFilesMode: true))
                XCTAssertEqual(mediaPickerAsksHeicConversion(asFile: asFile, hasHeic: hasHeic, isFilesMode: false), asFile && hasHeic)
            }
        }
    }

    func testFilePickerSelectionLimit() {
        XCTAssertEqual(chatMediaFilePickerSelectionLimit(isSlowMode: false, isEditingMessage: false), 100)
        XCTAssertEqual(chatMediaFilePickerSelectionLimit(isSlowMode: true, isEditingMessage: false), 10)
        XCTAssertEqual(chatMediaFilePickerSelectionLimit(isSlowMode: false, isEditingMessage: true), 1)
        XCTAssertEqual(chatMediaFilePickerSelectionLimit(isSlowMode: true, isEditingMessage: true), 1)
    }

    func testFilePickerSendOptions() {
        for isScheduledMessages in [false, true] {
            for isSecretChat in [false, true] {
                for isEditingMessage in [false, true] {
                    let options = chatMediaFilePickerSendOptions(isScheduledMessages: isScheduledMessages, isSecretChat: isSecretChat, isEditingMessage: isEditingMessage)
                    XCTAssertEqual(options.hasSchedule, !isScheduledMessages && !isSecretChat && !isEditingMessage, "\(isScheduledMessages) \(isSecretChat) \(isEditingMessage)")
                    XCTAssertEqual(options.hasSilentPosting, !isEditingMessage, "\(isScheduledMessages) \(isSecretChat) \(isEditingMessage)")
                }
            }
        }
    }
}
