import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import SolidRoundedButtonNode

/// The chat side list: the parent chat list over the right of the chat, with the chat's right edge left visible as a
/// strip. The owner moves the chat itself by `openFraction * (width - stripWidth)`; this node covers the whole chat and
/// lays the list out from its right edge, so both move together.
public final class ChatSideListPanelNode: ASDisplayNode {
    public static let stripWidth: CGFloat = 75.0
    /// A drag from the list's own left edge closes it too; further in, row swipes win.
    private static let listEdgeDragWidth: CGFloat = 20.0

    public let kind: ChatSideListKind
    public let listController: ChatListController

    /// The list's background, for the owner to put below the chat: the chat's rounded corners show it.
    public let backgroundNode: ASDisplayNode
    private let listContainer: ASDisplayNode
    private let stripNode: ASDisplayNode
    private var newTopicButton: SolidRoundedButtonNode?

    public private(set) var openFraction: CGFloat = 0.0
    private var validLayout: ContainerViewLayout?
    private var validListLayout: ContainerViewLayout?
    private var panStartFraction: CGFloat = 0.0
    private var panRecognizer: UIPanGestureRecognizer?

    private let closeAccessibilityLabel: String
    public var requestClose: (() -> Void)?
    /// A drag moved the panel: the owner relayouts the chat at `fraction`.
    public var dragUpdated: ((CGFloat) -> Void)?
    /// A drag ended: the owner animates to open (true) or closed (false).
    public var dragEnded: ((Bool) -> Void)?
    public var newTopic: (() -> Void)?

    public var isOpen: Bool {
        return self.openFraction > 0.0
    }

    public init(kind: ChatSideListKind, listController: ChatListController, presentationData: PresentationData) {
        self.closeAccessibilityLabel = presentationData.strings.Chat_SideList_Close
        self.kind = kind
        self.listController = listController

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = presentationData.theme.chatList.backgroundColor
        self.backgroundNode.isHidden = true

        self.listContainer = ASDisplayNode()
        self.listContainer.clipsToBounds = true

        self.stripNode = ASDisplayNode()

        super.init()

        self.addSubnode(self.listContainer)
        self.addSubnode(self.stripNode)

        if kind.showsNewTopicButton {
            let theme = presentationData.theme
            let button = SolidRoundedButtonNode(title: presentationData.strings.Chat_SideList_NewTopic, theme: SolidRoundedButtonTheme(backgroundColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor), glass: true, height: 52.0, cornerRadius: 26.0)
            button.pressed = { [weak self] in
                self?.newTopic?()
            }
            self.newTopicButton = button
            self.addSubnode(button)
        }
    }

    override public func didLoad() {
        super.didLoad()

        self.listContainer.view.addSubview(self.listController.view)

        // A layer that renders nothing gets no real touches; transparent contents make the strip tappable.
        self.stripNode.view.layer.contents = generateImage(CGSize(width: 1.0, height: 1.0), opaque: false, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
        })?.cgImage
        self.stripNode.view.isAccessibilityElement = true
        self.stripNode.view.accessibilityTraits = .button
        self.stripNode.view.accessibilityLabel = self.closeAccessibilityLabel
        self.stripNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.stripTapGesture(_:))))

        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isOpen {
            return nil
        }
        return super.hitTest(point, with: event)
    }

    @objc private func stripTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.requestClose?()
        }
    }

    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // UIKit asks this for recognizers on the subviews too (the strip's tap); only the close pan is gated here.
        guard let pan = self.panRecognizer, gestureRecognizer === pan else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        if !self.isOpen {
            return false
        }
        let velocity = pan.velocity(in: self.view)
        if velocity.x <= 0.0 || abs(velocity.x) < abs(velocity.y) {
            return false
        }
        let location = pan.location(in: self.view)
        return location.x < self.listContainer.frame.minX + ChatSideListPanelNode.listEdgeDragWidth
    }

    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        guard let layout = self.validLayout else {
            return
        }
        let distance = max(1.0, layout.size.width - ChatSideListPanelNode.stripWidth)
        switch recognizer.state {
        case .began:
            self.panStartFraction = self.openFraction
        case .changed:
            let translation = recognizer.translation(in: self.view).x
            let fraction = max(0.0, min(1.0, self.panStartFraction - translation / distance))
            self.dragUpdated?(fraction)
        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: self.view).x
            let remainsOpen = recognizer.state == .ended ? (velocity < -200.0 || (velocity < 200.0 && self.openFraction > 0.5)) : true
            self.dragEnded?(remainsOpen)
        default:
            break
        }
    }

    /// The list's own layout: the chat's minus the strip, with its own top and right insets.
    private func listLayout(_ layout: ContainerViewLayout) -> ContainerViewLayout {
        var safeInsets = layout.safeInsets
        safeInsets.left = 0.0
        var intrinsicInsets = layout.intrinsicInsets
        intrinsicInsets.left = 0.0
        if self.newTopicButton != nil {
            intrinsicInsets.bottom += 52.0 + 16.0
        }
        return ContainerViewLayout(
            size: CGSize(width: layout.size.width - ChatSideListPanelNode.stripWidth, height: layout.size.height),
            metrics: layout.metrics,
            deviceMetrics: layout.deviceMetrics,
            intrinsicInsets: intrinsicInsets,
            safeInsets: safeInsets,
            reservedCorners: layout.reservedCorners,
            division: nil,
            additionalInsets: layout.additionalInsets,
            statusBarHeight: layout.statusBarHeight,
            inputHeight: nil,
            inputHeightIsInteractivellyChanging: false,
            inVoiceOver: layout.inVoiceOver,
            presentedInFormSheet: false
        )
    }

    public func updateLayout(layout: ContainerViewLayout, openFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        self.openFraction = openFraction

        let offset = openFraction * (layout.size.width - ChatSideListPanelNode.stripWidth)
        let listLayout = self.listLayout(layout)
        let listFrame = CGRect(origin: CGPoint(x: layout.size.width - offset, y: 0.0), size: listLayout.size)
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.listContainer, frame: listFrame)
        transition.updateFrame(node: self.stripNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: max(0.0, listFrame.minX), height: layout.size.height)))

        if self.validListLayout != listLayout {
            let isFirst = self.validListLayout == nil
            self.validListLayout = listLayout
            self.listController.view.frame = CGRect(origin: CGPoint(), size: listLayout.size)
            self.listController.containerLayoutUpdated(listLayout, transition: isFirst ? .immediate : transition)
        }

        if let newTopicButton = self.newTopicButton {
            let sideInset: CGFloat = 16.0 + layout.safeInsets.right
            let buttonWidth = min(listLayout.size.width - 16.0 - sideInset, 320.0)
            let buttonHeight = newTopicButton.updateLayout(width: buttonWidth, transition: transition)
            let bottomInset = max(layout.intrinsicInsets.bottom, layout.safeInsets.bottom) + 8.0
            let buttonFrame = CGRect(origin: CGPoint(x: listFrame.minX + floor((listLayout.size.width - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
            transition.updateFrame(node: newTopicButton, frame: buttonFrame)
        }
    }
}
