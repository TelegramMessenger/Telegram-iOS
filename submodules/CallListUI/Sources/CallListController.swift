import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import AppBundle
import LocalizedPeerData

public enum CallListControllerMode {
    case tab
    case navigation
}

public final class CallListController: ViewController {
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
    
    public init(context: AccountContext, mode: CallListControllerMode) {
        self.context = context
        self.mode = mode
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.segmentedTitleView = ItemListControllerSegmentedTitleView(theme: self.presentationData.theme, segments: [self.presentationData.strings.Calls_All, self.presentationData.strings.Calls_Missed], selectedIndex: 0)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
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
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        let index = self.segmentedTitleView.index
        self.segmentedTitleView.segments = [self.presentationData.strings.Calls_All, self.presentationData.strings.Calls_Missed]
        self.segmentedTitleView.theme = self.presentationData.theme
        self.segmentedTitleView.index = index
            
        self.tabBarItem.title = self.presentationData.strings.Calls_TabTitle
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
        self.displayNode = CallListControllerNode(context: self.context, mode: self.mode, presentationData: self.presentationData, call: { [weak self] peerId in
            if let strongSelf = self {
                strongSelf.call(peerId)
            }
        }, openInfo: { [weak self] peerId, messages in
            if let strongSelf = self {
                let _ = (strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                |> take(1)
                |> deliverOnMainQueue).start(next: { peer in
                    if let strongSelf = self, let controller = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, peer: peer, mode: .calls(messages: messages), avatarInitiallyExpanded: false, fromChat: false) {
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
                            case .navigation:
                                strongSelf.navigationItem.setRightBarButton(nil, animated: true)
                        }
                    } else {
                        switch strongSelf.mode {
                            case .tab:
                                if strongSelf.editingMode {
                                    strongSelf.navigationItem.leftBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.donePressed))
                                } else {
                                    strongSelf.navigationItem.leftBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Edit, style: .plain, target: strongSelf, action: #selector(strongSelf.editPressed))
                                }
                            case .navigation:
                                if strongSelf.editingMode {
                                    strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Done, style: .done, target: strongSelf, action: #selector(strongSelf.donePressed))
                                } else {
                                    strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(title: strongSelf.presentationData.strings.Common_Edit, style: .plain, target: strongSelf, action: #selector(strongSelf.editPressed))
                                }
                        }
                    }
                }
            }
        })
        self._ready.set(self.controllerNode.ready)
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func callPressed() {
        let controller = self.context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(context: self.context, title: { $0.Calls_NewCall }))
        controller.navigationPresentation = .modal
        self.createActionDisposable.set((controller.result
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak controller, weak self] peer in
            controller?.dismissSearch()
            if let strongSelf = self, let contactPeer = peer, case let .peer(peer, _, _) = contactPeer {
                strongSelf.call(peer.id, began: {
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
        (self.navigationController as? NavigationController)?.pushViewController(controller)
    }
    
    @objc func editPressed() {
        self.editingMode = true
        switch self.mode {
            case .tab:
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
            case .navigation:
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        }
        
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(true)
        }
    }
    
    @objc func donePressed() {
        self.editingMode = false
        switch self.mode {
            case .tab:
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            case .navigation:
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        }
        
        self.controllerNode.updateState { state in
            return state.withUpdatedEditing(false).withUpdatedMessageIdWithRevealedOptions(nil)
        }
    }
    
    private func call(_ peerId: PeerId, began: (() -> Void)? = nil) {
        self.peerViewDisposable.set((self.context.account.viewTracker.peerView(peerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                guard let peer = peerViewMainPeer(view) else {
                    return
                }
                
                if let cachedUserData = view.cachedData as? CachedUserData, cachedUserData.callsPrivate {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    
                    strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.Call_ConnectionErrorTitle, text: presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    return
                }
            
                let callResult = strongSelf.context.sharedContext.callManager?.requestCall(account: strongSelf.context.account, peerId: peerId, endCurrentIfAny: false)
                if let callResult = callResult {
                    if case let .alreadyInProgress(currentPeerId) = callResult {
                        if currentPeerId == peerId {
                            began?()
                            strongSelf.context.sharedContext.navigateToCurrentCall()
                        } else {
                            let presentationData = strongSelf.presentationData
                            let _ = (strongSelf.context.account.postbox.transaction { transaction -> (Peer?, Peer?) in
                                return (transaction.getPeer(peerId), transaction.getPeer(currentPeerId))
                                } |> deliverOnMainQueue).start(next: { [weak self] peer, current in
                                    if let strongSelf = self, let peer = peer, let current = current {
                                        strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                            if let strongSelf = self {
                                                let _ = strongSelf.context.sharedContext.callManager?.requestCall(account: strongSelf.context.account, peerId: peerId, endCurrentIfAny: true)
                                                began?()
                                            }
                                        })]), in: .window(.root))
                                    }
                                })
                        }
                    } else {
                        began?()
                    }
                }
            }
        }))
    }
}
