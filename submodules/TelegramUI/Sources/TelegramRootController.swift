import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import ContactListUI
import CallListUI
import ChatListUI
import SettingsUI
import AppBundle
import DatePickerNode
import DebugSettingsUI
import TabBarUI
import WallpaperBackgroundNode
import ChatPresentationInterfaceState
import CameraScreen
import LegacyComponents
import LegacyMediaPickerUI
import LegacyCamera
import AvatarNode

private class DetailsChatPlaceholderNode: ASDisplayNode, NavigationDetailsPlaceholderNode {
    private var presentationData: PresentationData
    private var presentationInterfaceState: ChatPresentationInterfaceState
    
    let wallpaperBackgroundNode: WallpaperBackgroundNode
    let emptyNode: ChatEmptyNode
    
    init(context: AccountContext) {
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: context.account.peerId, mode: .standard(previewing: false), chatLocation: .peer(id: context.account.peerId), subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil, threadData: nil, isGeneralThreadClosed: nil)
        
        self.wallpaperBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: true, useSharedAnimationPhase: true)
        self.emptyNode = ChatEmptyNode(context: context, interaction: nil)
        
        super.init()
        
        self.addSubnode(self.wallpaperBackgroundNode)
        self.addSubnode(self.emptyNode)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: self.presentationData.chatWallpaper, theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: self.presentationInterfaceState.limitsConfiguration, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: self.presentationInterfaceState.accountPeerId, mode: .standard(previewing: false), chatLocation: self.presentationInterfaceState.chatLocation, subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil, threadData: nil, isGeneralThreadClosed: nil)
        
        self.wallpaperBackgroundNode.update(wallpaper: presentationData.chatWallpaper)
    }
    
    func updateLayout(size: CGSize, needsTiling: Bool, transition: ContainedViewLayoutTransition) {
        let contentBounds = CGRect(origin: .zero, size: size)
        self.wallpaperBackgroundNode.updateLayout(size: size, displayMode: needsTiling ? .aspectFit : .aspectFill, transition: transition)
        transition.updateFrame(node: self.wallpaperBackgroundNode, frame: contentBounds)
        
        self.emptyNode.updateLayout(interfaceState: self.presentationInterfaceState, subject: .detailsPlaceholder, loadingNode: nil, backgroundNode: self.wallpaperBackgroundNode, size: contentBounds.size, insets: .zero, transition: transition)
        transition.updateFrame(node: self.emptyNode, frame: CGRect(origin: .zero, size: size))
        self.emptyNode.update(rect: contentBounds, within: contentBounds.size, transition: transition)
    }
}

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
    
    private var detailsPlaceholderNode: DetailsChatPlaceholderNode?
    
    private var applicationInFocusDisposable: Disposable?
        
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(mode: .automaticMasterDetail, theme: NavigationControllerTheme(presentationTheme: self.presentationData.theme))
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.detailsPlaceholderNode?.updatePresentationData(presentationData)
                
                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData
                if previousTheme !== presentationData.theme {
                    (strongSelf.rootTabController as? TabBarControllerImpl)?.updateTheme(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData), theme: TabBarControllerTheme(rootControllerTheme: presentationData.theme))
                    strongSelf.rootTabController?.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
                }
            }
        })
        
        if context.sharedContext.applicationBindings.isMainApp {
            self.applicationInFocusDisposable = (context.sharedContext.applicationBindings.applicationIsActive
            |> distinctUntilChanged
            |> deliverOn(Queue.mainQueue())).start(next: { value in
                context.sharedContext.mainWindow?.setForceBadgeHidden(!value)
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.permissionsDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.applicationInFocusDisposable?.dispose()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let needsRootWallpaperBackgroundNode: Bool
        if case .regular = layout.metrics.widthClass {
            needsRootWallpaperBackgroundNode = true
        } else {
            needsRootWallpaperBackgroundNode = false
        }
        
        if needsRootWallpaperBackgroundNode {
            let detailsPlaceholderNode: DetailsChatPlaceholderNode
            if let current = self.detailsPlaceholderNode {
                detailsPlaceholderNode = current
            } else {
                detailsPlaceholderNode = DetailsChatPlaceholderNode(context: self.context)
                detailsPlaceholderNode.wallpaperBackgroundNode.update(wallpaper: self.presentationData.chatWallpaper)
                self.detailsPlaceholderNode = detailsPlaceholderNode
            }
            self.updateDetailsPlaceholderNode(detailsPlaceholderNode)
        } else if let _ = self.detailsPlaceholderNode {
            self.detailsPlaceholderNode = nil
            self.updateDetailsPlaceholderNode(nil)
        }
    
        super.containerLayoutUpdated(layout, transition: transition)
    }
    
    public func addRootControllers(showCallsTab: Bool) {
        let tabBarController = TabBarControllerImpl(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), theme: TabBarControllerTheme(rootControllerTheme: self.presentationData.theme))
        tabBarController.navigationPresentation = .master
        let chatListController = self.context.sharedContext.makeChatListController(context: self.context, location: .chatList(groupId: .root), controlsHistoryPreload: true, hideNetworkActivityStatus: false, previewing: false, enableDebugActions: !GlobalExperimentalSettings.isAppStoreBuild)
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
        
        let accountSettingsController = PeerInfoScreenImpl(context: self.context, updatedPresentationData: nil, peerId: self.context.account.peerId, avatarInitiallyExpanded: false, isOpenedFromChat: false, nearbyPeerDistance: nil, reactionSourceMessageId: nil, callMessages: [], isSettings: true)
        accountSettingsController.tabBarItemDebugTapAction = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pushViewController(debugController(sharedContext: strongSelf.context.sharedContext, context: strongSelf.context))
        }
        accountSettingsController.parentController = self
        controllers.append(accountSettingsController)
                
        if self.context.sharedContext.immediateExperimentalUISettings.storiesExperiment {
            tabBarController.cameraItemAndAction = (
                UITabBarItem(title: "Camera", image: UIImage(bundleImageName: "Chat List/Tabs/IconCamera"), tag: 2),
                { [weak self] in
                    self?.openStoryCamera()
                }
            )
        }
        
        tabBarController.setControllers(controllers, selectedIndex: restoreSettignsController != nil ? (controllers.count - 1) : (controllers.count - 2))
        
        self.contactsController = contactsController
        self.callListController = callListController
        self.chatListController = chatListController
        self.accountSettingsController = accountSettingsController
        self.rootTabController = tabBarController
        self.pushViewController(tabBarController, animated: false)
    }
        
    public func updateRootControllers(showCallsTab: Bool) {
        guard let rootTabController = self.rootTabController as? TabBarControllerImpl else {
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
    
    public func openChatsController(activateSearch: Bool, filter: ChatListSearchFilter = .chats, query: String? = nil) {
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
            self.chatListController?.activateSearch(filter: filter, query: query)
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
    
    public func openStoryCamera() {
        guard let controller = self.viewControllers.last as? ViewController else {
            return
        }
        controller.view.endEditing(true)
        
        var presentImpl: ((ViewController) -> Void)?
        var dismissCameraImpl: (() -> Void)?
        let cameraController = CameraScreen(context: self.context, mode: .story, completion: { [weak self] result in
            if let self {
                let item: TGMediaEditableItem & TGMediaSelectableItem
                switch result {
                case let .image(image):
                    item = TGCameraCapturedPhoto(existing: image)
                case let .video(path):
                    item = TGCameraCapturedVideo(url: URL(fileURLWithPath: path))
                case let .asset(asset):
                    item = TGMediaAsset(phAsset: asset)
                }
                let context = self.context
                legacyStoryMediaEditor(context: self.context, item: item, getCaptionPanelView: { return nil }, completion: { [weak self] mediaResult in
                    dismissCameraImpl?()
                    
                    guard let self else {
                        return
                    }
                    
                    enum AdditionalCategoryId: Int {
                        case everyone
                        case contacts
                        case closeFriends
                    }
                    
                    let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
                    
                    let additionalCategories: [ChatListNodeAdditionalCategory] = [
                        ChatListNodeAdditionalCategory(
                            id: AdditionalCategoryId.everyone.rawValue,
                            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Channel"), color: .white), cornerRadius: nil, color: .blue),
                            smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Channel"), color: .white), iconScale: 0.6, cornerRadius: 6.0, circleCorners: true, color: .blue),
                            title: "Everyone",
                            appearance: .option(sectionTitle: "WHO CAN VIEW FOR 24 HOURS")
                        ),
                        ChatListNodeAdditionalCategory(
                            id: AdditionalCategoryId.contacts.rawValue,
                            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconContacts"), color: .white), iconScale: 1.0 * 0.8, cornerRadius: nil, color: .yellow),
                            smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Chat List/Tabs/IconContacts"), color: .white), iconScale: 0.6 * 0.8, cornerRadius: 6.0, circleCorners: true, color: .yellow),
                            title: presentationData.strings.ChatListFolder_CategoryContacts,
                            appearance: .option(sectionTitle: "WHO CAN VIEW FOR 24 HOURS")
                        ),
                        ChatListNodeAdditionalCategory(
                            id: AdditionalCategoryId.closeFriends.rawValue,
                            icon: generateAvatarImage(size: CGSize(width: 40.0, height: 40.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Call/StarHighlighted"), color: .white), iconScale: 1.0 * 0.6, cornerRadius: nil, color: .green),
                            smallIcon: generateAvatarImage(size: CGSize(width: 22.0, height: 22.0), icon: generateTintedImage(image: UIImage(bundleImageName: "Call/StarHighlighted"), color: .white), iconScale: 0.6 * 0.6, cornerRadius: 6.0, circleCorners: true, color: .green),
                            title: "Close Friends",
                            appearance: .option(sectionTitle: "WHO CAN VIEW FOR 24 HOURS")
                        )
                    ]
                    
                    let selectionController = self.context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: self.context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
                        title: "Share Story",
                        searchPlaceholder: "Search contacts",
                        selectedChats: Set(),
                        additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: additionalCategories, selectedCategories: Set([AdditionalCategoryId.everyone.rawValue])),
                        chatListFilters: nil,
                        displayPresence: true
                    )), options: [], filters: [.excludeSelf], alwaysEnabled: true, limit: 1000, reachedLimit: { _ in
                    }))
                    selectionController.navigationPresentation = .modal
                    self.pushViewController(selectionController)
                    
                    let _ = (selectionController.result
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self, weak selectionController] result in
                        guard let self else {
                            return
                        }
                        guard case let .result(peerIds, additionalCategoryIds) = result else {
                            selectionController?.dismiss()
                            return
                        }
                        
                        var privacy = EngineStoryPrivacy(base: .everyone, additionallyIncludePeers: [])
                        if additionalCategoryIds.contains(AdditionalCategoryId.everyone.rawValue) {
                            privacy.base = .everyone
                        } else if additionalCategoryIds.contains(AdditionalCategoryId.contacts.rawValue) {
                            privacy.base = .contacts
                        } else if additionalCategoryIds.contains(AdditionalCategoryId.closeFriends.rawValue) {
                            privacy.base = .closeFriends
                        }
                        privacy.additionallyIncludePeers = peerIds.compactMap { id -> EnginePeer.Id? in
                            switch id {
                            case let .peer(peerId):
                                return peerId
                            default:
                                return nil
                            }
                        }
                        
                        selectionController?.displayProgress = true
                        
                        switch mediaResult {
                        case let .image(image):
                            _ = image
                            selectionController?.dismiss()
                        case let .video(path):
                            _ = path
                            selectionController?.dismiss()
                        case let .asset(asset):
                            let options = PHImageRequestOptions()
                            options.deliveryMode = .highQualityFormat
                            options.isNetworkAccessAllowed = true
                            PHImageManager.default().requestImageData(for: asset, options:options, resultHandler: { [weak self] data, _, _, _ in
                                if let data, let image = UIImage(data: data) {
                                    Queue.mainQueue().async {
                                        let _ = (context.engine.messages.uploadStory(media: .image(dimensions: PixelDimensions(image.size), data: data), privacy: privacy)
                                        |> deliverOnMainQueue).start(completed: {
                                            guard let self else {
                                                return
                                            }
                                            let _ = self
                                            selectionController?.dismiss()
                                        })
                                    }
                                }
                            })
                        }
                    })
                }, present: { c, a in
                    presentImpl?(c)
                })
            }
        })
        controller.push(cameraController)
        presentImpl = { [weak cameraController] c in
            cameraController?.present(c, in: .window(.root))
        }
        dismissCameraImpl = { [weak cameraController] in
            cameraController?.dismiss(animated: false)
        }
    }
    
    public func openSettings() {
        guard let rootTabController = self.rootTabController else {
            return
        }
        
        self.popToRoot(animated: false)
    
        if let index = rootTabController.controllers.firstIndex(where: { $0 is PeerInfoScreenImpl }) {
            rootTabController.selectedIndex = index
        }
    }
}
