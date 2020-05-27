import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import StickerPackPreviewUI
import OverlayStatusController
import PresentationDataUtils
import SearchBarNode
import UndoUI
import SegmentedControlNode

private final class DrawingStickersScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    fileprivate var selectSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?
    private var searchItemContext = StickerPaneSearchGlobalItemContext()
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    private let controllerInteraction: ChatControllerInteraction
    private var inputNodeInteraction: ChatMediaInputNodeInteraction!
    
    private let collectionListPanel: ASDisplayNode
    private let collectionListContainer: CollectionListContainerNode
    
    private let blurView: UIView
    
    private let topPanel: ASDisplayNode
    private let segmentedControlNode: SegmentedControlNode
    private let cancelButton: HighlightableButtonNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private let listView: ListView
    
    private var searchContainerNode: PaneSearchContainerNode?
    private let searchContainerNodeLoadedDisposable = MetaDisposable()
    
    private let stickerPane: ChatMediaInputStickerPane
    
    private let itemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentStickerPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentView: ItemCollectionsView?
    
    private var paneArrangement: ChatMediaInputPaneArrangement
    private var initializedArrangement = false
            
    private var validLayout: ContainerViewLayout?
    
    private var disposable = MetaDisposable()
        
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady: Bool = false
    
    fileprivate var dismiss: (() -> Void)?
    
    init(context: AccountContext, selectSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.selectSticker = selectSticker
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        var selectStickerImpl: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?
        
        self.controllerInteraction = ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _, _, _, _, _ in }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _ in }, tapMessage: nil, clickThroughMessage: { }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _ in }, sendMessage: { _ in }, sendSticker: { fileReference, _, node, rect in return selectStickerImpl?(fileReference, node, rect) ?? false }, sendGif: { _, _, _ in return false }, sendBotContextResultAsGif: { _, _, _, _ in return false }, requestMessageActionCallback: { _, _, _ in }, requestMessageActionUrlAuth: { _, _, _ in }, activateSwitchInline: { _, _ in }, openUrl: { _, _, _, _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, reactionContainerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _ in }, longTap: { _, _ in }, openCheckoutOrReceipt: { _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return .none
        }, navigateToFirstDateMessage: { _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: {
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _ in
        }, updateMessageLike: { _, _ in
        }, openMessageReactions: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: {
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
           pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: true))
        
        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        
        self.topPanel = ASDisplayNode()
        self.topPanel.clipsToBounds = true
        self.topPanel.backgroundColor = UIColor(rgb: 0x151515)
        self.topPanel.alpha = 0.3
        
        let segmentedTheme = SegmentedControlTheme(backgroundColor: UIColor(rgb: 0x2c2d2d), foregroundColor: UIColor(rgb: 0x656565), shadowColor: UIColor.clear, textColor: .white, dividerColor: .white)
        self.segmentedControlNode = SegmentedControlNode(theme: segmentedTheme, items: [SegmentedControlItem(title: self.presentationData.strings.Paint_Stickers), SegmentedControlItem(title: self.presentationData.strings.Paint_Masks)], selectedIndex: 0)
        
        self.cancelButton = HighlightableButtonNode()
        self.cancelButton.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: .white), for: .normal)
        
        self.collectionListPanel = ASDisplayNode()
        self.collectionListPanel.clipsToBounds = true
        self.collectionListPanel.backgroundColor = UIColor(rgb: 0x151515)
        self.collectionListPanel.alpha = 0.3
        
        self.collectionListContainer = CollectionListContainerNode()
        self.collectionListContainer.clipsToBounds = true
        
        self.listView = ListView()
        self.listView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = UIColor(rgb: 0x2c2d2d)
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.backgroundColor = UIColor(rgb: 0x2c2d2d)
        
        var paneDidScrollImpl: ((ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void)?
        self.stickerPane = ChatMediaInputStickerPane(theme: self.presentationData.theme, strings: self.presentationData.strings, paneDidScroll: { pane, state, transition in
            paneDidScrollImpl?(pane, state, transition)
        }, fixPaneScroll: { pane, state in
            //            fixPaneScrollImpl?(pane, state)
        })
        
        self.paneArrangement = ChatMediaInputPaneArrangement(panes: [.stickers], currentIndex: 0, indexTransition: 0.0)
        
        super.init()
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        
        self.view.addSubview(self.blurView)
        
        self.inputNodeInteraction = ChatMediaInputNodeInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentView, (collectionId != strongSelf.inputNodeInteraction.highlightedItemCollectionId || true) {
                var index: Int32 = 0
                if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
                    strongSelf.setCurrentPane(.gifs, transition: .animated(duration: 0.25, curve: .spring))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue {
                    strongSelf.controllerInteraction.navigationController()?.pushViewController(FeaturedStickersScreen(
                        context: strongSelf.context,
                        sendSticker: {
                            fileReference, sourceNode, sourceRect in
                            if let strongSelf = self {
                                return strongSelf.controllerInteraction.sendSticker(fileReference, false, sourceNode, sourceRect)
                            } else {
                                return false
                            }
                        }
                    ))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    for (id, _, _) in currentView.collectionInfos {
                        if id.namespace == collectionId.namespace {
                            if id == collectionId {
                                let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                                strongSelf.currentStickerPacksCollectionPosition = .navigate(index: itemIndex, collectionId: nil)
                                strongSelf.itemCollectionsViewPosition.set(.single(.navigate(index: itemIndex, collectionId: nil)))
                                break
                            }
                            index += 1
                        }
                    }
                }
            }
        }, navigateBackToStickers: {
        }, setGifMode: { _ in
        }, openSettings: { [weak self] in
            if let strongSelf = self {
//                let controller = installedStickerPacksController(context: context, mode: .modal)
//                controller.navigationPresentation = .modal
//                strongSelf.controllerInteraction.navigationController()?.pushViewController(controller)
            }
        }, toggleSearch: { [weak self] value, searchMode, query in
            if let strongSelf = self {
                if let searchMode = searchMode, value {
                    var searchContainerNode: PaneSearchContainerNode?
                    if let current = strongSelf.searchContainerNode {
                        searchContainerNode = current
                    } else {
                        searchContainerNode = PaneSearchContainerNode(context: strongSelf.context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, controllerInteraction: strongSelf.controllerInteraction, inputNodeInteraction: strongSelf.inputNodeInteraction, mode: searchMode, trendingGifsPromise: Promise(nil), cancel: {
                            self?.searchContainerNode?.deactivate()
                            self?.inputNodeInteraction.toggleSearch(false, nil, "")
                        })
                        strongSelf.searchContainerNode = searchContainerNode
                        if !query.isEmpty {
                            DispatchQueue.main.async {
                                searchContainerNode?.updateQuery(query)
                            }
                        }
                    }
                    if let searchContainerNode = searchContainerNode {
                        strongSelf.searchContainerNodeLoadedDisposable.set((searchContainerNode.ready
                        |> deliverOnMainQueue).start(next: {
                            if let strongSelf = self {
                                strongSelf.controllerInteraction.updateInputMode { current in
                                    switch current {
                                        case let .media(mode, _):
                                            return .media(mode: mode, expanded: .search(searchMode))
                                        default:
                                            return current
                                    }
                                }
                            }
                        }))
                    }
                } else {
                    strongSelf.controllerInteraction.updateInputMode { current in
                        switch current {
                            case let .media(mode, _):
                                return .media(mode: mode, expanded: nil)
                            default:
                                return current
                        }
                    }
                }
            }
        }, openPeerSpecificSettings: { [weak self] in
        }, dismissPeerSpecificSettings: { [weak self] in
        }, clearRecentlyUsedStickers: { [weak self] in
            if let strongSelf = self {
                let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: strongSelf.presentationData.theme, fontSize: strongSelf.presentationData.listsFontSize))
                var items: [ActionSheetItem] = []
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Stickers_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    let _ = (context.account.postbox.transaction { transaction in
                        clearRecentlyUsedStickers(transaction: transaction)
                    }).start()
                }))
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.controllerInteraction.presentController(actionSheet, nil)
            }
        })
        self.inputNodeInteraction.stickerSettings = ChatInterfaceStickerSettings(loopAnimatedStickers: true)
        
        
        self.addSubnode(self.topPanel)
        
        self.collectionListContainer.addSubnode(self.collectionListPanel)
        self.collectionListContainer.addSubnode(self.listView)
        self.addSubnode(self.collectionListContainer)
        
        self.addSubnode(self.segmentedControlNode)
        self.addSubnode(self.cancelButton)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
       
        let trendingInteraction = TrendingPaneInteraction(installPack: { [weak self] info in
        }, openPack: { [weak self] info in
        }, getItemIsPreviewed: { item in
            return false
        }, openSearch: {
        })
        
        let itemCollectionsView = self.itemCollectionsViewPosition.get()
            |> distinctUntilChanged
            |> mapToSignal { position -> Signal<(ItemCollectionsView, StickerPacksCollectionUpdate), NoError> in
                switch position {
                    case .initial:
                        var firstTime = true
                        return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 50)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .initial
                                } else {
                                    update = .generic
                                }
                                return (view, update)
                    }
                    case let .scroll(aroundIndex):
                        var firstTime = true
                        return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: aroundIndex, count: 300)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .scroll
                                } else {
                                    update = .generic
                                }
                                return (view, update)
                    }
                    case let .navigate(index, collectionId):
                        var firstTime = true
                        return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: index, count: 300)
                            |> map { view -> (ItemCollectionsView, StickerPacksCollectionUpdate) in
                                let update: StickerPacksCollectionUpdate
                                if firstTime {
                                    firstTime = false
                                    update = .navigate(index, collectionId)
                                } else {
                                    update = .generic
                                }
                                return (view, update)
                    }
                }
        }
        
        let controllerInteraction = self.controllerInteraction
        let inputNodeInteraction = self.inputNodeInteraction!
        
        let previousEntries = Atomic<([ChatMediaInputPanelEntry], [ChatMediaInputGridEntry])>(value: ([], []))
        let previousView = Atomic<ItemCollectionsView?>(value: nil)
        let transitionQueue = Queue()
        let transitions = combineLatest(queue: transitionQueue, itemCollectionsView, context.account.viewTracker.featuredStickerPacks(), self.themeAndStringsPromise.get())
            |> map { viewAndUpdate, trendingPacks, themeAndStrings -> (ItemCollectionsView, ChatMediaInputPanelTransition, Bool, ChatMediaInputGridTransition, Bool) in
                let (view, viewUpdate) = viewAndUpdate
                let previous = previousView.swap(view)
                var update = viewUpdate
                if previous === view {
                    update = .generic
                }
                let (theme, strings) = themeAndStrings
                
                var savedStickers: OrderedItemListView?
                var recentStickers: OrderedItemListView?
                for orderedView in view.orderedItemListsViews {
                    if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentStickers {
                        recentStickers = orderedView
                    } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudSavedStickers {
                        savedStickers = orderedView
                    }
                }
                
                var installedPacks = Set<ItemCollectionId>()
                for info in view.collectionInfos {
                    installedPacks.insert(info.0)
                }
                
                var hasUnreadTrending: Bool?
                for pack in trendingPacks {
                    if hasUnreadTrending == nil {
                        hasUnreadTrending = false
                    }
                    if pack.unread {
                        hasUnreadTrending = true
                        break
                    }
                }
                
                let panelEntries = chatMediaInputPanelEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, peerSpecificPack: nil, canInstallPeerSpecificPack: .none, hasUnreadTrending: nil, theme: theme, hasGifs: false)
                let gridEntries = chatMediaInputGridEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, peerSpecificPack: nil, canInstallPeerSpecificPack: .none, hasSearch: false, strings: strings, theme: theme)
                
                if view.higher == nil {
                    var hasTopSeparator = true
                    if gridEntries.count == 1, case .search = gridEntries[0] {
                        hasTopSeparator = false
                    }
                    
                    var index = 0
                    for item in trendingPacks {
                        if !installedPacks.contains(item.info.id) {
//                            gridEntries.append(.trending(TrendingPanePackEntry(index: index, info: item.info, theme: theme, strings: strings, topItems: item.topItems, installed: installedPacks.contains(item.info.id), unread: item.unread, topSeparator: hasTopSeparator)))
//                            hasTopSeparator = true
//                            index += 1
                        }
                    }
                }
                
                let (previousPanelEntries, previousGridEntries) = previousEntries.swap((panelEntries, gridEntries))
                return (view, preparedChatMediaInputPanelEntryTransition(context: context, from: previousPanelEntries, to: panelEntries, inputNodeInteraction: inputNodeInteraction), previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: context.account, view: view, from: previousGridEntries, to: gridEntries, update: update, interfaceInteraction: controllerInteraction, inputNodeInteraction: inputNodeInteraction, trendingInteraction: trendingInteraction), previousGridEntries.isEmpty)
        }
        
        self.disposable.set((transitions
            |> deliverOnMainQueue).start(next: { [weak self] (view, panelTransition, panelFirstTime, gridTransition, gridFirstTime) in
                if let strongSelf = self {
                    strongSelf.currentView = view
                    strongSelf.enqueuePanelTransition(panelTransition, firstTime: panelFirstTime, thenGridTransition: gridTransition, gridFirstTime: gridFirstTime)
                    if !strongSelf.initializedArrangement {
                        strongSelf.initializedArrangement = true
                        let currentPane = strongSelf.paneArrangement.panes[strongSelf.paneArrangement.currentIndex]
                        if currentPane != strongSelf.paneArrangement.panes[strongSelf.paneArrangement.currentIndex] {
                            strongSelf.setCurrentPane(currentPane, transition: .immediate)
                        }
                    }
                }
            }))
        
        self.stickerPane.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
            if let strongSelf = self {
                var topVisibleCollectionId: ItemCollectionId?
                
                if let topVisibleSection = visibleItems.topSectionVisible as? ChatMediaInputStickerGridSection {
                    topVisibleCollectionId = topVisibleSection.collectionId
                } else if let topVisible = visibleItems.topVisible {
                    if let item = topVisible.1 as? ChatMediaInputStickerGridItem {
                        topVisibleCollectionId = item.index.collectionId
                    } else if let _ = topVisible.1 as? StickerPanePeerSpecificSetupGridItem {
                        topVisibleCollectionId = ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue, id: 0)
                    }
                }
                if let collectionId = topVisibleCollectionId {
                    if strongSelf.inputNodeInteraction.highlightedItemCollectionId != collectionId {
                        strongSelf.setHighlightedItemCollectionId(collectionId)
                    }
                }
                
                if let currentView = strongSelf.currentView, let (topIndex, topItem) = visibleItems.top, let (bottomIndex, bottomItem) = visibleItems.bottom {
                    if topIndex <= 10 && currentView.lower != nil {
                        let position: StickerPacksCollectionPosition = clipScrollPosition(.scroll(aroundIndex: (topItem as! ChatMediaInputStickerGridItem).index))
                        if strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.itemCollectionsViewPosition.set(.single(position))
                        }
                    } else if bottomIndex >= visibleItems.count - 10 && currentView.higher != nil {
                        var position: StickerPacksCollectionPosition?
                        if let bottomItem = bottomItem as? ChatMediaInputStickerGridItem {
                            position = clipScrollPosition(.scroll(aroundIndex: bottomItem.index))
                        }
                        
                        if let position = position, strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.itemCollectionsViewPosition.set(.single(position))
                        }
                    }
                }
            }
        }
        
        self.currentStickerPacksCollectionPosition = .initial
        self.itemCollectionsViewPosition.set(.single(.initial))
        
        self.stickerPane.inputNodeInteraction = self.inputNodeInteraction
        
        paneDidScrollImpl = { [weak self] pane, state, transition in
            self?.updatePaneDidScroll(pane: pane, state: state, transition: transition)
        }
        
        selectStickerImpl = { [weak self] fileReference, node, rect in
            return self?.selectSticker?(fileReference, node, rect) ?? false
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    @objc private func cancelPressed() {
        self.dismiss?()
    }
    
    private func setHighlightedItemCollectionId(_ collectionId: ItemCollectionId) {
        if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue {
            if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs {
                self.inputNodeInteraction.highlightedItemCollectionId = collectionId
            }
        } else {
            self.inputNodeInteraction.highlightedStickerItemCollectionId = collectionId
            if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .stickers {
                self.inputNodeInteraction.highlightedItemCollectionId = collectionId
            }
        }
        var ensuredNodeVisible = false
        var firstVisibleCollectionId: ItemCollectionId?
        self.listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMediaInputStickerPackItemNode {
                if firstVisibleCollectionId == nil {
                    firstVisibleCollectionId = itemNode.currentCollectionId
                }
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputRecentGifsItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputTrendingItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputPeerSpecificItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.listView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            }
        }
        
        if let currentView = self.currentView, let firstVisibleCollectionId = firstVisibleCollectionId, !ensuredNodeVisible {
            let targetIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == collectionId })
            let firstVisibleIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == firstVisibleCollectionId })
            if let targetIndex = targetIndex, let firstVisibleIndex = firstVisibleIndex {
                let toRight = targetIndex > firstVisibleIndex
                self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], scrollToItem: ListViewScrollToItem(index: targetIndex, position: toRight ? .bottom(0.0) : .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: toRight ? .Down : .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil)
            }
        }
    }
    
    private func setCurrentPane(_ pane: ChatMediaInputPaneType, transition: ContainedViewLayoutTransition, collectionIdHint: Int32? = nil) {
        var transition = transition
        
        if let index = self.paneArrangement.panes.firstIndex(of: pane), index != self.paneArrangement.currentIndex {
            let previousGifPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs
            //let previousTrendingPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .trending
            self.paneArrangement = self.paneArrangement.withIndexTransition(0.0).withCurrentIndex(index)
            let updatedGifPanelWasActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .gifs
            //let updatedTrendingPanelIsActive = self.paneArrangement.panes[self.paneArrangement.currentIndex] == .trending
            
            /*if updatedTrendingPanelIsActive != previousTrendingPanelWasActive {
             transition = .immediate
             }*/
            
//            if let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible) = self.validLayout {
//                let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: transition, interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
//                self.updateAppearanceTransition(transition: transition)
//            }
//            if updatedGifPanelWasActive != previousGifPanelWasActive {
//                self.gifPaneIsActiveUpdated(updatedGifPanelWasActive)
//            }
            switch pane {
                case .gifs:
                    self.setHighlightedItemCollectionId(ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.recentGifs.rawValue, id: 0))
                case .stickers:
                    if let highlightedStickerCollectionId = self.inputNodeInteraction.highlightedStickerItemCollectionId {
                        self.setHighlightedItemCollectionId(highlightedStickerCollectionId)
                    } else if let collectionIdHint = collectionIdHint {
                        self.setHighlightedItemCollectionId(ItemCollectionId(namespace: collectionIdHint, id: 0))
                }
                /*case .trending:
                 self.setHighlightedItemCollectionId(ItemCollectionId(namespace: ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue, id: 0))*/
            }
            /*if updatedTrendingPanelIsActive != previousTrendingPanelWasActive {
             self.controllerInteraction.updateInputMode { current in
             switch current {
             case let .media(mode, _):
             if updatedTrendingPanelIsActive {
             return .media(mode: mode, expanded: .content)
             } else {
             return .media(mode: mode, expanded: nil)
             }
             default:
             return current
             }
             }
             }*/
        } else {
//            if let (width, leftInset, rightInset, bottomInset, standardInputHeight, inputHeight, maximumHeight, inputPanelHeight, interfaceState, deviceMetrics, isVisible) = self.validLayout {
//                let _ = self.updateLayout(width: width, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, standardInputHeight: standardInputHeight, inputHeight: inputHeight, maximumHeight: maximumHeight, inputPanelHeight: inputPanelHeight, transition: .animated(duration: 0.25, curve: .spring), interfaceState: interfaceState, deviceMetrics: deviceMetrics, isVisible: isVisible)
//            }
        }
    }
    
    private func currentCollectionListPanelOffset() -> CGFloat {
        let paneOffsets = self.paneArrangement.panes.map { pane -> CGFloat in
            return self.stickerPane.collectionListPanelOffset
        }
        
        let mainOffset = paneOffsets[self.paneArrangement.currentIndex]
        if self.paneArrangement.indexTransition.isZero {
            return mainOffset
        } else {
            var sideOffset: CGFloat?
            if self.paneArrangement.indexTransition < 0.0 {
                if self.paneArrangement.currentIndex != 0 {
                    sideOffset = paneOffsets[self.paneArrangement.currentIndex - 1]
                }
            } else {
                if self.paneArrangement.currentIndex != paneOffsets.count - 1 {
                    sideOffset = paneOffsets[self.paneArrangement.currentIndex + 1]
                }
            }
            if let sideOffset = sideOffset {
                let interpolator = CGFloat.interpolator()
                let value = interpolator(mainOffset, sideOffset, abs(self.paneArrangement.indexTransition)) as! CGFloat
                return value
            } else {
                return mainOffset
            }
        }
    }
    
    func updateLayout(width: CGFloat, topInset: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        var searchMode: ChatMediaInputSearchMode?
                
        var displaySearch = false
        let separatorHeight = max(UIScreenPixel, 1.0 - UIScreenPixel)
        let topPanelHeight: CGFloat = 56.0
        let panelHeight: CGFloat
        
        var isExpanded: Bool = true
//            switch expanded {
//                case .content:
                    panelHeight = maximumHeight
//                case let .search(mode):
//                    panelHeight = maximumHeight
//                    displaySearch = true
//                    searchMode = mode
//            }
        self.stickerPane.collectionListPanelOffset = 0.0
        
        transition.updateFrame(node: self.topPanel, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: topInset + topPanelHeight)))
        
        var cancelSize = self.cancelButton.measure(CGSize(width: width, height: .greatestFiniteMagnitude))
        cancelSize.width += 16.0 * 2.0
        transition.updateFrame(node: self.cancelButton, frame: CGRect(origin: CGPoint(x: width - cancelSize.width, y: topInset + floorToScreenPixels((topPanelHeight - cancelSize.height) / 2.0)), size: cancelSize))
        
        let controlSize = self.segmentedControlNode.updateLayout(.stretchToFill(width: width - cancelSize.width - 16.0 * 2.0), transition: transition)
        transition.updateFrame(node: self.segmentedControlNode, frame: CGRect(origin: CGPoint(x: 16.0, y: topInset + floorToScreenPixels((topPanelHeight - controlSize.height) / 2.0)), size: controlSize))
        
        if displaySearch {
            if let searchContainerNode = self.searchContainerNode {
                let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: -inputPanelHeight), size: CGSize(width: width, height: panelHeight + inputPanelHeight))
                if searchContainerNode.supernode != nil {
                    transition.updateFrame(node: searchContainerNode, frame: containerFrame)
                    searchContainerNode.updateLayout(size: containerFrame.size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: transition)
                } else {
                    self.searchContainerNode = searchContainerNode
                    self.insertSubnode(searchContainerNode, belowSubnode: self.collectionListContainer)
                    searchContainerNode.frame = containerFrame
                    searchContainerNode.updateLayout(size: containerFrame.size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: .immediate)
                    var placeholderNode: PaneSearchBarPlaceholderNode?
                    var anchorTop = CGPoint(x: 0.0, y: 0.0)
                    var anchorTopView: UIView = self.view
                    if let searchMode = searchMode {
                        switch searchMode {
                        case .sticker:
                            self.stickerPane.gridNode.forEachItemNode { itemNode in
                                if let itemNode = itemNode as? PaneSearchBarPlaceholderNode {
                                    placeholderNode = itemNode
                                }
                            }
                        default:
                            break
                        }
                    }
                    
                    if let placeholderNode = placeholderNode {
                        searchContainerNode.animateIn(from: placeholderNode, anchorTop: anchorTop, anhorTopView: anchorTopView, transition: transition, completion: { [weak self] in
                        })
                    }
                }
            }
        }
        
        let bottomPanelHeight: CGFloat = 49.0
        let contentVerticalOffset: CGFloat = displaySearch ? -(inputPanelHeight + 41.0) : 0.0
        
        let collectionListPanelOffset: CGFloat = 0.0
        
        transition.updateFrame(view: self.blurView, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: maximumHeight)))
        
        transition.updateFrame(node: self.collectionListContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: maximumHeight + contentVerticalOffset - bottomPanelHeight - bottomInset), size: CGSize(width: width, height: max(0.0, bottomPanelHeight + UIScreenPixel + bottomInset))))
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: bottomPanelHeight + bottomInset)))
        
        self.listView.bounds = CGRect(x: 0.0, y: 0.0, width: bottomPanelHeight, height: width)
        transition.updatePosition(node: self.listView, position: CGPoint(x: width / 2.0, y: (bottomPanelHeight - collectionListPanelOffset) / 2.0))
        
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + topPanelHeight), size: CGSize(width: width, height: separatorHeight)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: maximumHeight + contentVerticalOffset - bottomPanelHeight - bottomInset), size: CGSize(width: width, height: separatorHeight)))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: bottomPanelHeight, height: width), insets: UIEdgeInsets(top: 4.0 + leftInset, left: 0.0, bottom: 4.0 + rightInset, right: 0.0), duration: duration, curve: curve)
        
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        var visiblePanes: [(ChatMediaInputPaneType, CGFloat)] = []
        
        var paneIndex = 0
        for pane in self.paneArrangement.panes {
            let paneOrigin = CGFloat(paneIndex - self.paneArrangement.currentIndex) * width - self.paneArrangement.indexTransition * width
            if paneOrigin.isLess(than: width) && CGFloat(0.0).isLess(than: (paneOrigin + width)) {
                visiblePanes.append((pane, paneOrigin))
            }
            paneIndex += 1
        }
        
        for (pane, paneOrigin) in visiblePanes {
            let paneFrame = CGRect(origin: CGPoint(x: paneOrigin + leftInset, y: topInset + topPanelHeight), size: CGSize(width: width - leftInset - rightInset, height: panelHeight - topInset - topPanelHeight - bottomInset - bottomPanelHeight))
            switch pane {
                case .stickers:
                    if self.stickerPane.supernode == nil {
                        self.insertSubnode(self.stickerPane, belowSubnode: self.collectionListContainer)
                        self.stickerPane.frame = CGRect(origin: CGPoint(x: width, y: topInset + topPanelHeight), size: CGSize(width: width, height: panelHeight - topInset - topPanelHeight  - bottomInset - bottomPanelHeight))
                    }
                    if self.stickerPane.frame != paneFrame {
                        self.stickerPane.layer.removeAnimation(forKey: "position")
                        transition.updateFrame(node: self.stickerPane, frame: paneFrame)
                    }
                default:
                    break
            }
        }
        
        self.stickerPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight - topInset - topPanelHeight - bottomInset - bottomPanelHeight), topInset: 0.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: true, deviceMetrics: deviceMetrics, transition: transition)
    
        if !displaySearch, let searchContainerNode = self.searchContainerNode {
            self.searchContainerNode = nil
            self.searchContainerNodeLoadedDisposable.set(nil)
            
            var paneIsEmpty = false
            var placeholderNode: PaneSearchBarPlaceholderNode?
            if let searchMode = searchMode {
                switch searchMode {
                    case .sticker:
                        paneIsEmpty = true
                        self.stickerPane.gridNode.forEachItemNode { itemNode in
                            if let itemNode = itemNode as? PaneSearchBarPlaceholderNode {
                                placeholderNode = itemNode
                            }
                            if let _ = itemNode as? ChatMediaInputStickerGridItemNode {
                                paneIsEmpty = false
                            }
                    }
                    default:
                        break
                }
            }
            if let placeholderNode = placeholderNode {
                searchContainerNode.animateOut(to: placeholderNode, animateOutSearchBar: !paneIsEmpty, transition: transition, completion: { [weak searchContainerNode] in
                    searchContainerNode?.removeFromSupernode()
                })
            } else {
                searchContainerNode.removeFromSupernode()
            }
        }
        
