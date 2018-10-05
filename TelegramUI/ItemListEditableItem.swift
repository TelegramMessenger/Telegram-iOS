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

class ItemListRevealOptionsItemNode: ListViewItemNode, UIGestureRecognizerDelegate {
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    private var leftRevealNode: ItemListRevealOptionsNode?
    private var rightRevealNode: ItemListRevealOptionsNode?
    private var revealOptions: (left: [ItemListRevealOption], right: [ItemListRevealOption]) = ([], [])
    
    private var initialRevealOffset: CGFloat = 0.0
    private(set) var revealOffset: CGFloat = 0.0
    
    private var recognizer: ItemListRevealOptionsGestureRecognizer?
    private var tapRecognizer: UITapGestureRecognizer?
    private var hapticFeedback: HapticFeedback?
    
    private var allowAnyDirection = false
    
    var isDisplayingRevealedOptions: Bool {
        return !self.revealOffset.isZero
    }
    
    override var canBeSelected: Bool {
        return !self.isDisplayingRevealedOptions
    }
    
    override init(layerBacked: Bool, dynamicBounce: Bool, rotated: Bool, seeThrough: Bool) {
        super.init(layerBacked: layerBacked, dynamicBounce: dynamicBounce, rotated: rotated, seeThrough: seeThrough)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = ItemListRevealOptionsGestureRecognizer(target: self, action: #selector(self.revealGesture(_:)))
        self.recognizer = recognizer
        recognizer.allowAnyDirection = self.allowAnyDirection
        self.view.addGestureRecognizer(recognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.revealTapGesture(_:)))
        self.tapRecognizer = tapRecognizer
        tapRecognizer.delegate = self
        self.view.addGestureRecognizer(tapRecognizer)
        
        self.view.disablesInteractiveTransitionGestureRecognizer = self.allowAnyDirection
    }
    
