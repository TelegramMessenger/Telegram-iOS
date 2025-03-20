import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import EntityKeyboard
import ChatControllerInteraction
import MultiplexedVideoNode
import FeaturedStickersScreen
import StickerPeekUI
import EntityKeyboardGifContent
import BatchVideoRendering

private let searchBarHeight: CGFloat = 52.0

public protocol PaneSearchContentNode {
    var ready: Signal<Void, NoError> { get }
    var deactivateSearchBar: (() -> Void)? { get set }
    var updateActivity: ((Bool) -> Void)? { get set }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings)
    func updateText(_ text: String, languageCode: String?)
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition)
    
    func animateIn(additivePosition: CGFloat, transition: ContainedViewLayoutTransition)
    func animateOut(transition: ContainedViewLayoutTransition)
    
    func updatePreviewing(animated: Bool)
    func itemAt(point: CGPoint) -> (ASDisplayNode, Any)?
}

public final class PaneSearchContainerNode: ASDisplayNode, EntitySearchContainerNode {
    private let context: AccountContext
    private let mode: ChatMediaInputSearchMode
    public private(set) var contentNode: PaneSearchContentNode & ASDisplayNode
    private let interaction: ChatEntityKeyboardInputNode.Interaction
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    private let peekBehavior: EmojiContentPeekBehavior?
    
    private let backgroundNode: ASDisplayNode
    private let searchBar: PaneSearchBarNode
    
    private var validLayout: CGSize?
    
    public var onCancel: (() -> Void)?
    
    public var openGifContextMenu: ((MultiplexedVideoNodeFile, ASDisplayNode, CGRect, ContextGesture, Bool) -> Void)?
    
