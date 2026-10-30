import Foundation
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
    // Without bubbles the banner stands in a strip torn across the whole chat, which the item draws over this node's
    // `unsupportedContentAreas()`; the node keeps the room the torn edges take above and below the banner.
    private var isTornStrip = false

    required public init() {
        self.pillView = UnsupportedContentPillView()

        super.init()

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
            // Without bubbles the strip stands under its author's name, as media do.
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: item.bubbleStyle.isBubbleless ? 4.0 : 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .none)

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { [weak self] constrainedSize, position in
                let presentationData = item.presentationData
                let serviceColor = serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)

                let strings = UnsupportedContentPillStrings(strings: presentationData.strings)
                // Without bubbles the banner stands on the page, outlined by the torn strip, its Telegram badge in blue
                // glass and its button in light glass; it spans the text column, its button on the column's trailing
                // edge.
                let isTornStrip = item.bubbleStyle.isBubbleless
                let colors: UnsupportedContentPillColors
                if isTornStrip {
                    let messageTheme = presentationData.theme.theme.chat.message.incoming
                    let isDark = presentationData.theme.theme.overallDarkAppearance
                    let systemBlue = UIColor.systemBlue.resolvedColor(with: UITraitCollection(userInterfaceStyle: isDark ? .dark : .light))
                    colors = UnsupportedContentPillColors(
                        fill: .clear,
                        primaryText: messageTheme.primaryTextColor,
                        isDark: isDark,
                        style: .outlined(secondaryText: messageTheme.secondaryTextColor, accent: systemBlue, accentForeground: .white)
                    )
                } else {
                    colors = UnsupportedContentPillColors(
                        fill: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper),
                        primaryText: serviceColor.primaryText,
                        isDark: presentationData.theme.theme.overallDarkAppearance
                    )
                }
                let pillLayout = UnsupportedContentPill.layout(strings: strings, colors: colors, constrainedWidth: constrainedSize.width)

                // Each torn edge takes a band as deep as the tear, and the banner keeps the same room from either band.
                let tornVerticalInset: CGFloat = isTornStrip ? (chatMessageBubblelessUnsupportedTearDepth + 10.0) : 0.0

                return (isTornStrip ? max(pillLayout.size.width, constrainedSize.width) : pillLayout.size.width, { [weak self] boundingWidth in
                    let pillSize = CGSize(width: boundingWidth, height: pillLayout.size.height)
                    let backgroundSize = CGSize(width: boundingWidth, height: pillSize.height + tornVerticalInset * 2.0)

                    return (backgroundSize, { [weak self] animation, _, _ in
                        guard let self else {
                            return
                        }
                        self.item = item
                        self.isTornStrip = isTornStrip

                        self.pillView.frame = CGRect(origin: CGPoint(x: 0.0, y: tornVerticalInset), size: pillSize)
                        self.pillView.update(
                            layout: pillLayout,
                            colors: colors,
                            strings: strings,
                            size: pillSize,
                            wallpaperBackgroundNode: isTornStrip ? nil : item.controllerInteraction.presentationContext.backgroundNode,
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

    override public func bubblelessLiftParts() -> [ChatMessageBubblelessLiftPart] {
        return [.block(self.pillView.frame)]
    }
    
    override public func unsupportedContentAreas() -> [CGRect] {
        if self.isTornStrip {
            return [self.bounds]
        }
        return []
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.pillView.actionContains(point.offsetBy(dx: -self.pillView.frame.minX, dy: -self.pillView.frame.minY)) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }
}
