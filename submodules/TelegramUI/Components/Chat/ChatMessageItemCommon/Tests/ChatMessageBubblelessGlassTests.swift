import XCTest
import UIKit
import ChatMessageItemCommon

// What stands on the page in glass without bubbles (spec 5.5, 5.7).
final class ChatMessageBubblelessGlassTests: XCTestCase {
    // Reactions on the page are glass capsules: incoming ones and freeform ones (under a sticker or media) in both
    // directions; reactions inside your own bubble keep the bubble's plates, and with bubbles nothing changes.
    func testReactionPillsOnThePageAreGlass() {
        XCTAssertTrue(chatMessageBubblelessReactionsAreGlass(bubbleMode: false, isInsideOutgoingBubble: false))
        XCTAssertFalse(chatMessageBubblelessReactionsAreGlass(bubbleMode: false, isInsideOutgoingBubble: true))
        XCTAssertFalse(chatMessageBubblelessReactionsAreGlass(bubbleMode: true, isInsideOutgoingBubble: false))
        XCTAssertFalse(chatMessageBubblelessReactionsAreGlass(bubbleMode: true, isInsideOutgoingBubble: true))
    }

    // A date in the history is gray text on the page; parked at the top it stands on a glass island in the primary
    // text colour; when scrolling stops the parked date goes, island and all, and takes no taps (spec 5.7).
    func testTheParkedDateStandsOnGlass() {
        XCTAssertEqual(chatMessageBubblelessDateState(stickDistanceFactor: 0.0, isFlashing: false), ChatMessageBubblelessDateState(showsIsland: false, showsHistoryLabel: true, showsParkedLabel: false, takesTaps: true))
        XCTAssertEqual(chatMessageBubblelessDateState(stickDistanceFactor: 1.0, isFlashing: true), ChatMessageBubblelessDateState(showsIsland: true, showsHistoryLabel: false, showsParkedLabel: true, takesTaps: true))
        XCTAssertEqual(chatMessageBubblelessDateState(stickDistanceFactor: 1.0, isFlashing: false), ChatMessageBubblelessDateState(showsIsland: false, showsHistoryLabel: false, showsParkedLabel: false, takesTaps: false))
        XCTAssertTrue(chatMessageBubblelessDateIsParked(stickDistanceFactor: 0.5))
        XCTAssertFalse(chatMessageBubblelessDateIsParked(stickDistanceFactor: 0.49))
    }

    // Inline buttons are glass capsules 6pt apart (bubbles: 2pt); a button's type icon sits in the middle of its right
    // end, and the title keeps clear of it on both sides (spec 5.5).
    func testInlineButtonsAreGlassCapsules() {
        XCTAssertEqual(chatMessageActionButtonSpacing(bubbleMode: true), 2.0)
        XCTAssertEqual(chatMessageActionButtonSpacing(bubbleMode: false), 6.0)
        XCTAssertEqual(chatMessageBubblelessGlassCapsuleHeight, 42.0)
        XCTAssertEqual(chatMessageBubblelessGlassTypeIconFrame(buttonWidth: 200.0), CGRect(x: 173.0, y: 15.0, width: 12.0, height: 12.0))
        XCTAssertEqual(chatMessageBubblelessGlassTitleSideInset(iconWidth: 12.0), 31.0)
    }

    // The comments row is a glass capsule: commenters' avatars concentric with its left end (or the icon), the count
    // text after them, the chevron at the right end; the text takes what is left, the unread dot included (spec 5.5).
    func testTheCommentsRowIsAGlassCapsule() {
        let threeAvatars = chatMessageBubblelessCommentsCapsuleLayout(avatarCount: 3, iconWidth: 16.0, arrowWidth: 7.0, unreadWidth: 8.0, constrainedWidth: 300.0)
        XCTAssertEqual(threeAvatars, ChatMessageBubblelessCommentsCapsuleLayout(leading: 86.0, trailing: 33.0, textMaxWidth: 300.0 - 86.0 - 33.0 - 8.0))
        XCTAssertEqual(chatMessageBubblelessCommentsCapsuleLayout(avatarCount: 1, iconWidth: 16.0, arrowWidth: 7.0, unreadWidth: 0.0, constrainedWidth: 300.0).leading, 46.0)
        XCTAssertEqual(chatMessageBubblelessCommentsCapsuleLayout(avatarCount: 0, iconWidth: 16.0, arrowWidth: 7.0, unreadWidth: 0.0, constrainedWidth: 300.0).leading, 36.0)
        XCTAssertEqual(chatMessageBubblelessCommentsCapsuleLayout(avatarCount: 0, iconWidth: 16.0, arrowWidth: 7.0, unreadWidth: 0.0, constrainedWidth: 40.0).textMaxWidth, 1.0)
    }