    public var ready: Signal<Void, NoError> {
        return self.contentNode.ready
    }
    
    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, interaction: ChatEntityKeyboardInputNode.Interaction, inputNodeInteraction: ChatMediaInputNodeInteraction, mode: ChatMediaInputSearchMode, batchVideoRenderingContext: BatchVideoRenderingContext?, stickerActionTitle: String? = nil, trendingGifsPromise: Promise<ChatMediaInputGifPaneTrendingState?>, cancel: @escaping () -> Void, peekBehavior: EmojiContentPeekBehavior?) {
        self.context = context
        self.mode = mode
        self.interaction = interaction
        self.inputNodeInteraction = inputNodeInteraction
        self.peekBehavior = peekBehavior
        switch mode {
        case .gif:
            self.contentNode = GifPaneSearchContentNode(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction, batchVideoRenderingContext: batchVideoRenderingContext ?? BatchVideoRenderingContext(context: context), trendingPromise: trendingGifsPromise)
        case .sticker, .trending:
            self.contentNode = StickerPaneSearchContentNode(context: context, theme: theme, strings: strings, interaction: interaction, inputNodeInteraction: inputNodeInteraction, stickerActionTitle: stickerActionTitle)
        }
        self.backgroundNode = ASDisplayNode()
        
        self.searchBar = PaneSearchBarNode()
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.contentNode)
        self.addSubnode(self.searchBar)
        
        self.contentNode.deactivateSearchBar = { [weak self] in
            self?.searchBar.deactivate(clear: false)
        }
        self.contentNode.updateActivity = { [weak self] active in
            self?.searchBar.activity = active
        }
        
        self.searchBar.cancel = { [weak self] in
            cancel()
            
            self?.searchBar.view.endEditing(true)
            self?.onCancel?()
        }
        self.searchBar.activate()
        
        self.searchBar.textUpdated = { [weak self] text, languageCode in
            self?.contentNode.updateText(text, languageCode: languageCode)
        }
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
        
        if let contentNode = self.contentNode as? GifPaneSearchContentNode {
            contentNode.requestUpdateQuery = { [weak self] query in
                self?.updateQuery(query)
            }
            contentNode.openGifContextMenu = { [weak self] file, node, rect, gesture, isSaved in
                self?.openGifContextMenu?(file, node, rect, gesture, isSaved)
            }
        }
        
        if let contentNode = self.contentNode as? StickerPaneSearchContentNode, let peekBehavior = self.peekBehavior {
            peekBehavior.setGestureRecognizerEnabled(view: self.contentNode.view, isEnabled: true, itemAtPoint: { [weak contentNode] point in
                guard let contentNode else {
                    return nil
                }
                guard let (itemNode, item) = contentNode.itemAt(point: point) else {
                    return nil
                }
                
                var maybeFile: TelegramMediaFile?
                if let item = item as? StickerPreviewPeekItem {
                    switch item {
                    case let .found(foundItem):
                        maybeFile = foundItem.file
                    case let .pack(fileValue):
                        maybeFile = fileValue
                    case .portal:
                        break
                    }
                }
                guard let file = maybeFile else {
                    return nil
                }
                
                var groupId: AnyHashable = AnyHashable("search")
                for attribute in file.attributes {
                    if case let .Sticker(_, packReference, _) = attribute {
                        if case let .id(id, _) = packReference {
                            groupId = AnyHashable(ItemCollectionId(namespace: Namespaces.ItemCollection.CloudStickerPacks, id: id))
                        }
                    }
                }
                
                return (groupId, itemNode.layer, file)
            })
        }
    }
    
    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.backgroundNode.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor.withAlphaComponent(1.0)
        self.contentNode.updateThemeAndStrings(theme: theme, strings: strings)
        self.searchBar.updateThemeAndStrings(theme: theme, strings: strings)
        
        let placeholder: String
        switch mode {
        case .gif:
            placeholder = strings.Gif_Search
        case .sticker, .trending:
            placeholder = strings.Stickers_Search
        }
        self.searchBar.placeholderString = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: theme.chat.inputMediaPanel.stickersSearchPlaceholderColor)
    }
    
    public func updateQuery(_ query: String) {
        self.searchBar.updateQuery(query)
    }
    
    public func itemAt(point: CGPoint) -> (ASDisplayNode, Any)? {
        return self.contentNode.itemAt(point: CGPoint(x: point.x, y: point.y - searchBarHeight))
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        
        transition.updateFrame(node: self.searchBar, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: searchBarHeight)))
        self.searchBar.updateLayout(boundingSize: CGSize(width: size.width, height: searchBarHeight), leftInset: leftInset, rightInset: rightInset, transition: transition)
        
        let contentFrame = CGRect(origin: CGPoint(x: leftInset, y: searchBarHeight), size: CGSize(width: size.width - leftInset - rightInset, height: size.height - searchBarHeight))
        
        transition.updateFrame(node: self.contentNode, frame: contentFrame)
        self.contentNode.updateLayout(size: contentFrame.size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: transition)
    }
    
    public func deactivate() {
        self.searchBar.deactivate(clear: true)
    }
    
    public func animateIn(from placeholder: PaneSearchBarPlaceholderNode?, anchorTop: CGPoint, anhorTopView: UIView, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        var verticalOrigin: CGFloat = anhorTopView.convert(anchorTop, to: self.view).y
        if let placeholder = placeholder {
            let placeholderFrame = placeholder.view.convert(placeholder.bounds, to: self.view)
            verticalOrigin = placeholderFrame.minY - 4.0
            self.contentNode.animateIn(additivePosition: verticalOrigin, transition: transition)
        } else {
            self.contentNode.animateIn(additivePosition: 0.0, transition: transition)
        }
        
        switch transition {
            case let .animated(duration, curve):
                self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration / 2.0)
                if let placeholder = placeholder {
                    self.searchBar.animateIn(from: placeholder, duration: duration, timingFunction: curve.timingFunction, completion: completion)
                } else {
                    self.searchBar.alpha = 0.0
                    transition.updateAlpha(node: self.searchBar, alpha: 1.0)
                }
                if let size = self.validLayout {
                    let initialBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin), size: CGSize(width: size.width, height: max(0.0, size.height - verticalOrigin)))
                    self.backgroundNode.layer.animateFrame(from: initialBackgroundFrame, to: self.backgroundNode.frame, duration: duration, timingFunction: curve.timingFunction)
                }
            case .immediate:
                break
        }
    }
    
    public func animateOut(to placeholder: PaneSearchBarPlaceholderNode, animateOutSearchBar: Bool, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        if case let .animated(duration, curve) = transition {
            if let size = self.validLayout {
                let placeholderFrame = placeholder.view.convert(placeholder.bounds, to: self.view)
                let verticalOrigin = placeholderFrame.minY - 4.0
                self.backgroundNode.layer.animateFrame(from: self.backgroundNode.frame, to: CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin), size: CGSize(width: size.width, height: max(0.0, size.height - verticalOrigin))), duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false)
            }
        }
        self.searchBar.transitionOut(to: placeholder, transition: transition, completion: completion)
        transition.updateAlpha(node: self.backgroundNode, alpha: 0.0)
        if animateOutSearchBar {
            transition.updateAlpha(node: self.searchBar, alpha: 0.0)
        }
        self.contentNode.animateOut(transition: transition)
        self.deactivate()
    }
}
