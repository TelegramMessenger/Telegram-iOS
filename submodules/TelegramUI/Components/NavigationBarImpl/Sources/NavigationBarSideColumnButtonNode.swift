import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import GlassBackgroundComponent

/// iPhone Duo: the bar's back or close button as a glass circle at the top of the side strip, hosted by the
/// controller outside the bar (docs/iphone-duo-layout.md). Drawn
/// like the ItemList screens' side column: panel glass, the bar's glass arrow or X in the bar's primary colour
/// (a legacy bar's button colour is the accent, which no other strip button uses).
final class NavigationBarSideColumnButtonNode: ASDisplayNode, NavigationSideColumnButtonNode {
    var pressed: (() -> Void)?

    private let glassContainer: GlassBackgroundContainerView
    private let background: GlassContextExtractableContainer
    private let button: HighlightableButton
    private let iconView: UIImageView

    private var presentationData: NavigationBarPresentationData
    private var kind: NavigationSideColumnButtonKind?
    private var size: CGSize?

    init(presentationData: NavigationBarPresentationData) {
        self.presentationData = presentationData
        self.glassContainer = GlassBackgroundContainerView()
        self.background = GlassContextExtractableContainer()
        self.button = HighlightableButton()
        self.iconView = UIImageView()
        self.iconView.isUserInteractionEnabled = false

        super.init()

        self.view.addSubview(self.glassContainer)
        self.glassContainer.contentView.addSubview(self.background)
        self.background.contentView.addSubview(self.button)
        self.button.addSubview(self.iconView)

        self.button.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.button.alpha = 0.6
            } else {
                self.button.alpha = 1.0
                self.button.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
            }
        }
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }

    @objc private func buttonPressed() {
        self.pressed?()
    }

    func updatePresentationData(_ presentationData: NavigationBarPresentationData) {
        self.presentationData = presentationData
        if let kind = self.kind, let size = self.size {
            self.update(kind: kind, size: size, transition: .immediate)
        }
    }

    func update(kind: NavigationSideColumnButtonKind, size: CGSize, transition: ContainedViewLayoutTransition) {
        let previousKind = self.kind
        self.kind = kind
        self.size = size

        let theme = self.presentationData.theme
        let frame = CGRect(origin: CGPoint(), size: size)
        transition.updateFrame(view: self.glassContainer, frame: frame)
        self.glassContainer.update(size: size, isDark: theme.overallDarkAppearance, transition: ComponentTransition(transition))
        transition.updateFrame(view: self.background, frame: frame)
        self.background.update(size: size, cornerRadius: min(size.width, size.height) * 0.5, isDark: theme.overallDarkAppearance, tintColor: GlassBackgroundView.TintColor(kind: theme.glassStyle == .clear ? .clear : .panel), isInteractive: true, transition: ComponentTransition(transition))
        transition.updateFrame(view: self.button, frame: frame)

        if previousKind != kind || self.iconView.image == nil {
            let image: UIImage?
            switch kind {
            case .back:
                image = glassBackArrowImage
                self.button.accessibilityLabel = self.presentationData.strings.back
            case .close:
                image = glassCloseImage
                self.button.accessibilityLabel = self.presentationData.strings.close
            }
            self.iconView.image = image?.withRenderingMode(.alwaysTemplate)
        }
        self.iconView.tintColor = theme.primaryTextColor
        if let image = self.iconView.image {
            self.iconView.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) * 0.5), y: floor((size.height - image.size.height) * 0.5)), size: image.size)
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Only the circle takes touches.
        let result = super.hitTest(point, with: event)
        if result === self.view {
            return nil
        }
        return result
    }
}
