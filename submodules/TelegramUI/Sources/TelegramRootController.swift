import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContactListUI
import CallListUI
import ChatListUI
import SettingsUI
import AppBundle

public final class TelegramRootController: NavigationController {
    private let context: AccountContext
    
    public var rootTabController: TabBarController?
    
    public var contactsController: ContactsController?
    public var callListController: CallListController?
    public var chatListController: ChatListController?
    public var accountSettingsController: PeerInfoScreen?
    
    private var permissionsDisposable: Disposable?
    private var presentationDataDisposable: Disposable?
    private var presentationData: PresentationData
        
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let navigationDetailsBackgroundMode: NavigationEmptyDetailsBackgoundMode?
        switch presentationData.chatWallpaper {
        case .color:
            let image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/EmptyMasterDetailIcon"), color: presentationData.theme.chatList.messageTextColor.withAlphaComponent(0.2))
            navigationDetailsBackgroundMode = image != nil ? .image(image!) : nil
        default:
            let image = chatControllerBackgroundImage(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, mediaBox: context.account.postbox.mediaBox, knockoutMode: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper)
            navigationDetailsBackgroundMode = image != nil ? .wallpaper(image!) : nil
        }
        
        super.init(mode: .automaticMasterDetail, theme: NavigationControllerTheme(presentationTheme: self.presentationData.theme), backgroundDetailsMode: navigationDetailsBackgroundMode)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                if presentationData.chatWallpaper != strongSelf.presentationData.chatWallpaper {
                    let navigationDetailsBackgroundMode: NavigationEmptyDetailsBackgoundMode?
                    switch presentationData.chatWallpaper {
                        case .color:
                            let image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/EmptyMasterDetailIcon"), color: presentationData.theme.chatList.messageTextColor.withAlphaComponent(0.2))
                            navigationDetailsBackgroundMode = image != nil ? .image(image!) : nil
                        default:
                            navigationDetailsBackgroundMode = chatControllerBackgroundImage(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, mediaBox: strongSelf.context.sharedContext.accountManager.mediaBox, knockoutMode: strongSelf.context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper).flatMap(NavigationEmptyDetailsBackgoundMode.wallpaper)
                    }
                    strongSelf.updateBackgroundDetailsMode(navigationDetailsBackgroundMode, transition: .immediate)
                }

                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData
                if previousTheme !== presentationData.theme {
                    strongSelf.rootTabController?.updateTheme(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData), theme: TabBarControllerTheme(rootControllerTheme: presentationData.theme))
                    strongSelf.rootTabController?.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.permissionsDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    public func addRootControllers(showCallsTab: Bool) {
        let tabBarController = TabBarController(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), theme: TabBarControllerTheme(rootControllerTheme: self.presentationData.theme))
        tabBarController.navigationPresentation = .master
        let chatListController = self.context.sharedContext.makeChatListController(context: self.context, groupId: .root, controlsHistoryPreload: true, hideNetworkActivityStatus: false, previewing: false, enableDebugActions: !GlobalExperimentalSettings.isAppStoreBuild)
        if let sharedContext = self.context.sharedContext as? SharedAccountContextImpl {
            chatListController.tabBarItem.badgeValue = sharedContext.switchingData.chatListBadge
        }
        let callListController = CallListController(context: self.context, mode: .tab)
        
        var controllers: [ViewController] = []
        
        let contactsController = ContactsController(context: self.context)
        contactsController.switchToChatsController = {  [weak self] in
            self?.openChatsController(activateSearch: false)
        }
        controllers.append(contactsController)
        
        if showCallsTab {
            controllers.append(callListController)
        }
        controllers.append(chatListController)
        
        var restoreSettignsController: (ViewController & SettingsController)?
        if let sharedContext = self.context.sharedContext as? SharedAccountContextImpl {
            restoreSettignsController = sharedContext.switchingData.settingsController
        }
        restoreSettignsController?.updateContext(context: self.context)
        if let sharedContext = self.context.sharedContext as? SharedAccountContextImpl {
            sharedContext.switchingData = (nil, nil, nil)
        }
        
