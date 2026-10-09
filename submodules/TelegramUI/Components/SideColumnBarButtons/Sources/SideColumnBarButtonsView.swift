import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import AppBundle
import ActivityIndicator
import GlassBackgroundComponent
import NavigationBarImpl
import SideColumnLayout

/// A button in a side column.
public enum SideColumnBarButtonsItem {
    /// The bar's back arrow.
    case back(action: () -> Void)
    /// The close X.
    case close(action: () -> Void)
    /// An icon, tinted like the glass bar's buttons.
    case icon(image: UIImage?, accessibilityLabel: String?, isEnabled: Bool, action: () -> Void)
    /// The screen's own node, hosted in the cell while the column shows it; it keeps its own touches.
    case node(ASDisplayNode, isEnabled: Bool, action: () -> Void)
    /// The accent checkmark; a spinner replaces it while `isActivity`.
    case confirm(isEnabled: Bool, isActivity: Bool, action: () -> Void)
}

/// iPhone Duo: a screen's navigation buttons in the side strip
/// (docs/iphone-duo-layout.md): back or close in a glass circle at the top,
/// icon buttons in one glass capsule below it, and the accent checkmark in its own circle below that. Its
/// owner sets its frame to the column's region; it lays the shapes out in its own bounds from a
/// `SideColumnItemsLayout` and takes touches only on them.
public final class SideColumnBarButtonsView: UIView {
    private final class Cell {
        let button: HighlightableButton
        let iconView: UIImageView
        var activityIndicator: ActivityIndicator?
        var activityColor: UIColor?
        weak var hostedNode: ASDisplayNode?
        var action: (() -> Void)?

        init() {
            self.button = HighlightableButton()
            self.iconView = UIImageView()
            self.iconView.isUserInteractionEnabled = false
            self.button.addSubview(self.iconView)
        }

        /// Lets go of a hosted node, unless the bar already took it back.
        func releaseHostedNode() {
            if let hostedNode = self.hostedNode, hostedNode.view.superview === self.button {
                hostedNode.view.removeFromSuperview()
            }
            self.hostedNode = nil
        }
    }

    private let glassContainer: GlassBackgroundContainerView
    private let topBackground: GlassContextExtractableContainer
    private let capsuleBackground: GlassContextExtractableContainer
    private let confirmBackground: GlassContextExtractableContainer
    private let topCell: Cell
    private let confirmCell: Cell
    private var capsuleCells: [Cell] = []

