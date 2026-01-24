import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import SwiftSignalKit
import ContextUI
import TelegramCore
import AvatarNode
import AsyncDisplayKit
import ComponentFlow
import ComponentDisplayAdapters
import EmojiStatusComponent

extension PeerInfoScreenNode {
    func accountContextMenuItems(context: AccountContext, logout: @escaping () -> Void) -> Signal<[ContextMenuItem], NoError> {
        let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
        return context.engine.messages.unreadChatListPeerIds(groupId: .root, filterPredicate: nil)
        |> map { unreadChatListPeerIds -> [ContextMenuItem] in
            var items: [ContextMenuItem] = []
            
            if !unreadChatListPeerIds.isEmpty {
                items.append(.action(ContextMenuActionItem(text: strings.ChatList_Context_MarkAllAsRead, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/MarkAsRead"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                    let _ = (context.engine.messages.markAllChatsAsReadInteractively(items: [(groupId: .root, filterPredicate: nil)])
                    |> deliverOnMainQueue).startStandalone(completed: {
                        f(.default)
                    })
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: strings.Settings_Context_Logout, textColor: .destructive, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Logout"), color: theme.contextMenu.destructiveColor) }, action: { _, f in
                logout()
                f(.default)
            })))
            
            return items
        }
    }
    
    func accountContextMenu(id: AccountRecordId, node: ASDisplayNode, gesture: ContextGesture?) {
        var selectedAccount: Account?
        let _ = (self.accountsAndPeers.get()
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { accountsAndPeers in
            for (account, _, _) in accountsAndPeers {
                if account.account.id == id {
                    selectedAccount = account.account
                    break
                }
            }
        })
        if let selectedAccount = selectedAccount {
            let accountContext = self.context.sharedContext.makeTempAccountContext(account: selectedAccount)
            let chatListController = accountContext.sharedContext.makeChatListController(context: accountContext, location: .chatList(groupId: EngineChatList.Group(.root)), controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: true, enableDebugActions: false)
                    
            let contextController = ContextController(presentationData: self.presentationData, source: .controller(ContextControllerContentSourceImpl(controller: chatListController, sourceNode: node)), items: accountContextMenuItems(context: accountContext, logout: { [weak self] in
                self?.logoutAccount(id: id)
            }) |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
            self.controller?.presentInGlobalOverlay(contextController)
        } else {
            gesture?.cancel()
        }
    }

    func switchToAccount(id: AccountRecordId) {
        self.accountsAndPeers.set(.never())
        self.context.sharedContext.switchToAccount(id: id, fromSettingsController: nil, withChatListController: nil)
    }
    
    func logoutAccount(id: AccountRecordId) {
        let controller = ActionSheetController(presentationData: self.presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        
        var items: [ActionSheetItem] = []
        items.append(ActionSheetTextItem(title: self.presentationData.strings.Settings_LogoutConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines)))
        items.append(ActionSheetButtonItem(title: self.presentationData.strings.Settings_Logout, color: .destructive, action: { [weak self] in
            dismissAction()
            if let strongSelf = self {
                let _ = logoutFromAccount(id: id, accountManager: strongSelf.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).startStandalone()
            }
        }))
        controller.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        self.controller?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
}

final class AccountPeerContextItem: ContextMenuCustomItem {
    let context: AccountContext
    let account: Account
    let peer: EnginePeer
    let action: (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void
    
    init(context: AccountContext, account: Account, peer: EnginePeer, action: @escaping (ContextControllerProtocol, @escaping (ContextMenuActionResult) -> Void) -> Void) {
        self.context = context
        self.account = account
        self.peer = peer
        self.action = action
    }
    
    public func node(presentationData: PresentationData, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) -> ContextMenuCustomNode {
        return AccountPeerContextItemNode(presentationData: presentationData, item: self, getController: getController, actionSelected: actionSelected)
    }
}

private final class AccountPeerContextItemNode: ASDisplayNode, ContextMenuCustomNode {
    private let item: AccountPeerContextItem
    private let presentationData: PresentationData
    private let getController: () -> ContextControllerProtocol?
    private let actionSelected: (ContextMenuActionResult) -> Void
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    private let textNode: ImmediateTextNode
    private let avatarNode: AvatarNode
    private let emojiStatusView: ComponentView<Empty>
    
    init(presentationData: PresentationData, item: AccountPeerContextItem, getController: @escaping () -> ContextControllerProtocol?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.item = item
        self.presentationData = presentationData
        self.getController = getController
        self.actionSelected = actionSelected
        
        let textFont = Font.regular(presentationData.listsFontSize.baseDisplaySize * 17.0 / 17.0)
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isAccessibilityElement = false
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.isAccessibilityElement = false
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        let peerTitle = item.peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
        self.textNode.attributedText = NSAttributedString(string: peerTitle, font: textFont, textColor: presentationData.theme.contextMenu.primaryColor)
        self.textNode.maximumNumberOfLines = 1
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 14.0))
        
        self.emojiStatusView = ComponentView<Empty>()
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.isAccessibilityElement = true
        self.buttonNode.accessibilityLabel = peerTitle
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highligted in
            guard let strongSelf = self else {
                return
            }
            if highligted {
                strongSelf.highlightedBackgroundNode.alpha = 1.0
            } else {
                strongSelf.highlightedBackgroundNode.alpha = 0.0
                strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }

    func updateLayout(constrainedWidth: CGFloat, constrainedHeight: CGFloat) -> (CGSize, (CGSize, ContainedViewLayoutTransition) -> Void) {
        let sideInset: CGFloat = 16.0
        let iconSideInset: CGFloat = 12.0
        let verticalInset: CGFloat = 12.0
        
        let iconSize = CGSize(width: 28.0, height: 28.0)
        
        let standardIconWidth: CGFloat = 32.0
        var rightTextInset: CGFloat = sideInset
        if !iconSize.width.isZero {
            rightTextInset = max(iconSize.width, standardIconWidth) + iconSideInset + sideInset - 12.0
        }
        
        self.avatarNode.setPeer(context: self.item.context, account: self.item.account, theme: self.presentationData.theme, peer: self.item.peer)
        
        if self.item.peer.emojiStatus != nil {
            rightTextInset += 32.0
        }
    
        let textSize = self.textNode.updateLayout(CGSize(width: constrainedWidth - sideInset - rightTextInset, height: .greatestFiniteMagnitude))
        
        return (CGSize(width: textSize.width + sideInset + rightTextInset, height: verticalInset * 2.0 + textSize.height), { size, transition in
            let verticalOrigin = floor((size.height - textSize.height) / 2.0)
            let textFrame = CGRect(origin: CGPoint(x: sideInset, y: verticalOrigin), size: textSize)
            transition.updateFrameAdditive(node: self.textNode, frame: textFrame)
            
            var iconContent: EmojiStatusComponent.Content?
            if case let .user(user) = self.item.peer {
                if let emojiStatus = user.emojiStatus {
                    iconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 28.0, height: 28.0), placeholderColor: self.presentationData.theme.list.mediaPlaceholderColor, themeColor: self.presentationData.theme.list.itemAccentColor, loopMode: .forever)
                } else if user.isPremium {
                    iconContent = .premium(color: self.presentationData.theme.list.itemAccentColor)
                }
            } else if case let .channel(channel) = self.item.peer {
                if let emojiStatus = channel.emojiStatus {
                    iconContent = .animation(content: .customEmoji(fileId: emojiStatus.fileId), size: CGSize(width: 28.0, height: 28.0), placeholderColor: self.presentationData.theme.list.mediaPlaceholderColor, themeColor: self.presentationData.theme.list.itemAccentColor, loopMode: .forever)
                }
            }
            if let iconContent {
                let emojiStatusSize = self.emojiStatusView.update(
                    transition: .immediate,
                    component: AnyComponent(EmojiStatusComponent(
                        context: self.item.context,
                        animationCache: self.item.context.animationCache,
                        animationRenderer: self.item.context.animationRenderer,
                        content: iconContent,
                        isVisibleForAnimations: true,
                        action: nil
                    )),
                    environment: {},
                    containerSize: CGSize(width: 24.0, height: 24.0)
                )
                if let view = self.emojiStatusView.view {
                    if view.superview == nil {
                        self.view.addSubview(view)
                    }
                    transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: textFrame.maxX + 2.0, y: textFrame.minY + floor((textFrame.height - emojiStatusSize.height) / 2.0)), size: emojiStatusSize))
                }
            }
            
            transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize))
            
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
            transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height)))
        })
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.highlightedBackgroundNode.backgroundColor = presentationData.theme.contextMenu.itemHighlightedBackgroundColor
        
        if let attributedText = self.textNode.attributedText {
            let updatedAttributedText = NSMutableAttributedString(attributedString: attributedText)
            updatedAttributedText.addAttribute(.foregroundColor, value: presentationData.theme.contextMenu.primaryColor.cgColor, range: NSRange(location: 0, length: updatedAttributedText.length))
            self.textNode.attributedText = updatedAttributedText
        }
    }
    
    @objc private func buttonPressed() {
        self.performAction()
    }
    
    func canBeHighlighted() -> Bool {
        return true
    }
    
    func setIsHighlighted(_ value: Bool) {
        if value {
            self.highlightedBackgroundNode.alpha = 1.0
        } else {
            self.highlightedBackgroundNode.alpha = 0.0
        }
    }
    
    func updateIsHighlighted(isHighlighted: Bool) {
        self.setIsHighlighted(isHighlighted)
    }
    
    func performAction() {
        guard let controller = self.getController() else {
            return
        }
        self.item.action(controller, { [weak self] result in
            self?.actionSelected(result)
        })
    }
}

final class PeerInfoControllerContextReferenceContentSource: ContextReferenceContentSource {
    let controller: ViewController
    let sourceView: UIView
    let insets: UIEdgeInsets
    let contentInsets: UIEdgeInsets
    
    init(controller: ViewController, sourceView: UIView, insets: UIEdgeInsets, contentInsets: UIEdgeInsets = UIEdgeInsets()) {
        self.controller = controller
        self.sourceView = sourceView
        self.insets = insets
        self.contentInsets = contentInsets
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds.inset(by: self.insets), insets: self.contentInsets)
    }
}

final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private func cancelContextGestures(view: UIView) {
    if let gestureRecognizers = view.gestureRecognizers {
        for gesture in gestureRecognizers {
            if let gesture = gesture as? ContextGesture {
                gesture.cancel()
            }
        }
    }
    for subview in view.subviews {
        cancelContextGestures(view: subview)
    }
}
