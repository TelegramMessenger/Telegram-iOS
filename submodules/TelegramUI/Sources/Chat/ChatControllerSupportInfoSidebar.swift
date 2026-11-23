import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import PeerInfoScreen
import NavigationBarNode

private let supportInfoSidebarWidth: CGFloat = 320.0
private let supportInfoSidebarMinimumChatWidth: CGFloat = 380.0
private var supportInfoSidebarStaysOpen = false

final class ChatSupportInfoSidebar {
    let controller: ViewController
    let containerNode: ASDisplayNode
    let separatorNode: ASDisplayNode
    var hasAppeared: Bool = false
    var appliedLayout: ContainerViewLayout?

    init(controller: ViewController) {
        self.controller = controller
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
    }
}

extension ChatControllerImpl {
    private var supportInfoSidebarPeer: EnginePeer? {
        guard self.context.supportContext != nil, case let .peer(peerId) = self.chatLocation, case .standard(.default) = self.presentationInterfaceState.mode, self.currentSideListKind(presentationInterfaceState: self.presentationInterfaceState) == nil, let peer = self.presentationInterfaceState.renderedPeer?.peer, peer.id == peerId else {
            return nil
        }
        return EnginePeer(peer)
    }

    private func supportInfoSidebarFits(_ layout: ContainerViewLayout) -> Bool {
        guard layout.deviceMetrics.type == .tablet, layout.metrics.widthClass == .regular else {
            return false
        }
        return layout.size.width - layout.safeInsets.left - layout.safeInsets.right >= supportInfoSidebarWidth + supportInfoSidebarMinimumChatWidth
    }

    func supportInfoSidebarFullLayout(_ layout: ContainerViewLayout) -> ContainerViewLayout {
        guard self.supportInfoSidebar != nil, let fullLayout = self.sideListFullLayout, layout.size == self.validLayout?.size else {
            return layout
        }
        return fullLayout.withUpdatedInputHeight(layout.inputHeight)
    }

    func supportInfoSidebarChatLayout(_ layout: ContainerViewLayout) -> ContainerViewLayout {
        guard self.supportInfoSidebar != nil else {
            return layout
        }
        let width = supportInfoSidebarWidth + layout.safeInsets.right
        var safeInsets = layout.safeInsets
        safeInsets.right = 0.0
        var intrinsicInsets = layout.intrinsicInsets
        intrinsicInsets.right = 0.0
        return ContainerViewLayout(
            size: CGSize(width: layout.size.width - width, height: layout.size.height),
            metrics: layout.metrics,
            deviceMetrics: layout.deviceMetrics,
            intrinsicInsets: intrinsicInsets,
            safeInsets: safeInsets,
            reservedCorners: layout.reservedCorners,
            division: layout.division,
            additionalInsets: layout.additionalInsets,
            statusBarHeight: layout.statusBarHeight,
            inputHeight: layout.inputHeight,
            inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging,
            inVoiceOver: layout.inVoiceOver,
            presentedInFormSheet: layout.presentedInFormSheet
        )
    }

