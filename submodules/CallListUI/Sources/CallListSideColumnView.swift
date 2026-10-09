import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import AppBundle
import GlassBackgroundComponent
import SideColumnLayout

/// iPhone Duo: the Calls tab's new-call button in the side strip, one glass circle at the top of the
/// strip's region (the shared side column rules). Its owner sets its frame to the region; it lays out
/// in its own bounds and takes touches only on the circle.
final class CallListSideColumnView: UIView {
    private let glassContainer: GlassBackgroundContainerView
    private let circle: GlassContextExtractableContainer
    private let button: HighlightableButton
    private let iconView: UIImageView
    private var iconTheme: PresentationTheme?

    var pressed: (() -> Void)?

    override init(frame: CGRect) {
        self.glassContainer = GlassBackgroundContainerView()
        self.circle = GlassContextExtractableContainer()
        self.button = HighlightableButton()
        self.iconView = UIImageView()
        self.iconView.isUserInteractionEnabled = false

        super.init(frame: frame)

        self.addSubview(self.glassContainer)
        self.glassContainer.contentView.addSubview(self.circle)
        self.circle.contentView.addSubview(self.button)
        self.button.addSubview(self.iconView)

        self.button.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.iconView.alpha = 0.6
            } else {
                self.iconView.alpha = 1.0
                self.iconView.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
            }
        }
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func buttonPressed() {
        self.pressed?()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // The region runs down the strip; only the circle takes touches.
        let result = super.hitTest(point, with: event)
        if result === self {
            return nil
        }
        return result
    }

    func update(size: CGSize, theme: PresentationTheme, strings: PresentationStrings, transition: ContainedViewLayoutTransition) {
        guard let layout = sideColumnItemsLayout(regionLength: size.height, hasBack: false, priorities: [nil]), let circleFrame = layout.capsuleFrame else {
            return
        }
        // A circle laid out for the first time takes its frame without animation, so it never grows from zero.
        let glassTransition: ContainedViewLayoutTransition = self.circle.bounds.isEmpty ? .immediate : transition
        let isDark = theme.overallDarkAppearance

        glassTransition.updateFrame(view: self.glassContainer, frame: CGRect(origin: CGPoint(), size: size))
        self.glassContainer.update(size: size, isDark: isDark, transition: ComponentTransition(glassTransition))
        glassTransition.updateFrame(view: self.circle, frame: circleFrame)
        self.circle.update(size: circleFrame.size, cornerRadius: circleFrame.width * 0.5, isDark: isDark, tintColor: .init(kind: .panel), isInteractive: true, transition: ComponentTransition(glassTransition))
        glassTransition.updateFrame(view: self.button, frame: CGRect(origin: CGPoint(), size: circleFrame.size))

        if self.iconTheme !== theme {
            self.iconTheme = theme
            // Primary, like the glass bar's other buttons.
            self.iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Call List/CallIcon"), color: theme.chat.inputPanel.panelControlColor)
        }
        if let image = self.iconView.image {
            self.iconView.frame = CGRect(origin: CGPoint(x: floor((circleFrame.width - image.size.width) / 2.0), y: floor((circleFrame.height - image.size.height) / 2.0)), size: image.size)
        }
        self.button.accessibilityLabel = strings.CallList_NewCall
        self.button.accessibilityTraits = [.button]
    }
}