    // With bubbles the share button's top button stays the 30×30 circle, so a channel post's reply count under the comment
    // icon does not open the comments; a glass capsule without a second button opens the message from all of it.
    func testTheShareButtonKeepsItsTopButtonWithBubbles() {
        let capsule = CGSize(width: 30.0, height: 42.0)
        XCTAssertEqual(chatMessageShareButtonTopButtonHeight(size: capsule, hasBottomButton: false, isGlass: false), 30.0)
        XCTAssertEqual(chatMessageShareButtonTopButtonHeight(size: capsule, hasBottomButton: true, isGlass: false), 30.0)
        XCTAssertEqual(chatMessageShareButtonTopButtonHeight(size: capsule, hasBottomButton: false, isGlass: true), 42.0)
        XCTAssertEqual(chatMessageShareButtonTopButtonHeight(size: CGSize(width: 30.0, height: 60.0), hasBottomButton: true, isGlass: true), 30.0)
    }

    // Without bubbles the text column makes room for the buttons beside it: a summarize button too, not only the share
    // button and an ad's buttons (which stay even with the side panel open).
    func testSideButtonsMakeRoomForTheSummarizeButton() {
        XCTAssertTrue(chatMessageBubblelessHasSideButtons(needsShareButton: false, needsSummarizeButton: true, isAd: false, isSidePanelOpen: false))
        XCTAssertTrue(chatMessageBubblelessHasSideButtons(needsShareButton: true, needsSummarizeButton: false, isAd: false, isSidePanelOpen: false))
        XCTAssertTrue(chatMessageBubblelessHasSideButtons(needsShareButton: false, needsSummarizeButton: false, isAd: true, isSidePanelOpen: true))
        XCTAssertFalse(chatMessageBubblelessHasSideButtons(needsShareButton: false, needsSummarizeButton: false, isAd: false, isSidePanelOpen: false))
        XCTAssertFalse(chatMessageBubblelessHasSideButtons(needsShareButton: false, needsSummarizeButton: true, isAd: false, isSidePanelOpen: true))
    }

    // A loading chat without bubbles shows gray bars on the text column: the avatar at x 8 when the rows have avatars,
    // the column past it (or at the margin) 16pt from the right safe inset, a name bar and two or more lines (spec 5.7).
    func testTheSkeletonIsBarsOnTheColumn() {
        let rect = CGRect(x: 0.0, y: 100.0, width: 180.0, height: 93.0)
        let withAvatar = chatLoadingBubblelessSkeletonColumn(rect: rect, containerWidth: 393.0, rightInset: 0.0, showsAvatar: true)
        XCTAssertEqual(withAvatar.avatar, CGRect(x: 8.0, y: 101.0, width: 34.0, height: 34.0))
        XCTAssertEqual(withAvatar.column, CGRect(x: 51.0, y: 100.0, width: 326.0, height: 93.0))
        let withoutAvatar = chatLoadingBubblelessSkeletonColumn(rect: rect, containerWidth: 393.0, rightInset: 0.0, showsAvatar: false)
        XCTAssertNil(withoutAvatar.avatar)
        XCTAssertEqual(withoutAvatar.column.minX, 16.0)
        XCTAssertEqual(chatLoadingBubblelessSkeletonColumn(rect: rect, containerWidth: 393.0, rightInset: 20.0, showsAvatar: true).column.width, 306.0)

        let bars = chatLoadingBubblelessSkeletonBars(columnSize: CGSize(width: 326.0, height: 93.0), bubbleWidth: 180.0)
        XCTAssertEqual(bars, [
            // floor(180 × 0.35): 0.35 is not exact in binary, so 62, as the prototype draws it.
            CGRect(x: 0.0, y: 4.0, width: 62.0, height: 10.0),
            CGRect(x: 0.0, y: 24.0, width: 243.0, height: 11.0),
            CGRect(x: 0.0, y: 46.0, width: 133.0, height: 11.0)
        ])
        XCTAssertEqual(chatLoadingBubblelessSkeletonBars(columnSize: CGSize(width: 326.0, height: 167.0), bubbleWidth: 180.0).count, 1 + 6)
    }

    // On a styled (tinted) capsule the type icon takes the title's colour, as the title does: the theme's icons are drawn
    // in the plain text colour, which a primary capsule on the night theme (a white accent) would hide.
    func testStyledCapsulesTintTheirTypeIconLikeTheTitle() {
        let title = UIColor(white: 0.1, alpha: 1.0)
        let custom = UIColor.red
        XCTAssertEqual(chatMessageBubblelessGlassIconTint(isStyled: true, iconTint: nil, titleColor: title), title)
        XCTAssertEqual(chatMessageBubblelessGlassIconTint(isStyled: true, iconTint: custom, titleColor: title), title)
        XCTAssertNil(chatMessageBubblelessGlassIconTint(isStyled: false, iconTint: nil, titleColor: title))
        XCTAssertEqual(chatMessageBubblelessGlassIconTint(isStyled: false, iconTint: custom, titleColor: title), custom)
    }
}
