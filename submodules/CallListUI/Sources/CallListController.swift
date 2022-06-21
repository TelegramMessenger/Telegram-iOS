import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import AppBundle
import LocalizedPeerData
import ContextUI
import TelegramBaseController

public enum CallListControllerMode {
    case tab
    case navigation
}

private final class DeleteAllButtonNode: ASDisplayNode {
    private let pressed: () -> Void
    
    let contentNode: ContextExtractedContentContainingNode
    private let buttonNode: HighlightableButtonNode
    private let titleNode: ImmediateTextNode
    
    init(presentationData: PresentationData, pressed: @escaping () -> Void) {
        self.pressed = pressed
        
        self.contentNode = ContextExtractedContentContainingNode()
        self.buttonNode = HighlightableButtonNode()
        self.titleNode = ImmediateTextNode()
        
        super.init()
        
        self.addSubnode(self.contentNode)
        self.buttonNode.addSubnode(self.titleNode)
        self.contentNode.contentNode.addSubnode(self.buttonNode)
        
        self.titleNode.attributedText = NSAttributedString(string: presentationData.strings.Notification_Exceptions_DeleteAll, font: Font.regular(17.0), textColor: presentationData.theme.rootController.navigationBar.accentTextColor)
        
        //self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.pressed()
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.updateLayout(constrainedSize)
        self.titleNode.frame = CGRect(origin: CGPoint(), size: titleSize)
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: titleSize)
        return titleSize
    }
    
    override public func layout() {
        super.layout()
        
        let size = self.bounds.size
        self.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        self.contentNode.contentRect = CGRect(origin: CGPoint(), size: size)
    }
}

public final class CallListController: TelegramBaseController {
    private var controllerNode: CallListControllerNode {
        return self.displayNode as! CallListControllerNode
    }
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    private let mode: CallListControllerMode
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let peerViewDisposable = MetaDisposable()
    
    private let segmentedTitleView: ItemListControllerSegmentedTitleView
    
    private var isEmpty: Bool?
    private var editingMode: Bool = false
    
    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()
    
    public init(context: AccountContext, mode: CallListControllerMode) {
        self.context = context
        self.mode = mode
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.segmentedTitleView = ItemListControllerSegmentedTitleView(theme: self.presentationData.theme, segments: [self.presentationData.strings.Calls_All, self.presentationData.strings.Calls_Missed], selectedIndex: 0)
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        self.tabBarItemContextActionType = .always
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        if case .tab = self.mode {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCallIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.callPressed))
            
