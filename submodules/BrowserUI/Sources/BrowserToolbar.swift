import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import AppBundle

private func toolbarContentNode(for state: BrowserState, currentContentNode: BrowserToolbarContentNode?, layoutMetrics: LayoutMetrics, theme: BrowserToolbarTheme, strings: PresentationStrings, interaction: BrowserInteraction?) -> BrowserToolbarContentNode? {
    guard case .compact = layoutMetrics.widthClass else {
        return nil
    }
    if let _ = state.search {
        if let currentContentNode = currentContentNode as? BrowserToolbarSearchContentNode {
            currentContentNode.updateState(state)
            return currentContentNode
        } else {
            return BrowserToolbarSearchContentNode(theme: theme, strings: strings, state: state, interaction: interaction)
        }
    } else {
        if let currentContentNode = currentContentNode as? BrowserToolbarNavigationContentNode {
            currentContentNode.updateState(state)
            return currentContentNode
        } else {
            return BrowserToolbarNavigationContentNode(theme: theme, strings: strings, state: state, interaction: interaction)
        }
    }
}

final class BrowserToolbarTheme {
    let backgroundColor: UIColor
    let separatorColor: UIColor
    let buttonColor: UIColor
    let disabledButtonColor: UIColor
    
    init(backgroundColor: UIColor, separatorColor: UIColor, buttonColor: UIColor, disabledButtonColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
    }
}

protocol BrowserToolbarContentNode: ASDisplayNode {
    init(theme: BrowserToolbarTheme, strings: PresentationStrings, state: BrowserState, interaction: BrowserInteraction?)
    func updateState(_ state: BrowserState)
    func updateTheme(_ theme: BrowserToolbarTheme)
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}

private let toolbarHeight: CGFloat = 49.0

final class BrowserToolbar: ASDisplayNode {
    private var theme: BrowserToolbarTheme
    private let strings: PresentationStrings
    private var state: BrowserState
    var interaction: BrowserInteraction?
    
    private let containerNode: ASDisplayNode
    private let separatorNode: ASDisplayNode
    private var contentNode: BrowserToolbarContentNode?
    
    private var validLayout: (CGFloat, UIEdgeInsets, LayoutMetrics, CGFloat)?
    
    init(theme: BrowserToolbarTheme, strings: PresentationStrings, state: BrowserState) {
        self.theme = theme
        self.strings = strings
        self.state = state
        
        self.containerNode = ASDisplayNode()
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.separatorColor
        
        super.init()
        
        self.clipsToBounds = true
        self.containerNode.backgroundColor = theme.backgroundColor
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.separatorNode)
    }
    
    func updateState(_ state: BrowserState) {
        self.state = state
        if let (width, insets, layoutMetrics, collapseTransition) = self.validLayout {
            let _ = self.updateLayout(width: width, insets: insets, layoutMetrics: layoutMetrics, collapseTransition: collapseTransition, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
    }
    
    func updateTheme(_ theme: BrowserToolbarTheme) {
        guard self.theme !== theme else {
            return
        }
        self.theme = theme
        
        self.containerNode.backgroundColor = theme.backgroundColor
        self.separatorNode.backgroundColor = theme.separatorColor
        self.contentNode?.updateTheme(theme)
    }
    
    func updateLayout(width: CGFloat, insets: UIEdgeInsets, layoutMetrics: LayoutMetrics, collapseTransition: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = (width, insets, layoutMetrics, collapseTransition)
        
        var dismissedContentNode: ASDisplayNode?
        var immediatelyLayoutContentNodeAndAnimateAppearance = false
        if let contentNode = toolbarContentNode(for: self.state, currentContentNode: self.contentNode, layoutMetrics: layoutMetrics, theme: self.theme, strings: self.strings, interaction: self.interaction) {
            if contentNode !== self.contentNode {
                dismissedContentNode = self.contentNode
                immediatelyLayoutContentNodeAndAnimateAppearance = true
                self.containerNode.insertSubnode(contentNode, belowSubnode: self.separatorNode)
                self.contentNode = contentNode
            }
        } else {
            dismissedContentNode = self.contentNode
            self.contentNode = nil
        }
        
        let effectiveCollapseTransition = self.contentNode == nil ? 1.0 : collapseTransition
        
        let height = toolbarHeight + insets.bottom
        
        let containerFrame = CGRect(origin: CGPoint(x: 0.0, y: height * effectiveCollapseTransition), size: CGSize(width: width, height: height))
        transition.updateFrame(node: self.containerNode, frame: containerFrame)
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(x: 0.0, y: 0.0, width: width, height: UIScreenPixel))
        
        let constrainedSize = CGSize(width: width - insets.left - insets.right, height: toolbarHeight)
        
        if let contentNode = self.contentNode {
            let contentNodeFrame = CGRect(origin: CGPoint(x: insets.left, y: 0.0), size: constrainedSize)
            contentNode.updateLayout(size: constrainedSize, transition: transition)
            
            if immediatelyLayoutContentNodeAndAnimateAppearance {
                contentNode.frame = contentNodeFrame.offsetBy(dx: 0.0, dy: contentNodeFrame.height)
                contentNode.alpha = 0.0
            }
            
            transition.updateFrame(node: contentNode, frame: contentNodeFrame)
            transition.updateAlpha(node: contentNode, alpha: 1.0)
        }
        
        if let dismissedContentNode = dismissedContentNode {
            var frameCompleted = false
            var alphaCompleted = false
            let completed = { [weak self, weak dismissedContentNode] in
                if let strongSelf = self, let dismissedContentNode = dismissedContentNode, strongSelf.contentNode === dismissedContentNode {
                    return
                }
                if frameCompleted && alphaCompleted {
                    dismissedContentNode?.removeFromSupernode()
                }
            }
            let transitionTargetY = dismissedContentNode.frame.height
            transition.updateFrame(node: dismissedContentNode, frame: CGRect(origin: CGPoint(x: 0.0, y: transitionTargetY), size: dismissedContentNode.frame.size), completion: { _ in
                frameCompleted = true
                completed()
            })
            
            transition.updateAlpha(node: dismissedContentNode, alpha: 0.0, completion: { _ in
                alphaCompleted = true
                completed()
            })
        }
        return CGSize(width: width, height: height)
    }
}
