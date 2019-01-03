import Foundation
import AsyncDisplayKit
import Display

private let searchBarFont = Font.regular(17.0)
let navigationBarSearchContentHeight: CGFloat = 54.0

class NavigationBarSearchContentNode: NavigationBarContentNode {
    var theme: PresentationTheme?
    var placeholder: String
    
    let placeholderNode: SearchBarPlaceholderNode
    private var disabledOverlay: ASDisplayNode?
    
    private(set) var expansionProgress: CGFloat = 1.0
    
    init(theme: PresentationTheme, placeholder: String, activate: @escaping () -> Void) {
        self.theme = theme
        self.placeholder = placeholder
        self.placeholderNode = SearchBarPlaceholderNode(fieldStyle: .modern)
        
        super.init()
        
        self.addSubnode(self.placeholderNode)
        self.placeholderNode.activate = activate
    }
    
    func updateThemeAndPlaceholder(theme: PresentationTheme, placeholder: String) {
        self.theme = theme
        self.placeholder = placeholder
        if let disabledOverlay = self.disabledOverlay {
            disabledOverlay.backgroundColor = theme.rootController.navigationBar.backgroundColor.withAlphaComponent(0.5)
        }
        self.setNeedsLayout()
    }
    
    func updateExpansionProgress(_ progress: CGFloat, animated: Bool = false) {
        let newProgress = max(0.0, min(1.0, progress))
        if newProgress != self.expansionProgress {
            self.expansionProgress = newProgress
        
            let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.25, curve: .easeInOut) : .immediate
            if animated {
                self.updatePlaceholder(self.expansionProgress, transition: transition)
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
                disabledOverlay.frame = placeholderNode.frame
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
    
    private func updatePlaceholder(_ progress: CGFloat, transition: ContainedViewLayoutTransition) {
        let padding: CGFloat = 10.0
        let baseWidth = self.bounds.width - padding * 2.0
        
        let fieldHeight: CGFloat = 36.0
        let fraction = fieldHeight / self.nominalHeight
        let visibleProgress = max(0.0, self.expansionProgress - 1.0 + fraction) / fraction
        
        let makeLayout = self.placeholderNode.asyncLayout()
        let applyLayout = makeLayout(NSAttributedString(string: self.placeholder, font: searchBarFont, textColor: self.theme?.rootController.activeNavigationSearchBar.inputPlaceholderTextColor ?? UIColor(rgb: 0x8e8e93)), CGSize(width: baseWidth, height: fieldHeight), visibleProgress, self.theme?.rootController.activeNavigationSearchBar.inputPlaceholderTextColor ?? UIColor(rgb: 0x8e8e93), self.theme?.rootController.activeNavigationSearchBar.inputFillColor ?? .clear, self.theme?.rootController.navigationBar.backgroundColor ?? .clear, transition)
        applyLayout()
        
        let searchBarFrame = CGRect(origin: CGPoint(x: padding, y: 8.0), size: CGSize(width: baseWidth, height: fieldHeight))
        transition.updateFrame(node: self.placeholderNode, frame: searchBarFrame)
    }
    
    override func layout() {
        super.layout()

        self.updatePlaceholder(self.expansionProgress, transition: .immediate)
    }
    
    override var height: CGFloat {
        return self.nominalHeight * self.expansionProgress
    }
    
    override var nominalHeight: CGFloat {
        return navigationBarSearchContentHeight
    }
    
    override var mode: NavigationBarContentMode {
        return .expansion
    }
}
