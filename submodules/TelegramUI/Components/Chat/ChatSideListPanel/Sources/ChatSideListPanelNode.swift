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
public final class ChatSideListPanelNode: ASDisplayNode, ASGestureRecognizerDelegate {
    public static let stripWidth: CGFloat = 75.0

    /// How far the chat header's right button moves right as the list comes out, into the strip: iPhone Duo's side inset
    /// and status corner keep it in from the edge, and the list covers them (0 elsewhere).
    public static func headerButtonShift(_ layout: ContainerViewLayout) -> CGFloat {
        return layout.safeInsets.right + layout.navigationBarTrailingButtonsInset
    }

    /// Wide enough for the chat beside it (iPad, iPhone Duo unfolded, any landscape): the list is a column at the chat's
    /// right that narrows the chat, rather than a sheet that moves the chat aside.
    public static func isDocked(_ layout: ContainerViewLayout) -> Bool {
        return layout.metrics.widthClass == .regular || layout.size.width > layout.size.height
    }

    /// Docked beside the chat, the column narrows it on iPad and on iPhone Duo unfolded in portrait. On a phone in landscape
    /// it lies over the chat instead, which keeps its width (a tap on the chat closes the column then, as on the sheet).
    public static func narrowsChat(_ layout: ContainerViewLayout) -> Bool {
        guard ChatSideListPanelNode.isDocked(layout) else {
            return false
        }
        // The window's shape, not the chat's: unfolded, the chat is the split's detail column, taller than it is wide.
        let windowSize = layout.metrics.windowSize ?? layout.size
        if layout.deviceMetrics.type != .tablet, windowSize.width > windowSize.height {
            return false
        }
        return true
    }

    /// The docked column's width: its content's, plus the screen's right inset it reaches into (landscape's sensor side).
    public static func dockedWidth(_ layout: ContainerViewLayout) -> CGFloat {
        return min(360.0, max(300.0, floor(layout.size.width * 0.3))) + layout.safeInsets.right
    }
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
    public private(set) var isDocked = false
    /// Docked over the chat rather than beside it (`narrowsChat`).
    public private(set) var coversChat = false
    /// The open chat's row, as last given to the list.
    public var highlightedLocation: ChatLocation?
    /// Set by the owner the first time it opens the list.
    public var hasBeenOpened = false
    private var validLayout: ContainerViewLayout?
    private var validListLayout: ContainerViewLayout?
    private var panStartFraction: CGFloat = 0.0
    private var panRecognizer: UIPanGestureRecognizer?

    private let closeAccessibilityLabel: String
    public var requestClose: (() -> Void)?
    /// A drag began: the owner stops the panel where it is on screen if it was sliding.
    public var dragBegan: (() -> Void)?
    /// A drag moved the panel: the owner relayouts the chat at `fraction`.
    public var dragUpdated: ((CGFloat) -> Void)?
    /// A drag ended: the owner animates to open (true) or closed (false), carrying on with the finger's velocity
    /// (points per second, positive to the right).
    public var dragEnded: ((Bool, CGFloat) -> Void)?
    public var newTopic: (() -> Void)?

    public var isOpen: Bool {
        return self.openFraction > 0.0
    }

    /// Past the open position the list follows the finger reluctantly.
    public static func rubberBandedFraction(_ fraction: CGFloat) -> CGFloat {
        if fraction > 1.0 {
            return 1.0 + (fraction - 1.0) * 0.15
        }
        return max(0.0, fraction)
    }

    /// Where a released drag settles: a flick decides by its direction, a slow release by how far out the list is.
    public static func remainsOpen(fraction: CGFloat, velocity: CGFloat) -> Bool {
        if abs(velocity) > 300.0 {
            return velocity < 0.0
        }
        return fraction > 0.5
    }

