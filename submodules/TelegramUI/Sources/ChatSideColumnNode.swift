import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import TelegramPresentationData
import GlassBackgroundComponent
import GlassBarButtonComponent
import NavigationBarImpl
import ChatSideColumnLayout

/// iPhone Duo: the chat's navigation buttons as a column of glass circles in the side strip below the
/// status corner (docs/iphone-duo-layout.md). Bar items with a
/// custom node (the avatar, the "more" button) are the chat's own nodes, hosted here while the column is
/// up. The bar may take such a node back when it reuses one of its button wrappers, so every update
/// re-attaches the hosted nodes, and a node is only ever detached while this column holds it.
final class ChatSideColumnNode: ASDisplayNode {
    enum Item {
        case back
        case close
        case search
        case barItem(UIBarButtonItem)

        func isSame(as other: Item) -> Bool {
            switch (self, other) {
            case (.back, .back), (.close, .close), (.search, .search):
                return true
            case let (.barItem(lhs), .barItem(rhs)):
                return lhs === rhs
            default:
                return false
            }
        }
    }

    private final class Slot {
        let item: Item
        let node = ASDisplayNode()
        var button: ComponentView<Empty>?
        var background: GlassBackgroundView?
        weak var hostedNode: ASDisplayNode?

        init(item: Item) {
            self.item = item
        }
    }

    var backPressed: (() -> Void)?
    var searchPressed: (() -> Void)?

    private var items: [Item] = []
    private var slots: [Slot] = []
    private var theme: PresentationTheme?
    private let badgeNode: NavigationBarBadgeNode
    private var badgeText: String = ""
    private var appliedContainerSize: CGSize?
    private var appliedFrames: [CGRect] = []
    private var isColumnVisible = false

    var itemCount: Int {
        return self.items.count
    }

    override init() {
        self.badgeNode = NavigationBarBadgeNode(fillColor: .red, strokeColor: .red, textColor: .white)
        super.init()
        self.badgeNode.isHidden = true
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result === self.view {
            return nil
        }
        return result
    }

    func updateBadgeText(_ text: String) {
        self.badgeText = text
        self.badgeNode.text = text
        self.badgeNode.isHidden = text.isEmpty
        self.updateBadgeLayout(transition: .immediate)
    }
    
    /// The unread badge at the back circle's top-right corner, while the column shows a back circle.
    private func updateBadgeLayout(transition: ContainedViewLayoutTransition) {
        if self.isColumnVisible, !self.badgeNode.isHidden, let backSlot = self.slots.first(where: { if case .back = $0.item { return true } else { return false } }), !backSlot.node.frame.isEmpty {
            let badgeSize = self.badgeNode.measure(CGSize(width: 200.0, height: 100.0))
            transition.updateFrame(node: self.badgeNode, frame: CGRect(origin: CGPoint(x: backSlot.node.frame.maxX - badgeSize.width + 4.0, y: backSlot.node.frame.minY - 4.0), size: badgeSize))
            self.badgeNode.alpha = 1.0
        } else {
            self.badgeNode.alpha = 0.0
        }
    }

    /// Returns whether the slots were rebuilt (new items or a new theme): they then need a layout pass.
    @discardableResult
    func update(items: [Item], badgeText: String, theme: PresentationTheme) -> Bool {
        let themeUpdated = self.theme !== theme
        self.theme = theme
        if themeUpdated {
            let navigationBar = theme.rootController.navigationBar
            self.badgeNode.updateTheme(fillColor: navigationBar.badgeBackgroundColor, strokeColor: navigationBar.badgeStrokeColor, textColor: navigationBar.badgeTextColor)
        }
        self.updateBadgeText(badgeText)

        let itemsUpdated = items.count != self.items.count || zip(items, self.items).contains(where: { !$0.isSame(as: $1) })
        if itemsUpdated || themeUpdated {
            for slot in self.slots {
                if let hostedNode = slot.hostedNode, hostedNode.supernode === slot.node {
                    hostedNode.removeFromSupernode()
                }
                slot.node.removeFromSupernode()
            }
            self.items = items
            self.slots = items.map { Slot(item: $0) }
            for slot in self.slots {
                self.addSubnode(slot.node)
            }
            if self.badgeNode.supernode != nil {
                self.badgeNode.removeFromSupernode()
            }
            self.addSubnode(self.badgeNode)
            self.appliedFrames = []
        }
        // The bar can take a hosted node back when it reuses a button wrapper: re-attach.
        for slot in self.slots {
            if case let .barItem(item) = slot.item, let customNode = item.customDisplayNode, customNode.supernode !== slot.node {
                slot.node.addSubnode(customNode)
                slot.hostedNode = customNode
            }
        }
        return itemsUpdated || themeUpdated
    }

