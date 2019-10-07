import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils

class FormEditableBlockItemNode<Item: FormControllerItem>: ASDisplayNode, FormControllerItemNode, FormBlockItemNodeProto, UIGestureRecognizerDelegate {
    private let topSeparatorInset: FormBlockItemInset
    
    private let highlightedBackgroundNode: ASDisplayNode
    let backgroundNode: ASDisplayNode
    private let topSeparatorNode: ASDisplayNode
    private let bottomSeparatorNode: ASDisplayNode
    private let selectionButtonNode: HighlightTrackingButtonNode
    
    private var leftRevealNode: ItemListRevealOptionsNode?
    private var rightRevealNode: ItemListRevealOptionsNode?
    private var revealOptions: (left: [ItemListRevealOption], right: [ItemListRevealOption]) = ([], [])
    
    private var initialRevealOffset: CGFloat = 0.0
    public private(set) var revealOffset: CGFloat = 0.0
    
    private var recognizer: ItemListRevealOptionsGestureRecognizer?
    private var hapticFeedback: HapticFeedback?
    
    private var allowAnyDirection = false
    
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    var isDisplayingRevealedOptions: Bool {
        return !self.revealOffset.isZero
    }
    
    var canBeSelected: Bool {
        return !self.isDisplayingRevealedOptions
    }
    
