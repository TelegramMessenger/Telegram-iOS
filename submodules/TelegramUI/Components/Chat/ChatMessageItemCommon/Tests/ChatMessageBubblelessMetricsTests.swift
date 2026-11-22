import XCTest
import UIKit
import Display
import ChatMessageItemCommon

// The bubble-free numbers, each in one place (spec 6.5): the column, the layout constants, the lead and the vertical
// rhythm. Values from the reference patch.
final class ChatMessageBubblelessMetricsTests: XCTestCase {
    // compactInset 36, compactWidthBoundary 500, freeMaximumFillFactor 0.85.
    private let compactFill = ChatMessageItemLayoutConstants.compact.bubble.maximumWidthFill

    private func column(baseWidth: CGFloat, hasAvatarColumn: Bool, inSelection: Bool = false) -> (originX: CGFloat, width: CGFloat) {
        return chatMessageBubblelessColumn(baseWidth: baseWidth, leftInset: 0.0, hasAvatarColumn: hasAvatarColumn, inSelection: inSelection, deliveryFailedInset: 0.0, hasSideButtons: false, widthFill: self.compactFill)
    }

    func testColumnStartsPastTheAvatar() {
        XCTAssertEqual(self.column(baseWidth: 402.0, hasAvatarColumn: true).originX, 51.0)
        XCTAssertEqual(self.column(baseWidth: 402.0, hasAvatarColumn: false).originX, 16.0)
        XCTAssertEqual(chatMessageBubblelessColumn(baseWidth: 402.0, leftInset: 20.0, hasAvatarColumn: true, inSelection: false, deliveryFailedInset: 0.0, hasSideButtons: false, widthFill: self.compactFill).originX, 71.0)
    }

    func testColumnIsUncappedOnPhones() {
        XCTAssertEqual(self.column(baseWidth: 402.0, hasAvatarColumn: true).width, 335.0)
        XCTAssertEqual(self.column(baseWidth: 402.0, hasAvatarColumn: false).width, 370.0)
    }

    func testColumnIsCappedOnWideScreens() {
        XCTAssertEqual(self.column(baseWidth: 874.0, hasAvatarColumn: true).width, floor(874.0 * 0.85))
    }

    func testSelectionTakesTheCheckmarkRoom() {
        let plain = self.column(baseWidth: 402.0, hasAvatarColumn: true)
        let selecting = self.column(baseWidth: 402.0, hasAvatarColumn: true, inSelection: true)
        XCTAssertEqual(selecting.width, plain.width - 42.0)
        XCTAssertEqual(selecting.originX, plain.originX)
    }

    func testFlatMessagesLoseTheirInsets() {
        let constants = chatMessageBubblelessLayoutConstants(ChatMessageItemLayoutConstants.compact, mainRadius: 16.0, isCard: false)
        XCTAssertEqual(constants.bubble.contentInsets.left, 0.0)
        XCTAssertEqual(constants.bubble.contentInsets.right, 0.0)
        XCTAssertEqual(constants.text.bubbleInsets.left, 0.0)
        XCTAssertEqual(constants.text.bubbleInsets.right, 0.0)
        XCTAssertEqual(constants.text.bubbleInsets.bottom, 3.0 - UIScreenPixel)
        XCTAssertEqual(constants.text.bubbleInsets.top, ChatMessageItemLayoutConstants.compact.text.bubbleInsets.top)
        XCTAssertEqual(constants.image.bubbleInsets, .zero)
        XCTAssertEqual(constants.file.bubbleInsets.left, 0.0)
        XCTAssertEqual(constants.image.defaultCornerRadius, 16.0)
    }

    func testCardsKeepTheirInsets() {
        let original = ChatMessageItemLayoutConstants.compact
        let constants = chatMessageBubblelessLayoutConstants(original, mainRadius: 16.0, isCard: true)
        XCTAssertEqual(constants.bubble.contentInsets, original.bubble.contentInsets)
        XCTAssertEqual(constants.text.bubbleInsets, original.text.bubbleInsets)
        XCTAssertEqual(constants.image.bubbleInsets, original.image.bubbleInsets)
        XCTAssertEqual(constants.file.bubbleInsets, original.file.bubbleInsets)
        XCTAssertEqual(constants.image.defaultCornerRadius, original.image.defaultCornerRadius)
    }