//        if let panRecognizer = self.panRecognizer, panRecognizer.isEnabled != !displaySearch {
//            panRecognizer.isEnabled = !displaySearch
//        }
//
        
        return (standardInputHeight, max(0.0, panelHeight - standardInputHeight))
    }
    
    private func enqueuePanelTransition(_ transition: ChatMediaInputPanelTransition, firstTime: Bool, thenGridTransition gridTransition: ChatMediaInputGridTransition, gridFirstTime: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else {
            options.insert(.AnimateInsertion)
        }
        self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.enqueueGridTransition(gridTransition, firstTime: gridFirstTime)
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf._ready.set(.single(true))
                }
            }
        })
    }
    
    private func enqueueGridTransition(_ transition: ChatMediaInputGridTransition, firstTime: Bool) {
        var itemTransition: ContainedViewLayoutTransition = .immediate
        if transition.animated {
            itemTransition = .animated(duration: 0.3, curve: .spring)
        }
        self.stickerPane.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: itemTransition, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset, updateOpaqueState: transition.updateOpaqueState), completion: { _ in })
    }
    
    private func updatePaneDidScroll(pane: ChatMediaInputPane, state: ChatMediaInputPaneScrollState, transition: ContainedViewLayoutTransition) {
        pane.collectionListPanelOffset = 0.0
        
//        let collectionListPanelOffset = self.currentCollectionListPanelOffset()
//
//        self.updateAppearanceTransition(transition: transition)
//        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: collectionListPanelOffset), size: self.collectionListPanel.bounds.size))
//        transition.updateFrame(node: self.collectionListSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0 + collectionListPanelOffset), size: self.collectionListSeparator.bounds.size))
//        transition.updatePosition(node: self.listView, position: CGPoint(x: self.listView.position.x, y: (41.0 - collectionListPanelOffset) / 2.0))
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut() {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        let insets = layout.insets(options: [.statusBar])
        let height = layout.size.height
        
        let _ = self.updateLayout(width: layout.size.width, topInset: insets.top, leftInset: insets.left, rightInset: insets.right, bottomInset: insets.bottom, standardInputHeight: height, inputHeight: height, maximumHeight: height, inputPanelHeight: height, transition: transition, deviceMetrics: layout.deviceMetrics, isVisible: true)
    }
}

