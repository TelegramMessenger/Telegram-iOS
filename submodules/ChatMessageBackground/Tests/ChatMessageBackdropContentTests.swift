import XCTest
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import WallpaperBackgroundNode
@testable import ChatMessageBackground

/// On a patterned or gradient wallpaper with a translucent bubble fill (every dark theme) the bubble
/// is drawn by the backdrop alone: `ChatMessageBackground` drops its image whenever the wallpaper
/// answers `hasBubbleBackground`. `ChatMessageBackground` asks on every layout pass, so the backdrop
/// has to follow the same answer on every pass too. When it only re-asked on a type change, a flip in
/// the answer after a bubble's first layout left it with no content while the next pass dropped the
/// image, and the bubble's text sat on the bare wallpaper (issue #12).
///
/// `setType` needs a `PrincipalThemeEssentialGraphics`, which this target cannot build (its init
/// force-unwraps app-bundle images), so these drive the content half it hands to `updateContent`.
final class ChatMessageBackdropContentTests: XCTestCase {
    private final class FakeBubbleBackground: ASDisplayNode, WallpaperBubbleBackgroundNode {
        var implicitContentUpdate: Bool = true

        func reloadBindings() {
        }
    }

    private final class FakeWallpaperNode: ASDisplayNode, WallpaperBackgroundNode {
        var drawsBubbles: Bool = false
        private(set) var madeBubbleBackgrounds: Int = 0

        var isReady: Signal<Bool, NoError> {
            return .single(true)
        }
        var rotation: CGFloat = 0.0
        var contentStats: WallpaperContentStats? {
            return nil
        }
        var contentStatsUpdated: (() -> Void)?

        func update(wallpaper: TelegramWallpaper, animated: Bool) {
        }

        func update(wallpaper: TelegramWallpaper, starGift: StarGift?, animated: Bool) {
        }

        func _internalUpdateIsSettingUpWallpaper() {
        }

        func updateLayout(size: CGSize, displayMode: WallpaperDisplayMode, transition: ContainedViewLayoutTransition) {
        }

        func updateIsLooping(_ isLooping: Bool) {
        }

        func animateEvent(transition: ContainedViewLayoutTransition, extendAnimation: Bool) {
        }

        func updateBubbleTheme(bubbleTheme: PresentationTheme, bubbleCorners: PresentationChatBubbleCorners) {
        }

        func hasBubbleBackground(for type: WallpaperBubbleType) -> Bool {
            return self.drawsBubbles
        }

        func makeBubbleBackground(for type: WallpaperBubbleType) -> WallpaperBubbleBackgroundNode? {
            if !self.hasBubbleBackground(for: type) {
                return nil
            }
            self.madeBubbleBackgrounds += 1
            return FakeBubbleBackground()
        }

        func makeFreeBackground() -> PortalView? {
            return nil
        }

        func hasExtraBubbleBackground() -> Bool {
            return false
        }

        func makeDimmedNode() -> ASDisplayNode? {
            return nil
        }

        func makeEdgeEffectNode() -> WallpaperEdgeEffectNode? {
            return nil
        }
    }

    private let type: ChatMessageBackgroundType = .incoming(.None)

    func testTheBackdropStartsDrawingWhenTheWallpaperStartsDrawingBubbles() {
        let wallpaperNode = FakeWallpaperNode()
        let backdrop = ChatMessageBubbleBackdrop()

        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: true)
        XCTAssertFalse(backdrop.hasImage)

        // A later pass of the same bubble, nothing about it changed: only the wallpaper's answer did.
        wallpaperNode.drawsBubbles = true
        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: false)
        XCTAssertTrue(backdrop.hasImage)
    }

    func testTheBackdropStopsDrawingWhenTheWallpaperStopsDrawingBubbles() {
        let wallpaperNode = FakeWallpaperNode()
        wallpaperNode.drawsBubbles = true
        let backdrop = ChatMessageBubbleBackdrop()

        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: true)
        XCTAssertTrue(backdrop.hasImage)

        wallpaperNode.drawsBubbles = false
        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: false)
        XCTAssertFalse(backdrop.hasImage)
    }

    /// A new wallpaper node or theme rebuilds even when the answer is the same: the old portal
    /// mirrors the old source.
    func testATypeUpdateRebuildsTheContent() {
        let wallpaperNode = FakeWallpaperNode()
        wallpaperNode.drawsBubbles = true
        let backdrop = ChatMessageBubbleBackdrop()

        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: true)
        let content = backdrop.backgroundContent
        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: true)

        XCTAssertTrue(backdrop.hasImage)
        XCTAssertFalse(backdrop.backgroundContent === content)
        XCTAssertEqual(wallpaperNode.madeBubbleBackgrounds, 2)
    }

    func testABubbleWithoutABackgroundHasNoContent() {
        let wallpaperNode = FakeWallpaperNode()
        wallpaperNode.drawsBubbles = true
        let backdrop = ChatMessageBubbleBackdrop()

        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: true)
        XCTAssertTrue(backdrop.hasImage)

        backdrop.updateContent(type: .none, backgroundNode: wallpaperNode, typeUpdated: true)
        XCTAssertFalse(backdrop.hasImage)
    }

    /// A pass that changes nothing must not rebuild the content: each rebuild adds a portal to the
    /// wallpaper's source view.
    func testAnUnchangedAnswerKeepsTheContent() {
        let wallpaperNode = FakeWallpaperNode()
        wallpaperNode.drawsBubbles = true
        let backdrop = ChatMessageBubbleBackdrop()

        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: true)
        let content = backdrop.backgroundContent
        backdrop.updateContent(type: self.type, backgroundNode: wallpaperNode, typeUpdated: false)

        XCTAssertTrue(backdrop.backgroundContent === content)
        XCTAssertEqual(wallpaperNode.madeBubbleBackgrounds, 1)
    }
}
