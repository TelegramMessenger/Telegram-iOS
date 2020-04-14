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
    private let searchBar: SearchBarNode
    private let mode: SearchDisplayControllerMode
    public let contentNode: SearchDisplayControllerContentNode
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    public var isDeactivating = false
    
    private var isSearchingDisposable: Disposable?
    
    public init(presentationData: PresentationData, mode: SearchDisplayControllerMode = .navigation, placeholder: String? = nil, contentNode: SearchDisplayControllerContentNode, cancel: @escaping () -> Void) {
        self.searchBar = SearchBarNode(theme: SearchBarNodeTheme(theme: presentationData.theme, hasSeparator: false), strings: presentationData.strings, fieldStyle: .modern)
        self.mode = mode
        self.contentNode = contentNode
        
        self.searchBar.textUpdated = { [weak contentNode] text, _ in
            contentNode?.searchTextUpdated(text: text)
        }
        self.searchBar.cancel = { [weak self] in
            self?.isDeactivating = true
            cancel()
        }
        self.searchBar.clearPrefix = { [weak contentNode] in
            contentNode?.searchTextClearPrefix()
        }
        self.contentNode.cancel = { [weak self] in
            self?.isDeactivating = true
            cancel()
        }
        self.contentNode.dismissInput = { [weak self] in
            self?.searchBar.deactivate(clear: false)
        }
        self.contentNode.setQuery = { [weak self] prefix, query in
            self?.searchBar.prefixString = prefix
            self?.searchBar.text = query
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
        self.searchBar.updateThemeAndStrings(theme: SearchBarNodeTheme(theme: presentationData.theme, hasSeparator: false), strings: presentationData.strings)
        self.contentNode.updatePresentationData(presentationData)
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
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.contentNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: layout.intrinsicInsets, safeInsets: layout.safeInsets, statusBarHeight: nil, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), navigationBarHeight: navigationBarFrame.maxY, transition: transition)
    }
    
    public func activate(insertSubnode: (ASDisplayNode, Bool) -> Void, placeholder: SearchBarPlaceholderNode?) {
        guard let (layout, navigationBarHeight) = self.containerLayout else {
            return
        }
        
        insertSubnode(self.contentNode, false)
        
        self.contentNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        self.contentNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: layout.safeInsets, statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), navigationBarHeight: navigationBarHeight, transition: .immediate)
        
        var contentNavigationBarHeight = navigationBarHeight
        if layout.statusBarHeight == nil {
            contentNavigationBarHeight += 28.0
        }
        
        if let placeholder = placeholder {
            let initialTextBackgroundFrame = placeholder.convert(placeholder.backgroundNode.frame, to: nil)
            
            let contentNodePosition = self.contentNode.layer.position
            
            self.contentNode.layer.animatePosition(from: CGPoint(x: contentNodePosition.x, y: contentNodePosition.y + (initialTextBackgroundFrame.maxY + 8.0 - contentNavigationBarHeight)), to: contentNodePosition, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            self.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue)
            self.searchBar.placeholderString = placeholder.placeholderString
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
        
        self.searchBar.activate()
        if let placeholder = placeholder {
            self.searchBar.animateIn(from: placeholder, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
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
        
        let contentNode = self.contentNode
        if animated {
            if let placeholder = placeholder, let (layout, navigationBarHeight) = self.containerLayout {
                let contentNodePosition = self.contentNode.layer.position
                let targetTextBackgroundFrame = placeholder.convert(placeholder.backgroundNode.frame, to: nil)
                
                var contentNavigationBarHeight = navigationBarHeight
                if layout.statusBarHeight == nil {
                    contentNavigationBarHeight += 28.0
                }
                
                self.contentNode.layer.animatePosition(from: contentNodePosition, to: CGPoint(x: contentNodePosition.x, y: contentNodePosition.y + (targetTextBackgroundFrame.maxY + 8.0 - contentNavigationBarHeight)), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            }
            contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak contentNode] _ in
                contentNode?.removeFromSupernode()
            })
        } else {
            contentNode.removeFromSupernode()
        }
    }
    
    public func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, CGRect, Any)? {
        return self.contentNode.previewViewAndActionAtLocation(location)
    }
}