    func updateSupportInfoSidebar(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        guard self.context.supportContext != nil else {
            return
        }
        let peer = self.supportInfoSidebarPeer
        let isAvailable = peer != nil && self.supportInfoSidebarFits(layout)
        if self.supportInfoSidebarIsAvailable != isAvailable {
            self.supportInfoSidebarIsAvailable = isAvailable
            (self.navigationBar as? NavigationBarNode)?.rightButtonsChangeInLayout = isAvailable
            self.updateRightNavigationButtons(presentationInterfaceState: self.presentationInterfaceState, transition: .immediate)
        }

        if isAvailable && supportInfoSidebarStaysOpen, self.supportInfoSidebar == nil, let peer, let controller = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: true, requestsContext: nil) {
            let sidebar = ChatSupportInfoSidebar(controller: controller)
            self.addChild(controller)
            sidebar.containerNode.addSubnode(sidebar.separatorNode)
            sidebar.containerNode.frame = self.supportInfoSidebarFrame(layout: layout, isOpen: !transition.isAnimated)
            self.chatDisplayNode.addSubnode(sidebar.containerNode)
            sidebar.containerNode.view.disablesInteractiveKeyboardGestureRecognizer = true
            controller.view.frame = CGRect(origin: CGPoint(), size: sidebar.containerNode.bounds.size)
            sidebar.containerNode.view.insertSubview(controller.view, at: 0)
            controller.didMove(toParent: self)
            self.supportInfoSidebar = sidebar
            (controller as? PeerInfoScreenImpl)?.avatarCollapsedUpdated = { [weak self] _ in
                self?.applySupportInfoSidebarAvatarButton(transition: .animated(duration: 0.3, curve: .spring))
            }
            self.layoutSupportInfoSidebarContent(sidebar, layout: layout, transition: .immediate)
            self.applySupportInfoSidebarAvatarButton(transition: transition)
            if self.view.window != nil {
                controller.viewWillAppear(false)
                controller.viewDidAppear(false)
                sidebar.hasAppeared = true
            }
        } else if !(isAvailable && supportInfoSidebarStaysOpen), let sidebar = self.supportInfoSidebar {
            self.supportInfoSidebar = nil
            (sidebar.controller as? PeerInfoScreenImpl)?.avatarCollapsedUpdated = nil
            self.applySupportInfoSidebarAvatarButton(transition: transition)
            transition.updateFrame(node: sidebar.containerNode, frame: self.supportInfoSidebarFrame(layout: layout, isOpen: false), completion: { [weak self] _ in
                self?.removeSupportInfoSidebar(sidebar)
            })
        }

