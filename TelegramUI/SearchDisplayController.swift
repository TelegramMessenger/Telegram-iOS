import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Display

final class SearchDisplayController {
    private let searchBar: SearchBarNode
    let contentNode: SearchDisplayControllerContentNode
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private(set) var isDeactivating = false
    
    init(theme: PresentationTheme, strings: PresentationStrings, contentNode: SearchDisplayControllerContentNode, cancel: @escaping () -> Void) {
        self.searchBar = SearchBarNode(theme: theme, strings: strings)
        self.contentNode = contentNode
        
        self.searchBar.textUpdated = { [weak contentNode] text in
            contentNode?.searchTextUpdated(text: text)
        }
        self.searchBar.cancel = { [weak self] in
            self?.isDeactivating = true
            cancel()
        }
        self.contentNode.cancel = { [weak self] in
            self?.isDeactivating = true
            cancel()
        }
        self.contentNode.dismissInput = { [weak self] in
            self?.searchBar.deactivate(clear: false)
        }
    }
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.searchBar.updateThemeAndStrings(theme: theme, strings: strings)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let searchBarFrame = CGRect(origin: CGPoint(x: 0.0, y: (layout.statusBarHeight ?? 0.0) - 20.0), size: CGSize(width: layout.size.width, height: 64.0))
        transition.updateFrame(node: self.searchBar, frame: searchBarFrame)
        
        self.containerLayout = (layout, searchBarFrame.maxY)
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.contentNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: LayoutMetrics(), intrinsicInsets: layout.intrinsicInsets, statusBarHeight: nil, inputHeight: layout.inputHeight), navigationBarHeight: searchBarFrame.maxY, transition: transition)
    }
    
    func activate(insertSubnode: (ASDisplayNode) -> Void, placeholder: SearchBarPlaceholderNode) {
        guard let (layout, navigationBarHeight) = self.containerLayout else {
            return
        }
        
        insertSubnode(self.contentNode)
        
        self.contentNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.contentNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil), navigationBarHeight: navigationBarHeight, transition: .immediate)
        
        let initialTextBackgroundFrame = placeholder.convert(placeholder.backgroundNode.frame, to: self.contentNode.supernode)
        
        let contentNodePosition = self.contentNode.layer.position
        self.contentNode.layer.animatePosition(from: CGPoint(x: contentNodePosition.x, y: contentNodePosition.y + (initialTextBackgroundFrame.maxY + 8.0 - navigationBarHeight)), to: contentNodePosition, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        self.contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionEaseOut)
        
        self.searchBar.placeholderString = placeholder.placeholderString
        self.searchBar.frame = CGRect(origin: CGPoint(x: 0.0, y: (layout.statusBarHeight ?? 0.0) - 20.0), size: CGSize(width: layout.size.width, height: 64.0))
        insertSubnode(searchBar)
        self.searchBar.layout()
        
        self.searchBar.activate()
        self.searchBar.animateIn(from: placeholder, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func deactivate(placeholder: SearchBarPlaceholderNode?, animated: Bool = true) {
        searchBar.deactivate()
        
        if let placeholder = placeholder {
            let searchBar = self.searchBar
            searchBar.transitionOut(to: placeholder, transition: animated ? ContainedViewLayoutTransition.animated(duration: 0.5, curve: .spring) : ContainedViewLayoutTransition.immediate, completion: {
                [weak searchBar] in
                searchBar?.removeFromSupernode()
            })
        }
        
        let contentNode = self.contentNode
        if animated {
            if let placeholder = placeholder, let (_, navigationBarHeight) = self.containerLayout {
                let contentNodePosition = self.contentNode.layer.position
                let targetTextBackgroundFrame = placeholder.convert(placeholder.backgroundNode.frame, to: self.contentNode.supernode)
                
                self.contentNode.layer.animatePosition(from: contentNodePosition, to: CGPoint(x: contentNodePosition.x, y: contentNodePosition.y + (targetTextBackgroundFrame.maxY + 8.0 - navigationBarHeight)), duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            }
            contentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak contentNode] _ in
                contentNode?.removeFromSupernode()
            })
        } else {
            contentNode.removeFromSupernode()
        }
    }
    
    func previewViewAndActionAtLocation(_ location: CGPoint) -> (UIView, Any)? {
        return self.contentNode.previewViewAndActionAtLocation(location)
    }
}
