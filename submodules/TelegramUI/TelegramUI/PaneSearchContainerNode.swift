import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext

private let searchBarHeight: CGFloat = 52.0

protocol PaneSearchContentNode {
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

final class PaneSearchContainerNode: ASDisplayNode {
    private let context: AccountContext
    private let mode: ChatMediaInputSearchMode
    public private(set) var contentNode: PaneSearchContentNode & ASDisplayNode
    private let controllerInteraction: ChatControllerInteraction
    private let inputNodeInteraction: ChatMediaInputNodeInteraction
    
    private let backgroundNode: ASDisplayNode
    private let searchBar: PaneSearchBarNode
    
    private var validLayout: CGSize?
    
    var ready: Signal<Void, NoError> {
        return self.contentNode.ready
    }
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, controllerInteraction: ChatControllerInteraction, inputNodeInteraction: ChatMediaInputNodeInteraction, mode: ChatMediaInputSearchMode, trendingGifsPromise: Promise<[FileMediaReference]?>, cancel: @escaping () -> Void) {
        self.context = context
        self.mode = mode
        self.controllerInteraction = controllerInteraction
        self.inputNodeInteraction = inputNodeInteraction
        switch mode {
            case .gif:
                self.contentNode = GifPaneSearchContentNode(context: context, theme: theme, strings: strings, controllerInteraction: controllerInteraction, inputNodeInteraction: inputNodeInteraction, trendingPromise: trendingGifsPromise)
            case .sticker:
                self.contentNode = StickerPaneSearchContentNode(context: context, theme: theme, strings: strings, controllerInteraction: controllerInteraction, inputNodeInteraction: inputNodeInteraction)
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
        
        self.searchBar.cancel = {
            cancel()
        }
        self.searchBar.activate()
        
        self.searchBar.textUpdated = { [weak self] text, languageCode in
            self?.contentNode.updateText(text, languageCode: languageCode)
        }
        
        self.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.backgroundNode.backgroundColor = theme.chat.inputMediaPanel.stickersBackgroundColor
        self.contentNode.updateThemeAndStrings(theme: theme, strings: strings)
        self.searchBar.updateThemeAndStrings(theme: theme, strings: strings)
        
        let placeholder: String
        switch mode {
            case .gif:
                placeholder = strings.Gif_Search
            case .sticker:
                placeholder = strings.Stickers_Search
        }
        self.searchBar.placeholderString = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: theme.chat.inputMediaPanel.stickersSearchPlaceholderColor)
    }
    
    func itemAt(point: CGPoint) -> (ASDisplayNode, Any)? {
        return self.contentNode.itemAt(point: CGPoint(x: point.x, y: point.y - searchBarHeight))
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, inputHeight: CGFloat, deviceMetrics: DeviceMetrics, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        
        transition.updateFrame(node: self.searchBar, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: searchBarHeight)))
        self.searchBar.updateLayout(boundingSize: CGSize(width: size.width, height: searchBarHeight), leftInset: leftInset, rightInset: rightInset, transition: transition)
        
        let contentFrame = CGRect(origin: CGPoint(x: leftInset, y: searchBarHeight), size: CGSize(width: size.width - leftInset - rightInset, height: size.height - searchBarHeight))
        
        transition.updateFrame(node: self.contentNode, frame: contentFrame)
        self.contentNode.updateLayout(size: contentFrame.size, leftInset: leftInset, rightInset: rightInset, bottomInset: bottomInset, inputHeight: inputHeight, deviceMetrics: deviceMetrics, transition: transition)
    }
    
    func deactivate() {
        self.searchBar.deactivate(clear: true)
    }
    
    func animateIn(from placeholder: PaneSearchBarPlaceholderNode, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        let placeholderFrame = placeholder.view.convert(placeholder.bounds, to: self.view)
        let verticalOrigin = placeholderFrame.minY - 4.0
        self.contentNode.animateIn(additivePosition: verticalOrigin, transition: transition)
        
        switch transition {
            case let .animated(duration, curve):
                self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration / 2.0)
                self.searchBar.animateIn(from: placeholder, duration: duration, timingFunction: curve.timingFunction, completion: completion)
                if let size = self.validLayout {
                    let initialBackgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: verticalOrigin), size: CGSize(width: size.width, height: max(0.0, size.height - verticalOrigin)))
                    self.backgroundNode.layer.animateFrame(from: initialBackgroundFrame, to: self.backgroundNode.frame, duration: duration, timingFunction: curve.timingFunction)
                }
            case .immediate:
                break
        }
    }
    
    func animateOut(to placeholder: PaneSearchBarPlaceholderNode, animateOutSearchBar: Bool, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
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