        if let sidebar = self.supportInfoSidebar {
            transition.updateFrame(node: sidebar.containerNode, frame: self.supportInfoSidebarFrame(layout: layout, isOpen: true))
            self.layoutSupportInfoSidebarContent(sidebar, layout: layout, transition: transition)
        }
    }

    private func supportInfoSidebarFrame(layout: ContainerViewLayout, isOpen: Bool) -> CGRect {
        let width = supportInfoSidebarWidth + layout.safeInsets.right
        return CGRect(x: isOpen ? layout.size.width - width : layout.size.width, y: 0.0, width: width, height: layout.size.height)
    }

    private func layoutSupportInfoSidebarContent(_ sidebar: ChatSupportInfoSidebar, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let size = CGSize(width: supportInfoSidebarWidth + layout.safeInsets.right, height: layout.size.height)
        sidebar.containerNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        sidebar.separatorNode.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        sidebar.separatorNode.frame = CGRect(x: 0.0, y: 0.0, width: UIScreenPixel, height: size.height)
        let sidebarLayout = ContainerViewLayout(
            size: size,
            metrics: LayoutMetrics(widthClass: .compact, heightClass: layout.metrics.heightClass, orientation: layout.metrics.orientation, windowSize: layout.metrics.windowSize),
            deviceMetrics: layout.deviceMetrics,
            intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(layout.intrinsicInsets.bottom, layout.inputHeight ?? 0.0), right: 0.0),
            safeInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: layout.safeInsets.right),
            reservedCorners: layout.reservedCorners,
            division: nil,
            additionalInsets: UIEdgeInsets(),
            statusBarHeight: layout.statusBarHeight,
            inputHeight: nil,
            inputHeightIsInteractivellyChanging: false,
            inVoiceOver: layout.inVoiceOver,
            presentedInFormSheet: false
        )
        if sidebar.appliedLayout == sidebarLayout {
            return
        }
        sidebar.appliedLayout = sidebarLayout
        transition.updateFrame(view: sidebar.controller.view, frame: CGRect(origin: CGPoint(), size: size))
        sidebar.controller.containerLayoutUpdated(sidebarLayout, transition: transition)
    }

    private func removeSupportInfoSidebar(_ sidebar: ChatSupportInfoSidebar) {
        if sidebar.hasAppeared {
            sidebar.hasAppeared = false
            sidebar.controller.viewWillDisappear(false)
            sidebar.controller.viewDidDisappear(false)
        }
        sidebar.controller.willMove(toParent: nil)
        sidebar.containerNode.removeFromSupernode()
        sidebar.controller.view.removeFromSuperview()
        sidebar.controller.removeFromParent()
    }

    func forwardSupportInfoSidebarAppearance(_ appearance: SideListAppearance, animated: Bool) {
        guard let sidebar = self.supportInfoSidebar else {
            return
        }
        switch appearance {
        case .willAppear:
            if !sidebar.hasAppeared {
                sidebar.controller.viewWillAppear(animated)
            }
        case .didAppear:
            if !sidebar.hasAppeared {
                sidebar.controller.viewDidAppear(animated)
                sidebar.hasAppeared = true
            }
        case .willDisappear:
            if sidebar.hasAppeared {
                sidebar.controller.viewWillDisappear(animated)
            }
        case .didDisappear:
            if sidebar.hasAppeared {
                sidebar.controller.viewDidDisappear(animated)
                sidebar.hasAppeared = false
            }
        }
    }

    func supportInfoSidebarRecheckAvailability() {
        guard self.context.supportContext != nil, let layout = self.sideListFullLayout else {
            return
        }
        if self.supportInfoSidebarIsAvailable != (self.supportInfoSidebarPeer != nil && self.supportInfoSidebarFits(layout)) {
            DispatchQueue.main.async { [weak self] in
                guard let self, let layout = self.sideListFullLayout else {
                    return
                }
                self.containerLayoutUpdated(layout, transition: .immediate)
            }
        }
    }

    var supportInfoSidebarHidesChatAvatar: Bool {
        guard let sidebar = self.supportInfoSidebar else {
            return false
        }
        return !((sidebar.controller as? PeerInfoScreenImpl)?.isAvatarCollapsed ?? false)
    }

    private func applySupportInfoSidebarAvatarButton(transition: ContainedViewLayoutTransition) {
        let hides = self.supportInfoSidebarHidesChatAvatar
        guard self.supportInfoSidebarHidesAvatarButton != hides else {
            return
        }
        self.supportInfoSidebarHidesAvatarButton = hides
        let avatarNode = self.chatInfoNavigationButton?.buttonItem.customDisplayNode
        if hides {
            if transition.isAnimated, let avatarNode, avatarNode.view.window != nil {
                avatarNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3, removeOnCompletion: false)
            }
        } else {
            avatarNode?.layer.removeAnimation(forKey: "transform.scale")
        }
        self.updateRightNavigationButtons(presentationInterfaceState: self.presentationInterfaceState, transition: transition.isAnimated ? transition : .immediate)
        if !hides, transition.isAnimated {
            avatarNode?.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3)
        }
    }

    func supportInfoSidebarBarButton(presentationInterfaceState: ChatPresentationInterfaceState) -> UIBarButtonItem? {
        guard self.supportInfoSidebarIsAvailable else {
            return nil
        }
        if let current = self.supportInfoSidebarButton, current.theme === presentationInterfaceState.theme {
            return current.item
        }
        let item = UIBarButtonItem(image: generateTintedImage(image: UIImage(bundleImageName: "Chat/Title Panels/SideListIcon"), color: presentationInterfaceState.theme.rootController.navigationBar.primaryTextColor), style: .plain, target: self, action: #selector(self.supportInfoSidebarButtonPressed))
        item.accessibilityLabel = presentationInterfaceState.strings.Conversation_Info
        self.supportInfoSidebarButton = (item, presentationInterfaceState.theme)
        return item
    }

    @objc func supportInfoSidebarButtonPressed() {
        supportInfoSidebarStaysOpen = !supportInfoSidebarStaysOpen
        guard let layout = self.sideListFullLayout else {
            return
        }
        self.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .spring))
    }
}
