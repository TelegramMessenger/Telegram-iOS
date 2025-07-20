import Foundation
import UIKit
import AccountContext
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import ChatControllerInteraction
import TelegramUIPreferences
import ChatPresentationInterfaceState
import TextFormat
import UrlWhitelist
import SearchUI
import SearchBarNode
import ChatHistorySearchContainerNode
import ContextUI
import UndoUI

public final class BrowserBookmarksScreen: ViewController {
    final class Node: ViewControllerTracingNode, ASScrollViewDelegate {
        private let context: AccountContext
        private var presentationData: PresentationData
        private weak var controller: BrowserBookmarksScreen?
        
        private let controllerInteraction: ChatControllerInteraction
        private var searchDisplayController: SearchDisplayController?
        
        fileprivate let historyNode: ChatHistoryListNode
        private let bottomPanelNode: BottomPanelNode
        
        private var addedBookmark = false
        
        private var validLayout: (ContainerViewLayout, CGFloat, CGFloat)?
        
        init(context: AccountContext, controller: BrowserBookmarksScreen, presentationData: PresentationData) {
            self.context = context
            self.controller = controller
            self.presentationData = presentationData
        
            var openMessageImpl: ((Message) -> Bool)?
            var openContextMenuImpl: ((Message, ASDisplayNode, CGRect, UIGestureRecognizer?) -> Void)?
            self.controllerInteraction = ChatControllerInteraction(openMessage: { message, _ in
                if let openMessageImpl = openMessageImpl {
                    return openMessageImpl(message)
                } else {
                    return false
                }
            }, openPeer: { _, _, _, _ in
            }, openPeerMention: { _, _ in
            }, openMessageContextMenu: { message, _, sourceView, rect, gesture, _ in
                openContextMenuImpl?(message, sourceView, rect, gesture)
            }, openMessageReactionContextMenu: { _, _, _, _ in
            }, updateMessageReaction: { _, _, _, _ in
            }, activateMessagePinch: { _ in
            }, openMessageContextActions: { _, _, _, _ in
            }, navigateToMessage: { _, _, _ in
            }, navigateToMessageStandalone: { _ in
            }, navigateToThreadMessage: { _, _, _ in
            }, tapMessage: nil, clickThroughMessage: { _, _ in
            }, toggleMessagesSelection: { _, _ in
            }, sendCurrentMessage: { _, _ in
            }, sendMessage: { _ in
            }, sendSticker: { _, _, _, _, _, _, _, _, _ in
                return false
            }, sendEmoji: { _, _, _ in
            }, sendGif: { _, _, _, _, _ in
                return false
            }, sendBotContextResultAsGif: { _, _, _, _, _, _ in
                return false
            }, requestMessageActionCallback: { _, _, _, _, _ in
            }, requestMessageActionUrlAuth: { _, _ in
            }, activateSwitchInline: { _, _, _ in
            }, openUrl: { [weak controller] url in
                if let controller {
                    controller.openUrl(url.url)
                    controller.dismiss()
                }
            }, shareCurrentLocation: {
            }, shareAccountContact: {
            }, sendBotCommand: { _, _ in
            }, openInstantPage: { message, _ in
                if let openMessageImpl = openMessageImpl {
                    let _ = openMessageImpl(message)
                }
            }, openWallpaper: { _ in
            }, openTheme: {_ in
            }, openHashtag: { _, _ in
            }, updateInputState: { _ in
            }, updateInputMode: { _ in
            }, openMessageShareMenu: { _ in
            }, presentController: { _, _ in
            }, presentControllerInCurrent: { _, _ in
            }, navigationController: {
                return nil
            }, chatControllerNode: {
                return nil
            }, presentGlobalOverlayController: { _, _ in
            }, callPeer: { _, _ in
            }, openConferenceCall: { _ in                
            }, longTap: { _, _ in
            }, todoItemLongTap: { _, _ in
            }, openCheckoutOrReceipt: { _, _ in
            }, openSearch: {
            }, setupReply: { _ in
            }, canSetupReply: { _ in
                return .none
            }, canSendMessages: {
                return false
            }, navigateToFirstDateMessage: { _, _ in
            }, requestRedeliveryOfFailedMessages: { _ in
            }, addContact: { _ in
            }, rateCall: { _, _, _ in
            }, requestSelectMessagePollOptions: { _, _ in
            }, requestOpenMessagePollResults: { _, _ in
            }, openAppStorePage: {
            }, displayMessageTooltip: { _, _, _, _, _ in
            }, seekToTimecode: { _, _, _ in
            }, scheduleCurrentMessage: { _ in
            }, sendScheduledMessagesNow: { _ in
            }, editScheduledMessagesTime: { _ in
            }, performTextSelectionAction: { _, _, _, _ in
            }, displayImportedMessageTooltip: { _ in
            }, displaySwipeToReplyHint: {
            }, dismissReplyMarkupMessage: { _ in
            }, openMessagePollResults: { _, _ in
            }, openPollCreation: { _ in
            }, displayPollSolution: { _, _ in
            }, displayPsa: { _, _ in
            }, displayDiceTooltip: { _ in
            }, animateDiceSuccess: { _, _ in
            }, displayPremiumStickerTooltip: { _, _ in
            }, displayEmojiPackTooltip: { _, _ in
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
            }, activateAdAction: { _, _, _, _ in
            }, adContextAction: { _, _, _ in
            }, removeAd: { _ in
            }, openRequestedPeerSelection: { _, _, _, _ in
            }, saveMediaToFiles: { _ in
            }, openNoAdsDemo: {
            }, openAdsInfo: {
            }, displayGiveawayParticipationStatus: { _ in
            }, openPremiumStatusInfo: { _, _, _, _ in
            }, openRecommendedChannelContextMenu: { _, _, _ in
            }, openGroupBoostInfo: { _, _ in
            }, openStickerEditor: {
            }, openAgeRestrictedMessageMedia: { _, _ in
            }, playMessageEffect: { _ in
            }, editMessageFactCheck: { _ in
            }, sendGift: { _ in
            }, openUniqueGift: { _ in
            }, openMessageFeeException: {  
            }, requestMessageUpdate: { _, _ in
            }, cancelInteractiveKeyboardGestures: {
            }, dismissTextInput: {
            }, scrollToMessageId: { _ in
            }, navigateToStory: { _, _ in
            }, attemptedNavigationToPrivateQuote: { _ in
            }, forceUpdateWarpContents: {
            }, playShakeAnimation: {
            }, displayQuickShare: { _, _ ,_ in
            }, updateChatLocationThread: { _, _ in
            }, requestToggleTodoMessageItem: { _, _, _ in
            }, displayTodoToggleUnavailable: { _ in
            }, openStarsPurchase: { _ in
            }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings, pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(), presentationContext: ChatPresentationContext(context: context, backgroundNode: nil))
            
            
            let tagMask: MessageTags = .webPage
            let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
            self.historyNode = context.sharedContext.makeChatHistoryListNode(
                context: context,
                updatedPresentationData: (context.sharedContext.currentPresentationData.with({ $0 }), context.sharedContext.presentationData),
                chatLocation: .peer(id: context.account.peerId),
                chatLocationContextHolder: chatLocationContextHolder,
                tag: .tag(tagMask),
                source: .default,
                subject: nil,
                controllerInteraction: self.controllerInteraction,
                selectedMessages: .single(nil),
                mode: .list(
                    search: false,
                    reversed: false,
                    reverseGroups: false,
                    displayHeaders: .none,
                    hintLinks: true,
                    isGlobalSearch: false
                )
            )
            
            var addBookmarkImpl: (() -> Void)?
            self.bottomPanelNode = BottomPanelNode(theme: presentationData.theme, strings: presentationData.strings, action: {
                addBookmarkImpl?()
            })
            
            super.init()
            
            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.historyNode)
            self.addSubnode(self.bottomPanelNode)
            