            let icon: UIImage?
            if useSpecialTabBarIcons() {
                icon = UIImage(bundleImageName: "Chat List/Tabs/Holiday/IconCalls")
            } else {
                icon = UIImage(bundleImageName: "Chat List/Tabs/IconCalls")
            }
            self.tabBarItem.title = self.presentationData.strings.Calls_TabTitle
            self.tabBarItem.image = icon
            self.tabBarItem.selectedImage = icon
            if !self.presentationData.reduceMotion {
                self.tabBarItem.animationName = "TabCalls"
            }
        }
        
        self.segmentedTitleView.indexUpdated = { [weak self] index in
            if let strongSelf = self {
                strongSelf.controllerNode.updateType(index == 0 ? .all : .missed)
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToLatest()
        }
        
        self.navigationItem.titleView = self.segmentedTitleView
        if case .navigation = self.mode {
            self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        let index = self.segmentedTitleView.index
        self.segmentedTitleView.segments = [self.presentationData.strings.Calls_All, self.presentationData.strings.Calls_Missed]
        self.segmentedTitleView.theme = self.presentationData.theme
        self.segmentedTitleView.index = index
            
        self.tabBarItem.title = self.presentationData.strings.Calls_TabTitle
        if !self.presentationData.reduceMotion {
            self.tabBarItem.animationName = "TabCalls"
        } else {
            self.tabBarItem.animationName = nil
        }
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        switch self.mode {
            case .tab:
                if let isEmpty = self.isEmpty, isEmpty {
                } else {
                    if self.editingMode {
                        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
                    } else {
                        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
                    }
                }
                
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationCallIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.callPressed))
            case .navigation:
                if self.editingMode {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
                } else {
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
                }
        }
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        if self.isNodeLoaded {
            self.controllerNode.updateThemeAndStrings(presentationData: self.presentationData)
        }
        
    }
    
    override public func loadDisplayNode() {
        self.displayNode = CallListControllerNode(controller: self, context: self.context, mode: self.mode, presentationData: self.presentationData, call: { [weak self] peerId, isVideo in
            if let strongSelf = self {
                strongSelf.call(peerId, isVideo: isVideo)
            }
        }, joinGroupCall: { [weak self] peerId, activeCall in
            if let strongSelf = self {
                strongSelf.joinGroupCall(peerId: peerId, invite: nil, activeCall: activeCall)
            }
        }, openInfo: { [weak self] peerId, messages in
            if let strongSelf = self {
                let _ = (strongSelf.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                )
                |> deliverOnMainQueue).start(next: { peer in
                    if let strongSelf = self, let peer = peer, let controller = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .calls(messages: messages.map({ $0._asMessage() })), avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
                    }
                })
            }
        }, emptyStateUpdated: { [weak self] empty in
            if let strongSelf = self {
                if empty != strongSelf.isEmpty {
                    strongSelf.isEmpty = empty
                    
                    if empty {
                        switch strongSelf.mode {
                            case .tab:
                                strongSelf.navigationItem.setLeftBarButton(nil, animated: true)
                                strongSelf.navigationItem.setRightBarButton(nil, animated: true)
                            case .navigation:
                                strongSelf.navigationItem.setRightBarButton(nil, animated: true)
                        }
                    } else {
                        switch strongSelf.mode {
                            case .tab:
                                if strongSelf.editingMode {
                                    strongSelf.navigationItem.setLeftBarButton(UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.donePressed)), animated: true)
                                    var pressedImpl: (() -> Void)?
                                    let buttonNode = DeleteAllButtonNode(presentationData: strongSelf.presentationData, pressed: {
                                        pressedImpl?()
                                    })
                                    strongSelf.navigationItem.setRightBarButton(UIBarButtonItem(customDisplayNode: buttonNode), animated: true)
                                    strongSelf.navigationItem.rightBarButtonItem?.setCustomAction({
                                        pressedImpl?()
                                    })
                                    pressedImpl = { [weak self, weak buttonNode] in
                                        guard let strongSelf = self, let buttonNode = buttonNode else {
                                            return
                                        }
                                        strongSelf.deleteAllPressed(buttonNode: buttonNode)
                                    }
                                    
                                    //strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Notification_Exceptions_DeleteAll, style: .plain, target: strongSelf, action: #selector(strongSelf.deleteAllPressed))
                                } else {
                                    strongSelf.navigationItem.setLeftBarButton(UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Edit, style: .plain, target: strongSelf, action: #selector(strongSelf.editPressed)), animated: true)
                                    strongSelf.navigationItem.setRightBarButton(UIBarButtonItem(image: PresentationResourcesRootController.navigationCallIcon(strongSelf.presentationData.theme), style: .plain, target: self, action: #selector(strongSelf.callPressed)), animated: true)
                                }
                            case .navigation:
                                if strongSelf.editingMode {
                                    strongSelf.navigationItem.setRightBarButton(UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.donePressed)), animated: true)
                                } else {
                                    strongSelf.navigationItem.setRightBarButton(UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Edit, style: .plain, target: strongSelf, action: #selector(strongSelf.editPressed)), animated: true)
                                }
                        }
                    }
                }
            }
        })
        
        if case .navigation = self.mode {
            self.controllerNode.navigationBar = self.navigationBar
            self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        }
        
        self.controllerNode.startNewCall = { [weak self] in
            self?.beginCallImpl()
        }
        self._ready.set(self.controllerNode.ready)
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func callPressed() {
        self.beginCallImpl()
    }
    
    @objc private func deleteAllPressed(buttonNode: DeleteAllButtonNode) {
        var items: [ContextMenuItem] = []
        
        let beginClear: (Bool) -> Void = { [weak self] forEveryone in
            guard let strongSelf = self else {
                return
            }
            
            var signal = strongSelf.context.engine.messages.clearCallHistory(forEveryone: forEveryone)
            
            var cancelImpl: (() -> Void)?
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            let progressSignal = Signal<Never, NoError> { subscriber in
                let controller = OverlayStatusController(theme: presentationData.theme,  type: .loading(cancelled: {
                    cancelImpl?()
                }))
                strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                return ActionDisposable { [weak controller] in
                    Queue.mainQueue().async() {
                        controller?.dismiss()
                    }
                }
            }
            |> runOn(Queue.mainQueue())
            |> delay(0.15, queue: Queue.mainQueue())
            let progressDisposable = progressSignal.start()
            
            signal = signal
            |> afterDisposed {
                Queue.mainQueue().async {
                    progressDisposable.dispose()
                }
            }
            cancelImpl = {
                self?.clearDisposable.set(nil)
            }
            strongSelf.clearDisposable.set((signal
            |> deliverOnMainQueue).start(completed: {
            }))
        }
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.CallList_DeleteAllForMe, textColor: .destructive, icon: { _ in
            return nil
        }, action: { _, f in
            f(.default)
            beginClear(false)
        })))
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.CallList_DeleteAllForEveryone, textColor: .destructive, icon: { _ in
            return nil
        }, action: { _, f in
            f(.default)
            beginClear(true)
        })))
        
        final class ExtractedContentSourceImpl: ContextExtractedContentSource {
            var keepInPlace: Bool
            let ignoreContentTouches: Bool = true
            let blurBackground: Bool
            
            private let controller: ViewController
            private let sourceNode: ContextExtractedContentContainingNode
            
            init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool, blurBackground: Bool) {
                self.controller = controller
                self.sourceNode = sourceNode
                self.keepInPlace = keepInPlace
                self.blurBackground = blurBackground
            }
            
            func takeView() -> ContextControllerTakeViewInfo? {
                return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
            }
            
            func putBack() -> ContextControllerPutBackViewInfo? {
                return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
            }
        }
    
        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .extracted(ExtractedContentSourceImpl(controller: self, sourceNode: buttonNode.contentNode, keepInPlace: false, blurBackground: false)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        self.presentInGlobalOverlay(contextController)
    }
    
    private func beginCallImpl() {
        let controller = self.context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: self.context, title: { $0.Calls_NewCall }, displayCallIcons: true))
        controller.navigationPresentation = .modal
        self.createActionDisposable.set((controller.result
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak controller, weak self] result in
            controller?.dismissSearch()
            if let strongSelf = self, let (contactPeers, action, _, _, _) = result, let contactPeer = contactPeers.first,  case let .peer(peer, _, _) = contactPeer {
                strongSelf.call(peer.id, isVideo: action == .videoCall, began: {
                    if let strongSelf = self {
                        let _ = (strongSelf.context.sharedContext.hasOngoingCall.get()
                        |> filter { $0 }
                        |> timeout(1.0, queue: Queue.mainQueue(), alternate: .single(true))
                        |> delay(0.5, queue: Queue.mainQueue())
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { _ in
                            if let _ = self, let controller = controller, let navigationController = controller.navigationController as? NavigationController {
                                if navigationController.viewControllers.last === controller {
                                    let _ = navigationController.popViewController(animated: true)
                                }
                            }
                        })
                    }
                })
            }
        }))
        if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
            navigationController.pushViewController(controller)
        }
    }
    
    @objc func editPressed() {
        self.editingMode = true
        
        switch self.mode {
            case .tab:
                self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed)), animated: true)
                var pressedImpl: (() -> Void)?
                let buttonNode = DeleteAllButtonNode(presentationData: self.presentationData, pressed: {
                    pressedImpl?()
                })
                self.navigationItem.setRightBarButton(UIBarButtonItem(customDisplayNode: buttonNode), animated: true)
                self.navigationItem.rightBarButtonItem?.setCustomAction({
                    pressedImpl?()
                })
                pressedImpl = { [weak self, weak buttonNode] in
                    guard let strongSelf = self, let buttonNode = buttonNode else {
                        return
                    }
                    strongSelf.deleteAllPressed(buttonNode: buttonNode)
                }
                //self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Notification_Exceptions_DeleteAll, style: .plain, target: self, action: #selector(self.deleteAllPressed))
            case .navigation:
                self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed)), animated: true)
        }
        
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(true)
        }
    }
    
    @objc func donePressed() {
        self.editingMode = false
        switch self.mode {
            case .tab:
                self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed)), animated: true)
                self.navigationItem.setRightBarButton(UIBarButtonItem(image: PresentationResourcesRootController.navigationCallIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.callPressed)), animated: true)
            case .navigation:
                self.navigationItem.setRightBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed)), animated: true)
        }
        
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(false).withUpdatedMessageIdWithRevealedOptions(nil)
        }
    }
    
    private func call(_ peerId: EnginePeer.Id, isVideo: Bool, began: (() -> Void)? = nil) {
        self.peerViewDisposable.set((self.context.account.viewTracker.peerView(peerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                guard let peer = peerViewMainPeer(view) else {
                    return
                }
                
                if let cachedUserData = view.cachedData as? CachedUserData, cachedUserData.callsPrivate {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    
                    strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.Call_ConnectionErrorTitle, text: presentationData.strings.Call_PrivacyErrorMessage(EnginePeer(peer).compactDisplayTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
                
                strongSelf.context.requestCall(peerId: peerId, isVideo: isVideo, completion: {
                    began?()
                })
            }
        }))
    }
    
    override public func tabBarItemContextAction(sourceNode: ContextExtractedContentContainingNode, gesture: ContextGesture) {
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Calls_StartNewCall, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] c, f in
            c.dismiss(completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.callPressed()
            })
        })))
        
        let controller = ContextController(account: self.context.account, presentationData: self.presentationData, source: .extracted(CallListTabBarContextExtractedContentSource(controller: self, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
    }
}

private final class CallListTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let centerActionsHorizontally: Bool = true
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(contentContainingNode: self.sourceNode, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
