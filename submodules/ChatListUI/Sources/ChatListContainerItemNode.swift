import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import AccountContext
import TelegramPresentationData
import SwiftSignalKit
import AnimationCache
import MultiAnimationRenderer
import TelegramCore
import Postbox
import ChatListHeaderComponent
import ActionPanelComponent
import ChatFolderLinkPreviewScreen

final class ChatListContainerItemNode: ASDisplayNode {
    private final class TopPanelItem {
        let view = ComponentView<Empty>()
        var size: CGSize?
        
        init() {
        }
    }
    
    private let context: AccountContext
    private weak var controller: ChatListControllerImpl?
    private let location: ChatListControllerLocation
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    private var presentationData: PresentationData
    private let becameEmpty: (ChatListFilter?) -> Void
    private let emptyAction: (ChatListFilter?) -> Void
    private let secondaryEmptyAction: () -> Void
    private let openArchiveSettings: () -> Void
    private let isInlineMode: Bool
    
    private var floatingHeaderOffset: CGFloat?
    
    private(set) var emptyNode: ChatListEmptyNode?
    var emptyShimmerEffectNode: ChatListShimmerNode?
    private var shimmerNodeOffset: CGFloat = 0.0
    let listNode: ChatListNode
    
    private var topPanel: TopPanelItem?
    
    private var pollFilterUpdatesDisposable: Disposable?
    private var chatFilterUpdatesDisposable: Disposable?
    private var peerDataDisposable: Disposable?
    
    private var chatFolderUpdates: ChatFolderUpdates?
    
    private var canReportPeer: Bool = false
    
    private(set) var validLayout: (size: CGSize, insets: UIEdgeInsets, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, storiesInset: CGFloat)?
    private var scrollingOffset: (navigationHeight: CGFloat, offset: CGFloat)?
    
