import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
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
import LegacyComponents
import ChatPresentationInterfaceState

private enum DrawingPaneType {
    case stickers
    case masks
}

private struct DrawingPaneArrangement {
    let panes: [DrawingPaneType]
    let currentIndex: Int
    let indexTransition: CGFloat
    
    func withIndexTransition(_ indexTransition: CGFloat) -> DrawingPaneArrangement {
        return DrawingPaneArrangement(panes: self.panes, currentIndex: currentIndex, indexTransition: indexTransition)
    }
    
    func withCurrentIndex(_ currentIndex: Int) -> DrawingPaneArrangement {
        return DrawingPaneArrangement(panes: self.panes, currentIndex: currentIndex, indexTransition: self.indexTransition)
    }
}

private final class DrawingStickersScreenNode: ViewControllerTracingNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    fileprivate var selectSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?
    private var searchItemContext = StickerPaneSearchGlobalItemContext()
    private let themeAndStringsPromise: Promise<(PresentationTheme, PresentationStrings)>
    
    private let controllerInteraction: ChatControllerInteraction
    private var stickersNodeInteraction: ChatMediaInputNodeInteraction!
    private var masksNodeInteraction: ChatMediaInputNodeInteraction!
    
    private let collectionListPanel: ASDisplayNode
    private let collectionListContainer: ASDisplayNode
    
    private let blurView: UIView
    
    private let topPanel: ASDisplayNode
    private let segmentedControlNode: SegmentedControlNode
    private let cancelButton: HighlightableButtonNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    
    private let stickerListView: ListView
    private let maskListView: ListView
    private var hiddenListView: ListView?
    
    private var searchContainerNode: PaneSearchContainerNode?
    private let searchContainerNodeLoadedDisposable = MetaDisposable()
    
    private let stickerPane: ChatMediaInputStickerPane
    private let maskPane: ChatMediaInputStickerPane
    private var hiddenPane: ChatMediaInputStickerPane?
    
    private let stickerItemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentStickerPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentStickerView: ItemCollectionsView?
    
    private let maskItemCollectionsViewPosition = Promise<StickerPacksCollectionPosition>()
    private var currentMaskPacksCollectionPosition: StickerPacksCollectionPosition?
    private var currentMaskView: ItemCollectionsView?
    
    private var paneArrangement: DrawingPaneArrangement
    
    private var animatingStickerPaneOut = false
    private var animatingMaskPaneOut = false
     
    private var panRecognizer: UIPanGestureRecognizer?
            
    private var validLayout: ContainerViewLayout?
    
    private var disposable = MetaDisposable()
    private var maskDisposable = MetaDisposable()
    
    private let _ready = Promise<Bool>()
    var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady: Bool = false
    
    fileprivate var dismiss: (() -> Void)?
    
    init(context: AccountContext, selectSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?) {
        self.context = context
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationData = presentationData
        self.selectSticker = selectSticker
        
        self.themeAndStringsPromise = Promise((self.presentationData.theme, self.presentationData.strings))
        
        var selectStickerImpl: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?
        
        self.controllerInteraction = ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _, _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _, _, _, _, _ in }, openMessageReactionContextMenu: { _, _, _, _ in
            }, updateMessageReaction: { _, _ in }, activateMessagePinch: { _ in
            }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _ in }, navigateToMessageStandalone: { _ in
            }, tapMessage: nil, clickThroughMessage: { }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _ in }, sendMessage: { _ in }, sendSticker: { fileReference, _, _, _, _, node, rect in return selectStickerImpl?(fileReference, node, rect) ?? false }, sendGif: { _, _, _, _, _ in return false }, sendBotContextResultAsGif: { _, _, _, _, _ in return false }, requestMessageActionCallback: { _, _, _, _ in }, requestMessageActionUrlAuth: { _, _ in }, activateSwitchInline: { _, _ in }, openUrl: { _, _, _, _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _, _ in }, longTap: { _, _ in }, openCheckoutOrReceipt: { _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return .none
        }, navigateToFirstDateMessage: { _, _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: {
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _ in
        }, displayImportedMessageTooltip: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: { _ in
        }, displayPremiumStickerTooltip: { _, _ in
        }, openPeerContextMenu: { _, _, _, _, _ in
        }, openMessageReplies: { _, _, _ in
        }, openReplyThreadOriginalMessage: { _ in
        }, openMessageStats: { _ in
        }, editMessageMedia: { _, _ in
        }, copyText: { _ in
        }, displayUndo: { _ in
        }, isAnimatingMessage: { _ in
            return false
        }, getMessageTransitionNode: {
            return nil
        }, updateChoosingSticker: { _ in
        }, commitEmojiInteraction: { _, _, _, _ in
        }, openLargeEmojiInfo: { _, _, _ in
        }, openJoinLink: { _ in
        }, openWebView: { _, _, _, _ in
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
        pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: true), presentationContext: ChatPresentationContext(context: context, backgroundNode: nil))
        
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
        
        self.collectionListContainer = ASDisplayNode()
        self.collectionListContainer.clipsToBounds = true
        
        self.stickerListView = ListView()
        self.stickerListView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        self.stickerListView.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.maskListView = ListView()
        self.maskListView.transform = CATransform3DMakeRotation(-CGFloat(Double.pi / 2.0), 0.0, 0.0, 1.0)
        self.maskListView.accessibilityPageScrolledString = { row, count in
            return presentationData.strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.backgroundColor = UIColor(rgb: 0x2c2d2d)
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.backgroundColor = UIColor(rgb: 0x2c2d2d)
        
        var paneDidScrollImpl: ((ChatMediaInputPane, ChatMediaInputPaneScrollState, ContainedViewLayoutTransition) -> Void)?
        self.stickerPane = ChatMediaInputStickerPane(theme: self.presentationData.theme, strings: self.presentationData.strings, paneDidScroll: { pane, state, transition in
            paneDidScrollImpl?(pane, state, transition)
        }, fixPaneScroll: { pane, state in

        })
        
        self.maskPane = ChatMediaInputStickerPane(theme: self.presentationData.theme, strings: self.presentationData.strings, paneDidScroll: { pane, state, transition in
            paneDidScrollImpl?(pane, state, transition)
        }, fixPaneScroll: { pane, state in
        
        })
        
        self.paneArrangement = DrawingPaneArrangement(panes: [.stickers, .masks], currentIndex: 0, indexTransition: 0.0)
        
        super.init()
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        
        self.view.addSubview(self.blurView)
        
        self.stickersNodeInteraction = ChatMediaInputNodeInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentStickerView, (collectionId != strongSelf.stickersNodeInteraction.highlightedItemCollectionId || true) {
                var index: Int32 = 0
                if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue {
                    strongSelf.controllerInteraction.navigationController()?.pushViewController(FeaturedStickersScreen(
                        context: strongSelf.context,
                        highlightedPackId: nil,
                        sendSticker: {
                            fileReference, sourceNode, sourceRect in
                            if let strongSelf = self {
                                return strongSelf.controllerInteraction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect)
                            } else {
                                return false
                            }
                        }
                    ))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.stickerItemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.stickerItemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    strongSelf.currentStickerPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.stickerItemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else {
                    strongSelf.setCurrentPane(.stickers, transition: .animated(duration: 0.25, curve: .spring))
                    for (id, _, _) in currentView.collectionInfos {
                        if id.namespace == collectionId.namespace {
                            if id == collectionId {
                                let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                                strongSelf.currentStickerPacksCollectionPosition = .navigate(index: itemIndex, collectionId: nil)
                                strongSelf.stickerItemCollectionsViewPosition.set(.single(.navigate(index: itemIndex, collectionId: nil)))
                                break
                            }
                            index += 1
                        }
                    }
                }
            }
        }, navigateBackToStickers: {
        }, setGifMode: { _ in
        }, openSettings: {
        }, openTrending: { _ in
        }, dismissTrendingPacks: { _ in
        }, toggleSearch: { [weak self] value, searchMode, query in
            if let strongSelf = self {
                if let searchMode = searchMode, value {
                    var searchContainerNode: PaneSearchContainerNode?
                    if let current = strongSelf.searchContainerNode {
                        searchContainerNode = current
                    } else {
                        searchContainerNode = PaneSearchContainerNode(context: strongSelf.context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, controllerInteraction: strongSelf.controllerInteraction, inputNodeInteraction: strongSelf.stickersNodeInteraction, mode: searchMode, trendingGifsPromise: Promise(nil), cancel: {
                            self?.searchContainerNode?.deactivate()
                            self?.stickersNodeInteraction.toggleSearch(false, nil, "")
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
                                        case let .media(mode, _, focused):
                                            return .media(mode: mode, expanded: .search(searchMode), focused: focused)
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
                            case let .media(mode, _, focused):
                                return .media(mode: mode, expanded: nil, focused: focused)
                            default:
                                return current
                        }
                    }
                }
            }
        }, openPeerSpecificSettings: {
        }, dismissPeerSpecificSettings: {
        }, clearRecentlyUsedStickers: { [weak self] in
            if let strongSelf = self {
                let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: strongSelf.presentationData.theme, fontSize: strongSelf.presentationData.listsFontSize))
                var items: [ActionSheetItem] = []
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Stickers_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    let _ = context.engine.stickers.clearRecentlyUsedStickers().start()
                }))
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])])
                strongSelf.controllerInteraction.presentController(actionSheet, nil)
            }
        })
        self.stickersNodeInteraction.stickerSettings = ChatInterfaceStickerSettings(loopAnimatedStickers: true)
        self.stickersNodeInteraction.displayStickerPlaceholder = false
        
        self.masksNodeInteraction = ChatMediaInputNodeInteraction(navigateToCollectionId: { [weak self] collectionId in
            if let strongSelf = self, let currentView = strongSelf.currentMaskView, (collectionId != strongSelf.masksNodeInteraction.highlightedItemCollectionId || true) {
                var index: Int32 = 0
                if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.trending.rawValue {
                    strongSelf.controllerInteraction.navigationController()?.pushViewController(FeaturedStickersScreen(
                        context: strongSelf.context,
                        highlightedPackId: nil,
                        sendSticker: {
                            fileReference, sourceNode, sourceRect in
                            if let strongSelf = self {
                                return strongSelf.controllerInteraction.sendSticker(fileReference, false, false, nil, false, sourceNode, sourceRect)
                            } else {
                                return false
                            }
                    }
                    ))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.savedStickers.rawValue {
                    strongSelf.setCurrentPane(.masks, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentMaskPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.maskItemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.recentStickers.rawValue {
                    strongSelf.setCurrentPane(.masks, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: collectionId.namespace)
                    strongSelf.currentMaskPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.maskItemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else if collectionId.namespace == ChatMediaInputPanelAuxiliaryNamespace.peerSpecific.rawValue {
                    strongSelf.setCurrentPane(.masks, transition: .animated(duration: 0.25, curve: .spring))
                    strongSelf.currentMaskPacksCollectionPosition = .navigate(index: nil, collectionId: collectionId)
                    strongSelf.maskItemCollectionsViewPosition.set(.single(.navigate(index: nil, collectionId: collectionId)))
                } else {
                    strongSelf.setCurrentPane(.masks, transition: .animated(duration: 0.25, curve: .spring))
                    for (id, _, _) in currentView.collectionInfos {
                        if id.namespace == collectionId.namespace {
                            if id == collectionId {
                                let itemIndex = ItemCollectionViewEntryIndex.lowerBound(collectionIndex: index, collectionId: id)
                                strongSelf.currentMaskPacksCollectionPosition = .navigate(index: itemIndex, collectionId: nil)
                                strongSelf.maskItemCollectionsViewPosition.set(.single(.navigate(index: itemIndex, collectionId: nil)))
                                break
                            }
                            index += 1
                        }
                    }
                }
            }
            }, navigateBackToStickers: {
        }, setGifMode: { _ in
        }, openSettings: {
        }, openTrending: { _ in
        }, dismissTrendingPacks: { _ in
        }, toggleSearch: { [weak self] value, searchMode, query in
                if let strongSelf = self {
                    if let searchMode = searchMode, value {
                        var searchContainerNode: PaneSearchContainerNode?
                        if let current = strongSelf.searchContainerNode {
                            searchContainerNode = current
                        } else {
                            searchContainerNode = PaneSearchContainerNode(context: strongSelf.context, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, controllerInteraction: strongSelf.controllerInteraction, inputNodeInteraction: strongSelf.masksNodeInteraction, mode: searchMode, trendingGifsPromise: Promise(nil), cancel: {
                                self?.searchContainerNode?.deactivate()
                                self?.masksNodeInteraction.toggleSearch(false, nil, "")
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
                                                case let .media(mode, _, focused):
                                                    return .media(mode: mode, expanded: .search(searchMode), focused: focused)
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
                                case let .media(mode, _, focused):
                                    return .media(mode: mode, expanded: nil, focused: focused)
                                default:
                                    return current
                            }
                        }
                    }
                }
            }, openPeerSpecificSettings: {
            }, dismissPeerSpecificSettings: {
            }, clearRecentlyUsedStickers: { [weak self] in
                if let strongSelf = self {
                    let actionSheet = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: strongSelf.presentationData.theme, fontSize: strongSelf.presentationData.listsFontSize))
                    var items: [ActionSheetItem] = []
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Stickers_ClearRecent, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        let _ = context.engine.stickers.clearRecentlyUsedStickers().start()
                    }))
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])])
                    strongSelf.controllerInteraction.presentController(actionSheet, nil)
                }
        })
        self.masksNodeInteraction.stickerSettings = ChatInterfaceStickerSettings(loopAnimatedStickers: true)
        self.masksNodeInteraction.displayStickerPlaceholder = false
        
        self.addSubnode(self.topPanel)
        
        self.collectionListContainer.addSubnode(self.collectionListPanel)
        self.addSubnode(self.collectionListContainer)
        
        self.addSubnode(self.segmentedControlNode)
        self.addSubnode(self.cancelButton)
        
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
       
        let trendingInteraction = TrendingPaneInteraction(installPack: { info in
        }, openPack: { info in
        }, getItemIsPreviewed: { item in
            return false
        }, openSearch: {
        })
        
        let stickerItemCollectionsView = self.stickerItemCollectionsViewPosition.get()
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
        
        let maskItemCollectionsView = self.maskItemCollectionsViewPosition.get()
        |> distinctUntilChanged
        |> mapToSignal { position -> Signal<(ItemCollectionsView, StickerPacksCollectionUpdate), NoError> in
            switch position {
                case .initial:
                    var firstTime = true
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudMaskPacks], aroundIndex: nil, count: 50)
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
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudMaskPacks], aroundIndex: aroundIndex, count: 300)
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
                    return context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers], namespaces: [Namespaces.ItemCollection.CloudMaskPacks], aroundIndex: index, count: 300)
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
        let stickersInputNodeInteraction = self.stickersNodeInteraction!
        
        let previousStickerEntries = Atomic<([ChatMediaInputPanelEntry], [ChatMediaInputGridEntry])>(value: ([], []))
        let previousStickerView = Atomic<ItemCollectionsView?>(value: nil)
        
        let stickerTransitions = combineLatest(queue: Queue(), stickerItemCollectionsView, context.account.viewTracker.featuredStickerPacks(), self.themeAndStringsPromise.get())
        |> map { viewAndUpdate, trendingPacks, themeAndStrings -> (ItemCollectionsView, ChatMediaInputPanelTransition, Bool, ChatMediaInputGridTransition, Bool) in
            let (view, viewUpdate) = viewAndUpdate
            let previous = previousStickerView.swap(view)
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
                        
            let panelEntries = chatMediaInputPanelEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, peerSpecificPack: nil, canInstallPeerSpecificPack: .none, theme: theme, strings: strings, hasGifs: false, hasSettings: false)
            let gridEntries = chatMediaInputGridEntries(view: view, savedStickers: savedStickers, recentStickers: recentStickers, peerSpecificPack: nil, canInstallPeerSpecificPack: .none, trendingPacks: [], installedPacks: installedPacks, hasSearch: false, hasAccessories: false, strings: strings, theme: theme, hasPremium: false, isPremiumDisabled: true, trendingIsPremium: false)
            
            let (previousPanelEntries, previousGridEntries) = previousStickerEntries.swap((panelEntries, gridEntries))
            return (view, preparedChatMediaInputPanelEntryTransition(context: context, from: previousPanelEntries, to: panelEntries, inputNodeInteraction: stickersInputNodeInteraction, scrollToItem: nil), previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: context.account, view: view, from: previousGridEntries, to: gridEntries, update: update, interfaceInteraction: controllerInteraction, inputNodeInteraction: stickersInputNodeInteraction, trendingInteraction: trendingInteraction), previousGridEntries.isEmpty)
        }
        
        self.disposable.set((stickerTransitions
        |> deliverOnMainQueue).start(next: { [weak self] (view, panelTransition, panelFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                strongSelf.currentStickerView = view
                strongSelf.enqueuePanelTransition(listView: strongSelf.stickerListView, pane: strongSelf.stickerPane, transition: panelTransition, firstTime: panelFirstTime, thenGridTransition: gridTransition, gridFirstTime: gridFirstTime)
            }
        }))
        
        let masksInputNodeInteraction = self.masksNodeInteraction!
        
        let previousMaskEntries = Atomic<([ChatMediaInputPanelEntry], [ChatMediaInputGridEntry])>(value: ([], []))
        let previousMaskView = Atomic<ItemCollectionsView?>(value: nil)
        
        let maskTransitions = combineLatest(queue: Queue(), maskItemCollectionsView, self.themeAndStringsPromise.get())
        |> map { viewAndUpdate, themeAndStrings -> (ItemCollectionsView, ChatMediaInputPanelTransition, Bool, ChatMediaInputGridTransition, Bool) in
            let (view, viewUpdate) = viewAndUpdate
            let previous = previousMaskView.swap(view)
            var update = viewUpdate
            if previous === view {
                update = .generic
            }
            let (theme, strings) = themeAndStrings
            
            var installedPacks = Set<ItemCollectionId>()
            for info in view.collectionInfos {
                installedPacks.insert(info.0)
            }
            
            let panelEntries = chatMediaInputPanelEntries(view: view, savedStickers: nil, recentStickers: nil, peerSpecificPack: nil, canInstallPeerSpecificPack: .none, theme: theme, strings: strings, hasGifs: false, hasSettings: false)
            let gridEntries = chatMediaInputGridEntries(view: view, savedStickers: nil, recentStickers: nil, peerSpecificPack: nil, canInstallPeerSpecificPack: .none, trendingPacks: [], installedPacks: installedPacks, hasSearch: false, hasAccessories: false, strings: strings, theme: theme, hasPremium: false, isPremiumDisabled: true, trendingIsPremium: false)
                        
            let (previousPanelEntries, previousGridEntries) = previousMaskEntries.swap((panelEntries, gridEntries))
            return (view, preparedChatMediaInputPanelEntryTransition(context: context, from: previousPanelEntries, to: panelEntries, inputNodeInteraction: masksInputNodeInteraction, scrollToItem: nil), previousPanelEntries.isEmpty, preparedChatMediaInputGridEntryTransition(account: context.account, view: view, from: previousGridEntries, to: gridEntries, update: update, interfaceInteraction: controllerInteraction, inputNodeInteraction: masksInputNodeInteraction, trendingInteraction: trendingInteraction), previousGridEntries.isEmpty)
        }
        
        self.maskDisposable.set((maskTransitions
        |> deliverOnMainQueue).start(next: { [weak self] (view, panelTransition, panelFirstTime, gridTransition, gridFirstTime) in
            if let strongSelf = self {
                strongSelf.currentMaskView = view
                strongSelf.enqueuePanelTransition(listView: strongSelf.maskListView, pane: strongSelf.maskPane, transition: panelTransition, firstTime: panelFirstTime, thenGridTransition: gridTransition, gridFirstTime: gridFirstTime)
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
                    if strongSelf.stickersNodeInteraction.highlightedItemCollectionId != collectionId {
                        strongSelf.setHighlightedStickerItemCollectionId(collectionId)
                    }
                }
                
                if let currentView = strongSelf.currentStickerView, let (topIndex, topItem) = visibleItems.top, let (bottomIndex, bottomItem) = visibleItems.bottom {
                    if topIndex <= 10 && currentView.lower != nil {
                        let position: StickerPacksCollectionPosition = clipScrollPosition(.scroll(aroundIndex: (topItem as! ChatMediaInputStickerGridItem).index))
                        if strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.stickerItemCollectionsViewPosition.set(.single(position))
                        }
                    } else if bottomIndex >= visibleItems.count - 10 && currentView.higher != nil {
                        var position: StickerPacksCollectionPosition?
                        if let bottomItem = bottomItem as? ChatMediaInputStickerGridItem {
                            position = clipScrollPosition(.scroll(aroundIndex: bottomItem.index))
                        }
                        
                        if let position = position, strongSelf.currentStickerPacksCollectionPosition != position {
                            strongSelf.currentStickerPacksCollectionPosition = position
                            strongSelf.stickerItemCollectionsViewPosition.set(.single(position))
                        }
                    }
                }
            }
        }
        
        self.maskPane.gridNode.visibleItemsUpdated = { [weak self] visibleItems in
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
                    if strongSelf.masksNodeInteraction.highlightedItemCollectionId != collectionId {
                        strongSelf.setHighlightedMaskItemCollectionId(collectionId)
                    }
                }
                
                if let currentView = strongSelf.currentMaskView, let (topIndex, topItem) = visibleItems.top, let (bottomIndex, bottomItem) = visibleItems.bottom {
                    if topIndex <= 10 && currentView.lower != nil {
                        let position: StickerPacksCollectionPosition = clipScrollPosition(.scroll(aroundIndex: (topItem as! ChatMediaInputStickerGridItem).index))
                        if strongSelf.currentMaskPacksCollectionPosition != position {
                            strongSelf.currentMaskPacksCollectionPosition = position
                            strongSelf.maskItemCollectionsViewPosition.set(.single(position))
                        }
                    } else if bottomIndex >= visibleItems.count - 10 && currentView.higher != nil {
                        var position: StickerPacksCollectionPosition?
                        if let bottomItem = bottomItem as? ChatMediaInputStickerGridItem {
                            position = clipScrollPosition(.scroll(aroundIndex: bottomItem.index))
                        }
                        
                        if let position = position, strongSelf.currentMaskPacksCollectionPosition != position {
                            strongSelf.currentMaskPacksCollectionPosition = position
                            strongSelf.maskItemCollectionsViewPosition.set(.single(position))
                        }
                    }
                }
            }
        }
        
        self.currentStickerPacksCollectionPosition = .initial
        self.stickerItemCollectionsViewPosition.set(.single(.initial))
        
        self.currentMaskPacksCollectionPosition = .initial
        self.maskItemCollectionsViewPosition.set(.single(.initial))
        
        self.stickerPane.inputNodeInteraction = self.stickersNodeInteraction
        self.maskPane.inputNodeInteraction = self.masksNodeInteraction
        
        paneDidScrollImpl = { [weak self] pane, state, transition in
            self?.updatePaneDidScroll(pane: pane, state: state, transition: transition)
        }
        
        selectStickerImpl = { [weak self] fileReference, node, rect in
            return self?.selectSticker?(fileReference, node, rect) ?? false
        }
        
        self.segmentedControlNode.selectedIndexChanged = { [weak self] index in
            if let strongSelf = self {
                strongSelf.setCurrentPane(index == 0 ? .stickers : .masks, transition: .animated(duration: 0.25, curve: .spring), collectionIdHint: nil)
            }
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.panRecognizer = panRecognizer
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    @objc private func cancelPressed() {
        self.animateOut()
    }
        
    private func setHighlightedStickerItemCollectionId(_ collectionId: ItemCollectionId) {
        self.stickersNodeInteraction.highlightedStickerItemCollectionId = collectionId
        if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .stickers {
            self.stickersNodeInteraction.highlightedItemCollectionId = collectionId
        }
        var ensuredNodeVisible = false
        var firstVisibleCollectionId: ItemCollectionId?
        self.stickerListView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMediaInputStickerPackItemNode {
                if firstVisibleCollectionId == nil {
                    firstVisibleCollectionId = itemNode.currentCollectionId
                }
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputRecentGifsItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputTrendingItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputPeerSpecificItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            }
        }
        
        if let currentView = self.currentStickerView, let firstVisibleCollectionId = firstVisibleCollectionId, !ensuredNodeVisible {
            let targetIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == collectionId })
            let firstVisibleIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == firstVisibleCollectionId })
            if let targetIndex = targetIndex, let firstVisibleIndex = firstVisibleIndex {
                let toRight = targetIndex > firstVisibleIndex
                self.stickerListView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], scrollToItem: ListViewScrollToItem(index: targetIndex, position: toRight ? .bottom(0.0) : .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: toRight ? .Down : .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil)
            }
        }
    }
    
    private func setHighlightedMaskItemCollectionId(_ collectionId: ItemCollectionId) {
        self.masksNodeInteraction.highlightedStickerItemCollectionId = collectionId
        if self.paneArrangement.panes[self.paneArrangement.currentIndex] == .masks {
            self.masksNodeInteraction.highlightedItemCollectionId = collectionId
        }
        var ensuredNodeVisible = false
        var firstVisibleCollectionId: ItemCollectionId?
        self.maskListView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatMediaInputStickerPackItemNode {
                if firstVisibleCollectionId == nil {
                    firstVisibleCollectionId = itemNode.currentCollectionId
                }
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputMetaSectionItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputRecentGifsItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputTrendingItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            } else if let itemNode = itemNode as? ChatMediaInputPeerSpecificItemNode {
                itemNode.updateIsHighlighted()
                if itemNode.currentCollectionId == collectionId {
                    self.stickerListView.ensureItemNodeVisible(itemNode)
                    ensuredNodeVisible = true
                }
            }
        }
        
        if let currentView = self.currentMaskView, let firstVisibleCollectionId = firstVisibleCollectionId, !ensuredNodeVisible {
            let targetIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == collectionId })
            let firstVisibleIndex = currentView.collectionInfos.firstIndex(where: { id, _, _ in return id == firstVisibleCollectionId })
            if let targetIndex = targetIndex, let firstVisibleIndex = firstVisibleIndex {
                let toRight = targetIndex > firstVisibleIndex
                self.maskListView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [], scrollToItem: ListViewScrollToItem(index: targetIndex, position: toRight ? .bottom(0.0) : .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: toRight ? .Down : .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil)
            }
        }
    }
    
    private func setCurrentPane(_ pane: DrawingPaneType, transition: ContainedViewLayoutTransition, collectionIdHint: Int32? = nil) {
        if let index = self.paneArrangement.panes.firstIndex(of: pane), index != self.paneArrangement.currentIndex, let layout = self.validLayout {
            self.paneArrangement = self.paneArrangement.withIndexTransition(0.0).withCurrentIndex(index)

            switch pane {
                case .stickers:
                    if let highlightedStickerCollectionId = self.stickersNodeInteraction.highlightedStickerItemCollectionId {
                        self.setHighlightedStickerItemCollectionId(highlightedStickerCollectionId)
                    } else if let collectionIdHint = collectionIdHint {
                        self.setHighlightedStickerItemCollectionId(ItemCollectionId(namespace: collectionIdHint, id: 0))
                    }
                    self.maskListView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: layout.size.width, y: 0.0), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak self] completed in
                        guard let strongSelf = self, completed else {
                            return
                        }
                        strongSelf.maskListView.isHidden = true
                        strongSelf.maskListView.layer.removeAllAnimations()
                    })
                    self.stickerListView.layer.removeAllAnimations()
                    self.stickerListView.isHidden = false
                    self.stickerListView.layer.animatePosition(from: CGPoint(x: -layout.size.width, y: 0.0), to: CGPoint(), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                case .masks:
                    if let highlightedStickerCollectionId = self.stickersNodeInteraction.highlightedStickerItemCollectionId {
                        self.setHighlightedMaskItemCollectionId(highlightedStickerCollectionId)
                    } else if let collectionIdHint = collectionIdHint {
                        self.setHighlightedMaskItemCollectionId(ItemCollectionId(namespace: collectionIdHint, id: 0))
                    }
                    self.stickerListView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -layout.size.width, y: 0.0), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { [weak self] completed in
                        guard let strongSelf = self, completed else {
                            return
                        }
                        strongSelf.stickerListView.isHidden = true
                        strongSelf.stickerListView.layer.removeAllAnimations()
                    })
                    self.maskListView.layer.removeAllAnimations()
                    self.maskListView.isHidden = false
                    self.maskListView.layer.animatePosition(from: CGPoint(x: layout.size.width, y: 0.0), to: CGPoint(), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            }
        }
        if let layout = self.validLayout {
            self.updateLayout(layout, transition: transition)
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
    
    private func updateLayout(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        let insets = layout.insets(options: [.statusBar])
        let height = layout.size.height
        
        let _ = self.updateLayout(width: layout.size.width, topInset: insets.top, leftInset: insets.left, rightInset: insets.right, bottomInset: insets.bottom, standardInputHeight: height, inputHeight: height, maximumHeight: height, inputPanelHeight: height, transition: transition, deviceMetrics: layout.deviceMetrics, isVisible: true)
    }
    
    func updateLayout(width: CGFloat, topInset: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, deviceMetrics: DeviceMetrics, isVisible: Bool) -> (CGFloat, CGFloat) {
        let searchMode: ChatMediaInputSearchMode? = nil
                
        let displaySearch = !"".isEmpty //silence warning
        let separatorHeight = max(UIScreenPixel, 1.0 - UIScreenPixel)
        let topPanelHeight: CGFloat = 56.0
        let panelHeight: CGFloat
        
        let isExpanded: Bool = true
        panelHeight = maximumHeight

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
                    let anchorTop = CGPoint(x: 0.0, y: 0.0)
                    let anchorTopView: UIView = self.view
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
                        searchContainerNode.animateIn(from: placeholderNode, anchorTop: anchorTop, anhorTopView: anchorTopView, transition: transition, completion: {
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
        transition.updateFrame(node: self.collectionListPanel, frame: CGRect(origin: CGPoint(x: 0.0, y: 41.0), size: CGSize(width: width, height: bottomPanelHeight + bottomInset)))
    
        transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topInset + topPanelHeight), size: CGSize(width: width, height: separatorHeight)))
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: maximumHeight + contentVerticalOffset - bottomPanelHeight - bottomInset), size: CGSize(width: width, height: separatorHeight)))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        
        let listPosition = CGPoint(x: width / 2.0, y: (bottomPanelHeight - collectionListPanelOffset) / 2.0 + 15.0)
        self.stickerListView.bounds = CGRect(x: 0.0, y: 0.0, width: bottomPanelHeight + 31.0, height: width)
        transition.updatePosition(node: self.stickerListView, position: listPosition)
        
        self.maskListView.bounds = CGRect(x: 0.0, y: 0.0, width: bottomPanelHeight + 31.0, height: width)
        transition.updatePosition(node: self.maskListView, position: listPosition)
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: bottomPanelHeight + 31.0, height: width), insets: UIEdgeInsets(top: 4.0 + leftInset, left: 0.0, bottom: 4.0 + rightInset, right: 0.0), duration: duration, curve: curve)
        self.stickerListView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        self.maskListView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        var visiblePanes: [(DrawingPaneType, CGFloat)] = []

        var paneIndex = 0
        for pane in self.paneArrangement.panes {
            let paneOrigin = CGFloat(paneIndex - self.paneArrangement.currentIndex) * width - self.paneArrangement.indexTransition * width
            if paneOrigin.isLess(than: width) && CGFloat(0.0).isLess(than: (paneOrigin + width)) {
                visiblePanes.append((pane, paneOrigin))
            }
            paneIndex += 1
        }
        
        var stickersVisible = false
        var masksVisible = false
        
        for (pane, paneOrigin) in visiblePanes {
            let paneFrame = CGRect(origin: CGPoint(x: paneOrigin + leftInset, y: topInset + topPanelHeight), size: CGSize(width: width - leftInset - rightInset, height: panelHeight - topInset - topPanelHeight - bottomInset - bottomPanelHeight))
            switch pane {
                case .stickers:
                    if self.stickerPane.supernode == nil {
                        self.insertSubnode(self.stickerPane, belowSubnode: self.collectionListContainer)
                        self.stickerPane.frame = CGRect(origin: CGPoint(x: -width, y: topInset + topPanelHeight), size: CGSize(width: width, height: panelHeight - topInset - topPanelHeight  - bottomInset - bottomPanelHeight))
                    }
                    if self.stickerListView.supernode == nil {
                        self.collectionListContainer.addSubnode(self.stickerListView)
                    }
                    if self.stickerPane.frame != paneFrame {
                        self.stickerPane.layer.removeAnimation(forKey: "position")
                        transition.updateFrame(node: self.stickerPane, frame: paneFrame)
                    }
                    stickersVisible = true
                case .masks:
                    if self.maskPane.supernode == nil {
                        self.insertSubnode(self.maskPane, belowSubnode: self.collectionListContainer)
                        self.maskPane.frame = CGRect(origin: CGPoint(x: width, y: topInset + topPanelHeight), size: CGSize(width: width, height: panelHeight - topInset - topPanelHeight  - bottomInset - bottomPanelHeight))
                    }
                    if self.maskListView.supernode == nil {
                        self.collectionListContainer.addSubnode(self.maskListView)
                    }
                    if self.maskPane.frame != paneFrame {
                        self.maskPane.layer.removeAnimation(forKey: "position")
                        transition.updateFrame(node: self.maskPane, frame: paneFrame)
                    }
                    masksVisible = true
            }
        }
        
        self.stickerPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight - topInset - topPanelHeight - bottomInset - bottomPanelHeight), topInset: 0.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: stickersVisible, deviceMetrics: deviceMetrics, transition: transition)
        
        self.maskPane.updateLayout(size: CGSize(width: width - leftInset - rightInset, height: panelHeight - topInset - topPanelHeight - bottomInset - bottomPanelHeight), topInset: 0.0, bottomInset: bottomInset, isExpanded: isExpanded, isVisible: masksVisible, deviceMetrics: deviceMetrics, transition: transition)
        
        if self.stickerPane.supernode != nil {
            if !visiblePanes.contains(where: { $0.0 == .stickers }) {
                if case .animated = transition {
                    if !self.animatingStickerPaneOut {
                        self.animatingStickerPaneOut = true
                        transition.animatePosition(node: self.stickerPane, to: CGPoint(x: -width + width / 2.0, y: self.stickerPane.layer.position.y), removeOnCompletion: false, completion: { [weak self] value in
                            if let strongSelf = self, value {
                                strongSelf.animatingStickerPaneOut = false
                                strongSelf.stickerPane.removeFromSupernode()
                            }
                        })
                    }
                } else {
                    self.animatingStickerPaneOut = false
                    self.stickerPane.removeFromSupernode()
                    self.stickerListView.removeFromSupernode()
                }
            }
        } else {
            self.animatingStickerPaneOut = false
        }
        
        if self.maskPane.supernode != nil {
            if !visiblePanes.contains(where: { $0.0 == .masks }) {
                if case .animated = transition {
                    if !self.animatingMaskPaneOut {
                        self.animatingMaskPaneOut = true
                        transition.animatePosition(node: self.maskPane, to: CGPoint(x: width + width / 2.0, y: self.maskPane.layer.position.y), removeOnCompletion: false, completion: { [weak self] value in
                            if let strongSelf = self, value {
                                strongSelf.animatingMaskPaneOut = false
                                strongSelf.maskPane.removeFromSupernode()
                            }
                        })
                    }
                } else {
                    self.animatingMaskPaneOut = false
                    self.maskPane.removeFromSupernode()
                    self.maskListView.removeFromSupernode()
                }
            }
        } else {
            self.animatingMaskPaneOut = false
        }
    
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
    
    private func enqueuePanelTransition(listView: ListView, pane: ChatMediaInputStickerPane, transition: ChatMediaInputPanelTransition, firstTime: Bool, thenGridTransition gridTransition: ChatMediaInputGridTransition, gridFirstTime: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else {
            options.insert(.AnimateInsertion)
        }
        listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateOpaqueState: nil, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.enqueueGridTransition(pane: pane, transition: gridTransition, firstTime: gridFirstTime)
                if !strongSelf.didSetReady && pane === strongSelf.stickerPane {
                    strongSelf.didSetReady = true
                    strongSelf._ready.set(.single(true))
                }
            }
        })
    }
    
    private func enqueueGridTransition(pane: ChatMediaInputStickerPane, transition: ChatMediaInputGridTransition, firstTime: Bool) {
        var itemTransition: ContainedViewLayoutTransition = .immediate
        if transition.animated {
            itemTransition = .animated(duration: 0.3, curve: .spring)
        }
        pane.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: itemTransition, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset, updateOpaqueState: transition.updateOpaqueState), completion: { _ in })
    }
    
    private func updatePaneDidScroll(pane: ChatMediaInputPane, state: ChatMediaInputPaneScrollState, transition: ContainedViewLayoutTransition) {
        pane.collectionListPanelOffset = 0.0
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                self.stickerPane.layer.removeAllAnimations()
                if self.animatingStickerPaneOut {
                    self.animatingStickerPaneOut = false
                    self.stickerPane.removeFromSupernode()
                }
                self.maskPane.layer.removeAllAnimations()
                if self.animatingMaskPaneOut {
                  self.animatingMaskPaneOut = false
                  self.maskPane.removeFromSupernode()
              }
            case .changed:
                if let layout = self.validLayout {
                    let translationX = -recognizer.translation(in: self.view).x
                    var indexTransition = translationX / layout.size.width
                    if self.paneArrangement.currentIndex == 0 {
                        indexTransition = max(0.0, indexTransition)
                    } else if self.paneArrangement.currentIndex == self.paneArrangement.panes.count - 1 {
                        indexTransition = min(0.0, indexTransition)
                    }
                    self.paneArrangement = self.paneArrangement.withIndexTransition(indexTransition)
                    self.updateLayout(layout, transition: .immediate)
                }
            case .ended:
                if let layout = self.validLayout {
                    var updatedIndex = self.paneArrangement.currentIndex
                    if abs(self.paneArrangement.indexTransition * layout.size.width) > 30.0 {
                        if self.paneArrangement.indexTransition < 0.0 {
                            updatedIndex = max(0, self.paneArrangement.currentIndex - 1)
                        } else {
                            updatedIndex = min(self.paneArrangement.panes.count - 1, self.paneArrangement.currentIndex + 1)
                        }
                    }
                    self.paneArrangement = self.paneArrangement.withIndexTransition(0.0)
                    self.setCurrentPane(self.paneArrangement.panes[updatedIndex], transition: .animated(duration: 0.25, curve: .spring))
                    self.segmentedControlNode.setSelectedIndex(updatedIndex, animated: true)
                }
            case .cancelled:
                if let layout = self.validLayout {
                    self.paneArrangement = self.paneArrangement.withIndexTransition(0.0)
                    self.updateLayout(layout, transition: .animated(duration: 0.25, curve: .spring))
            }
            default:
                break
        }
    }
       
    fileprivate var didAppear: (() -> Void)?
    fileprivate var willDisappear: (() -> Void)?
    
    func animateIn() {
        self.isUserInteractionEnabled = true
        self.isHidden = false
        
        if let hiddenPane = self.hiddenPane {
            self.insertSubnode(hiddenPane, belowSubnode: self.collectionListContainer)
            self.hiddenPane = nil
        }
        if let hiddenListView = self.hiddenListView {
            self.collectionListContainer.addSubnode(hiddenListView)
            self.hiddenListView = nil
        }
        
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.didAppear?()
            }
        })
    }
    
    func animateOut() {
        self.willDisappear?()
        
        self.isUserInteractionEnabled = false
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                if strongSelf.stickerPane.supernode != nil {
                    strongSelf.hiddenPane = strongSelf.stickerPane
                    strongSelf.hiddenListView = strongSelf.stickerListView
                } else if strongSelf.maskPane.supernode != nil {
                    strongSelf.hiddenPane = strongSelf.maskPane
                    strongSelf.hiddenListView = strongSelf.maskListView
                }
                strongSelf.hiddenPane?.removeFromSupernode()
                strongSelf.hiddenListView?.removeFromSupernode()
                strongSelf.isHidden = true
            }
        })
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout

        self.updateLayout(layout, transition: transition)
    }
}

final class DrawingStickersScreen: ViewController, TGPhotoPaintStickersScreen {
    public var screenDidAppear: (() -> Void)?
    public var screenWillDisappear: (() -> Void)?
    
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
                    (strongSelf.displayNode as! DrawingStickersScreenNode).animateOut()
                    return selectSticker(file, sourceNode, sourceRect)
                } else {
                    return false
                }
            }
        )
        (self.displayNode as! DrawingStickersScreenNode).dismiss = { [weak self] in
            self?.dismiss()
        }
        (self.displayNode as! DrawingStickersScreenNode).didAppear = { [weak self] in
            self?.screenDidAppear?()
        }
        (self.displayNode as! DrawingStickersScreenNode).willDisappear = { [weak self] in
            self?.screenWillDisappear?()
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
        
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: 0.0, transition: transition)
    }
    
    func restore() {
        (self.displayNode as! DrawingStickersScreenNode).animateIn()
    }
    
    func invalidate() {
        self.dismiss()
    }
}
