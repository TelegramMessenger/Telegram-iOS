import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

final class PeerInfoScreenSelectableBackgroundNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let button: HighlightTrackingButton
    
    let bringToFrontForHighlight: () -> Void
    
    private var isHighlighted: Bool = false
    
    var pressed: (() -> Void)? {
        didSet {
            self.button.isUserInteractionEnabled = self.pressed != nil
        }
    }
    
    init(bringToFrontForHighlight: @escaping () -> Void) {
        self.bringToFrontForHighlight = bringToFrontForHighlight
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 0.0
        
        self.button = HighlightTrackingButton()
        self.button.isAccessibilityElement = false
        // The row's own accessibility element (its `AccessibilityAreaNode`) describes and activates the row; the
        // highlight button would otherwise be read as an unlabelled container around it.
        self.button.accessibilityElementsHidden = true

        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.view.addSubview(self.button)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        self.button.highligthedChanged = { [weak self] highlighted in
            self?.updateIsHighlighted(highlighted)
        }
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
    
    func updateIsHighlighted(_ isHighlighted: Bool) {
        if self.isHighlighted != isHighlighted {
            self.isHighlighted = isHighlighted
            if isHighlighted {
                self.bringToFrontForHighlight()
                self.backgroundNode.layer.removeAnimation(forKey: "opacity")
                self.backgroundNode.alpha = 1.0
            } else {
                self.backgroundNode.alpha = 0.0
                self.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
            }
        }
    }
    
    func update(size: CGSize, theme: PresentationTheme, transition: ContainedViewLayoutTransition) {
        self.backgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(view: self.button, frame: CGRect(origin: CGPoint(), size: size))
    }
}

extension AccessibilityAreaNode {
    /// A tappable PeerInfo row: a button that runs the row's action, the same closure its tap runs; a row without an
    /// action is not enabled.
    func applyPeerInfoRowAction(_ action: (() -> Void)?, traits: UIAccessibilityTraits = []) {
        var accessibilityTraits: UIAccessibilityTraits = traits
        accessibilityTraits.insert(.button)
        if action == nil {
            accessibilityTraits.insert(.notEnabled)
        }
        self.accessibilityTraits = accessibilityTraits
        self.activate = action.flatMap { action in
            return {
                action()
                return true
            }
        }
    }
}