    init(context: AccountContext, controller: ChatListControllerImpl?, location: ChatListControllerLocation, filter: ChatListFilter?, chatListMode: ChatListNodeMode, previewing: Bool, isInlineMode: Bool, controlsHistoryPreload: Bool, presentationData: PresentationData, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, becameEmpty: @escaping (ChatListFilter?) -> Void, emptyAction: @escaping (ChatListFilter?) -> Void, secondaryEmptyAction: @escaping () -> Void, openArchiveSettings: @escaping () -> Void, autoSetReady: Bool, isMainTab: Bool?) {
        self.context = context
        self.controller = controller
        self.location = location
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        self.presentationData = presentationData
        self.becameEmpty = becameEmpty
        self.emptyAction = emptyAction
        self.secondaryEmptyAction = secondaryEmptyAction
        self.openArchiveSettings = openArchiveSettings
        self.isInlineMode = isInlineMode
        
        self.listNode = ChatListNode(context: context, location: location, chatListFilter: filter, previewing: previewing, fillPreloadItems: controlsHistoryPreload, mode: chatListMode, theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, animationCache: animationCache, animationRenderer: animationRenderer, disableAnimations: true, isInlineMode: isInlineMode, autoSetReady: autoSetReady, isMainTab: isMainTab)
        
        if let controller, case .chatList(groupId: .root) = controller.location {
            self.listNode.scrollHeightTopInset = ChatListNavigationBar.searchScrollHeight + ChatListNavigationBar.storiesScrollHeight
        }
        
        super.init()
        
        self.addSubnode(self.listNode)
        
        self.listNode.isEmptyUpdated = { [weak self] isEmptyState, _, transition in
            guard let strongSelf = self else {
                return
            }
            var needsShimmerNode = false
            var shimmerNodeOffset: CGFloat = 0.0
            
            var needsEmptyNode = false
            var hasOnlyArchive = false
            var hasOnlyGeneralThread = false
            var isLoading = false
            
            switch isEmptyState {
            case let .empty(isLoadingValue, hasArchiveInfo):
                if hasArchiveInfo {
                    shimmerNodeOffset = 253.0
                }
                if isLoadingValue {
                    needsShimmerNode = true
                    needsEmptyNode = false
                    isLoading = isLoadingValue
                } else {
                    needsEmptyNode = true
                }
                if !isLoadingValue {
                    strongSelf.becameEmpty(filter)
                }
            case let .notEmpty(_, onlyHasArchiveValue, onlyGeneralThreadValue):
                needsEmptyNode = onlyHasArchiveValue || onlyGeneralThreadValue
                hasOnlyArchive = onlyHasArchiveValue
                hasOnlyGeneralThread = onlyGeneralThreadValue
            }
            
            if needsEmptyNode {
                if let currentNode = strongSelf.emptyNode {
                    currentNode.updateIsLoading(isLoading)
                } else {
                    let subject: ChatListEmptyNode.Subject
                    if let filter = filter {
                        var showEdit = true
                        if case let .filter(_, _, _, data) = filter {
                            if data.excludeRead && data.includePeers.peers.isEmpty && data.includePeers.pinnedPeers.isEmpty {
                                showEdit = false
                            }
                        }
                        subject = .filter(showEdit: showEdit)
                    } else {
                        if case .forum = location {
                            subject = .forum(hasGeneral: hasOnlyGeneralThread)
                        } else {
                            if case .chatList(groupId: .archive) = location {
                                subject = .archive
                            } else {
                                subject = .chats(hasArchive: hasOnlyArchive)
                            }
                        }
                    }
                    
                    let emptyNode = ChatListEmptyNode(context: context, subject: subject, isLoading: isLoading, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, action: {
                        self?.emptyAction(filter)
                    }, secondaryAction: {
                        self?.secondaryEmptyAction()
                    }, openArchiveSettings: {
                        self?.openArchiveSettings()
                    })
                    strongSelf.emptyNode = emptyNode
                    strongSelf.listNode.addSubnode(emptyNode)
                    if let (size, insets, _, _, _, _, _) = strongSelf.validLayout {
                        let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
                        emptyNode.frame = emptyNodeFrame
                        emptyNode.updateLayout(size: size, insets: insets,  transition: .immediate)
                        
                        if let scrollingOffset = strongSelf.scrollingOffset {
                            emptyNode.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: .immediate)
                        }
                    }
                    emptyNode.alpha = 0.0
                    transition.updateAlpha(node: emptyNode, alpha: 1.0)
                }
            } else if let emptyNode = strongSelf.emptyNode {
                strongSelf.emptyNode = nil
                transition.updateAlpha(node: emptyNode, alpha: 0.0, completion: { [weak emptyNode] _ in
                    emptyNode?.removeFromSupernode()
                })
            }
            
            
            if needsShimmerNode {
                strongSelf.shimmerNodeOffset = shimmerNodeOffset
                if strongSelf.emptyShimmerEffectNode == nil {
                    let emptyShimmerEffectNode = ChatListShimmerNode()
                    strongSelf.emptyShimmerEffectNode = emptyShimmerEffectNode
                    strongSelf.insertSubnode(emptyShimmerEffectNode, belowSubnode: strongSelf.listNode)
                    if let (size, insets, _, _, _, _, _) = strongSelf.validLayout, let offset = strongSelf.floatingHeaderOffset {
                        strongSelf.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: size, insets: insets, verticalOffset: offset + strongSelf.shimmerNodeOffset, transition: .immediate)
                    }
                }
            } else if let emptyShimmerEffectNode = strongSelf.emptyShimmerEffectNode {
                strongSelf.emptyShimmerEffectNode = nil
                let emptyNodeTransition = transition.isAnimated ? transition : .animated(duration: 0.3, curve: .easeInOut)
                emptyNodeTransition.updateAlpha(node: emptyShimmerEffectNode, alpha: 0.0, completion: { [weak emptyShimmerEffectNode] _ in
                    emptyShimmerEffectNode?.removeFromSupernode()
                })
                strongSelf.listNode.alpha = 0.0
                emptyNodeTransition.updateAlpha(node: strongSelf.listNode, alpha: 1.0)
            }
        }
        
        self.listNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
            guard let strongSelf = self else {
                return
            }
            strongSelf.floatingHeaderOffset = offset
            if let (size, insets, _, _, _, _, _) = strongSelf.validLayout, let emptyShimmerEffectNode = strongSelf.emptyShimmerEffectNode {
                strongSelf.layoutEmptyShimmerEffectNode(node: emptyShimmerEffectNode, size: size, insets: insets, verticalOffset: offset + strongSelf.shimmerNodeOffset, transition: transition)
            }
            strongSelf.layoutAdditionalPanels(transition: transition)
        }
        
        if let filter, case let .filter(id, _, _, data) = filter, data.isShared {
            self.pollFilterUpdatesDisposable = self.context.engine.peers.pollChatFolderUpdates(folderId: id).startStrict()
            self.chatFilterUpdatesDisposable = (self.context.engine.peers.subscribedChatFolderUpdates(folderId: id)
            |> deliverOnMainQueue).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                var update = false
                if let result, result.availableChatsToJoin != 0 {
                    if self.chatFolderUpdates?.availableChatsToJoin != result.availableChatsToJoin {
                        update = true
                    }
                    self.chatFolderUpdates = result
                } else {
                    if self.chatFolderUpdates != nil {
                        self.chatFolderUpdates = nil
                        update = true
                    }
                }
                if update {
                    if let (size, insets, visualNavigationHeight, originalNavigationHeight, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout {
                        self.updateLayout(size: size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
        
        if case let .forum(peerId) = location {
            self.peerDataDisposable = (context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.StatusSettings(id: peerId)
            )
            |> deliverOnMainQueue).startStrict(next: { [weak self] statusSettings in
                guard let self else {
                    return
                }
                var canReportPeer = false
                if let statusSettings, statusSettings.flags.contains(.canReport) {
                    canReportPeer = true
                }
                if self.canReportPeer != canReportPeer {
                    self.canReportPeer = canReportPeer
                    if let (size, insets, visualNavigationHeight, originalNavigationHeight, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset) = self.validLayout {
                        self.updateLayout(size: size, insets: insets, visualNavigationHeight: visualNavigationHeight, originalNavigationHeight: originalNavigationHeight, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction, storiesInset: storiesInset, transition: .animated(duration: 0.4, curve: .spring))
                    }
                }
            })
        }
    }
    
    deinit {
        self.pollFilterUpdatesDisposable?.dispose()
        self.chatFilterUpdatesDisposable?.dispose()
        self.peerDataDisposable?.dispose()
    }
    
    private func layoutEmptyShimmerEffectNode(node: ChatListShimmerNode, size: CGSize, insets: UIEdgeInsets, verticalOffset: CGFloat, transition: ContainedViewLayoutTransition) {
        node.update(context: self.context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, size: size, isInlineMode: self.isInlineMode, presentationData: self.presentationData, transition: .immediate)
        transition.updateFrameAdditive(node: node, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: size))
    }
    
    private func layoutAdditionalPanels(transition: ContainedViewLayoutTransition) {
        guard let (size, insets, visualNavigationHeight, _, _, _, _) = self.validLayout, let offset = self.floatingHeaderOffset else {
            return
        }
        
        let _ = size
        let _ = insets
        
        if let topPanel = self.topPanel, let topPanelSize = topPanel.size {
            let minY: CGFloat = visualNavigationHeight - 44.0 + topPanelSize.height
            
            if let topPanelView = topPanel.view.view {
                var animateIn = false
                var topPanelTransition = transition
                if topPanelView.bounds.isEmpty {
                    topPanelTransition = .immediate
                    animateIn = true
                }
                topPanelTransition.updateFrame(view: topPanelView, frame: CGRect(origin: CGPoint(x: 0.0, y: max(minY, offset - topPanelSize.height)), size: topPanelSize))
                if animateIn {
                    transition.animatePositionAdditive(layer: topPanelView.layer, offset: CGPoint(x: 0.0, y: -topPanelView.bounds.height))
                }
            }
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.listNode.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.listNode.updateThemeAndStrings(theme: presentationData.theme, fontSize: presentationData.listsFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
        
        self.emptyNode?.updateThemeAndStrings(theme: presentationData.theme, strings: presentationData.strings)
    }
    
    func updateLayout(size: CGSize, insets: UIEdgeInsets, visualNavigationHeight: CGFloat, originalNavigationHeight: CGFloat, inlineNavigationLocation: ChatListControllerLocation?, inlineNavigationTransitionFraction: CGFloat, storiesInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets, visualNavigationHeight, originalNavigationHeight, inlineNavigationLocation, inlineNavigationTransitionFraction, storiesInset)
        
        var listInsets = insets
        var additionalTopInset: CGFloat = 0.0
        
        if let chatFolderUpdates = self.chatFolderUpdates {
            let topPanel: TopPanelItem
            var topPanelTransition = ComponentTransition(transition)
            if let current = self.topPanel {
                topPanel = current
            } else {
                topPanelTransition = .immediate
                topPanel = TopPanelItem()
                self.topPanel = topPanel
            }
            
            let title: String = self.presentationData.strings.ChatList_PanelNewChatsAvailable(Int32(chatFolderUpdates.availableChatsToJoin))
            
            let topPanelHeight: CGFloat = 44.0
            
            let _ = topPanel.view.update(
                transition: topPanelTransition,
                component: AnyComponent(ActionPanelComponent(
                    theme: self.presentationData.theme,
                    title: title,
                    color: .accent,
                    action: { [weak self] in
                        guard let self, let chatFolderUpdates = self.chatFolderUpdates else {
                            return
                        }
                        
                        self.listNode.push?(ChatFolderLinkPreviewScreen(context: self.context, subject: .updates(chatFolderUpdates), contents: chatFolderUpdates.chatFolderLinkContents))
                    },
                    dismissAction: { [weak self] in
                        guard let self, let chatFolderUpdates = self.chatFolderUpdates else {
                            return
                        }
                        let _ = self.context.engine.peers.hideChatFolderUpdates(folderId: chatFolderUpdates.folderId).startStandalone()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: topPanelHeight)
            )
            if let topPanelView = topPanel.view.view {
                if topPanelView.superview == nil {
                    self.view.addSubview(topPanelView)
                }
            }
            
            topPanel.size = CGSize(width: size.width, height: topPanelHeight)
            listInsets.top += topPanelHeight
            additionalTopInset += topPanelHeight
        } else if self.canReportPeer {
            let topPanel: TopPanelItem
            var topPanelTransition = ComponentTransition(transition)
            if let current = self.topPanel {
                topPanel = current
            } else {
                topPanelTransition = .immediate
                topPanel = TopPanelItem()
                self.topPanel = topPanel
            }
            
            let title: String = self.presentationData.strings.Conversation_ReportSpamAndLeave
            
            let topPanelHeight: CGFloat = 44.0
            
            let _ = topPanel.view.update(
                transition: topPanelTransition,
                component: AnyComponent(ActionPanelComponent(
                    theme: self.presentationData.theme,
                    title: title,
                    color: .destructive,
                    action: { [weak self] in
                        guard let self, case let .forum(peerId) = self.location else {
                            return
                        }
                        
                        let actionSheet = ActionSheetController(presentationData: self.presentationData)
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetTextItem(title: self.presentationData.strings.Conversation_ReportSpamGroupConfirmation),
                                ActionSheetButtonItem(title: self.presentationData.strings.Conversation_ReportSpamAndLeave, color: .destructive, action: { [weak self, weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    if let self {
                                        self.controller?.setInlineChatList(location: nil)
                                        let _ = self.context.engine.peers.removePeerChat(peerId: peerId, reportChatSpam: true).startStandalone()
                                    }
                                })
                            ]),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        self.listNode.present?(actionSheet)
                    },
                    dismissAction: { [weak self] in
                        guard let self, case let .forum(peerId) = self.location else {
                            return
                        }
                        let _ = self.context.engine.peers.dismissPeerStatusOptions(peerId: peerId).startStandalone()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: topPanelHeight)
            )
            if let topPanelView = topPanel.view.view {
                if topPanelView.superview == nil {
                    self.view.addSubview(topPanelView)
                }
            }
            
            topPanel.size = CGSize(width: size.width, height: topPanelHeight)
            listInsets.top += topPanelHeight
            additionalTopInset += topPanelHeight
        } else {
            if let topPanel = self.topPanel {
                self.topPanel = nil
                if let topPanelView = topPanel.view.view {
                    transition.updatePosition(layer: topPanelView.layer, position: CGPoint(x: topPanelView.layer.position.x, y: topPanelView.layer.position.y - topPanelView.layer.bounds.height), completion: { [weak topPanelView] _ in
                        topPanelView?.removeFromSuperview()
                    })
                }
            }
        }
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: size, insets: listInsets, duration: duration, curve: curve)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets, visibleTopInset: visualNavigationHeight + additionalTopInset, originalTopInset: originalNavigationHeight + additionalTopInset, storiesInset: storiesInset, inlineNavigationLocation: inlineNavigationLocation, inlineNavigationTransitionFraction: inlineNavigationTransitionFraction)
        
        if let emptyNode = self.emptyNode {
            let emptyNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height))
            transition.updateFrame(node: emptyNode, frame: emptyNodeFrame)
            emptyNode.updateLayout(size: emptyNodeFrame.size, insets: listInsets, transition: transition)
            
            if let scrollingOffset = self.scrollingOffset {
                emptyNode.updateScrollingOffset(navigationHeight: scrollingOffset.navigationHeight, offset: scrollingOffset.offset, transition: transition)
            }
        }
        
        self.layoutAdditionalPanels(transition: transition)
    }
    
    func updateScrollingOffset(navigationHeight: CGFloat, offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.scrollingOffset = (navigationHeight, offset)
        
        if let emptyNode = self.emptyNode {
            emptyNode.updateScrollingOffset(navigationHeight: navigationHeight, offset: offset, transition: transition)
        }
    }
}
