import AsyncDisplayKit
import Display
import TelegramPresentationData

final class PeerInfoScreenSelectableBackgroundNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    private let buttonNode: HighlightTrackingButtonNode
    
    let bringToFrontForHighlight: () -> Void
    
    private var isHighlighted: Bool = false
    
    var pressed: (() -> Void)? {
        didSet {
            self.buttonNode.isUserInteractionEnabled = self.pressed != nil
        }
    }
    
    init(bringToFrontForHighlight: @escaping () -> Void) {
        self.bringToFrontForHighlight = bringToFrontForHighlight
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
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
        transition.updateFrame(node: self.buttonNode, frame: CGRect(origin: CGPoint(), size: size))
    }
}
