import Foundation
import LottieSettings
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import WallpaperBackgroundNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import UnsupportedContentPill

/// The "please update" bubble shown for media this build cannot render.
///
/// All of the pill's geometry, colours and assets live in `UnsupportedContentPill`, which the
/// InstantPage V2 renderer also uses for `InstantPageBlock.unsupported`. This node contributes only
/// the bubble-content wiring: sizing, tap arbitration and the insertion/removal animations.
public final class ChatMessageUnsupportedBubbleContentNode: ChatMessageBubbleContentNode {
    private let pillView: UnsupportedContentPillView

    required public init(lottieSettings: LottieRenderingSettings) {
        self.pillView = UnsupportedContentPillView()

        super.init(lottieSettings: lottieSettings)

        self.pillView.action = { [weak self] in
            guard let item = self?.item else {
                return
            }
            item.controllerInteraction.openAppStorePage()
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didLoad() {
        super.didLoad()

        self.view.addSubview(self.pillView)
    }

    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        return { [weak self] item, layoutConstants, _, _, constrainedSize, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .none)

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { [weak self] constrainedSize, position in
                let presentationData = item.presentationData
                let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)

                let strings = UnsupportedContentPillStrings(strings: presentationData.strings)
                let colors = UnsupportedContentPillColors(
                    fill: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper),
                    primaryText: serviceColor.primaryText,
                    isDark: presentationData.theme.theme.overallDarkAppearance
                )
                let pillLayout = UnsupportedContentPill.layout(strings: strings, colors: colors, constrainedWidth: constrainedSize.width)

                return (pillLayout.size.width, { [weak self] boundingWidth in
                    let backgroundSize = CGSize(width: boundingWidth, height: pillLayout.size.height)

                    return (backgroundSize, { [weak self] animation, _, _ in
                        guard let self else {
                            return
                        }
                        self.item = item

                        self.pillView.frame = CGRect(origin: CGPoint(), size: backgroundSize)
                        self.pillView.update(
                            layout: pillLayout,
                            colors: colors,
                            strings: strings,
                            size: backgroundSize,
                            wallpaperBackgroundNode: item.controllerInteraction.presentationContext.backgroundNode,
                            animation: animation
                        )
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        // Deliberately empty: bubble backgrounds here are portal views that mirror their source,
        // so the pill's wallpaper follows the page without being told where it is.
    }

    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }

    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }

    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }

    override public func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.pillView.actionContains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}