    func testLeadCentersBetweenCapLineAndFirstBaseline() {
        let nameFont = Font.semibold(14.0)
        let textFont = Font.regular(17.0)
        let nameHeight: CGFloat = 17.0
        let capTop = nameFont.ascender - nameFont.capHeight
        let firstBaseline = nameHeight + 1.0 + UIScreenPixel + textFont.ascender
        XCTAssertEqual(chatMessageBubblelessLeadCenterY(nameFont: nameFont, firstLineFont: textFont, nameHeight: nameHeight), floorToScreenPixels((capTop + firstBaseline) * 0.5))
    }

    private func rhythm(_ style: ChatMessageBubbleStyle, incoming: Bool = true, mergedTop: Bool = false, mergedBottom: Bool = false, hasDateAbove: Bool = false, hasBubbleAbove: Bool = false, hasBubbleBelow: Bool = false, hasHeader: Bool = false, firstBlock: ChatMessageBubblelessBlockKind? = .text, lastBlock: ChatMessageBubblelessBlockKind? = .text, hasButtonsOrReactionsBelow: Bool = false) -> (top: CGFloat, bottom: CGFloat) {
        return chatMessageBubblelessRhythm(style: style, incoming: incoming, mergedTop: mergedTop, mergedBottom: mergedBottom, hasDateAbove: hasDateAbove, hasBubbleAbove: hasBubbleAbove, hasBubbleBelow: hasBubbleBelow, hasHeader: hasHeader, firstBlock: firstBlock, lastBlock: lastBlock, hasButtonsOrReactionsBelow: hasButtonsOrReactionsBelow)
    }

    func testRhythmOfARunOfFlatMessages() {
        let unmerged = self.rhythm(.bubbleless)
        XCTAssertEqual(unmerged.top, 3.0)
        XCTAssertEqual(unmerged.bottom, 1.0)
        let merged = self.rhythm(.bubbleless, mergedTop: true, mergedBottom: true)
        XCTAssertEqual(merged.top, 0.0)
        XCTAssertEqual(merged.bottom, 0.0)
    }

    func testRhythmKeepsHalfABlockGapInsideARun() {
        XCTAssertEqual(self.rhythm(.bubbleless, mergedTop: true, firstBlock: .block).top, 4.0)
        XCTAssertEqual(self.rhythm(.bubbleless, mergedTop: true, hasHeader: true, firstBlock: .block).top, 0.0)
        XCTAssertEqual(self.rhythm(.bubblelessCard, mergedBottom: true, lastBlock: .block).bottom, 4.0)
        XCTAssertEqual(self.rhythm(.bubbleless, mergedBottom: true, lastBlock: .block, hasButtonsOrReactionsBelow: true).bottom, 0.0)
        XCTAssertEqual(self.rhythm(.bubbleless, mergedTop: true, firstBlock: .text).top, 0.0)
    }

    func testRhythmOfOutgoingUnderFlatMessages() {
        XCTAssertEqual(self.rhythm(.bubble, incoming: false).top, 6.0)
        XCTAssertEqual(self.rhythm(.bubble, incoming: false, hasBubbleAbove: true).top, 0.0)
        XCTAssertEqual(self.rhythm(.bubble, incoming: false, mergedTop: true).top, 1.0)
        XCTAssertEqual(self.rhythm(.bubble, incoming: false).bottom, 3.0)
        XCTAssertEqual(self.rhythm(.bubble, incoming: false, mergedBottom: true).bottom, 1.0)
        XCTAssertEqual(self.rhythm(.bubble, incoming: false, hasBubbleBelow: true).bottom, 0.0)
    }

    func testRhythmOfServiceMessages() {
        let underDate = self.rhythm(.bubblelessService, hasDateAbove: true)
        XCTAssertEqual(underDate.top, 3.0 + 5.0)
        XCTAssertEqual(underDate.bottom, 3.0 - 1.0)
        XCTAssertEqual(self.rhythm(.bubblelessService).top, 3.0 + 9.0)
        let merged = self.rhythm(.bubblelessService, mergedTop: true, mergedBottom: true, hasBubbleAbove: true, hasBubbleBelow: true)
        XCTAssertEqual(merged.top, 1.0 + 1.0)
        XCTAssertEqual(merged.bottom, 1.0 + 1.0)
    }
}