    /// `showsNewTopicButton`: the kind's button, where the user can make one (a forum's needs the right to create topics).
    public init(kind: ChatSideListKind, listController: ChatListController, presentationData: PresentationData, showsNewTopicButton: Bool) {
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

        if showsNewTopicButton {
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
        // Through the delegate: a view's own `gestureRecognizerShouldBegin` is asked of the view under the touch, and a
        // list row answers for itself without asking this one, which let the pan take a row's swipe.
        panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.isOpen {
            return nil
        }
        // Docked, the chat beside the column takes its own touches.
        if self.isDocked, !self.coversChat, !self.listContainer.frame.contains(point), !(self.newTopicButton?.frame.contains(point) ?? false) {
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
        if !self.isOpen || self.isDocked {
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
            self.dragBegan?()
            self.panStartFraction = self.openFraction
        case .changed:
            let translation = recognizer.translation(in: self.view).x
            self.dragUpdated?(ChatSideListPanelNode.rubberBandedFraction(self.panStartFraction - translation / distance))
        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: self.view).x
            let remainsOpen = recognizer.state == .ended ? ChatSideListPanelNode.remainsOpen(fraction: self.openFraction, velocity: velocity) : true
            self.dragEnded?(remainsOpen, velocity)
        default:
            break
        }
    }

    /// Stops the slide where it is: the owner lays the panel out at the fraction it is shown at right after.
    public func removeLayoutAnimations() {
        var layers: [CALayer] = [self.listContainer.layer, self.stripNode.layer, self.backgroundNode.layer]
        if let newTopicButton = self.newTopicButton {
            layers.append(newTopicButton.layer)
        }
        for layer in layers {
            layer.removeAnimation(forKey: "position")
            layer.removeAnimation(forKey: "bounds")
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
        let width = self.isDocked ? ChatSideListPanelNode.dockedWidth(layout) : layout.size.width - ChatSideListPanelNode.stripWidth
        return ContainerViewLayout(
            size: CGSize(width: width, height: layout.size.height),
            metrics: layout.metrics,
            deviceMetrics: layout.deviceMetrics,
            intrinsicInsets: intrinsicInsets,
            safeInsets: safeInsets,
            reservedCorners: layout.reservedCorners,
            division: nil,
            additionalInsets: layout.additionalInsets,
            statusBarHeight: layout.statusBarHeight,
            // The keyboard only matters to the list while it is out, for its search.
            inputHeight: self.openFraction > 0.0 ? layout.inputHeight : nil,
            inputHeightIsInteractivellyChanging: false,
            inVoiceOver: layout.inVoiceOver,
            presentedInFormSheet: false
        )
    }

    public func updateLayout(layout: ContainerViewLayout, openFraction: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        self.openFraction = openFraction
        self.isDocked = ChatSideListPanelNode.isDocked(layout)
        self.coversChat = self.isDocked && !ChatSideListPanelNode.narrowsChat(layout)

        let listLayout = self.listLayout(layout)
        // Docked, the column slides in at the right edge; otherwise the list comes out by the distance the chat moves.
        let offset = self.isDocked ? openFraction * listLayout.size.width : openFraction * (layout.size.width - ChatSideListPanelNode.stripWidth)
        let listFrame = CGRect(origin: CGPoint(x: layout.size.width - offset, y: 0.0), size: listLayout.size)
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.listContainer, frame: listFrame)
        // Beside the chat there is nothing of it to tap; over it, a tap on what shows closes the column.
        let hasStrip = !self.isDocked || self.coversChat
        self.stripNode.isHidden = !hasStrip
        transition.updateFrame(node: self.stripNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: hasStrip ? max(0.0, listFrame.minX) : 0.0, height: layout.size.height)))

        if self.validListLayout != listLayout {
            let isFirst = self.validListLayout == nil
            self.validListLayout = listLayout
            self.listController.view.frame = CGRect(origin: CGPoint(), size: listLayout.size)
            self.listController.containerLayoutUpdated(listLayout, transition: isFirst ? .immediate : transition)
        }

        if let newTopicButton = self.newTopicButton {
            // Centred on the list's content, clear of the screen's right inset.
            let contentWidth = listLayout.size.width - layout.safeInsets.right
            let buttonWidth = min(contentWidth - 16.0 * 2.0, 320.0)
            let buttonHeight = newTopicButton.updateLayout(width: buttonWidth, transition: transition)
            let bottomInset = max(layout.intrinsicInsets.bottom, layout.safeInsets.bottom) + 8.0
            let buttonFrame = CGRect(origin: CGPoint(x: listFrame.minX + floor((contentWidth - buttonWidth) / 2.0), y: layout.size.height - bottomInset - buttonHeight), size: CGSize(width: buttonWidth, height: buttonHeight))
            transition.updateFrame(node: newTopicButton, frame: buttonFrame)
        }
    }
}
