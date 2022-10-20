import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramPresentationData
import SearchBarNode

public enum SearchDisplayControllerMode {
    case list
    case navigation
}

public final class SearchDisplayController {
    private final class BackgroundNode: ASDisplayNode {
        var isTransparent: Bool = false
        
        override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = self.view.hitTest(point, with: event)
            if self.isTransparent, result === self.view {
                return nil
            } else {
                return result
            }
        }
    }
    
    private let searchBar: SearchBarNode
    private let mode: SearchDisplayControllerMode
    private let backgroundNode: BackgroundNode
    public let contentNode: SearchDisplayControllerContentNode
    private var hasSeparator: Bool
    private let inline: Bool
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    public var isDeactivating = false
    
    private var isSearchingDisposable: Disposable?
    
    public init(presentationData: PresentationData, mode: SearchDisplayControllerMode = .navigation, placeholder: String? = nil, hasBackground: Bool = false, hasSeparator: Bool = false, contentNode: SearchDisplayControllerContentNode, inline: Bool = false, cancel: @escaping () -> Void) {
        self.inline = inline
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: presentationData.theme, hasBackground: hasBackground, hasSeparator: hasSeparator, inline: inline), strings: presentationData.strings, fieldStyle: .modern, forceSeparator: hasSeparator, displayBackground: hasBackground)
        self.backgroundNode = BackgroundNode()
        self.backgroundNode.backgroundColor = presentationData.theme.chatList.backgroundColor
        self.backgroundNode.allowsGroupOpacity = true
        
        self.mode = mode
        self.contentNode = contentNode
        self.hasSeparator = hasSeparator
        
        self.searchBar.textUpdated = { [weak contentNode] text, _ in
            contentNode?.searchTextUpdated(text: text)
        }
        self.searchBar.tokensUpdated = { [weak contentNode] tokens in
            contentNode?.searchTokensUpdated(tokens: tokens)
        }
        self.searchBar.cancel = { [weak self] in
            self?.isDeactivating = true
            cancel()
        }
        self.searchBar.clearPrefix = { [weak contentNode] in
            contentNode?.searchTextClearPrefix()
        }
        self.searchBar.clearTokens = { [weak contentNode] in
            contentNode?.searchTextClearTokens()
        }
        self.contentNode.cancel = { [weak self] in
            self?.isDeactivating = true
            cancel()
        }
        self.contentNode.dismissInput = { [weak self] in
            self?.searchBar.deactivate(clear: false)
        }
        
        var isFirstTime = true
        self.contentNode.setQuery = { [weak self] prefix, tokens, query in
            if let strongSelf = self {
                strongSelf.searchBar.prefixString = prefix
                let previousTokens = strongSelf.searchBar.tokens
                strongSelf.searchBar.tokens = tokens
                strongSelf.searchBar.text = query
                if previousTokens.count < tokens.count && !isFirstTime {
                    strongSelf.searchBar.selectLastToken()
                }
                isFirstTime = false
            }
        }
        if let placeholder = placeholder {
            self.searchBar.placeholderString = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: presentationData.theme.rootController.navigationSearchBar.inputPlaceholderTextColor)
        }
        self.contentNode.setPlaceholder = { [weak self] string in
            guard string != self?.searchBar.placeholderString?.string else {
                return
            }
            if let mutableAttributedString = self?.searchBar.placeholderString?.mutableCopy() as? NSMutableAttributedString {
                mutableAttributedString.mutableString.setString(string)
                self?.searchBar.placeholderString = mutableAttributedString
            }
        }
        
        self.isSearchingDisposable = (contentNode.isSearching
        |> deliverOnMainQueue).start(next: { [weak self] value in
            self?.searchBar.activity = value
        })
    }
    
    public func updatePresentationData(_ presentationData: PresentationData) {
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: presentationData.theme, hasSeparator: self.hasSeparator, inline: self.inline), strings: presentationData.strings)
        self.contentNode.updatePresentationData(presentationData)
        
        if self.contentNode.hasDim {
            self.backgroundNode.backgroundColor = .clear
            self.backgroundNode.isTransparent = true
        } else {
            self.backgroundNode.backgroundColor = presentationData.theme.chatList.backgroundColor
            self.backgroundNode.isTransparent = false
        }
    }
    
    public func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let statusBarHeight: CGFloat = layout.statusBarHeight ?? 0.0
        let searchBarHeight: CGFloat = max(20.0, statusBarHeight) + 44.0
        let navigationBarOffset: CGFloat
        if statusBarHeight.isZero {
            navigationBarOffset = -20.0
        } else {
            navigationBarOffset = 0.0
        }
        var navigationBarFrame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarOffset), size: CGSize(width: layout.size.width, height: searchBarHeight))
        if layout.statusBarHeight == nil {
            navigationBarFrame.size.height = 64.0
        }
        navigationBarFrame.size.height += 10.0
        
        let searchBarFrame: CGRect
        if case .navigation = self.mode {
            searchBarFrame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: 54.0)
        } else {
            searchBarFrame = navigationBarFrame
        }
        transition.updateFrame(node: self.searchBar, frame: searchBarFrame)
        self.searchBar.updateLayout(boundingSize: searchBarFrame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, transition: transition)
        
        self.containerLayout = (layout, navigationBarFrame.maxY)
        
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        transition.updateFrame(node: self.backgroundNode, frame: bounds.insetBy(dx: -20.0, dy: -20.0))
        
        var size = layout.size
        size.width += 20.0 * 2.0
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 20.0), size: size))
                               
        var safeInsets = layout.safeInsets
        safeInsets.left += 20.0
        safeInsets.right += 20.0
        
        self.contentNode.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: safeInsets, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    public func activate(insertSubnode: @escaping (ASDisplayNode, Bool) -> Void, placeholder: SearchBarPlaceholderNode?, focus: Bool = true) {
        guard let (layout, navigationBarHeight) = self.containerLayout else {
            return
        }
        
        insertSubnode(self.backgroundNode, false)
        self.backgroundNode.addSubnode(self.contentNode)
        
        if self.contentNode.hasDim {
            self.backgroundNode.backgroundColor = .clear
            self.backgroundNode.isTransparent = true
        } else {
            self.backgroundNode.alpha = 0.0
            self.backgroundNode.isTransparent = false
        }
        
        var size = layout.size
        size.width += 20.0 * 2.0
        
        self.contentNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 20.0), size: size)
        
        var safeInsets = layout.safeInsets
        safeInsets.left += 20.0
        safeInsets.right += 20.0
        self.contentNode.containerLayoutUpdated(ContainerViewLayout(size: size, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: safeInsets, additionalInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), navigationBarHeight: navigationBarHeight, transition: .immediate)
        
        var contentNavigationBarHeight = navigationBarHeight
        if layout.statusBarHeight == nil {
            contentNavigationBarHeight += 28.0
        }
                
        if !self.contentNode.hasDim {
            self.backgroundNode.alpha = 1.0
            self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            
            self.backgroundNode.layer.animateScale(from: 0.85, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        if !self.contentNode.hasDim {
            if let placeholder = placeholder {
                self.searchBar.placeholderString = placeholder.placeholderString
            }
        } else {
            if let placeholder = placeholder {
                let initialTextBackgroundFrame = placeholder.convert(placeholder.backgroundNode.frame, to: nil)
                let contentNodePosition = self.backgroundNode.layer.position
                self.backgroundNode.layer.animatePosition(from: CGPoint(x: contentNodePosition.x, y: contentNodePosition.y + (initialTextBackgroundFrame.maxY + 8.0 - contentNavigationBarHeight)), to: contentNodePosition, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
                self.searchBar.placeholderString = placeholder.placeholderString
            }
        }
        
        let navigationBarFrame: CGRect
        switch self.mode {
            case .list:
                let statusBarHeight: CGFloat = layout.statusBarHeight ?? 0.0
                let searchBarHeight: CGFloat = max(20.0, statusBarHeight) + 44.0
                let navigationBarOffset: CGFloat
                if statusBarHeight.isZero {
                    navigationBarOffset = -20.0
                } else {
                    navigationBarOffset = 0.0
                }
                var frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarOffset), size: CGSize(width: layout.size.width, height: searchBarHeight))
                if layout.statusBarHeight == nil {
                    frame.size.height = 64.0
                }
                navigationBarFrame = frame
            case .navigation:
                navigationBarFrame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: 54.0)
        }
        
        self.searchBar.frame = navigationBarFrame
        insertSubnode(self.searchBar, true)
        self.searchBar.layout()
        
        if focus {
            self.searchBar.activate()
        }
        if let placeholder = placeholder {
            self.searchBar.animateIn(from: placeholder, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            if self.contentNode.hasDim {
                self.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            }
        } else {
            self.searchBar.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            self.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
        }
    }
    
    public func deactivate(placeholder: SearchBarPlaceholderNode?, animated: Bool = true) {
        self.searchBar.deactivate()
        
        let searchBar = self.searchBar
        if let placeholder = placeholder {
            searchBar.transitionOut(to: placeholder, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate, completion: {
                [weak searchBar] in
                searchBar?.removeFromSupernode()
            })
        } else {
            searchBar.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak searchBar] _ in
                searchBar?.removeFromSupernode()
            })
        }
        
        let backgroundNode = self.backgroundNode
        let contentNode = self.contentNode
        if animated {
            backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak backgroundNode] _ in
                backgroundNode?.removeFromSupernode()
            })
        } else {
            backgroundNode.removeFromSupernode()
            contentNode.removeFromSupernode()
        }
    }
    
    public func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
        return self.contentNode.previewViewAndActionAtLocation(location)
    }
}
