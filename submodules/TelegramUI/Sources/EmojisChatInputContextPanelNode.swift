import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import Display
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import AccountContext
import Emoji
import ChatPresentationInterfaceState
import AnimationCache
import MultiAnimationRenderer
import TextFormat
import ChatControllerInteraction
import ContextUI
import SwiftSignalKit
import PremiumUI
import StickerPeekUI
import UndoUI
import Pasteboard

private enum EmojisChatInputContextPanelEntryStableId: Hashable, Equatable {
    case symbol(String)
    case media(MediaId)
}

private func backgroundCenterImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 55.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        let lineWidth = UIScreenPixel
        context.setLineWidth(lineWidth)
        
        context.translateBy(x: 460.5, y: 364.0 - 27.0)
        let path: StaticString = "M-490.476836,-365 L-394.167708,-365 L-394.167708,-291.918214 C-394.167708,-291.918214 -383.538396,-291.918214 -397.691655,-291.918214 C-402.778486,-291.918214 -424.555168,-291.918214 -434.037301,-291.918214 C-440.297129,-291.918214 -440.780682,-283.5 -445.999879,-283.5 C-450.393041,-283.5 -452.491241,-291.918214 -456.502636,-291.918214 C-465.083339,-291.918214 -476.209155,-291.918214 -483.779021,-291.918214 C-503.033963,-291.918214 -490.476836,-291.918214 -490.476836,-291.918214 L-490.476836,-365 "
        let _ = try? drawSvgPath(context, path: path)
        context.fillPath()
        context.translateBy(x: 0.0, y: lineWidth / 2.0)
        let _ = try? drawSvgPath(context, path: path)
        context.strokePath()
        context.translateBy(x: -460.5, y: -lineWidth / 2.0 - 364.0 + 27.0)
        context.move(to: CGPoint(x: 0.0, y: lineWidth / 2.0))
        context.addLine(to: CGPoint(x: size.width, y: lineWidth / 2.0))
        context.strokePath()
    })
}

private func backgroundLeftImage(_ theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 16.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(theme.list.itemPlainSeparatorColor.cgColor)
        context.setFillColor(theme.list.plainBackgroundColor.cgColor)
        let lineWidth = UIScreenPixel
        context.setLineWidth(lineWidth)
        
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.height, height: size.height)))
        context.strokeEllipse(in: CGRect(origin: CGPoint(x: lineWidth / 2.0, y: lineWidth / 2.0), size: CGSize(width: size.height - lineWidth, height: size.height - lineWidth)))
    })?.stretchableImage(withLeftCapWidth: 8, topCapHeight: 8)
}

private struct EmojisChatInputContextPanelEntry: Comparable, Identifiable {
    let index: Int
    let theme: PresentationTheme
    let symbol: String
    let text: String
    let file: TelegramMediaFile?
    
    var stableId: EmojisChatInputContextPanelEntryStableId {
        if let file = self.file {
            return .media(file.fileId)
        } else {
            return .symbol(self.symbol)
        }
    }
    
    func withUpdatedTheme(_ theme: PresentationTheme) -> EmojisChatInputContextPanelEntry {
        return EmojisChatInputContextPanelEntry(index: self.index, theme: theme, symbol: self.symbol, text: self.text, file: self.file)
    }
    
    static func ==(lhs: EmojisChatInputContextPanelEntry, rhs: EmojisChatInputContextPanelEntry) -> Bool {
        return lhs.index == rhs.index && lhs.symbol == rhs.symbol && lhs.text == rhs.text && lhs.theme === rhs.theme && lhs.file?.fileId == rhs.file?.fileId
    }
    
    static func <(lhs: EmojisChatInputContextPanelEntry, rhs: EmojisChatInputContextPanelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, emojiSelected: @escaping (String, TelegramMediaFile?) -> Void) -> ListViewItem {
        return EmojisChatInputPanelItem(context: context, theme: self.theme, symbol: self.symbol, text: self.text, file: self.file, animationCache: animationCache, animationRenderer: animationRenderer, emojiSelected: emojiSelected)
    }
}

private struct EmojisChatInputContextPanelTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [EmojisChatInputContextPanelEntry], to toEntries: [EmojisChatInputContextPanelEntry], context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, emojiSelected: @escaping (String, TelegramMediaFile?) -> Void) -> EmojisChatInputContextPanelTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, animationCache: animationCache, animationRenderer: animationRenderer, emojiSelected: emojiSelected), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, animationCache: animationCache, animationRenderer: animationRenderer, emojiSelected: emojiSelected), directionHint: nil) }
    
    return EmojisChatInputContextPanelTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class EmojisChatInputContextPanelNode: ChatInputContextPanelNode {
    private let backgroundLeftNode: ASImageNode
    private let backgroundNode: ASImageNode
    private let backgroundRightNode: ASImageNode
    private let clippingNode: ASDisplayNode
    private let listView: ListView
    
    private var currentEntries: [EmojisChatInputContextPanelEntry]?
    
    private var enqueuedTransitions: [(EmojisChatInputContextPanelTransition, Bool)] = []
    private var validLayout: (CGSize, CGFloat, CGFloat, CGFloat)?
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
    
    private weak var peekController: PeekController?
    
    override init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.animationCache = chatPresentationContext.animationCache
        self.animationRenderer = chatPresentationContext.animationRenderer
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = backgroundCenterImage(theme)
        
        self.backgroundLeftNode = ASImageNode()
        self.backgroundLeftNode.displayWithoutProcessing = true
        self.backgroundLeftNode.displaysAsynchronously = false
        self.backgroundLeftNode.image = backgroundLeftImage(theme)
        
        self.backgroundRightNode = ASImageNode()
        self.backgroundRightNode.displayWithoutProcessing = true
        self.backgroundRightNode.displaysAsynchronously = false
        self.backgroundRightNode.image = backgroundLeftImage(theme)
        self.backgroundRightNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.listView = ListView()
        self.listView.isOpaque = false
        self.listView.view.disablesInteractiveTransitionGestureRecognizer = true
        self.listView.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        self.listView.accessibilityPageScrolledString = { row, count in
            return strings.VoiceOver_ScrollStatus(row, count).string
        }
        
        super.init(context: context, theme: theme, strings: strings, fontSize: fontSize, chatPresentationContext: chatPresentationContext)
        
        self.placement = .overTextInput
        self.isOpaque = false
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.backgroundLeftNode)
        self.addSubnode(self.backgroundRightNode)
        
        self.addSubnode(self.clippingNode)
        self.clippingNode.addSubnode(self.listView)
        
        let peekRecognizer = PeekControllerGestureRecognizer(contentAtPoint: { [weak self] point in
            guard let self else {
                return nil
            }
            return self.peekContentAtPoint(point: point)
        }, present: { [weak self] content, sourceView, sourceRect in
            guard let strongSelf = self else {
                return nil
            }
            
            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
            let controller = PeekController(presentationData: presentationData, content: content, sourceView: {
                return (sourceView, sourceRect)
            })
            /*controller.visibilityUpdated = { [weak self] visible in
                self?.previewingStickersPromise.set(visible)
                self?.requestDisableStickerAnimations?(visible)
                self?.simulateUpdateLayout(isVisible: !visible)
            }*/
            strongSelf.peekController = controller
            strongSelf.interfaceInteraction?.presentController(controller, nil)
            return controller
        }, updateContent: { [weak self] content in
            guard let strongSelf = self else {
                return
            }
            
            let _ = strongSelf
        })
        self.view.addGestureRecognizer(peekRecognizer)
    }
    
    private func peekContentAtPoint(point: CGPoint) -> Signal<(UIView, CGRect, PeekControllerContent)?, NoError>? {
        guard let presentationInterfaceState = self.presentationInterfaceState else {
            return nil
        }
        guard let chatPeerId = presentationInterfaceState.renderedPeer?.peer?.id else {
            return nil
        }
        
        var maybeFile: TelegramMediaFile?
        var maybeItemLayer: CALayer?
        
        self.listView.forEachItemNode { itemNode in
            if let itemNode = itemNode as? EmojisChatInputPanelItemNode, let item = itemNode.item {
                let localPoint = self.view.convert(point, to: itemNode.view)
                if itemNode.view.bounds.contains(localPoint) {
                    maybeFile = item.file
                    maybeItemLayer = itemNode.layer
                }
            }
        }
        
        guard let file = maybeFile else {
            return nil
        }
        guard let itemLayer = maybeItemLayer else {
            return nil
        }
        
        let _ = chatPeerId
        let _ = file
        let _ = itemLayer
        
        var collectionId: ItemCollectionId?
        for attribute in file.attributes {
            if case let .CustomEmoji(_, _, _, packReference) = attribute {
                switch packReference {
                case let .id(id, _):
                    collectionId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: id)
                default:
                    break
                }
            }
        }
        
        var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
        if let collectionId {
            bubbleUpEmojiOrStickersets.append(collectionId)
        }
        
        let context = self.context
        let accountPeerId = context.account.peerId
        
        let _ = bubbleUpEmojiOrStickersets
        let _ = context
        let _ = accountPeerId
        
        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId))
        |> map { peer -> Bool in
            var hasPremium = false
            if case let .user(user) = peer, user.isPremium {
                hasPremium = true
            }
            return hasPremium
        }
        |> deliverOnMainQueue
        |> map { [weak self, weak itemLayer] hasPremium -> (UIView, CGRect, PeekControllerContent)? in
            guard let strongSelf = self, let itemLayer = itemLayer else {
                return nil
            }
            
            let _ = strongSelf
            let _ = itemLayer
            
            var menuItems: [ContextMenuItem] = []
            menuItems.removeAll()
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let _ = presentationData
            
            var isLocked = false
            if !hasPremium {
                isLocked = file.isPremiumEmoji
                if isLocked && chatPeerId == context.account.peerId {
                    isLocked = false
                }
            }
            
            if let interaction = strongSelf.interfaceInteraction {
                let _ = interaction
                
                let sendEmoji: (TelegramMediaFile) -> Void = { file in
                    guard let self else {
                        return
                    }
                    guard let controller = (self.interfaceInteraction?.chatController() as? ChatControllerImpl) else {
                        return
                    }
                    
                    var text = "."
                    var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                    loop: for attribute in file.attributes {
                        switch attribute {
                        case let .CustomEmoji(_, _, displayText, stickerPackReference):
                            text = displayText
                            
                            var packId: ItemCollectionId?
                            if case let .id(id, _) = stickerPackReference {
                                packId = ItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: id)
                            }
                            emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: packId, fileId: file.fileId.id, file: file)
                            break loop
                        default:
                            break
                        }
                    }
                    
                    if let emojiAttribute {
                        controller.controllerInteraction?.sendEmoji(text, emojiAttribute, true)
                    }
                }
                let setStatus: (TelegramMediaFile) -> Void = { file in
                    guard let self else {
                        return
                    }
                    guard let controller = (self.interfaceInteraction?.chatController() as? ChatControllerImpl) else {
                        return
                    }
                    
                    let _ = self.context.engine.accountData.setEmojiStatus(file: file, expirationDate: nil).start()
                    
                    var animateInAsReplacement = false
                    animateInAsReplacement = false
                    /*if let currentUndoOverlayController = strongSelf.currentUndoOverlayController {
                        currentUndoOverlayController.dismissWithCommitActionAndReplacementAnimation()
                        strongSelf.currentUndoOverlayController = nil
                        animateInAsReplacement = true
                    }*/
                                                
                    let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                    
                    let undoController = UndoOverlayController(presentationData: presentationData, content: .sticker(context: self.context, file: file, title: nil, text: presentationData.strings.EmojiStatus_AppliedText, undoText: nil, customAction: nil), elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: { _ in return false })
                    //strongSelf.currentUndoOverlayController = controller
                    controller.controllerInteraction?.presentController(undoController, nil)
                }
                let copyEmoji: (TelegramMediaFile) -> Void = { file in
                    var text = "."
                    var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                    loop: for attribute in file.attributes {
                        switch attribute {
                        case let .CustomEmoji(_, _, displayText, _):
                            text = displayText
                            
                            emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                            break loop
                        default:
                            break
                        }
                    }
                    
                    if let _ = emojiAttribute {
                        storeMessageTextInPasteboard(text, entities: [MessageTextEntity(range: 0 ..< (text as NSString).length, type: .CustomEmoji(stickerPack: nil, fileId: file.fileId.id))])
                    }
                }
                
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_SendEmoji, icon: { theme in
                    if let image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Download"), color: theme.actionSheet.primaryTextColor) {
                        return generateImage(image.size, rotatedContext: { size, context in
                            context.clear(CGRect(origin: CGPoint(), size: size))
                            
                            if let cgImage = image.cgImage {
                                context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                            }
                        })
                    } else {
                        return nil
                    }
                }, action: { _, f in
                    sendEmoji(file)
                    f(.default)
                })))
                
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_SetAsStatus, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Smile"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.default)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if hasPremium {
                        setStatus(file)
                    } else {
                        var replaceImpl: ((ViewController) -> Void)?
                        let controller = PremiumDemoScreen(context: context, subject: .animatedEmoji, action: {
                            let controller = PremiumIntroScreen(context: context, source: .animatedEmoji)
                            replaceImpl?(controller)
                        })
                        replaceImpl = { [weak controller] c in
                            controller?.replace(with: c)
                        }
                        strongSelf.interfaceInteraction?.getNavigationController()?.pushViewController(controller)
                    }
                })))
                
                menuItems.append(.action(ContextMenuActionItem(text: presentationData.strings.EmojiPreview_CopyEmoji, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    copyEmoji(file)
                    f(.default)
                })))
            }
            
            if menuItems.isEmpty {
                return nil
            }
            
            let content = StickerPreviewPeekContent(context: context, theme: presentationData.theme, strings: presentationData.strings, item: .pack(file), isLocked: isLocked, menu: menuItems, openPremiumIntro: { [weak self] in
                guard let self else {
                    return
                }
                guard let interfaceInteraction = self.interfaceInteraction else {
                    return
                }
                
                let _ = self
                let _ = interfaceInteraction
                
                let controller = PremiumIntroScreen(context: context, source: .stickers)
                //let _ = controller
                
                interfaceInteraction.getNavigationController()?.pushViewController(controller)
            })
            let _ = content
            //return nil
            
            return (strongSelf.view, itemLayer.convert(itemLayer.bounds, to: strongSelf.view.layer), content)
        }
    }
    
    func updateResults(_ results: [(String, TelegramMediaFile?, String)]) {
        var entries: [EmojisChatInputContextPanelEntry] = []
        var index = 0
        var stableIds = Set<EmojisChatInputContextPanelEntryStableId>()
        for (symbol, file, text) in results {
            let entry = EmojisChatInputContextPanelEntry(index: index, theme: self.theme, symbol: symbol.normalizedEmoji, text: text, file: file)
            if stableIds.contains(entry.stableId) {
                continue
            }
            stableIds.insert(entry.stableId)
            entries.append(entry)
            index += 1
        }
        self.prepareTransition(from: self.currentEntries, to: entries)
    }
    
    private func prepareTransition(from: [EmojisChatInputContextPanelEntry]? , to: [EmojisChatInputContextPanelEntry]) {
        let firstTime = self.currentEntries == nil
        let transition = preparedTransition(from: from ?? [], to: to, context: self.context, animationCache: self.animationCache, animationRenderer: self.animationRenderer, emojiSelected: { [weak self] text, file in
            guard let strongSelf = self, let interfaceInteraction = strongSelf.interfaceInteraction else {
                return
            }
            
            var text = text
            
            interfaceInteraction.updateTextInputStateAndMode { textInputState, inputMode in
                var hashtagQueryRange: NSRange?
                inner: for (range, type, _) in textInputStateContextQueryRangeAndType(textInputState) {
                    if type == [.emojiSearch] {
                        var range = range
                        range.location -= 1
                        range.length += 1
                        hashtagQueryRange = range
                        break inner
                    }
                }
                
                if let range = hashtagQueryRange {
                    let inputText = NSMutableAttributedString(attributedString: textInputState.inputText)
                    
                    var emojiAttribute: ChatTextInputTextCustomEmojiAttribute?
                    if let file = file {
                        loop: for attribute in file.attributes {
                            switch attribute {
                            case let .CustomEmoji(_, _, displayText, _):
                                text = displayText
                                emojiAttribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: file.fileId.id, file: file)
                                break loop
                            default:
                                break
                            }
                        }
                    }
                    
                    var replacementText = NSAttributedString(string: text)
                    if let emojiAttribute = emojiAttribute {
                        replacementText = NSAttributedString(string: text, attributes: [ChatTextInputAttributes.customEmoji: emojiAttribute])
                    }
                    
                    inputText.replaceCharacters(in: range, with: replacementText)
                    
                    let selectionPosition = range.lowerBound + (replacementText.string as NSString).length
                    
                    return (ChatTextInputState(inputText: inputText, selectionRange: selectionPosition ..< selectionPosition), inputMode)
                }
                return (textInputState, inputMode)
            }
        })
        self.currentEntries = to
        self.enqueueTransition(transition, firstTime: firstTime)
        
        if let presentationInterfaceState = presentationInterfaceState, let (size, leftInset, rightInset, bottomInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, transition: .immediate, interfaceState: presentationInterfaceState)
        }
    }
    
    private func enqueueTransition(_ transition: EmojisChatInputContextPanelTransition, firstTime: Bool) {
        enqueuedTransitions.append((transition, firstTime))
        
        if self.validLayout != nil {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        if let validLayout = self.validLayout, let (transition, _) = self.enqueuedTransitions.first {
            self.enqueuedTransitions.remove(at: 0)
            
            var options = ListViewDeleteAndInsertOptions()
            options.insert(.Synchronous)
            
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: validLayout.0, insets: UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0), duration: 0.0, curve: .Default(duration: nil))
            
            self.listView.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, updateSizeAndInsets: updateSizeAndInsets, updateOpaqueState: nil)
        }
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (size, leftInset, rightInset, bottomInset)
        self.presentationInterfaceState = interfaceState
        
        let sideInsets: CGFloat = 10.0 + leftInset
        let contentWidth = min(size.width - sideInsets - sideInsets, max(24.0, CGFloat(self.currentEntries?.count ?? 0) * 45.0))
        
        var contentLeftInset: CGFloat = 40.0
        var leftOffset: CGFloat = 0.0
        if sideInsets + floor(contentWidth / 2.0) < sideInsets + contentLeftInset + 15.0 {
            let updatedLeftInset = sideInsets + floor(contentWidth / 2.0) - 15.0 - sideInsets
            leftOffset = contentLeftInset - updatedLeftInset
            contentLeftInset = updatedLeftInset
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: sideInsets + leftOffset, y: size.height - 55.0 + 4.0), size: CGSize(width: contentWidth, height: 55.0))
        let backgroundLeftFrame = CGRect(origin: backgroundFrame.origin, size: CGSize(width: contentLeftInset, height: backgroundFrame.size.height - 10.0 + UIScreenPixel))
        let backgroundCenterFrame = CGRect(origin: CGPoint(x: backgroundLeftFrame.maxX, y: backgroundFrame.minY), size: CGSize(width: 30.0, height: 55.0))
        let backgroundRightFrame = CGRect(origin: CGPoint(x: backgroundCenterFrame.maxX, y: backgroundFrame.minY), size: CGSize(width: max(0.0, backgroundFrame.minX + backgroundFrame.size.width - backgroundCenterFrame.maxX), height: backgroundFrame.size.height - 10.0 + UIScreenPixel))
        transition.updateFrame(node: self.backgroundLeftNode, frame: backgroundLeftFrame)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundCenterFrame)
        transition.updateFrame(node: self.backgroundRightNode, frame: backgroundRightFrame)
        
        let gridFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX, y: backgroundFrame.minY + 2.0), size: CGSize(width: backgroundFrame.size.width, height: 45.0))
        transition.updateFrame(node: self.clippingNode, frame: gridFrame)
        self.listView.frame = CGRect(origin: CGPoint(), size: CGSize(width: gridFrame.size.height, height: gridFrame.size.width))
        
        let gridBounds = self.listView.bounds
        self.listView.bounds = CGRect(x: gridBounds.minX, y: gridBounds.minY, width: gridFrame.size.height, height: gridFrame.size.width)
        self.listView.position = CGPoint(x: gridFrame.size.width / 2.0, y: gridFrame.size.height / 2.0)
        
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: CGSize(width: gridFrame.size.height, height: gridFrame.size.width), insets: UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0), duration: 0.0, curve: .Default(duration: 0.0))

        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: updateSizeAndInsets, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        
        if !hadValidLayout {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
            self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
        
        if self.theme !== interfaceState.theme {
            self.theme = interfaceState.theme

            let updatedEntries = self.currentEntries?.map({$0.withUpdatedTheme(interfaceState.theme)}) ?? []
            self.prepareTransition(from: self.currentEntries, to: updatedEntries)
        }
    }
    
    override func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.clippingNode.frame.contains(point) {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}

