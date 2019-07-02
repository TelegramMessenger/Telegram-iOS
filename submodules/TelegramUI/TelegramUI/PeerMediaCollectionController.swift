import Foundation
import UIKit
import Postbox
import SwiftSignalKit
import Display
import AsyncDisplayKit
import TelegramCore
import SafariServices
import TelegramPresentationData
import TelegramUIPreferences

public class PeerMediaCollectionController: TelegramController {
    private var validLayout: ContainerViewLayout?
    
    private let context: AccountContext
    private let peerId: PeerId
    private let messageId: MessageId?
    
    private let peerDisposable = MetaDisposable()
    private let navigationActionDisposable = MetaDisposable()
    
    private let messageIndexDisposable = MetaDisposable()
    
    private let _peerReady = Promise<Bool>()
    private var didSetPeerReady = false
    private let peer = Promise<Peer?>(nil)
    
    private var interfaceState: PeerMediaCollectionInterfaceState
    
    private var rightNavigationButton: PeerMediaCollectionNavigationButton?
    
    private let galleryHiddenMesageAndMediaDisposable = MetaDisposable()
    private var presentationDataDisposable:Disposable?
    
    private var controllerInteraction: ChatControllerInteraction?
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let messageContextDisposable = MetaDisposable()
    private var shareStatusDisposable: MetaDisposable?
    
    private var presentationData: PresentationData
    
    private var resolveUrlDisposable: MetaDisposable?
    
    public init(context: AccountContext, peerId: PeerId, messageId: MessageId? = nil) {
        self.context = context
        self.peerId = peerId
        self.messageId = messageId
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.interfaceState = PeerMediaCollectionInterfaceState(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme).withUpdatedSeparatorColor(self.presentationData.theme.rootController.navigationBar.backgroundColor), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none)
        
