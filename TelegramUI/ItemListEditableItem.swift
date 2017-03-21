import Foundation
import Display
import AsyncDisplayKit

final class ItemListRevealOptionsGestureRecognizer: UIPanGestureRecognizer {
    var validatedGesture = false
    var firstLocation: CGPoint = CGPoint()
    
    var allowAnyDirection = false
    var lastVelocity: CGPoint = CGPoint()
    
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override func reset() {
        super.reset()
        
        validatedGesture = false
    }
    
    func becomeCancelled() {
        self.state = .cancelled
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        let touch = touches.first!
        self.firstLocation = touch.location(in: self.view)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        let location = touches.first!.location(in: self.view)
        let translation = CGPoint(x: location.x - firstLocation.x, y: location.y - firstLocation.y)
        
        if !validatedGesture {
            if !self.allowAnyDirection && translation.x > 0.0 {
                self.state = .failed
            } else if abs(translation.y) > 4.0 && abs(translation.y) > abs(translation.x) * 2.5 {
                self.state = .failed
            } else if abs(translation.x) > 4.0 && abs(translation.y) * 2.5 < abs(translation.x) {
                validatedGesture = true
            }
        }
        
        if validatedGesture {
            self.lastVelocity = self.velocity(in: self.view)
            super.touchesMoved(touches, with: event)
        }
    }
}

class ItemListRevealOptionsItemNode: ListViewItemNode {
    private var revealNode: ItemListRevealOptionsNode?
    private var revealOptions: [ItemListRevealOption] = []
    
    private var initialRevealOffset: CGFloat = 0.0
    private(set) var revealOffset: CGFloat = 0.0
    
    private var recognizer: ItemListRevealOptionsGestureRecognizer?
    
    private var allowAnyDirection = false
    
    var isDisplayingRevealedOptions: Bool {
        return !self.revealOffset.isZero
    }
    
    override var canBeSelected: Bool {
        return !self.isDisplayingRevealedOptions
    }
    
    override init(layerBacked: Bool, dynamicBounce: Bool, rotated: Bool) {
        super.init(layerBacked: layerBacked, dynamicBounce: dynamicBounce, rotated: rotated)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = ItemListRevealOptionsGestureRecognizer(target: self, action: #selector(self.revealGesture(_:)))
        self.recognizer = recognizer
        recognizer.allowAnyDirection = self.allowAnyDirection
        self.view.addGestureRecognizer(recognizer)
    }
    
    func setRevealOptions(_ options: [ItemListRevealOption]) {
        let wasEmpty = self.revealOptions.isEmpty
        self.revealOptions = options
        if options.isEmpty {
            if let _ = self.revealNode {
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))
            }
        } else {
            if let revealNode = self.revealNode {
                revealNode.setOptions(options)
            }
        }
        if wasEmpty != options.isEmpty {
            self.recognizer?.isEnabled = !options.isEmpty
        }
    }
    
    @objc func revealGesture(_ recognizer: ItemListRevealOptionsGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let revealNode = self.revealNode {
                    let revealSize = revealNode.calculatedSize
                    let location = recognizer.location(in: self.view)
                    if location.x > self.bounds.size.width - revealSize.width {
                        recognizer.becomeCancelled()
                    } else {
                        self.initialRevealOffset = self.revealOffset
                    }
                } else {
                    if self.revealOptions.isEmpty {
                        recognizer.becomeCancelled()
                    }
                    self.initialRevealOffset = self.revealOffset
                }
            case .changed:
                var translation = recognizer.translation(in: self.view)
                translation.x += self.initialRevealOffset
                translation.x = min(0.0, translation.x)
                if self.revealNode == nil && translation.x.isLess(than: 0.0) {
                    self.setupAndAddRevealNode()
                    self.revealOptionsInteractivelyOpened()
                }
                self.updateRevealOffsetInternal(offset: translation.x, transition: .immediate)
                if self.revealNode == nil {
                    self.revealOptionsInteractivelyClosed()
                }
            case .ended, .cancelled:
                if let recognizer = self.recognizer, let revealNode = self.revealNode {
                    let velocity = recognizer.velocity(in: self.view)
                    let revealSize = revealNode.calculatedSize
                    var reveal = false
                    if abs(velocity.x) < 100.0 {
                        if self.initialRevealOffset.isZero && self.revealOffset < 0.0 {
                            reveal = true
                        } else if self.revealOffset < -revealSize.width {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    } else {
                        if velocity.x < 0.0 {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    }
                    self.updateRevealOffsetInternal(offset: reveal ? -revealSize.width : 0.0, transition: .animated(duration: 0.3, curve: .spring))
                    if !reveal {
                        self.revealOptionsInteractivelyClosed()
                    }
                }
            default:
                break
        }
    }
    
    private func setupAndAddRevealNode() {
        if !self.revealOptions.isEmpty {
            let revealNode = ItemListRevealOptionsNode(optionSelected: { [weak self] option in
                self?.revealOptionSelected(option)
            })
            revealNode.setOptions(self.revealOptions)
            self.revealNode = revealNode
            
            let revealSize = revealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: self.bounds.size.height))
            revealNode.frame = CGRect(origin: CGPoint(x: self.bounds.size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
            
            self.addSubnode(revealNode)
        }
    }
    
    override func layout() {
        if let revealNode = self.revealNode {
            let height = self.contentSize.height
            let revealSize = revealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: height))
            revealNode.frame = CGRect(origin: CGPoint(x: self.bounds.size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
        }
    }
    
    func updateRevealOffsetInternal(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        if let revealNode = self.revealNode {
            let revealSize = revealNode.calculatedSize
            
            let revealFrame = CGRect(origin: CGPoint(x: self.bounds.size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
            let revealNodeOffset = -max(self.revealOffset, -revealSize.width)
            revealNode.updateRevealOffset(offset: revealNodeOffset, transition: transition)
            
            if CGFloat(0.0).isLessThanOrEqualTo(offset) {
                self.revealNode = nil
                transition.updateFrame(node: revealNode, frame: revealFrame, completion: { [weak revealNode] _ in
                    revealNode?.removeFromSupernode()
                })
            } else {
                transition.updateFrame(node: revealNode, frame: revealFrame)
            }
        }
        let allowAnyDirection = !offset.isZero
        if allowAnyDirection != self.allowAnyDirection {
            self.allowAnyDirection = allowAnyDirection
            self.recognizer?.allowAnyDirection = allowAnyDirection
            self.view.disablesInteractiveTransitionGestureRecognizer = allowAnyDirection
        }
        
        self.updateRevealOffset(offset: offset, transition: transition)
    }
    
    func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
    
    func revealOptionsInteractivelyOpened() {
        
    }
    
    func revealOptionsInteractivelyClosed() {
        
    }
    
    func setRevealOptionsOpened(_ value: Bool, animated: Bool) {
        if value != !self.revealOffset.isZero {
            if !self.revealOffset.isZero {
                self.recognizer?.becomeCancelled()
            }
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.3, curve: .spring)
            } else {
                transition = .immediate
            }
            if value {
                if self.revealNode == nil {
                    self.setupAndAddRevealNode()
                    if let revealNode = self.revealNode {
                        revealNode.layout()
                        let revealSize = revealNode.calculatedSize
                        self.updateRevealOffsetInternal(offset: -revealSize.width, transition: transition)
                    }
                }
            } else if !self.revealOffset.isZero {
                self.updateRevealOffsetInternal(offset: 0.0, transition: transition)
            }
        }
    }
    
    func revealOptionSelected(_ option: ItemListRevealOption) {
    }
}