        let accountSettingsController = PeerInfoScreen(context: self.context, peerId: self.context.account.peerId, avatarInitiallyExpanded: false, isOpenedFromChat: false, nearbyPeerDistance: nil, callMessages: [], isSettings: true)
        accountSettingsController.tabBarItemDebugTapAction = { [weak self, weak accountSettingsController] in
            guard let strongSelf = self, let accountSettingsController = accountSettingsController else {
                return
            }
            accountSettingsController.push(debugController(sharedContext: strongSelf.context.sharedContext, context: strongSelf.context))
        }
        controllers.append(accountSettingsController)
        
        tabBarController.setControllers(controllers, selectedIndex: restoreSettignsController != nil ? (controllers.count - 1) : (controllers.count - 2))
        
        self.contactsController = contactsController
        self.callListController = callListController
        self.chatListController = chatListController
        self.accountSettingsController = accountSettingsController
        self.rootTabController = tabBarController
        self.pushViewController(tabBarController, animated: false)
        
//        Queue.mainQueue().after(2.0) {
//            let messageId = MessageId(peerId: PeerId(namespace: 2, id: 1488156064), namespace: 0, id: 528)
//            let _ = ((self.context.account.postbox.transaction { transaction in
//                return transaction.getMessage(messageId)
//            }) |> deliverOnMainQueue).start(next: { [weak self] message in
//                guard let strongSelf = self, let message = message else {
//                    return
//                }
//
//                let layout = ContainerViewLayout(size: CGSize(width: 414.0, height: 896.0), metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact), deviceMetrics: .iPhoneX, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: 0.0, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false)
//                let renderer = MessageStoryRenderer(context: strongSelf.context, message: message)
//                let image = renderer.update(layout: layout)
//
//                let node = renderer.containerNode
//                node.frame = CGRect(origin: CGPoint(), size: layout.size)
//                strongSelf.displayNode.addSubnode(node)
//            })
//        }
    }
        
    public func updateRootControllers(showCallsTab: Bool) {
        guard let rootTabController = self.rootTabController else {
            return
        }
        var controllers: [ViewController] = []
        controllers.append(self.contactsController!)
        if showCallsTab {
            controllers.append(self.callListController!)
        }
        controllers.append(self.chatListController!)
        controllers.append(self.accountSettingsController!)
        
        rootTabController.setControllers(controllers, selectedIndex: nil)
    }
    
    public func openChatsController(activateSearch: Bool) {
        guard let rootTabController = self.rootTabController else {
            return
        }
        
        if activateSearch {
            self.popToRoot(animated: false)
        }
        
        if let index = rootTabController.controllers.firstIndex(where: { $0 is ChatListController}) {
            rootTabController.selectedIndex = index
        }
        
        if activateSearch {
            self.chatListController?.activateSearch()
        }
    }
    
    public func openRootCompose() {
        self.chatListController?.activateCompose()
    }
    
    public func openRootCamera() {
        guard let controller = self.viewControllers.last as? ViewController else {
            return
        }
        controller.view.endEditing(true)
        presentedLegacyShortcutCamera(context: self.context, saveCapturedMedia: false, saveEditedPhotos: false, mediaGrouping: true, parentController: controller)
    }
}

class MessageStoryRenderer {
    private let context: AccountContext
    private let presentationData: PresentationData
    private let message: Message
    
    let containerNode: ASDisplayNode
    private let instantChatBackgroundNode: WallpaperBackgroundNode
    private let messagesContainerNode: ASDisplayNode
    private var dateHeaderNode: ListViewItemHeaderNode?
    private var messageNodes: [ListViewItemNode]?
    private let addressNode: ImmediateTextNode
    
    init(context: AccountContext, message: Message) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.message = message

        self.containerNode = ASDisplayNode()
        