            openMessageImpl = { [weak controller] message in
                guard let controller else {
                    return false
                }
                if let primaryUrl = getPrimaryUrl(message: message) {
                    controller.openUrl(primaryUrl)
                }
                controller.dismiss()
                return true
            }
            
            addBookmarkImpl = { [weak self] in
                guard let self else {
                    return
                }
                self.controller?.addBookmark()
                self.addedBookmark = true
                if let (layout, navigationBarHeight, actualNavigationBarHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout: layout, navigationBarHeight: navigationBarHeight, actualNavigationBarHeight: actualNavigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                }
            }
            
            openContextMenuImpl = { [weak self] message, sourceNode, rect, gesture in
                guard let self, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
                    return
                }
                
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                
                var itemList: [ContextMenuItem] = []
                if let webPage = message.media.first(where: { $0 is TelegramMediaWebpage }) as? TelegramMediaWebpage, let url = webPage.content.url {
                    itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.WebBrowser_CopyLink, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        UIPasteboard.general.string = url
                        if let self  {
                            self.controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                        }
                    })))
                }
                itemList.append(.action(ContextMenuActionItem(text: presentationData.strings.WebBrowser_DeleteBookmark, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)
                     
                    if let self {
                        let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: [message.id], type: .forEveryone).startStandalone()
                    }
                })))
                
                let items = ContextController.Items(content: .list(itemList))
                let controller = ContextController(
                    presentationData: presentationData,
                    source: .extracted(BrowserBookmarksContextExtractedContentSource(contentNode: sourceNode)),
                    items: .single(items),
                    recognizer: nil,
                    gesture: gesture as? ContextGesture
                )
                self.controller?.presentInGlobalOverlay(controller)
            }
        }
        
        func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
            guard let (layout, navigationBarHeight, _) = self.validLayout, let navigationBar = self.controller?.navigationBar else {
                return
            }
            let tagMask: MessageTags = .webPage
            
            self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, mode: .list, placeholder: self.presentationData.strings.Common_Search, hasBackground: true, contentNode: ChatHistorySearchContainerNode(context: self.context, peerId: self.context.account.peerId, threadId: nil, tagMask: tagMask, interfaceInteraction: self.controllerInteraction), cancel: { [weak self] in
                self?.controller?.deactivateSearch()
            })
            
            self.searchDisplayController?.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
                if let strongSelf = self, let placeholderNode {
                    if isSearchBar {
                        placeholderNode.supernode?.insertSubnode(subnode, aboveSubnode: placeholderNode)
                    } else {
                        strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                    }
                }
            }, placeholder: placeholderNode)
        }
        
        func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
            guard let searchDisplayController = self.searchDisplayController else {
                return
            }
            self.searchDisplayController = nil
            searchDisplayController.deactivate(placeholder: placeholderNode)
        }
        
        func scrollToTop() {
            self.historyNode.scrollToEndOfHistory()
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            self.validLayout = (layout, navigationBarHeight, actualNavigationBarHeight)
            
            let historyFrame = CGRect(origin: .zero, size: layout.size)
            transition.updateFrame(node: self.historyNode, frame: historyFrame)
            
            var insets = layout.insets(options: [.input])
            insets.top += navigationBarHeight
            
            var headerInsets = layout.insets(options: [.input])
            headerInsets.top += actualNavigationBarHeight
            
            let panelHeight = self.bottomPanelNode.updateLayout(width: layout.size.width, sideInset: layout.safeInsets.left, bottomInset: insets.bottom, transition: transition)
            var panelOrigin: CGFloat = layout.size.height
            if !self.addedBookmark {
                panelOrigin -= panelHeight
                insets.bottom = panelHeight
            }
            let panelFrame = CGRect(origin: CGPoint(x: 0.0, y: panelOrigin), size: CGSize(width: layout.size.width, height: panelHeight))
            transition.updateFrame(node: self.bottomPanelNode, frame: panelFrame)
            
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: historyFrame.size, insets: insets, headerInsets: headerInsets, duration: duration, curve: curve)
            self.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
            
            if let searchDisplayController = self.searchDisplayController {
                searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
            }
        }
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let url: String
    private let openUrl: (String) -> Void
    private let addBookmark: () -> Void
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    private var validLayout: ContainerViewLayout?
    
    private var node: Node {
        return self.displayNode as! Node
    }
    
    public init(context: AccountContext, url: String, openUrl: @escaping (String) -> Void, addBookmark: @escaping () -> Void) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.url = url
        self.openUrl = openUrl
        self.addBookmark = addBookmark
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
                
        self.navigationPresentation = .modal
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Close, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.title = self.presentationData.strings.WebBrowser_Bookmarks_Title
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: { [weak self] in
            self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
        
        self.scrollToTop = { [weak self] in
            if let self {
                if let searchContentNode = self.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                self.node.scrollToTop()
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
        }).strict()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, presentationData: self.presentationData)
        
        self.node.historyNode.contentPositionChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
            }
        }