        self.title = self.presentationData.strings.SharedMedia_TitleAll
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.ready.set(.never())
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.mediaCollectionDisplayNode.historyNode.scrollToEndOfHistory()
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                let previousChatWallpaper = strongSelf.presentationData.chatWallpaper
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings || presentationData.chatWallpaper != previousChatWallpaper {
                    strongSelf.themeAndStringsUpdated()
                }
            }
        })
        
        let controllerInteraction = ChatControllerInteraction(openMessage: { [weak self] message, mode in
            if let strongSelf = self, strongSelf.isNodeLoaded, let galleryMessage = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id) {
                guard let navigationController = strongSelf.navigationController as? NavigationController else {
                    return false
                }
                strongSelf.mediaCollectionDisplayNode.view.endEditing(true)
                return openChatMessage(context: context, message: galleryMessage.message, standalone: false, reverseMessageGalleryOrder: true, navigationController: navigationController, dismissInput: {
                    self?.mediaCollectionDisplayNode.view.endEditing(true)
                }, present: { c, a in
                    self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                }, transitionNode: { messageId, media in
                    if let strongSelf = self {
                        return strongSelf.mediaCollectionDisplayNode.transitionNodeForGallery(messageId: messageId, media: media)
                    }
                    return nil
                }, addToTransitionSurface: { view in
                    if let strongSelf = self {
                        strongSelf.mediaCollectionDisplayNode.view.insertSubview(view, aboveSubview: strongSelf.mediaCollectionDisplayNode.historyNode.view)
                    }
                }, openUrl: { url in
                    self?.openUrl(url)
                }, openPeer: { peer, navigation in
                    self?.controllerInteraction?.openPeer(peer.id, navigation, nil)
                }, callPeer: { peerId in
                    self?.controllerInteraction?.callPeer(peerId)
                }, enqueueMessage: { _ in
                }, sendSticker: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in})
            }
            return false
            }, openPeer: { [weak self] id, navigation, _ in
                if let strongSelf = self, let id = id, let navigationController = strongSelf.navigationController as? NavigationController {
                    navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id))
                }
            }, openPeerMention: { _ in
            }, openMessageContextMenu: { [weak self] message, _, _, _ in
                var messageIds = Set<MessageId>()
                messageIds.insert(message.id)
                
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    if let message = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id)?.message {
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.SharedMedia_ViewInChat, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                                        navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(strongSelf.peerId), messageId: message.id)
                                    }
                                }),
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ContextMenuForward, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self {
                                        strongSelf.forwardMessages(messageIds)
                                    }
                                }),
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_ContextMenuDelete, color: .destructive, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self {
                                        strongSelf.deleteMessages(messageIds)
                                    }
                                })
                            ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                            })
                        ])])
                        strongSelf.mediaCollectionDisplayNode.view.endEditing(true)
                        strongSelf.present(actionSheet, in: .window(.root))
                    }
                }
            }, navigateToMessage: { [weak self] fromId, id in
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    if id.peerId == strongSelf.peerId {
                        var fromIndex: MessageIndex?
                        
                        if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(fromId) {
                            fromIndex = message.index
                        }
                        
                        /*if let fromIndex = fromIndex {
                            if let message = strongSelf.mediaCollectionDisplayNode.historyNode.messageInCurrentHistoryView(id) {
                                strongSelf.mediaCollectionDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: MessageIndex(message))
                            } else {
                                strongSelf.messageIndexDisposable.set((strongSelf.account.postbox.messageIndexAtId(id) |> deliverOnMainQueue).start(next: { [weak strongSelf] index in
                                    if let strongSelf = strongSelf, let index = index {
                                        strongSelf.mediaCollectionDisplayNode.historyNode.scrollToMessage(from: fromIndex, to: index)
                                    }
                                }))
                            }
                        }*/
                    } else {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(context: strongSelf.context, chatLocation: .peer(id.peerId), messageId: id))
                    }
                }
            }, clickThroughMessage: { [weak self] in
                self?.view.endEditing(true)
            }, toggleMessagesSelection: { [weak self] ids, value in
                if let strongSelf = self, strongSelf.isNodeLoaded {
                    strongSelf.updateInterfaceState(animated: true, { $0.withToggledSelectedMessages(ids, value: value) })
                }
            }, sendMessage: { _ in
            },sendSticker: { _, _ in
            }, sendGif: { _ in
            }, requestMessageActionCallback: { _, _, _ in
            }, requestMessageActionUrlAuth: { _, _, _ in
            }, activateSwitchInline: { _, _ in
            }, openUrl: { [weak self] url, _, external in
                self?.openUrl(url, external: external ?? false)
            }, shareCurrentLocation: {
            }, shareAccountContact: {
            }, sendBotCommand: { _, _ in
            }, openInstantPage: { [weak self] message, associatedData in
                if let strongSelf = self, strongSelf.isNodeLoaded, let navigationController = strongSelf.navigationController as? NavigationController, let message = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id)?.message {
                    openChatInstantPage(context: strongSelf.context, message: message, sourcePeerType: associatedData?.automaticDownloadPeerType, navigationController: navigationController)
                }
            }, openWallpaper: { [weak self] message in
                if let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.mediaCollectionDisplayNode.messageForGallery(message.id)?.message {
                    openChatWallpaper(context: strongSelf.context, message: message, present: { [weak self] c, a in
                        self?.present(c, in: .window(.root), with: a, blockInteraction: true)
                    })
                }
            }, openHashtag: { _, _ in
            }, updateInputState: { _ in
            }, updateInputMode: { _ in
            }, openMessageShareMenu: { _ in
            }, presentController: { _, _ in
            }, navigationController: {
                return nil
            }, presentGlobalOverlayController: { _, _ in }, callPeer: { _ in
            }, longTap: { [weak self] content, _ in
                if let strongSelf = self {
                    strongSelf.view.endEditing(true)
                    switch content {
                        case let .url(url):
                            let canOpenIn = availableOpenInOptions(context: strongSelf.context, item: .url(url: url)).count > 1
                            let openText = canOpenIn ? strongSelf.presentationData.strings.Conversation_FileOpenIn : strongSelf.presentationData.strings.Conversation_LinkDialogOpen
                            let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                            actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                                ActionSheetTextItem(title: url),
                                ActionSheetButtonItem(title: openText, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let strongSelf = self {
                                        if canOpenIn {
                                            let actionSheet = OpenInActionSheetController(context: strongSelf.context, item: .url(url: url), openUrl: { [weak self] url in
                                                if let strongSelf = self, let navigationController = strongSelf.navigationController as? NavigationController {
                                                    openExternalUrl(context: strongSelf.context, url: url, forceExternal: true, presentationData: strongSelf.presentationData, navigationController: navigationController, dismissInput: {
                                                    })
                                                }
                                            })
                                            strongSelf.present(actionSheet, in: .window(.root))
                                        } else {
                                            strongSelf.context.sharedContext.applicationBindings.openUrl(url)
                                        }
                                    }
                                }),
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.ShareMenu_CopyShareLink, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    UIPasteboard.general.string = url
                                }),
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Conversation_AddToReadingList, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    if let link = URL(string: url) {
                                        let _ = try? SSReadingList.default()?.addItem(with: link, title: nil, previewText: nil)
                                    }
                                })
                            ]), ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])])
                            strongSelf.present(actionSheet, in: .window(.root))
                        default:
                            break
                    }
                }
            }, openCheckoutOrReceipt: { _ in
            }, openSearch: { [weak self] in
                self?.activateSearch()
            }, setupReply: { _ in
            }, canSetupReply: { _ in
                return false
        }, navigateToFirstDateMessage: { _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _ in
        }, requestSelectMessagePollOption: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _ in    
        }, seekToTimecode: { _, _, _ in    
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
           pollActionState: ChatInterfacePollActionState())
        
        self.controllerInteraction = controllerInteraction
        
        self.interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _ in
        }, setupEditMessage: { _ in
        }, beginMessageSelection: { _ in
        }, deleteSelectedMessages: { [weak self] in
            if let strongSelf = self, let messageIds = strongSelf.interfaceState.selectionState?.selectedIds {
                strongSelf.deleteMessages(messageIds)
            }
        }, reportSelectedMessages: { [weak self] in
            if let strongSelf = self, let messageIds = strongSelf.interfaceState.selectionState?.selectedIds, !messageIds.isEmpty {
                strongSelf.present(peerReportOptionsController(context: strongSelf.context, subject: .messages(Array(messageIds).sorted()), present: { c, a in
                    self?.present(c, in: .window(.root), with: a)
                }), in: .window(.root))
            }
        }, reportMessages: { _ in
        }, deleteMessages: { _ in
        }, forwardSelectedMessages: { [weak self] in
            if let strongSelf = self {
                if let forwardMessageIdsSet = strongSelf.interfaceState.selectionState?.selectedIds {
                    strongSelf.forwardMessages(forwardMessageIdsSet)
                }
            }
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, shareSelectedMessages: { [weak self] in
            if let strongSelf = self, let selectedIds = strongSelf.interfaceState.selectionState?.selectedIds, !selectedIds.isEmpty {
                let _ = (strongSelf.context.account.postbox.transaction { transaction -> [Message] in
                    var messages: [Message] = []
                    for id in selectedIds {
                        if let message = transaction.getMessage(id) {
                            messages.append(message)
                        }
                    }
                    return messages
                    } |> deliverOnMainQueue).start(next: { messages in
                        if let strongSelf = self, !messages.isEmpty {
                            strongSelf.updateInterfaceState(animated: true, {
                                $0.withoutSelectionState()
                            })
                            
                            let shareController = ShareController(context: strongSelf.context, subject: .messages(messages.sorted(by: { lhs, rhs in
                                return lhs.index < rhs.index
                            })), externalShare: true, immediateExternalShare: true)
                            strongSelf.present(shareController, in: .window(.root))
                        }
                    })
            }
        }, updateTextInputStateAndMode: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in 
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _ in
        }, navigateToChat: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _ in
        }, sendBotCommand: { _, _ in
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in 
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: {
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _ in
        }, unblockPeer: {
        }, pinMessage: { _ in
        }, unpinMessage: {
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: {
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, getNavigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, requestUnvoteInMessage: { _ in
        }, requestStopPollInMessage: { _ in
        }, updateInputLanguage: { _ in
        }, unarchiveChat: {
        }, openLinkEditing: {
        }, reportPeerIrrelevantGeoLocation: {
        }, statuses: nil)
        
        self.updateInterfaceState(animated: false, { return $0 })
        
        self.peer.set(context.account.postbox.peerView(id: peerId) |> map { $0.peers[$0.peerId] })
        
        self.peerDisposable.set((self.peer.get()
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                if let strongSelf = self {
                    strongSelf.updateInterfaceState(animated: false, { return $0.withUpdatedPeer(peer) })
                    if !strongSelf.didSetPeerReady {
                        strongSelf.didSetPeerReady = true
                        strongSelf._peerReady.set(.single(true))
                    }
                }
            }))
    }
    
    private func themeAndStringsUpdated() {
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
      //  self.chatTitleView?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
        self.updateInterfaceState(animated: false, { state in
            var state = state
            state = state.updatedTheme(self.presentationData.theme)
            state = state.updatedStrings(self.presentationData.strings)
            return state
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.messageIndexDisposable.dispose()
        self.navigationActionDisposable.dispose()
        self.galleryHiddenMesageAndMediaDisposable.dispose()
        self.messageContextDisposable.dispose()
        self.resolveUrlDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    var mediaCollectionDisplayNode: PeerMediaCollectionControllerNode {
        get {
            return super.displayNode as! PeerMediaCollectionControllerNode
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerMediaCollectionControllerNode(context: self.context, peerId: self.peerId, messageId: self.messageId, controllerInteraction: self.controllerInteraction!, interfaceInteraction: self.interfaceInteraction!, navigationBar: self.navigationBar, requestDeactivateSearch: { [weak self] in
            self?.deactivateSearch()
        })
    
        let mediaManager = self.context.sharedContext.mediaManager
        self.galleryHiddenMesageAndMediaDisposable.set(mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
            if let strongSelf = self, let controllerInteraction = strongSelf.controllerInteraction {
                var messageIdAndMedia: [MessageId: [Media]] = [:]
                
                for id in ids {
                    if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                        messageIdAndMedia[messageId] = [media]
                    }
                }
                
                //if controllerInteraction.hiddenMedia != messageIdAndMedia {
                controllerInteraction.hiddenMedia = messageIdAndMedia
                
                strongSelf.mediaCollectionDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? GridMessageItemNode {
                        itemNode.updateHiddenMedia()
                    } else if let itemNode = itemNode as? ListMessageNode {
                        itemNode.updateHiddenMedia()
                    }
                }
                //}
            }
        }))
        
        self.ready.set(combineLatest(self.mediaCollectionDisplayNode.historyNode.historyState.get(), self._peerReady.get()) |> map { $1 })
        
        self.mediaCollectionDisplayNode.requestLayout = { [weak self] transition in
            self?.requestLayout(transition: transition)
        }
        
        self.mediaCollectionDisplayNode.requestUpdateMediaCollectionInterfaceState = { [weak self] animated, f in
            self?.updateInterfaceState(animated: animated, f)
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.mediaCollectionDisplayNode.historyNode.preloadPages = true
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.mediaCollectionDisplayNode.clearHighlightAnimated(true)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        self.mediaCollectionDisplayNode.containerLayoutUpdated(layout, navigationBarHeightAndPrimaryHeight: (self.navigationHeight, self.primaryNavigationHeight), transition: transition, listViewTransaction: { updateSizeAndInsets in
            self.mediaCollectionDisplayNode.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        })
    }
    
    func updateInterfaceState(animated: Bool = true, _ f: (PeerMediaCollectionInterfaceState) -> PeerMediaCollectionInterfaceState) {
        let updatedInterfaceState = f(self.interfaceState)
        
        if self.isNodeLoaded {
            self.mediaCollectionDisplayNode.updateMediaCollectionInterfaceState(updatedInterfaceState, animated: animated)
        }
        self.interfaceState = updatedInterfaceState
        
        if let button = rightNavigationButtonForPeerMediaCollectionInterfaceState(updatedInterfaceState, currentButton: self.rightNavigationButton, target: self, selector: #selector(self.rightNavigationButtonAction)) {
            if self.rightNavigationButton != button {
                self.navigationItem.setRightBarButton(button.buttonItem, animated: true)
            }
            self.rightNavigationButton = button
        } else if let _ = self.rightNavigationButton {
            self.navigationItem.setRightBarButton(nil, animated: true)
            self.rightNavigationButton = nil
        }
        
        if let controllerInteraction = self.controllerInteraction {
            if updatedInterfaceState.selectionState != controllerInteraction.selectionState {
                let animated = animated || controllerInteraction.selectionState == nil || updatedInterfaceState.selectionState == nil
                controllerInteraction.selectionState = updatedInterfaceState.selectionState
                self.mediaCollectionDisplayNode.historyNode.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView {
                        itemNode.updateSelectionState(animated: animated)
                    } else if let itemNode = itemNode as? GridMessageItemNode {
                        itemNode.updateSelectionState(animated: animated)
                    }
                }
                
                self.mediaCollectionDisplayNode.selectedMessages = updatedInterfaceState.selectionState?.selectedIds
                view.disablesInteractiveTransitionGestureRecognizer = updatedInterfaceState.selectionState != nil && self.mediaCollectionDisplayNode.historyNode is ChatHistoryGridNode
            }
        }
    }
    
    @objc func rightNavigationButtonAction() {
        if let button = self.rightNavigationButton {
            self.navigationButtonAction(button.action)
        }
    }
    
    private func navigationButtonAction(_ action: PeerMediaCollectionNavigationButtonAction) {
        switch action {
            case .cancelMessageSelection:
                self.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
            case .beginMessageSelection:
                self.updateInterfaceState(animated: true, { $0.withSelectionState() })
        }
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.mediaCollectionDisplayNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            self.mediaCollectionDisplayNode.deactivateSearch()
        }
    }
    
    private func openUrl(_ url: String, external: Bool = false) {
        let disposable: MetaDisposable
        if let current = self.resolveUrlDisposable {
            disposable = current
        } else {
            disposable = MetaDisposable()
            self.resolveUrlDisposable = disposable
        }
        
        let resolvedUrl: Signal<ResolvedUrl, NoError>
        if external {
            resolvedUrl = .single(.externalUrl(url))
        } else {
            resolvedUrl = resolveUrl(account: self.context.account, url: url)
        }
        
        disposable.set((resolvedUrl |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                openResolvedUrl(result, context: strongSelf.context, navigationController: strongSelf.navigationController as? NavigationController, openPeer: { peerId, navigation in
                    if let strongSelf = self {
                        switch navigation {
                            case let .chat(_, messageId):
                                if let navigationController = strongSelf.navigationController as? NavigationController {
                                    navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), messageId: messageId, keepStack: .always)
                                }
                            case .info:
                                strongSelf.navigationActionDisposable.set((strongSelf.context.account.postbox.loadedPeerWithId(peerId)
                                |> take(1)
                                |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    if let strongSelf = self, peer.restrictionText == nil {
                                        if let infoController = peerInfoController(context: strongSelf.context, peer: peer) {
                                            (strongSelf.navigationController as? NavigationController)?.pushViewController(infoController)
                                        }
                                    }
                                }))
                            case let .withBotStartPayload(startPayload):
                                if let navigationController = strongSelf.navigationController as? NavigationController {
                                    navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), botStart: startPayload)
                                }
                            default:
                                break
                        }
                    }
                }, present: { c, a in
                    self?.present(c, in: .window(.root), with: a)
                }, dismissInput: {
                    self?.view.endEditing(true)
                })
            }
        }))
    }
    
    func forwardMessages(_ messageIds: Set<MessageId>) {
        let currentMessages = (self.mediaCollectionDisplayNode.searchDisplayController?.contentNode as? ChatHistorySearchContainerNode)?.currentMessages
        let _ = (self.context.account.postbox.transaction { transaction -> Void in
            for id in messageIds {
                if transaction.getMessage(id) == nil {
                    if let message = currentMessages?[id] {
                        storeMessageFromSearch(transaction: transaction, message: message)
                    }
                }
            }
        }
        |> deliverOnMainQueue).start(completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let forwardMessageIds = Array(messageIds).sorted()
            
            let controller = PeerSelectionController(context: strongSelf.context, filter: [.onlyWriteable, .excludeDisabled])
            controller.peerSelected = { [weak controller] peerId in
                if let strongSelf = self, let _ = controller {
                    let _ = (strongSelf.context.account.postbox.transaction({ transaction -> Void in
                        transaction.updatePeerChatInterfaceState(peerId, update: { currentState in
                            if let currentState = currentState as? ChatInterfaceState {
                                return currentState.withUpdatedForwardMessageIds(forwardMessageIds)
                            } else {
                                return ChatInterfaceState().withUpdatedForwardMessageIds(forwardMessageIds)
                            }
                        })
                    }) |> deliverOnMainQueue).start(completed: {
                        if let strongSelf = self {
                            strongSelf.updateInterfaceState(animated: false, { $0.withoutSelectionState() })
                            
                            if peerId == strongSelf.context.account.peerId {
                                let _ = (enqueueMessages(account: strongSelf.context.account, peerId: peerId, messages: messageIds.map { id -> EnqueueMessage in
                                    return .forward(source: id, grouping: .auto)
                                })
                                |> deliverOnMainQueue).start(next: { [weak self] messageIds in
                                    if let strongSelf = self {
                                        let signals: [Signal<Bool, NoError>] = messageIds.compactMap({ id -> Signal<Bool, NoError>? in
                                            guard let id = id else {
                                                return nil
                                            }
                                            return strongSelf.context.account.pendingMessageManager.pendingMessageStatus(id)
                                            |> mapToSignal { status -> Signal<Bool, NoError> in
                                                if status != nil {
                                                    return .never()
                                                } else {
                                                    return .single(true)
                                                }
                                            }
                                            |> take(1)
                                        })
                                        if strongSelf.shareStatusDisposable == nil {
                                            strongSelf.shareStatusDisposable = MetaDisposable()
                                        }
                                        strongSelf.shareStatusDisposable?.set((combineLatest(signals)
                                        |> deliverOnMainQueue).start(completed: {
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            strongSelf.present(OverlayStatusController(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, type: .success), in: .window(.root))
                                        }))
                                    }
                                })
                                if let strongController = controller {
                                    strongController.dismiss()
                                }
                            } else {
                                let ready = ValuePromise<Bool>()
                                
                                strongSelf.messageContextDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                    if let strongController = controller {
                                        strongController.dismiss()
                                    }
                                }))
                                
                                (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChatController(context: strongSelf.context, chatLocation: .peer(peerId)), animated: false, ready: ready)
                            }
                        }
                    })
                }
            }
            strongSelf.present(controller, in: .window(.root))
        })
    }
    
    func deleteMessages(_ messageIds: Set<MessageId>) {
        if !messageIds.isEmpty {
            self.messageContextDisposable.set((combineLatest(chatAvailableMessageActions(postbox: self.context.account.postbox, accountPeerId: self.context.account.peerId, messageIds: messageIds), self.peer.get() |> take(1)) |> deliverOnMainQueue).start(next: { [weak self] actions, peer in
                if let strongSelf = self, let peer = peer, !actions.options.isEmpty {
                    let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                    var items: [ActionSheetItem] = []
                    var personalPeerName: String?
                    var isChannel = false
                    if let user = peer as? TelegramUser {
                        personalPeerName = user.compactDisplayTitle
                    } else if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        isChannel = true
                    }
                    
                    if actions.options.contains(.deleteGlobally) {
                        let globalTitle: String
                        if isChannel {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                        } else if let personalPeerName = personalPeerName {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).0
                        } else {
                            globalTitle = strongSelf.presentationData.strings.Conversation_DeleteMessagesForEveryone
                        }
                        items.append(ActionSheetButtonItem(title: globalTitle, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
                                let _ = deleteMessagesInteractively(postbox: strongSelf.context.account.postbox, messageIds: Array(messageIds), type: .forEveryone).start()
                            }
                        }))
                    }
                    if actions.options.contains(.deleteLocally) {
                        var localOptionText = strongSelf.presentationData.strings.Conversation_DeleteMessagesForMe
                        if strongSelf.context.account.peerId == strongSelf.peerId {
                            if messageIds.count == 1 {
                                localOptionText = strongSelf.presentationData.strings.Conversation_Moderate_Delete
                            } else {
                                localOptionText = strongSelf.presentationData.strings.Conversation_DeleteManyMessages
                            }
                        }
                        items.append(ActionSheetButtonItem(title: localOptionText, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            if let strongSelf = self {
                                strongSelf.updateInterfaceState(animated: true, { $0.withoutSelectionState() })
                                let _ = deleteMessagesInteractively(postbox: strongSelf.context.account.postbox, messageIds: Array(messageIds), type: .forLocalPeer).start()
                            }
                        }))
                    }
                    actionSheet.setItemGroups([ActionSheetItemGroup(items: items), ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                        ])])
                    strongSelf.present(actionSheet, in: .window(.root))
                }
            }))
        }
    }
}