    override public init(frame: CGRect) {
        self.glassContainer = GlassBackgroundContainerView()
        self.topBackground = GlassContextExtractableContainer()
        self.capsuleBackground = GlassContextExtractableContainer()
        self.confirmBackground = GlassContextExtractableContainer()
        self.topCell = Cell()
        self.confirmCell = Cell()

        super.init(frame: frame)

        self.addSubview(self.glassContainer)
        self.glassContainer.contentView.addSubview(self.topBackground)
        self.glassContainer.contentView.addSubview(self.capsuleBackground)
        self.glassContainer.contentView.addSubview(self.confirmBackground)
        self.topBackground.contentView.addSubview(self.topCell.button)
        self.confirmBackground.contentView.addSubview(self.confirmCell.button)
        self.setUp(self.topCell)
        self.setUp(self.confirmCell)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp(_ cell: Cell) {
        cell.button.highligthedChanged = { [weak cell] highlighted in
            guard let cell else {
                return
            }
            if highlighted {
                cell.button.alpha = 0.6
            } else {
                cell.button.alpha = 1.0
                cell.button.layer.animateAlpha(from: 0.6, to: 1.0, duration: 0.2)
            }
        }
        cell.button.addTarget(self, action: #selector(self.buttonPressed(_:)), for: .touchUpInside)
    }

    @objc private func buttonPressed(_ button: UIButton) {
        for cell in [self.topCell, self.confirmCell] + self.capsuleCells where cell.button === button {
            cell.action?()
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // The region runs down the strip; only the shapes take touches.
        let result = super.hitTest(point, with: event)
        if result === self {
            return nil
        }
        return result
    }

    public func update(size: CGSize, top: SideColumnBarButtonsItem?, capsule: [SideColumnBarButtonsItem], confirm: SideColumnBarButtonsItem?, layout: SideColumnItemsLayout, theme: PresentationTheme, strings: PresentationStrings, transition: ContainedViewLayoutTransition) {
        let isDark = theme.overallDarkAppearance
        self.glassContainer.frame = CGRect(origin: CGPoint(), size: size)
        self.glassContainer.update(size: size, isDark: isDark, transition: .immediate)

        let topFrame = top == nil ? nil : layout.backFrame
        self.updateShape(self.topBackground, frame: topFrame, tintColor: GlassBackgroundView.TintColor(kind: .panel), isDark: isDark, transition: transition)
        if let top, let topFrame {
            self.configure(self.topCell, item: top, frame: CGRect(origin: CGPoint(), size: topFrame.size), theme: theme, strings: strings)
        } else {
            self.topCell.releaseHostedNode()
        }

        while self.capsuleCells.count < capsule.count {
            let cell = Cell()
            self.setUp(cell)
            self.capsuleBackground.contentView.addSubview(cell.button)
            self.capsuleCells.append(cell)
        }
        while self.capsuleCells.count > capsule.count {
            let cell = self.capsuleCells.removeLast()
            cell.releaseHostedNode()
            cell.button.removeFromSuperview()
        }
        self.updateShape(self.capsuleBackground, frame: capsule.isEmpty ? nil : layout.capsuleFrame, tintColor: GlassBackgroundView.TintColor(kind: .panel), isDark: isDark, transition: transition)
        for (index, item) in capsule.enumerated() where index < layout.cellFrames.count {
            self.configure(self.capsuleCells[index], item: item, frame: layout.cellFrames[index], theme: theme, strings: strings)
        }

        let confirmFrame = confirm == nil ? nil : layout.trailingFrame
        var confirmTint = GlassBackgroundView.TintColor(kind: .panel)
        if case let .confirm(isEnabled, _, _)? = confirm {
            confirmTint = GlassBackgroundView.TintColor(kind: .custom(style: .default, color: isEnabled ? theme.list.itemCheckColors.fillColor : theme.chat.inputPanel.panelControlDisabledColor))
        }
        self.updateShape(self.confirmBackground, frame: confirmFrame, tintColor: confirmTint, isDark: isDark, transition: transition)
        if let confirm, let confirmFrame {
            self.configure(self.confirmCell, item: confirm, frame: CGRect(origin: CGPoint(), size: confirmFrame.size), theme: theme, strings: strings)
        } else {
            self.confirmCell.releaseHostedNode()
        }
    }

    /// A shape laid out for the first time takes its frame without animation, so it never grows from zero.
    private func updateShape(_ shape: GlassContextExtractableContainer, frame: CGRect?, tintColor: GlassBackgroundView.TintColor, isDark: Bool, transition: ContainedViewLayoutTransition) {
        guard let frame else {
            shape.isHidden = true
            shape.frame = CGRect()
            return
        }
        let shapeTransition: ContainedViewLayoutTransition = shape.bounds.isEmpty ? .immediate : transition
        shape.isHidden = false
        shapeTransition.updateFrame(view: shape, frame: frame)
        shape.update(size: frame.size, cornerRadius: min(frame.width, frame.height) * 0.5, isDark: isDark, tintColor: tintColor, isInteractive: true, transition: ComponentTransition(shapeTransition))
    }

    private func configure(_ cell: Cell, item: SideColumnBarButtonsItem, frame: CGRect, theme: PresentationTheme, strings: PresentationStrings) {
        cell.button.frame = frame
        let size = frame.size
        var image: UIImage?
        var color = theme.chat.inputPanel.panelControlColor
        var accessibilityLabel: String?
        var isEnabled = true
        var isActivity = false
        var node: ASDisplayNode?
        switch item {
        case let .back(action):
            image = glassBackArrowImage
            accessibilityLabel = strings.Common_Back
            cell.action = action
        case let .close(action):
            image = glassCloseImage
            accessibilityLabel = strings.Common_Close
            cell.action = action
        case let .icon(iconImage, label, enabled, action):
            image = iconImage
            accessibilityLabel = label
            isEnabled = enabled
            cell.action = action
        case let .node(hostedNode, enabled, action):
            node = hostedNode
            isEnabled = enabled
            cell.action = action
        case let .confirm(enabled, activity, action):
            image = UIImage(bundleImageName: "Navigation/Done")
            color = theme.list.itemCheckColors.foregroundColor
            accessibilityLabel = strings.Common_Done
            isEnabled = enabled
            isActivity = activity
            cell.action = action
        }
        cell.button.isEnabled = isEnabled && !isActivity
        cell.button.isAccessibilityElement = node == nil
        cell.button.accessibilityLabel = accessibilityLabel
        cell.button.accessibilityTraits = isEnabled ? [.button] : [.button, .notEnabled]

        cell.iconView.image = image?.withRenderingMode(.alwaysTemplate)
        cell.iconView.tintColor = color
        cell.iconView.alpha = isEnabled ? 1.0 : 0.5
        cell.iconView.isHidden = image == nil || isActivity
        if let image {
            cell.iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) * 0.5), y: floorToScreenPixels((size.height - image.size.height) * 0.5)), size: image.size)
        }

        // A hosted node is re-attached on every update: the bar may take it back when it reuses a button
        // wrapper. It keeps its own touches; the button takes the rest of the cell.
        if let node {
            if cell.hostedNode !== node {
                cell.releaseHostedNode()
            }
            if node.view.superview !== cell.button {
                cell.button.addSubnode(node)
            }
            cell.hostedNode = node
            let nodeSize = node.measure(size)
            node.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - nodeSize.width) * 0.5), y: floorToScreenPixels((size.height - nodeSize.height) * 0.5)), size: nodeSize)
        } else {
            cell.releaseHostedNode()
        }

        if isActivity {
            let indicator: ActivityIndicator
            if let current = cell.activityIndicator {
                indicator = current
            } else {
                indicator = ActivityIndicator(type: .custom(color, 22.0, 1.0, false))
                cell.activityIndicator = indicator
                cell.activityColor = color
                cell.button.addSubnode(indicator)
            }
            if cell.activityColor != color {
                cell.activityColor = color
                indicator.type = .custom(color, 22.0, 1.0, false)
            }
            indicator.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - 22.0) * 0.5), y: floorToScreenPixels((size.height - 22.0) * 0.5)), size: CGSize(width: 22.0, height: 22.0))
        } else if let indicator = cell.activityIndicator {
            cell.activityIndicator = nil
            cell.activityColor = nil
            indicator.removeFromSupernode()
        }
    }
}
