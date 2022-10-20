import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import CheckNode

public final class GridMessageSelectionNode: ASDisplayNode {
    private let toggle: (Bool) -> Void
    
    private var selected = false
    private let checkNode: CheckNode
    
    public init(theme: PresentationTheme, toggle: @escaping (Bool) -> Void) {
        self.toggle = toggle
        self.checkNode = CheckNode(theme: CheckNodeTheme(theme: theme, style: .overlay, hasInset: true))
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    public func animateIn() {
        self.checkNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        self.checkNode.layer.animateScale(from: 0.2, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    public func animateOut(completion: @escaping () -> Void) {
        self.checkNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.checkNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    public func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkNode.setSelected(selected, animated: animated)
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggle(!self.selected)
        }
    }
    
    override public func layout() {
        super.layout()
        
        let checkSize = CGSize(width: 28.0, height: 28.0)
        self.checkNode.frame = CGRect(origin: CGPoint(x: self.bounds.size.width - checkSize.width - 2.0, y: 2.0), size: checkSize)
    }
}

public final class GridMessageSelectionLayer: CALayer {
    private var selected = false
    private let checkLayer: CheckLayer

    public init(theme: CheckNodeTheme) {
        self.checkLayer = CheckLayer(theme: theme, content: .check)

        super.init()

        self.addSublayer(self.checkLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func action(forKey event: String) -> CAAction? {
        return nullAction
    }

    public func animateIn() {
        self.checkLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        self.checkLayer.animateScale(from: 0.2, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }

    public func animateOut(completion: @escaping () -> Void) {
        self.checkLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.checkLayer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }

    public func updateSelected(_ selected: Bool, animated: Bool) {
        if self.selected != selected {
            self.selected = selected
            self.checkLayer.setSelected(selected, animated: animated)
        }
    }

    public func updateLayout(size: CGSize) {
        let checkWidth: CGFloat
        if size.width <= 60.0 {
            checkWidth = 22.0
        } else {
            checkWidth = 28.0
        }
        let checkSize = CGSize(width: checkWidth, height: checkWidth)
        let previousSize = self.checkLayer.bounds.size
        self.checkLayer.frame = CGRect(origin: CGPoint(x: self.bounds.size.width - checkSize.width - 2.0, y: 2.0), size: checkSize)
        if self.checkLayer.bounds.size != previousSize {
            self.checkLayer.setNeedsDisplay()
        }
    }
}
