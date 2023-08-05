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
import MediaEditorScreen
import LegacyComponents
import LegacyMediaPickerUI
import LegacyCamera
import AvatarNode
import LocalMediaResources
import ImageCompression
import TextFormat
import MediaEditor

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

public final class TelegramRootController: NavigationController, TelegramRootControllerInterface {
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
    private var storyUploadEventsDisposable: Disposable?
        
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
            
            self.storyUploadEventsDisposable = (context.engine.messages.allStoriesUploadEvents()
            |> deliverOnMainQueue).start(next: { [weak self] event in
                guard let self else {
                    return
                }
                let (stableId, id) = event
                moveStorySource(engine: self.context.engine, peerId: self.context.account.peerId, from: Int64(stableId), to: Int64(id))
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
        self.storyUploadEventsDisposable?.dispose()
    }
    
    public func getContactsController() -> ViewController? {
        return self.contactsController
    }
    
    public func getChatsController() -> ViewController? {
        return self.chatListController
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
    
    @discardableResult
    public func openStoryCamera(transitionIn: StoryCameraTransitionIn?, transitionedIn: @escaping () -> Void, transitionOut: @escaping (Bool) -> StoryCameraTransitionOut?) -> StoryCameraTransitionInCoordinator? {
        guard let controller = self.viewControllers.last as? ViewController else {
            return nil
        }
        controller.view.endEditing(true)
        
        let context = self.context
        
        var presentImpl: ((ViewController) -> Void)?
        var returnToCameraImpl: (() -> Void)?
        var dismissCameraImpl: (() -> Void)?
        var showDraftTooltipImpl: (() -> Void)?
        let cameraController = CameraScreen(
            context: context,
            mode: .story,
            transitionIn: transitionIn.flatMap {
                if let sourceView = $0.sourceView {
                    return CameraScreen.TransitionIn(
                        sourceView: sourceView,
                        sourceRect: $0.sourceRect,
                        sourceCornerRadius: $0.sourceCornerRadius
                    )
                } else {
                    return nil
                }
            },
            transitionOut: { finished in
                if let transitionOut = transitionOut(finished), let destinationView = transitionOut.destinationView {
                    return CameraScreen.TransitionOut(
                        destinationView: destinationView,
                        destinationRect: transitionOut.destinationRect,
                        destinationCornerRadius: transitionOut.destinationCornerRadius
                    )
                } else {
                    return nil
                }
            },
            completion: { result, resultTransition, dismissed in
                let subject: Signal<MediaEditorScreen.Subject?, NoError> = result
                |> map { value -> MediaEditorScreen.Subject? in
                    func editorPIPPosition(_ position: CameraScreen.PIPPosition) -> MediaEditorScreen.PIPPosition {
                        switch position {
                        case .topLeft:
                            return .topLeft
                        case .topRight:
                            return .topRight
                        case .bottomLeft:
                            return .bottomLeft
                        case .bottomRight:
                            return .bottomRight
                        }
                    }
                    switch value {
                    case .pendingImage:
                        return nil
                    case let .image(image):
                        return .image(image.image, PixelDimensions(image.image.size), image.additionalImage, editorPIPPosition(image.additionalImagePosition))
                    case let .video(video):
                        return .video(video.videoPath, video.coverImage, video.mirror, video.additionalVideoPath, video.additionalCoverImage, video.dimensions, video.duration, video.positionChangeTimestamps, editorPIPPosition(video.additionalVideoPosition))
                    case let .asset(asset):
                        return .asset(asset)
                    case let .draft(draft):
                        return .draft(draft, nil)
                    }
                }
                
                var transitionIn: MediaEditorScreen.TransitionIn?
                if let resultTransition, let sourceView = resultTransition.sourceView {
                    transitionIn = .gallery(
                        MediaEditorScreen.TransitionIn.GalleryTransitionIn(
                            sourceView: sourceView,
                            sourceRect: resultTransition.sourceRect,
                            sourceImage: resultTransition.sourceImage
                        )
                    )
                } else {
                    transitionIn = .camera
                }
                
                let controller = MediaEditorScreen(
                    context: context,
                    subject: subject,
                    isEditing: false,
                    transitionIn: transitionIn,
                    transitionOut: { finished, isNew in
                        if finished, let transitionOut = transitionOut(finished), let destinationView = transitionOut.destinationView {
                            return MediaEditorScreen.TransitionOut(
                                destinationView: destinationView,
                                destinationRect: transitionOut.destinationRect,
                                destinationCornerRadius: transitionOut.destinationCornerRadius
                            )
                        } else if !finished, let resultTransition, let (destinationView, destinationRect) = resultTransition.transitionOut(isNew) {
                            return MediaEditorScreen.TransitionOut(
                                destinationView: destinationView,
                                destinationRect: destinationRect,
                                destinationCornerRadius: 0.0
                            )
                        } else {
                            return nil
                        }
                    }, completion: { [weak self] randomId, mediaResult, mediaAreas, caption, privacy, stickers, commit in
                        guard let self, let mediaResult else {
                            dismissCameraImpl?()
                            commit({})
                            return
                        }
                        
                        let context = self.context
                        if let rootTabController = self.rootTabController {
                            if let index = rootTabController.controllers.firstIndex(where: { $0 is ChatListController}) {
                                rootTabController.selectedIndex = index
                            }
                        }
                        
                        let completionImpl: () -> Void = { [weak self] in
                            guard let self else {
                                return
                            }
                            
                            if let chatListController = self.chatListController as? ChatListControllerImpl {
                                let _ = (chatListController.hasPendingStories
                                |> filter { $0 }
                                |> take(1)
                                |> timeout(0.25, queue: .mainQueue(), alternate: .single(true))
                                |> deliverOnMainQueue).start(completed: { [weak chatListController] in
                                    chatListController?.scrollToStories()
                                    Queue.mainQueue().justDispatch {
                                        commit({})
                                    }
                                })
                            } else {
                                Queue.mainQueue().justDispatch {
                                    commit({})
                                }
                            }
                        }
                        
                        if let _ = self.chatListController as? ChatListControllerImpl {
                            switch mediaResult {
                            case let .image(image, dimensions):
                                if let imageData = compressImageToJPEG(image, quality: 0.7) {
                                    let entities = generateChatInputTextEntities(caption)
                                    Logger.shared.log("MediaEditor", "Calling uploadStory for image, randomId \(randomId)")
                                    let _ = (context.engine.messages.uploadStory(media: .image(dimensions: dimensions, data: imageData, stickers: stickers), mediaAreas: mediaAreas, text: caption.string, entities: entities, pin: privacy.pin, privacy: privacy.privacy, isForwardingDisabled: privacy.isForwardingDisabled, period: privacy.timeout, randomId: randomId)
                                    |> deliverOnMainQueue).start(next: { stableId in
                                        moveStorySource(engine: context.engine, peerId: context.account.peerId, from: randomId, to: Int64(stableId))
                                    })
                                    
                                    completionImpl()
                                }
                            case let .video(content, firstFrameImage, values, duration, dimensions):
                                let adjustments: VideoMediaResourceAdjustments
                                if let valuesData = try? JSONEncoder().encode(values) {
                                    let data = MemoryBuffer(data: valuesData)
                                    let digest = MemoryBuffer(data: data.md5Digest())
                                    adjustments = VideoMediaResourceAdjustments(data: data, digest: digest, isStory: true)
                                    
                                    let resource: TelegramMediaResource
                                    switch content {
                                    case let .imageFile(path):
                                        resource = LocalFileVideoMediaResource(randomId: Int64.random(in: .min ... .max), path: path, adjustments: adjustments)
                                    case let .videoFile(path):
                                        resource = LocalFileVideoMediaResource(randomId: Int64.random(in: .min ... .max), path: path, adjustments: adjustments)
                                    case let .asset(localIdentifier):
                                        resource = VideoLibraryMediaResource(localIdentifier: localIdentifier, conversion: .compress(adjustments))
                                    }
                                    let imageData = firstFrameImage.flatMap { compressImageToJPEG($0, quality: 0.6) }
                                    let firstFrameFile = imageData.flatMap { data -> TempBoxFile? in
                                        let file = TempBox.shared.tempFile(fileName: "image.jpg")
                                        if let _ = try? data.write(to: URL(fileURLWithPath: file.path)) {
                                            return file
                                        } else {
                                            return nil
                                        }
                                    }
                                    Logger.shared.log("MediaEditor", "Calling uploadStory for video, randomId \(randomId)")
                                    let entities = generateChatInputTextEntities(caption)
                                    let _ = (context.engine.messages.uploadStory(media: .video(dimensions: dimensions, duration: duration, resource: resource, firstFrameFile: firstFrameFile, stickers: stickers), mediaAreas: mediaAreas, text: caption.string, entities: entities, pin: privacy.pin, privacy: privacy.privacy, isForwardingDisabled: privacy.isForwardingDisabled, period: privacy.timeout, randomId: randomId)
                                    |> deliverOnMainQueue).start(next: { stableId in
                                        moveStorySource(engine: context.engine, peerId: context.account.peerId, from: randomId, to: Int64(stableId))
                                    })
                                    
                                    completionImpl()
                                }
                            }
                        }
                        
                        dismissCameraImpl?()
                    } as (Int64, MediaEditorScreen.Result?, [MediaArea], NSAttributedString, MediaEditorResultPrivacy, [TelegramMediaFile], @escaping (@escaping () -> Void) -> Void) -> Void
                )
                controller.cancelled = { showDraftTooltip in
                    if showDraftTooltip {
                        showDraftTooltipImpl?()
                    }
                    returnToCameraImpl?()
                }
                controller.dismissed = {
                    dismissed()
                }
                presentImpl?(controller)
            }
        )
        cameraController.transitionedIn = transitionedIn
        controller.push(cameraController)
        presentImpl = { [weak cameraController] c in
            if let navigationController = cameraController?.navigationController as? NavigationController {
                var controllers = navigationController.viewControllers
                controllers.append(c)
                navigationController.setViewControllers(controllers, animated: false)
            }
        }
        dismissCameraImpl = { [weak cameraController] in
            cameraController?.dismiss(animated: false)
        }
        returnToCameraImpl = { [weak cameraController] in
            if let cameraController {
                cameraController.returnFromEditor()
            }
        }
        showDraftTooltipImpl = { [weak cameraController] in
            if let cameraController {
                cameraController.presentDraftTooltip()
            }
        }
        return StoryCameraTransitionInCoordinator(
            animateIn: { [weak cameraController] in
                if let cameraController {
                    cameraController.updateTransitionProgress(0.0, transition: .immediate)
                    cameraController.completeWithTransitionProgress(1.0, velocity: 0.0, dismissing: false)
                }
            },
            updateTransitionProgress: { [weak cameraController] transitionFraction in
                if let cameraController {
                    cameraController.updateTransitionProgress(transitionFraction, transition: .immediate)
                }
            },
            completeWithTransitionProgressAndVelocity: { [weak cameraController] transitionFraction, velocity in
                if let cameraController {
                    cameraController.completeWithTransitionProgress(transitionFraction, velocity: velocity, dismissing: false)
                }
            })
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
