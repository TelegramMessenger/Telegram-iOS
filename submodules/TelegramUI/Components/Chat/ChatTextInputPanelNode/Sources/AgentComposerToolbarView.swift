import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import GlassBackgroundComponent

/// The agent composer's bottom row, inside the input container: the attachment button and the model and effort chips.
/// The emoji button and the mic/send button share the row but stay the panel's own nodes, placed at its right end.
final class AgentComposerToolbarView: UIView {
    /// A chip is its menu's morph source. UIKit's morph goes astray when its source takes a touch while it runs (a tap
    /// on the chip as its menu closes sends the menu up and the chip back down from there), so the chip takes none:
    /// its button is a sibling laid over it by the toolbar.
    final class Chip: UIView {
        let button: HighlightTrackingButton
        private let contentView: UIView
        private let backgroundView: UIView
        private let iconView: UIImageView
        private let titleView: ImmediateTextView

        var action: ((Chip) -> Void)?

        override init(frame: CGRect) {
            self.button = HighlightTrackingButton()
            self.contentView = UIView()
            self.contentView.isUserInteractionEnabled = false
            self.backgroundView = UIView()
            self.backgroundView.isUserInteractionEnabled = false
            self.iconView = UIImageView()
            self.iconView.isUserInteractionEnabled = false
            self.titleView = ImmediateTextView()
            self.titleView.isUserInteractionEnabled = false
            self.titleView.maximumNumberOfLines = 1

            super.init(frame: frame)

            self.contentView.addSubview(self.backgroundView)
            self.contentView.addSubview(self.iconView)
            self.contentView.addSubview(self.titleView)
            self.addSubview(self.contentView)
            self.isUserInteractionEnabled = false

            self.button.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.contentView.alpha = 0.6
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                    transition.updateAlpha(layer: self.contentView.layer, alpha: 1.0)
                }
            }
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)

            // The chip's menu grows out of the chip (iOS 26 liquid morph). The chip is not glass, so the morph takes
            // its outline from the layer's corner radius, which draws nothing as the layer does not clip.
            self.morphsIntoContextMenu = true
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            self.action?(self)
        }

        func update(title: String, icon: UIImage?, theme: PresentationTheme, height: CGFloat) -> CGSize {
            let sideInset: CGFloat = 12.5
            let iconSideInset: CGFloat = 15.5
            let iconSpacing: CGFloat = 8.0

            self.titleView.attributedText = NSAttributedString(string: title, font: Font.semibold(15.0), textColor: theme.chat.inputPanel.primaryTextColor)
            let titleSize = self.titleView.updateLayout(CGSize(width: 200.0, height: height))

            self.iconView.image = icon
            self.iconView.tintColor = theme.chat.inputPanel.primaryTextColor
            let iconSize = icon?.size ?? CGSize()

            var width = sideInset * 2.0 + titleSize.width
            if icon != nil {
                width += iconSideInset - sideInset + iconSize.width + iconSpacing
            }
            let size = CGSize(width: width, height: height)

            var x = icon != nil ? iconSideInset : sideInset
            if icon != nil {
                self.iconView.frame = CGRect(origin: CGPoint(x: x, y: floorToScreenPixels((height - iconSize.height) * 0.5)), size: iconSize)
                x += iconSize.width + iconSpacing
            }
            self.titleView.frame = CGRect(origin: CGPoint(x: x, y: floorToScreenPixels((height - titleSize.height) * 0.5)), size: titleSize)

            self.backgroundView.backgroundColor = theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.06)
            self.backgroundView.layer.cornerRadius = height * 0.5
            self.layer.cornerRadius = height * 0.5
            self.contentView.frame = CGRect(origin: CGPoint(), size: size)
            self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)

            return size
        }
    }

    /// The attachment menu grows out of the glass the attachment button sits on and hides it meanwhile. This glass draws
    /// nothing (the button is plain, inside the composer's glass), but gives the menu the button's own glass to take,
    /// rather than the whole composer.
    let attachmentGlassView: GlassBackgroundView
    let attachmentButton: HighlightTrackingButton
    private let attachmentIconView: UIImageView
    let modelChip: Chip
    let effortChip: Chip

    override init(frame: CGRect) {
        self.attachmentGlassView = GlassBackgroundView()
        self.attachmentButton = HighlightTrackingButton()
        self.attachmentIconView = UIImageView()
        self.attachmentIconView.isUserInteractionEnabled = false
        self.modelChip = Chip()
        self.effortChip = Chip()

        super.init(frame: frame)

        self.attachmentGlassView.contentView.addSubview(self.attachmentIconView)
        self.attachmentGlassView.contentView.addSubview(self.attachmentButton)
        self.addSubview(self.attachmentGlassView)
        self.addSubview(self.modelChip)
        self.addSubview(self.effortChip)
        self.addSubview(self.modelChip.button)
        self.addSubview(self.effortChip.button)

        self.attachmentButton.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.attachmentIconView.alpha = 0.6
            } else {
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
                transition.updateAlpha(layer: self.attachmentIconView.layer, alpha: 1.0)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(size: CGSize, theme: PresentationTheme, glassTintColor: GlassBackgroundView.TintColor, modelTitle: String, effortTitle: String, isAttachmentEnabled: Bool, transition: ContainedViewLayoutTransition) {
        let chipHeight: CGFloat = 34.0

        // Measured from the design: the attachment icon is centred 25pt from the container's left edge, the first chip
        // starts at 45.3pt and the chips are 6pt apart.
        let attachmentFrame = CGRect(origin: CGPoint(x: 5.0, y: floorToScreenPixels((size.height - 40.0) * 0.5)), size: CGSize(width: 40.0, height: 40.0))
        transition.updateFrame(view: self.attachmentGlassView, frame: attachmentFrame)
        self.attachmentGlassView.update(size: attachmentFrame.size, cornerRadius: attachmentFrame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: glassTintColor, isVisible: false, transition: ComponentTransition(transition))
        let attachmentBounds = CGRect(origin: CGPoint(), size: attachmentFrame.size)
        transition.updateFrame(view: self.attachmentButton, frame: attachmentBounds)
        self.attachmentButton.isEnabled = isAttachmentEnabled
        if self.attachmentIconView.image == nil {
            self.attachmentIconView.image = UIImage(bundleImageName: "Chat/Input/Text/IconAttachment")?.withRenderingMode(.alwaysTemplate)
        }
        self.attachmentIconView.tintColor = theme.chat.inputPanel.panelControlColor
        if let image = self.attachmentIconView.image {
            transition.updateFrame(view: self.attachmentIconView, frame: image.size.centered(in: attachmentBounds))
        }
        self.attachmentIconView.alpha = isAttachmentEnabled ? 1.0 : 0.4

        var x: CGFloat = 45.3
        let chipY = floorToScreenPixels((size.height - chipHeight) * 0.5)

        let modelSize = self.modelChip.update(title: modelTitle, icon: nil, theme: theme, height: chipHeight)
        let modelFrame = CGRect(origin: CGPoint(x: x, y: chipY), size: modelSize)
        transition.updateFrame(view: self.modelChip, frame: modelFrame)
        transition.updateFrame(view: self.modelChip.button, frame: modelFrame)
        x += modelSize.width + 6.0

        let effortSize = self.effortChip.update(title: effortTitle, icon: nil, theme: theme, height: chipHeight)
        let effortFrame = CGRect(origin: CGPoint(x: x, y: chipY), size: effortSize)
        transition.updateFrame(view: self.effortChip, frame: effortFrame)
        transition.updateFrame(view: self.effortChip.button, frame: effortFrame)
    }
}
