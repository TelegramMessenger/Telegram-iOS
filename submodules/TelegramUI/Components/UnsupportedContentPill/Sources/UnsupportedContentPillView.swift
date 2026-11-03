import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AppBundle
import TelegramPresentationData
import WallpaperBackgroundNode

/// The unsupported-content pill: a rounded card carrying a badge, a title/subtitle column and a
/// trailing action button, over either a live wallpaper patch or a static fill.
///
/// The view does NOT write its own `frame` — the host positions it and passes the size it chose.
public final class UnsupportedContentPillView: UIView {
    private let backgroundColorView: UIView
    private var wallpaperBackgroundContent: WallpaperBubbleBackgroundNode?
    private weak var currentWallpaperBackgroundNode: WallpaperBackgroundNode?

    private let badgeBackgroundView: UIImageView
    private let badgeIconView: UIImageView

    private var titleNode: TextNode?
    private var subtitleNode: TextNode?
    private var buttonTitleNode: TextNode?

    private let buttonNode: HighlightTrackingButton

    private var buttonFrame: CGRect = CGRect()

    /// Invoked when the trailing button is tapped. Hosts that leave this nil still render the
    /// button; the tap simply does nothing.
    public var action: (() -> Void)?

    public override init(frame: CGRect) {
        self.backgroundColorView = UIView()
        self.backgroundColorView.clipsToBounds = true

        self.badgeBackgroundView = UIImageView()
        self.badgeBackgroundView.contentMode = .scaleAspectFit
        self.badgeBackgroundView.image = UIImage(bundleImageName: "Chat/Message/UnsupportedIconBackground")?.withRenderingMode(.alwaysTemplate)

        self.badgeIconView = UIImageView()
        self.badgeIconView.contentMode = .scaleAspectFit
        self.badgeIconView.image = UIImage(bundleImageName: "Chat/Message/UnsupportedIcon")?.withRenderingMode(.alwaysTemplate)

        self.buttonNode = HighlightTrackingButton()
        self.buttonNode.clipsToBounds = true

        super.init(frame: frame)

        self.addSubview(self.backgroundColorView)
        self.addSubview(self.badgeBackgroundView)
        self.addSubview(self.badgeIconView)
        self.addSubview(self.buttonNode)

        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.buttonNode.layer.removeAnimation(forKey: "opacity")
                self.buttonNode.alpha = 0.6
            } else {
                self.buttonNode.alpha = 1.0
                self.buttonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }

    public convenience init() {
        self.init(frame: CGRect())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func buttonPressed() {
        self.action?()
    }

    /// True when `point` (in this view's coordinate space) is inside the action button. For hosts
    /// that arbitrate taps themselves rather than letting the button receive them.
    public func actionContains(_ point: CGPoint) -> Bool {
        return self.buttonFrame.contains(point)
    }

    public func update(
        layout: UnsupportedContentPillLayout,
        colors: UnsupportedContentPillColors,
        strings: UnsupportedContentPillStrings,
        size: CGSize,
        wallpaperBackgroundNode: WallpaperBackgroundNode?,
        animation: ListViewItemUpdateAnimation
    ) {
        // Re-derive the text through the SAME measure function the host used, against our own
        // nodes so they are reused rather than rebuilt.
        let (_, apply) = measureUnsupportedContentPill(
            strings: strings,
            colors: colors,
            constrainedWidth: layout.constrainedWidth,
            titleNode: self.titleNode,
            subtitleNode: self.subtitleNode,
            buttonTitleNode: self.buttonTitleNode
        )
        let titleNode = apply.title()
        let subtitleNode = apply.subtitle()
        let buttonTitleNode = apply.buttonTitle()
        if titleNode !== self.titleNode {
            self.titleNode?.view.removeFromSuperview()
            self.titleNode = titleNode
            self.addSubview(titleNode.view)
        }
        if subtitleNode !== self.subtitleNode {
            self.subtitleNode?.view.removeFromSuperview()
            self.subtitleNode = subtitleNode
            self.addSubview(subtitleNode.view)
        }
        if buttonTitleNode !== self.buttonTitleNode {
            self.buttonTitleNode?.view.removeFromSuperview()
            self.buttonTitleNode = buttonTitleNode
            // LOAD-BEARING for the tap, not just a tidiness flag. An `ASDisplayNode`'s view is
            // interactive by default, so an interactive label would be the deepest hit-test result
            // inside the button — and Telegram's bubble-wide tap recognizer only steps aside when
            // the hit-test result IS a `UIButton`
            // (`TapLongTapOrDoubleTapGestureRecognizer.touchesBegan`). With the label winning the
            // hit test the recognizer claims the touch instead and cancels the button's tracking,
            // so `touchUpInside` never fires and the pill reads as dead.
            buttonTitleNode.isUserInteractionEnabled = false
            self.buttonNode.addSubview(buttonTitleNode.view)
        }

        let backgroundFrame = CGRect(origin: CGPoint(), size: size)
        let cornerRadius = min(size.height * 0.5, pillMaximumCornerRadius)

        // Rebuild the wallpaper child when the host's background node identity changes; a portal
        // view mirrors ITS source, so a stale one would mirror a dead wallpaper.
        if wallpaperBackgroundNode !== self.currentWallpaperBackgroundNode {
            self.wallpaperBackgroundContent?.removeFromSupernode()
            self.wallpaperBackgroundContent = nil
            self.currentWallpaperBackgroundNode = wallpaperBackgroundNode
        }
        if self.wallpaperBackgroundContent == nil, let backgroundContent = wallpaperBackgroundNode?.makeBubbleBackground(for: .free) {
            self.wallpaperBackgroundContent = backgroundContent
            self.insertSubview(backgroundContent.view, at: 0)
        }

        if let backgroundContent = self.wallpaperBackgroundContent {
            self.backgroundColorView.isHidden = true
            backgroundContent.clipsToBounds = true
            backgroundContent.cornerRadius = cornerRadius
            animation.animator.updateFrame(layer: backgroundContent.layer, frame: backgroundFrame, completion: nil)
        } else {
            self.backgroundColorView.isHidden = false
            self.backgroundColorView.backgroundColor = colors.fill
            self.backgroundColorView.layer.cornerRadius = cornerRadius
            animation.animator.updateFrame(layer: self.backgroundColorView.layer, frame: backgroundFrame, completion: nil)
        }

        // The badge reads as a recess and the button as a raised surface, so they
        // move in opposite directions from the background rather than sharing a fill.
        let badgeFrame = CGRect(
            origin: CGPoint(x: pillContentInsets.left, y: floorToScreenPixels((size.height - pillBadgeDiameter) / 2.0)),
            size: CGSize(width: pillBadgeDiameter, height: pillBadgeDiameter)
        )
        animation.animator.updateFrame(layer: self.badgeBackgroundView.layer, frame: badgeFrame, completion: nil)
        self.badgeBackgroundView.tintColor = UIColor(rgb: 0x000000)
        self.badgeBackgroundView.alpha = colors.isDark ? pillBadgeBackgroundAlpha.dark : pillBadgeBackgroundAlpha.light

        // Same frame as the background: the plane's position inside the bubble is
        // baked into the asset, so any inset here would push it off centre.
        animation.animator.updateFrame(layer: self.badgeIconView.layer, frame: badgeFrame, completion: nil)
        self.badgeIconView.tintColor = colors.primaryText

        let textColumnX = badgeFrame.maxX + pillBadgeTextSpacing
        let textColumnY = floorToScreenPixels((size.height - layout.textColumnSize.height) / 2.0)

        let titleFrame = CGRect(origin: CGPoint(x: textColumnX, y: textColumnY), size: layout.titleSize)
        animation.animator.updateFrame(layer: titleNode.layer, frame: titleFrame, completion: nil)

        let subtitleFrame = CGRect(origin: CGPoint(x: textColumnX, y: titleFrame.maxY + pillTitleSubtitleSpacing), size: layout.subtitleSize)
        animation.animator.updateFrame(layer: subtitleNode.layer, frame: subtitleFrame, completion: nil)

        let buttonFrame = layout.actionFrame(in: size)
        self.buttonFrame = buttonFrame
        animation.animator.updateFrame(layer: self.buttonNode.layer, frame: buttonFrame, completion: nil)

        self.buttonNode.layer.cornerRadius = layout.buttonSize.height * 0.5
        self.buttonNode.backgroundColor = UIColor(rgb: colors.isDark ? 0xffffff : 0x000000, alpha: 0.12)
        self.buttonNode.accessibilityLabel = strings.action

        // From the measured layout, NOT from the node's own bounds — an applied TextNode has zero
        // bounds until this assignment, so reading them here would draw an empty label.
        let buttonTitleSize = layout.buttonTitleSize
        buttonTitleNode.frame = CGRect(
            origin: CGPoint(
                x: floorToScreenPixels((layout.buttonSize.width - buttonTitleSize.width) / 2.0),
                y: floorToScreenPixels((layout.buttonSize.height - buttonTitleSize.height) / 2.0)
            ),
            size: buttonTitleSize
        )
    }
}