//        
//        self.node.historyNode.didEndScrolling = { [weak self] _ in
//            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
//                let _ = fixNavigationSearchableListNodeScrolling(strongSelf.node.historyNode, searchNode: searchContentNode)
//            }
//        }
        
        self.displayNodeDidLoad()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)
    }
    
    fileprivate func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            if let searchContentNode = self.searchContentNode {
                self.node.activateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    fileprivate func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode {
                self.node.deactivateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
                
        self.controllerNode.containerLayoutUpdated(layout: layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
}

private class BottomPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    private let action: () -> Void
    
    private let separatorNode: ASDisplayNode
    private let button: HighlightTrackingButtonNode
    private let iconNode: ASImageNode
    private let textNode: ImmediateTextNode
    
    private var validLayout: (CGFloat, CGFloat, CGFloat)?
    
    init(theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings
        self.action = action

        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/AddIcon"), color: theme.rootController.navigationBar.accentTextColor)
        self.iconNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.attributedText = NSAttributedString(string: strings.WebBrowser_Bookmarks_BookmarkCurrent, font: Font.regular(17.0), textColor: theme.rootController.navigationBar.accentTextColor)
        self.textNode.isUserInteractionEnabled = false
        
        self.button = HighlightTrackingButtonNode()
        
        super.init()
        
        self.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
        
        self.addSubnode(self.button)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.iconNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.button)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let self {
                if highlighted {
                    self.iconNode.layer.removeAnimation(forKey: "opacity")
                    self.iconNode.alpha = 0.4
                    
                    self.textNode.layer.removeAnimation(forKey: "opacity")
                    self.textNode.alpha = 0.4
                } else {
                    self.iconNode.alpha = 1.0
                    self.iconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    
                    self.textNode.alpha = 1.0
                    self.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.action()
    }
    
    func updateLayout(width: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, sideInset, bottomInset)
        let topInset: CGFloat = 8.0
        var bottomInset = bottomInset
        bottomInset += topInset - (bottomInset.isZero ? 0.0 : 4.0)
                
        let buttonHeight: CGFloat = 40.0
        let textSize = self.textNode.updateLayout(CGSize(width: width, height: 44.0))
        
        let spacing: CGFloat = 8.0
        var contentWidth = textSize.width
        var contentOriginX = floorToScreenPixels((width - contentWidth) / 2.0)
        if let icon = self.iconNode.image {
            contentWidth += icon.size.width + spacing
            contentOriginX = floorToScreenPixels((width - contentWidth) / 2.0)
            transition.updateFrame(node: self.iconNode, frame: CGRect(origin: CGPoint(x: contentOriginX, y: 12.0 + UIScreenPixel), size: icon.size))
            contentOriginX += icon.size.width + spacing
        }
        let textFrame = CGRect(origin: CGPoint(x: contentOriginX, y: 17.0), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        transition.updateFrame(node: self.button, frame: textFrame.insetBy(dx: -10.0, dy: -10.0))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return topInset + buttonHeight + bottomInset
    }
}


final class BrowserBookmarksContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private let contentNode: ContextExtractedContentContainingNode
    
    init(contentNode: ContextExtractedContentContainingNode) {
        self.contentNode = contentNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.contentNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
