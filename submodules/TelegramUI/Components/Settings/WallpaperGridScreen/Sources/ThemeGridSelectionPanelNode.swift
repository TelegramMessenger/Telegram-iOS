import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AppBundle
import ComponentFlow
import GlassBackgroundComponent
import ComponentDisplayAdapters

private final class GlassButtonView: UIView {
    private let backgroundView: GlassBackgroundView
    let button: HighlightTrackingButton
    private let iconView: GlassBackgroundView.ContentImageView

    private var params: (theme: PresentationTheme, size: CGSize)?

    var isEnabled: Bool = true {
        didSet {
            if self.isEnabled != oldValue, let params = self.params {
                self.updateImpl(theme: params.theme, size: params.size, transition: .immediate)
            }
        }
    }

    init(icon: String) {
        self.backgroundView = GlassBackgroundView()

        self.iconView = GlassBackgroundView.ContentImageView()
        self.iconView.image = UIImage(bundleImageName: icon)?.withRenderingMode(.alwaysTemplate)
        self.backgroundView.contentView.addSubview(self.iconView)

        self.button = HighlightTrackingButton()
        self.backgroundView.contentView.addSubview(self.button)

        super.init(frame: CGRect())

        self.addSubview(self.backgroundView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(theme: PresentationTheme, size: CGSize, transition: ComponentTransition) {
        if let params = self.params, params.theme === theme, params.size == size {
            return
        }
        self.params = (theme, size)
        self.iconView.tintColor = theme.chat.inputPanel.panelControlColor
        self.updateImpl(theme: theme, size: size, transition: transition)
    }

    private func updateImpl(theme: PresentationTheme, size: CGSize, transition: ComponentTransition) {
        if let image = self.iconView.image {
            let iconFrame = image.size.centered(in: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.iconView, frame: iconFrame)
        }

        transition.setFrame(view: self.button, frame: CGRect(origin: CGPoint(), size: size))

        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size))
        self.backgroundView.update(size: size, cornerRadius: min(size.width, size.height) * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: true, transition: transition)
        self.backgroundView.isUserInteractionEnabled = self.isEnabled

        self.iconView.alpha = self.isEnabled ? 1.0 : 0.5
        self.iconView.tintMask.alpha = self.iconView.alpha

        self.button.isEnabled = self.isEnabled
    }
}

final class ThemeGridSelectionPanelNode: ASDisplayNode {
    private let deleteButton: GlassButtonView
    private let shareButton: GlassButtonView

    private var validLayout: (width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, metrics: LayoutMetrics)?

    private var theme: PresentationTheme

    var selectedIds = Set<ThemeGridControllerEntry.StableId>() {
        didSet {
            if oldValue != self.selectedIds {
                self.deleteButton.isEnabled = !self.selectedIds.isEmpty
                self.shareButton.isEnabled = !self.selectedIds.isEmpty
            }
        }
    }

    var controllerInteraction: ThemeGridControllerInteraction?

    init(theme: PresentationTheme) {
        self.theme = theme

        self.deleteButton = GlassButtonView(icon: "Chat/Input/Accessory Panels/MessageSelectionTrash")
        self.deleteButton.isEnabled = false
        self.shareButton = GlassButtonView(icon: "Chat/Input/Accessory Panels/MessageSelectionForward")
        self.shareButton.isEnabled = false

        super.init()

        self.view.addSubview(self.deleteButton)
        self.view.addSubview(self.shareButton)

        self.deleteButton.button.addTarget(self, action: #selector(self.deleteButtonPressed), for: [.touchUpInside])
        self.shareButton.button.addTarget(self, action: #selector(self.shareButtonPressed), for: [.touchUpInside])
    }

    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme

            if let validLayout = self.validLayout {
                let _ = self.updateLayout(width: validLayout.width, leftInset: validLayout.leftInset, rightInset: validLayout.rightInset, maxHeight: validLayout.maxHeight, transition: .immediate, metrics: validLayout.metrics)
            }
        }
    }

    @objc func deleteButtonPressed() {
        self.controllerInteraction?.deleteSelectedWallpapers()
    }

    @objc func shareButtonPressed() {
        self.controllerInteraction?.shareSelectedWallpapers()
    }

    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, metrics: LayoutMetrics) -> CGFloat {
        self.validLayout = (width, leftInset, rightInset, maxHeight, metrics)

        let buttonSize = CGSize(width: 40.0, height: 40.0)

        let deleteButtonFrame = CGRect(origin: CGPoint(x: leftInset, y: 0.0), size: buttonSize)
        transition.updateFrame(view: self.deleteButton, frame: deleteButtonFrame)
        self.deleteButton.update(theme: self.theme, size: buttonSize, transition: ComponentTransition(transition))

        let shareButtonFrame = CGRect(origin: CGPoint(x: width - rightInset - buttonSize.width, y: 0.0), size: buttonSize)
        transition.updateFrame(view: self.shareButton, frame: shareButtonFrame)
        self.shareButton.update(theme: self.theme, size: buttonSize, transition: ComponentTransition(transition))

        return buttonSize.height
    }
}