    init(selectable: Bool, topSeparatorInset: FormBlockItemInset) {
        self.topSeparatorInset = topSeparatorInset
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.topSeparatorNode = ASDisplayNode()
        self.topSeparatorNode.isLayerBacked = true
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.selectionButtonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.topSeparatorNode)
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.highlightedBackgroundNode)
        
        if selectable {
            self.selectionButtonNode.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self, strongSelf.canBeSelected {
                    if highlighted {
                        strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                        strongSelf.highlightedBackgroundNode.alpha = 1.0
                    } else {
                        strongSelf.highlightedBackgroundNode.alpha = 0.0
                        strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    }
                }
            }
            self.addSubnode(self.selectionButtonNode)
            self.selectionButtonNode.addTarget(self, action: #selector(self.selectionButtonPressed), forControlEvents: .touchUpInside)
        }
        
        let recognizer = ItemListRevealOptionsGestureRecognizer(target: self, action: #selector(self.revealGesture(_:)))
        self.recognizer = recognizer
        recognizer.allowAnyDirection = self.allowAnyDirection
        self.view.addGestureRecognizer(recognizer)
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
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = self.recognizer, otherGestureRecognizer == recognizer {
            return true
        } else {
            return false
        }
    }
    
    @objc func revealGesture(_ recognizer: ItemListRevealOptionsGestureRecognizer) {
        guard let (size, _, _) = self.validLayout else {
            return
        }
        switch recognizer.state {
        case .began:
            if let leftRevealNode = self.leftRevealNode {
                let revealSize = leftRevealNode.bounds.size
                let location = recognizer.location(in: self.view)
                if location.x < revealSize.width {
                    recognizer.becomeCancelled()
                } else {
                    self.initialRevealOffset = self.revealOffset
                }
            } else if let rightRevealNode = self.rightRevealNode {
                let revealSize = rightRevealNode.bounds.size
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
                let revealSize = leftRevealNode.bounds.size
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
                let revealSize = rightRevealNode.bounds.size
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
                    self?.hapticImpact()
            })
            revealNode.setOptions(self.revealOptions.left, isLeft: true)
            self.leftRevealNode = revealNode
            
            if let (size, leftInset, _) = self.validLayout {
                var revealSize = revealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
                revealSize.width += leftInset
                
                revealNode.frame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
                revealNode.updateRevealOffset(offset: 0.0, sideInset: leftInset, transition: .immediate)
            }
            
            self.addSubnode(revealNode)
        }
    }
    
    private func setupAndAddRightRevealNode() {
        if !self.revealOptions.right.isEmpty {
            let revealNode = ItemListRevealOptionsNode(optionSelected: { [weak self] option in
                self?.revealOptionSelected(option, animated: false)
                }, tapticAction: { [weak self] in
                    self?.hapticImpact()
            })
            revealNode.setOptions(self.revealOptions.right, isLeft: false)
            self.rightRevealNode = revealNode
            
            if let (size, _, rightInset) = self.validLayout {
                var revealSize = revealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: size.height))
                revealSize.width += rightInset
                
                revealNode.frame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
                revealNode.updateRevealOffset(offset: 0.0, sideInset: -rightInset, transition: .immediate)
            }
            
            self.addSubnode(revealNode)
        }
    }
    
    final func updateInternal(item: Item, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        let (preLayout, apply) = self.update(item: item, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
        return (preLayout, { params in
            self.backgroundNode.backgroundColor = theme.list.itemBlocksBackgroundColor
            self.topSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
            self.bottomSeparatorNode.backgroundColor = theme.list.itemBlocksSeparatorColor
            self.highlightedBackgroundNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
            
            let height = apply(params)
            
            let topSeparatorInset: CGFloat
            switch previousNeighbor {
                case let .item(item) where item is FormBlockItemNodeProto:
                    switch self.topSeparatorInset {
                        case .regular:
                            topSeparatorInset = 16.0
                        case let .custom(value):
                            topSeparatorInset = value
                    }
                default:
                    topSeparatorInset = 0.0
            }
            
            switch nextNeighbor {
                case let .item(item) where item is FormBlockItemNodeProto:
                    self.bottomSeparatorNode.isHidden = true
                default:
                    self.bottomSeparatorNode.isHidden = false
            }
            
            if let leftRevealNode = self.leftRevealNode {
                let revealSize = leftRevealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: height))
                //revealSize.width += leftInset
                leftRevealNode.frame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
            }
            
            if let rightRevealNode = self.rightRevealNode {
                let revealSize = rightRevealNode.measure(CGSize(width: CGFloat.greatestFiniteMagnitude, height: height))
                //revealSize.width += rightInset
                rightRevealNode.frame = CGRect(origin: CGPoint(x: width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
            }
            
            self.validLayout = (CGSize(width: width, height: height), 0.0, 0.0)
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
            transition.updateFrame(node: self.highlightedBackgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
            transition.updateFrame(node: self.selectionButtonNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: width, height: height)))
            transition.updateFrame(node: self.topSeparatorNode, frame: CGRect(origin: CGPoint(x: topSeparatorInset, y: 0.0), size: CGSize(width: width - topSeparatorInset, height: UIScreenPixel)))
            transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: height - UIScreenPixel), size: CGSize(width: width, height: UIScreenPixel)))
            
            return height
        })
    }
    
    func updateRevealOffsetInternal(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        guard let (size, leftInset, rightInset) = self.validLayout else {
            return
        }
        
        if let leftRevealNode = self.leftRevealNode {
            let revealSize = leftRevealNode.bounds.size
            
            let revealFrame = CGRect(origin: CGPoint(x: min(self.revealOffset - revealSize.width, 0.0), y: 0.0), size: revealSize)
            //let revealNodeOffset = max(-self.revealOffset, revealSize.width)
            let revealNodeOffset = -self.revealOffset
            leftRevealNode.updateRevealOffset(offset: revealNodeOffset, sideInset: leftInset, transition: transition)
            
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
            let revealSize = rightRevealNode.bounds.size
            
            let revealFrame = CGRect(origin: CGPoint(x: size.width + max(self.revealOffset, -revealSize.width), y: 0.0), size: revealSize)
            let revealNodeOffset = -max(self.revealOffset, -revealSize.width)
            rightRevealNode.updateRevealOffset(offset: revealNodeOffset, sideInset: -rightInset, transition: transition)
            
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
                    if let rightRevealNode = self.rightRevealNode, rightRevealNode.isNodeLoaded, let _ = self.validLayout {
                        rightRevealNode.layout()
                        let revealSize = rightRevealNode.bounds.size
                        self.updateRevealOffsetInternal(offset: -revealSize.width, transition: transition)
                    }
                }
            } else if !self.revealOffset.isZero {
                self.updateRevealOffsetInternal(offset: 0.0, transition: transition)
            }
        }
    }
    
    func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
    }
    
    private func hapticImpact() {
        if self.hapticFeedback == nil {
            self.hapticFeedback = HapticFeedback()
        }
        self.hapticFeedback?.impact(.medium)
    }
    
    func update(item: Item, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        preconditionFailure()
    }
    
    @objc private func selectionButtonPressed() {
        if self.canBeSelected {
            self.selected()
        } else {
            self.updateRevealOffsetInternal(offset: 0.0, transition: .animated(duration: 0.3, curve: .spring))
            self.revealOptionsInteractivelyClosed()
        }
    }
    
    func selected() {
    }
    
    var preventsTouchesToOtherItems: Bool {
        return self.isDisplayingRevealedOptions
    }
    
    func touchesToOtherItemsPrevented() {
        if self.isDisplayingRevealedOptions {
            self.setRevealOptionsOpened(false, animated: true)
        }
    }
}

