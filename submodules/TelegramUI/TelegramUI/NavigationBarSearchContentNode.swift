import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let searchBarFont = Font.regular(17.0)
let navigationBarSearchContentHeight: CGFloat = 54.0

class NavigationBarSearchContentNode: NavigationBarContentNode {
    var theme: PresentationTheme?
    var placeholder: String
    
    let placeholderNode: SearchBarPlaceholderNode
    var placeholderHeight: CGFloat?
    private var disabledOverlay: ASDisplayNode?
    
    private(set) var expansionProgress: CGFloat = 1.0

    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    init(theme: PresentationTheme, placeholder: String, activate: @escaping () -> Void) {
        self.theme = theme
        self.placeholder = placeholder
        self.placeholderNode = SearchBarPlaceholderNode(fieldStyle: .modern)
        self.placeholderNode.labelNode.displaysAsynchronously = false
        
        super.init()
        
        self.placeholderNode.isAccessibilityElement = true
        self.placeholderNode.accessibilityLabel = placeholder
        self.placeholderNode.accessibilityTraits = UIAccessibilityTraitSearchField
        
        self.addSubnode(self.placeholderNode)
        self.placeholderNode.activate = activate
    }
    
    func updateThemeAndPlaceholder(theme: PresentationTheme, placeholder: String) {
        self.theme = theme
        self.placeholder = placeholder
        self.placeholderNode.accessibilityLabel = placeholder
        if let disabledOverlay = self.disabledOverlay {
            disabledOverlay.backgroundColor = theme.rootController.navigationBar.backgroundColor.withAlphaComponent(0.5)
        }
        if let validLayout = self.validLayout {
            self.updatePlaceholder(self.expansionProgress, size: validLayout.0, leftInset: validLayout.1, rightInset: validLayout.2, transition: .immediate)
        }
    }
    
    func updateListVisibleContentOffset(_ offset: ListViewVisibleContentOffset) {
        var progress: CGFloat = 0.0
        switch offset {
            case let .known(offset):
                progress = max(0.0, (self.nominalHeight - offset)) / self.nominalHeight
            case .none:
                progress = 1.0
            default:
                break
        }
        self.updateExpansionProgress(progress)
    }
    
    func updateGridVisibleContentOffset(_ offset: GridNodeVisibleContentOffset) {
        var progress: CGFloat = 0.0
        switch offset {
            case let .known(offset):
                progress = max(0.0, (self.nominalHeight - offset)) / self.nominalHeight
            case .none:
                progress = 1.0
            default:
                break
        }
        self.updateExpansionProgress(progress)
    }
    
    func updateExpansionProgress(_ progress: CGFloat, animated: Bool = false) {
        let newProgress = max(0.0, min(10.0, progress))
        if abs(newProgress - self.expansionProgress) > 0.0001 {
            self.expansionProgress = newProgress
        
            let animationCurve: ContainedViewLayoutTransitionCurve = .custom(0.33, 0.52, 0.25, 0.99)
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: animationCurve) : .immediate
            if let validLayout = self.validLayout, animated {
                self.updatePlaceholder(self.expansionProgress, size: validLayout.0, leftInset: validLayout.1, rightInset: validLayout.2, transition: transition)
            }
            self.requestContainerLayout(transition)
        }
    }
    
    func setIsEnabled(_ enabled: Bool, animated: Bool = false) {
        if !enabled {
            if self.disabledOverlay == nil {
                let disabledOverlay = ASDisplayNode()
                self.addSubnode(disabledOverlay)
                self.disabledOverlay = disabledOverlay
                if animated {
                    disabledOverlay.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            }
            if let disabledOverlay = self.disabledOverlay {
                disabledOverlay.backgroundColor = self.theme?.rootController.navigationBar.backgroundColor.withAlphaComponent(0.4)
                
                var disabledOverlayFrame = self.placeholderNode.frame
                if let searchBarHeight = self.placeholderHeight {
                    disabledOverlayFrame.size.height = searchBarHeight
                }
                disabledOverlay.frame = disabledOverlayFrame
            }
        } else if let disabledOverlay = self.disabledOverlay {
            self.disabledOverlay = nil
            if animated {
                disabledOverlay.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak disabledOverlay] _ in
                    disabledOverlay?.removeFromSupernode()
                })
            } else {
                disabledOverlay.removeFromSupernode()
            }
        }
    }
    
    private func updatePlaceholder(_ progress: CGFloat, size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        let padding: CGFloat = 10.0
        let baseWidth = self.bounds.width - padding * 2.0 - leftInset - rightInset
        
        let fieldHeight: CGFloat = 36.0
        let fraction = fieldHeight / self.nominalHeight
        
        let visibleProgress = max(0.0, min(1.0, self.expansionProgress) - 1.0 + fraction) / fraction
        
        let overscrollProgress = max(0.0, max(0.0, self.expansionProgress - 1.0 + fraction) / fraction - visibleProgress)
        
        let searchBarNodeLayout = self.placeholderNode.asyncLayout()
        let (searchBarHeight, searchBarApply) = searchBarNodeLayout(NSAttributedString(string: self.placeholder, font: searchBarFont, textColor: self.theme?.rootController.activeNavigationSearchBar.inputPlaceholderTextColor ?? UIColor(rgb: 0x8e8e93)), CGSize(width: baseWidth, height: fieldHeight), visibleProgress, self.theme?.rootController.activeNavigationSearchBar.inputPlaceholderTextColor ?? UIColor(rgb: 0x8e8e93), self.theme?.rootController.activeNavigationSearchBar.inputFillColor ?? .clear, self.theme?.rootController.navigationBar.backgroundColor ?? .clear, transition)
        searchBarApply()
        
        let searchBarFrame = CGRect(origin: CGPoint(x: padding + leftInset, y: 8.0 + overscrollProgress * fieldHeight), size: CGSize(width: baseWidth, height: fieldHeight))
        transition.updateFrame(node: self.placeholderNode, frame: searchBarFrame)
        
        self.placeholderHeight = searchBarHeight
        if let disabledOverlay = self.disabledOverlay {
            var disabledOverlayFrame = self.placeholderNode.frame
            disabledOverlayFrame.size.height = searchBarHeight
            transition.updateFrame(node: disabledOverlay, frame: disabledOverlayFrame)
        }
    }
    
    override func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset)
        
        self.updatePlaceholder(self.expansionProgress, size: size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    override var height: CGFloat {
        return self.nominalHeight * self.expansionProgress
    }
    
    override var clippedHeight: CGFloat {
        return self.nominalHeight * min(1.0, self.expansionProgress)
    }
    
    override var nominalHeight: CGFloat {
        return navigationBarSearchContentHeight
    }
    
    override var mode: NavigationBarContentMode {
        return .expansion
    }
}