    private func perform(_ item: UIBarButtonItem) {
        if let target = item.target as? NSObject, let action = item.action {
            let _ = target.perform(action)
        }
    }

    private func updateSlot(_ slot: Slot, size: CGSize, theme: PresentationTheme) {
        let iconColor = theme.chat.inputPanel.panelControlColor
        let image: UIImage?
        let action: () -> Void
        switch slot.item {
        case .back:
            image = glassBackArrowImage
            action = { [weak self] in self?.backPressed?() }
        case .close:
            image = glassCloseImage
            action = { [weak self] in self?.backPressed?() }
        case .search:
            image = PresentationResourcesRootController.navigationCompactSearchIcon(theme)?.withRenderingMode(.alwaysTemplate)
            action = { [weak self] in self?.searchPressed?() }
        case let .barItem(item):
            if let customNode = item.customDisplayNode {
                // The chat's own node (the avatar), on a glass circle.
                let background: GlassBackgroundView
                if let current = slot.background {
                    background = current
                } else {
                    background = GlassBackgroundView()
                    slot.background = background
                    slot.node.view.insertSubview(background, at: 0)
                    slot.node.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.hostedNodeTapped(_:))))
                }
                background.frame = CGRect(origin: CGPoint(), size: size)
                background.update(size: size, cornerRadius: size.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), transition: .immediate)
                let nodeSize = customNode.measure(size)
                customNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - nodeSize.width) * 0.5), y: floorToScreenPixels((size.height - nodeSize.height) * 0.5)), size: nodeSize)
                return
            }
            image = item.image?.withRenderingMode(.alwaysTemplate)
            action = { [weak self] in self?.perform(item) }
        }
        let button: ComponentView<Empty>
        if let current = slot.button {
            button = current
        } else {
            button = ComponentView()
            slot.button = button
        }
        let _ = button.update(
            transition: .immediate,
            component: AnyComponent(GlassBarButtonComponent(
                size: size,
                backgroundColor: nil,
                isDark: theme.overallDarkAppearance,
                state: .glass,
                component: AnyComponentWithIdentity(id: "icon", component: AnyComponent(Image(image: image, tintColor: iconColor, contentMode: .center))),
                action: { _ in action() }
            )),
            environment: {},
            containerSize: size
        )
        if let view = button.view {
            if view.superview == nil {
                slot.node.view.addSubview(view)
            }
            view.frame = CGRect(origin: CGPoint(), size: size)
        }
    }

    @objc private func hostedNodeTapped(_ recognizer: UITapGestureRecognizer) {
        guard case .ended = recognizer.state else {
            return
        }
        for slot in self.slots where slot.node.view === recognizer.view {
            if case let .barItem(item) = slot.item {
                self.perform(item)
            }
        }
    }

    func updateLayout(containerSize: CGSize, frames: [CGRect], isHidden: Bool, transition: ContainedViewLayoutTransition) {
        guard let theme = self.theme else {
            return
        }
        let isVisible = !isHidden && !frames.isEmpty && frames.count == self.slots.count
        let wasVisible = self.isColumnVisible
        let previousContainerSize = self.appliedContainerSize
        self.isColumnVisible = isVisible
        self.appliedContainerSize = containerSize

        var slotTransition = transition
        if isVisible {
            switch chatSideColumnMove(previousFrames: self.appliedFrames, previousContainerSize: previousContainerSize, frames: frames, containerSize: containerSize) {
            case .animate:
                break
            case .immediate:
                // New slots start at a zero frame: animating from it would fly them in.
                slotTransition = .immediate
            case .fade:
                // A rotation or the strip switching sides: fade instead of flying across the messages.
                slotTransition = .immediate
                if wasVisible, let previousContainerSize, case let .animated(duration, _) = transition, let snapshotView = self.view.snapshotView(afterScreenUpdates: false) {
                    var snapshotFrame = CGRect(origin: CGPoint(), size: previousContainerSize)
                    if let firstFrame = self.appliedFrames.first, firstFrame.midX > previousContainerSize.width * 0.5 {
                        snapshotFrame.origin.x = containerSize.width - previousContainerSize.width
                    }
                    snapshotView.frame = snapshotFrame
                    self.view.superview?.insertSubview(snapshotView, aboveSubview: self.view)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5, delay: duration * 0.5)
                }
            }
            for (slot, frame) in zip(self.slots, frames) {
                slotTransition.updateFrame(node: slot.node, frame: frame)
                self.updateSlot(slot, size: frame.size, theme: theme)
            }
            self.appliedFrames = frames
        }
        self.updateBadgeLayout(transition: slotTransition)
        transition.updateAlpha(node: self, alpha: isVisible ? 1.0 : 0.0)
        self.isUserInteractionEnabled = isVisible
    }
}