    func setRevealOptions(_ options: (left: [ItemListRevealOption], right: [ItemListRevealOption])) {
        if self.revealOptions == options {
            return
        }
        let previousOptions = self.revealOptions
        let wasEmpty = self.revealOptions.left.isEmpty && self.revealOptions.right.isEmpty
        self.revealOptions = options
        let isEmpty = options.left.isEmpty && options.right.isEmpty
        if options.left.isEmpty {
            if let _ = self.leftRevealNode {
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))
            }
        } else if previousOptions.left != options.left {
            /*if let _ = self.leftRevealNode {
                self.revealOptionsInteractivelyClosed()
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))
            }*/
        }
        if options.right.isEmpty {
            if let _ = self.rightRevealNode {
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))
            }
        } else if previousOptions.right != options.right {
            if let _ = self.rightRevealNode {
                /*self.revealOptionsInteractivelyClosed()
                self.recognizer?.becomeCancelled()
                self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))*/
            }
        }
        if wasEmpty != isEmpty {
            self.recognizer?.isEnabled = !isEmpty
        }
        let allowAnyDirection = !options.left.isEmpty || !self.revealOffset.isZero
        if allowAnyDirection != self.allowAnyDirection {
            self.allowAnyDirection = allowAnyDirection
            self.recognizer?.allowAnyDirection = allowAnyDirection
            if self.isNodeLoaded {
                self.view.disablesInteractiveTransitionGestureRecognizer = allowAnyDirection
            }
        }
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = self.recognizer, gestureRecognizer == self.tapRecognizer {
            return abs(self.revealOffset) > 0.0 && !recognizer.validatedGesture
        } else {
            return true
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = self.recognizer, otherGestureRecognizer == recognizer {
            return true
        } else {
            return false
        }
    }
    
    @objc func revealTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))
            self.revealOptionsInteractivelyClosed()
        }
    }

    @objc func revealGesture(_ recognizer: ItemListRevealOptionsGestureRecognizer) {
        guard let (size, _, _) = self.validLayout else {
            return
        }
        switch recognizer.state {
            case .began:
                if let leftRevealNode = self.leftRevealNode {
                    let revealSize = leftRevealNode.calculatedSize
                    let location = recognizer.location(in: self.view)
                    if location.x < revealSize.width {
                        recognizer.becomeCancelled()
                    } else {
                        self.initialRevealOffset = self.revealOffset
                    }
                } else if let rightRevealNode = self.rightRevealNode {
                    let revealSize = rightRevealNode.calculatedSize
                    let location = recognizer.location(in: self.view)
                    if location.x > size.width - revealSize.width {
                        recognizer.becomeCancelled()
                    } else {
                        self.initialRevealOffset = self.revealOffset
                    }
                } else {
                    if self.revealOptions.left.isEmpty && self.revealOptions.right.isEmpty {
                        recognizer.becomeCancelled()
                    }
                    self.initialRevealOffset = self.revealOffset
                }
            case .changed:
                var translation = recognizer.translation(in: self.view)
                translation.x += self.initialRevealOffset
                if self.revealOptions.left.isEmpty {
                    translation.x = min(0.0, translation.x)
                }
                if self.leftRevealNode == nil && CGFloat(0.0).isLess(than: translation.x) {
                    self.setupAndAddLeftRevealNode()
                    self.revealOptionsInteractivelyOpened()
                } else if self.rightRevealNode == nil && translation.x.isLess(than: 0.0) {
                    self.setupAndAddRightRevealNode()
                    self.revealOptionsInteractivelyOpened()
                }
                self.updateRevealOffsetInternal(offset: translation.x, transition: .immediate)
                if self.leftRevealNode == nil && self.rightRevealNode == nil {
                    self.revealOptionsInteractivelyClosed()
                }
            case .ended, .cancelled:
                guard let recognizer = self.recognizer else {
                    break
                }
                
                if let leftRevealNode = self.leftRevealNode {
                    let velocity = recognizer.velocity(in: self.view)
                    let revealSize = leftRevealNode.calculatedSize
                    var reveal = false
                    if abs(velocity.x) < 100.0 {
                        if self.initialRevealOffset.isZero && self.revealOffset > 0.0 {
                            reveal = true
                        } else if self.revealOffset > revealSize.width {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    } else {
                        if velocity.x > 0.0 {
                            reveal = true
                        } else {
                            reveal = false
                        }
                    }
                    
                    var selectedOption: ItemListRevealOption?
                    if reveal && leftRevealNode.isDisplayingExtendedAction() {
                        reveal = false
                        selectedOption = self.revealOptions.left.first
                    } else {
                        self.updateRevealOffsetInternal(offset: reveal ?revealSize.width : 0.0, transition: .animated(duration: 0.3, curve: .spring))
                    }
            
                    if let selectedOption = selectedOption {
                        self.revealOptionSelected(selectedOption, animated: true)
                    } else {
                        if !reveal {
                            self.revealOptionsInteractivelyClosed()
                        }
                    }
                } else if let rightRevealNode = self.rightRevealNode {
                    let velocity = recognizer.velocity(in: self.view)
                    let revealSize = rightRevealNode.calculatedSize
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
    
    private func setupAndAddLeftRevealNode() {
        if !self.revealOptions.left.isEmpty {
            let revealNode = ItemListRevealOptionsNode(optionSelected: { [weak self] option in
                self?.revealOptionSelected(option, animated: false)
                }, tapticAction: { [weak self] in
                self?.hapticTap()
            })
            revealNode.setOptions(self.revealOptions.left)
            self.leftRevealNode = revealNode
            
            if let (size, _, rightInset) = self.validLayout {
                let revealSize = revealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
                
                revealNode.frame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
                revealNode.updateRevealOffset(offset: 0.0, rightInset: rightInset, transition: .immediate)
            }
            
            self.addSubnode(revealNode)
        }
    }
    
    private func setupAndAddRightRevealNode() {
        if !self.revealOptions.right.isEmpty {
            let revealNode = ItemListRevealOptionsNode(optionSelected: { [weak self] option in
                self?.revealOptionSelected(option, animated: false)
                }, tapticAction: { [weak self] in
                self?.hapticTap()
            })
            revealNode.setOptions(self.revealOptions.right)
            self.rightRevealNode = revealNode
            
            if let (size, _, rightInset) = self.validLayout {
                let revealSize = revealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
                
                revealNode.frame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width - rightInset), y: 0.0), size: revealSize)
                revealNode.updateRevealOffset(offset: 0.0, rightInset: rightInset, transition: .immediate)
            }
            
            self.addSubnode(revealNode)
        }
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat) {
        self.validLayout = (size, leftInset, rightInset)
        
        if let leftRevealNode = self.leftRevealNode {
            let revealSize = leftRevealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
            leftRevealNode.frame = CGRect(origin: CGPoint(x: leftInset + min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
        }
        
        if let rightRevealNode = self.rightRevealNode {
            let revealSize = rightRevealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
            rightRevealNode.frame = CGRect(origin: CGPoint(x: size.width - rightInset + max(self.revealOffset, -revealSize.width - rightInset), y: 0.0), size: revealSize)
        }
    }
    
    func updateRevealOffsetInternal(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        guard let (size, _, rightInset) = self.validLayout else {
            return
        }
        
        if let leftRevealNode = self.leftRevealNode {
            let revealSize = leftRevealNode.calculatedSize
            
            let revealFrame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
            //let revealNodeOffset = max(-self.revealOffset, revealSize.width)
            let revealNodeOffset = -self.revealOffset
            leftRevealNode.updateRevealOffset(offset: revealNodeOffset, rightInset: rightInset, transition: transition)
            
            if CGFloat(offset).isLessThanOrEqualTo(0.0) {
                self.leftRevealNode = nil
                transition.updateFrame(node: leftRevealNode, frame: revealFrame, completion: { [weak leftRevealNode] _ in
                    leftRevealNode?.removeFromSupernode()
                })
            } else {
                transition.updateFrame(node: leftRevealNode, frame: revealFrame)
            }
        }
        if let rightRevealNode = self.rightRevealNode {
            let revealSize = rightRevealNode.calculatedSize
            
            let revealFrame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
            let revealNodeOffset = -max(self.revealOffset, -revealSize.width - rightInset)
            rightRevealNode.updateRevealOffset(offset: revealNodeOffset, rightInset: rightInset, transition: transition)
            
            if CGFloat(0.0).isLessThanOrEqualTo(offset) {
                self.rightRevealNode = nil
                transition.updateFrame(node: rightRevealNode, frame: revealFrame, completion: { [weak rightRevealNode] _ in
                    rightRevealNode?.removeFromSupernode()
                })
            } else {
                transition.updateFrame(node: rightRevealNode, frame: revealFrame)
            }
        }
        let allowAnyDirection = !self.revealOptions.left.isEmpty || !offset.isZero
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
                if self.rightRevealNode == nil {
                    self.setupAndAddRightRevealNode()
                    if let rightRevealNode = self.rightRevealNode, rightRevealNode.isNodeLoaded, let (_, _, rightInset) = self.validLayout {
                        rightRevealNode.layout()
                        let revealSize = rightRevealNode.calculatedSize
                        self.updateRevealOffsetInternal(offset: -revealSize.width - rightInset, transition: transition)
                    }
                }
            } else if !self.revealOffset.isZero {
                self.updateRevealOffsetInternal(offset: 0.0, transition: transition)
            }
        }
    }
    
    func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
    }
    
    override var preventsTouchesToOtherItems: Bool {
        return self.isDisplayingRevealedOptions
    }
    
    override func touchesToOtherItemsPrevented() {
        if self.isDisplayingRevealedOptions {
            self.setRevealOptionsOpened(false, animated: true)
        }
    }
    
    private func hapticTap() {
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }
        self.hapticFeedback?.tap()
    }
}