final class DrawingStickersScreen: ViewController {
    private let context: AccountContext
    var selectSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?
    
    private var controllerNode: DrawingStickersScreenNode {
        return self.displayNode as! DrawingStickersScreenNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var didPlayPresentationAnimation = false
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
        
    public init(context: AccountContext, selectSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)? = nil) {
        self.context = context
        self.selectSticker = selectSticker
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.navigationPresentation = .modal
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previous = strongSelf.presentationData
                strongSelf.presentationData = presentationData
                
                if previous.theme !== presentationData.theme || previous.strings !== presentationData.strings {
                    strongSelf.updatePresentationData()
                }
            }
        })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updatePresentationData() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
    }
    
    override public func loadDisplayNode() {
        self.displayNode = DrawingStickersScreenNode(
            context: self.context,
            selectSticker: { [weak self] file, sourceNode, sourceRect in
                if let strongSelf = self, let selectSticker = strongSelf.selectSticker {
                    return selectSticker(file, sourceNode, sourceRect)
                } else {
                    return false
                }
            }
        )
        (self.displayNode as! DrawingStickersScreenNode).dismiss = { [weak self] in
            self?.dismiss()
        }
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            (self.displayNode as! DrawingStickersScreenNode).animateIn()
        }
    }
    
//    override public func inFocusUpdated(isInFocus: Bool) {
//        self.controllerNode.inFocusUpdated(isInFocus: isInFocus)
//    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: 0.0, transition: transition)
    }
}