        self.instantChatBackgroundNode = WallpaperBackgroundNode()
        self.instantChatBackgroundNode.displaysAsynchronously = false
        self.instantChatBackgroundNode.image = chatControllerBackgroundImage(theme: presentationData.theme, wallpaper: .builtin(WallpaperSettings()), mediaBox: context.sharedContext.accountManager.mediaBox, knockoutMode: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper)
        
        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.clipsToBounds = true
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        let peer = message.peers[message.id.peerId]!
        self.addressNode = ImmediateTextNode()
        self.addressNode.displaysAsynchronously = false
        self.addressNode.attributedText = NSAttributedString(string: "t.me/\(peer.addressName ?? "")", font: Font.medium(14.0), textColor: UIColor(rgb: 0xa8b7c4))
//        self.addressNode.textShadowColor = .black
        
        self.containerNode.addSubnode(self.instantChatBackgroundNode)
        self.containerNode.addSubnode(self.messagesContainerNode)
        self.containerNode.addSubnode(self.addressNode)
    }
    
//    func update(layout: ContainerViewLayout, completion: (UIImage?) -> Void) {
//        self.updateMessagesLayout(layout: layout)
//        
//        Queue.mainQueue().after(0.01) {
//            UIGraphicsBeginImageContextWithOptions(layout.size, false, 3.0)
//            self.containerNode.view.drawHierarchy(in: CGRect(origin: CGPoint(), size: layout.size), afterScreenUpdates: true)
//            let img = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext()
//            completion(img)
//        }
//    }
    
    private func updateMessagesLayout(layout: ContainerViewLayout) {
        let size = layout.size
        self.containerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.instantChatBackgroundNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.instantChatBackgroundNode.updateLayout(size: size, transition: .immediate)
        self.messagesContainerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        let addressLayout = self.addressNode.updateLayout(size)
        
        let theme = self.presentationData.theme.withUpdated(preview: true)
        let headerItem = self.context.sharedContext.makeChatMessageDateHeaderItem(context: self.context, timestamp: self.message.timestamp, theme: theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder)
    
        var items: [ListViewItem] = []
        let sampleMessages: [Message] = [self.message]
    
        items = sampleMessages.reversed().map { message in
            self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message, theme: theme, strings: self.presentationData.strings, wallpaper: self.presentationData.theme.chat.defaultWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil)
        }
    
        let inset: CGFloat = 16.0
        let width = layout.size.width - inset * 2.0
        let params = ListViewItemLayoutParams(width: width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: CGPoint(x: 0.0, y: floor((size.height - layout.size.height) / 2.0)), size: CGSize(width: width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: true, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.messagesContainerNode.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        var bottomOffset: CGFloat = 0.0
        if let messageNodes = self.messageNodes {
            for itemNode in messageNodes {
                itemNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((size.height - itemNode.frame.height) / 2.0)), size: itemNode.frame.size)
                bottomOffset += itemNode.frame.maxY
                itemNode.updateFrame(itemNode.frame, within: layout.size)
            }
        }
        
        self.addressNode.frame = CGRect(origin: CGPoint(x: inset + 16.0, y: bottomOffset + 3.0), size: CGSize(width: addressLayout.width, height: addressLayout.height + 3.0))
        
        let dateHeaderNode: ListViewItemHeaderNode
        if let currentDateHeaderNode = self.dateHeaderNode {
            dateHeaderNode = currentDateHeaderNode
            headerItem.updateNode(dateHeaderNode, previous: nil, next: headerItem)
        } else {
            dateHeaderNode = headerItem.node()
            dateHeaderNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            self.messagesContainerNode.addSubnode(dateHeaderNode)
            self.dateHeaderNode = dateHeaderNode
        }
        
        dateHeaderNode.frame = CGRect(origin: CGPoint(x: 0.0, y: bottomOffset), size: CGSize(width: layout.size.width, height: headerItem.height))
        dateHeaderNode.updateLayout(size: self.containerNode.frame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right)
    }
}
