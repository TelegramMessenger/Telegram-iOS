import Foundation
import Display
import UIKit
import AsyncDisplayKit
import TelegramPresentationData

private let textFont = Font.regular(13.0)
private let selectedTextFont = Font.bold(13.0)

public enum SegmentedControlLayout {
    case stretchToFill(width: CGFloat)
    case sizeToFit(maximumWidth: CGFloat, minimumWidth: CGFloat, height: CGFloat)
}

public final class SegmentedControlTheme: Equatable {
    public let backgroundColor: UIColor
    public let foregroundColor: UIColor
    public let shadowColor: UIColor
    public let textColor: UIColor
    public let dividerColor: UIColor
    
    public init(backgroundColor: UIColor, foregroundColor: UIColor, shadowColor: UIColor, textColor: UIColor, dividerColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.shadowColor = shadowColor
        self.textColor = textColor
        self.dividerColor = dividerColor
    }
    
    public static func ==(lhs: SegmentedControlTheme, rhs: SegmentedControlTheme) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.shadowColor != rhs.shadowColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.dividerColor != rhs.dividerColor {
            return false
        }
        return true
    }
}

public extension SegmentedControlTheme {
    convenience init(theme: PresentationTheme) {
        self.init(backgroundColor: theme.rootController.navigationBar.segmentedBackgroundColor, foregroundColor: theme.rootController.navigationBar.segmentedForegroundColor, shadowColor: .black, textColor: theme.rootController.navigationBar.segmentedTextColor, dividerColor: theme.rootController.navigationBar.segmentedDividerColor)
    }
}

private func generateSelectionImage(theme: SegmentedControlTheme) -> UIImage? {
    return generateImage(CGSize(width: 20.0, height: 20.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        if theme.shadowColor != .clear {
            context.setShadow(offset: CGSize(width: 0.0, height: -3.0), blur: 6.0, color: theme.shadowColor.withAlphaComponent(0.12).cgColor)
        }
        context.setFillColor(theme.foregroundColor.cgColor)
        context.fillEllipse(in: CGRect(x: 2.0, y: 2.0, width: 16.0, height: 16.0))
    })?.stretchableImage(withLeftCapWidth: 10, topCapHeight: 10)
}

public struct SegmentedControlItem: Equatable {
    public let title: String
    
    public init(title: String) {
        self.title = title
    }
}

private class SegmentedControlItemNode: HighlightTrackingButtonNode {
}

public final class SegmentedControlNode: ASDisplayNode, UIGestureRecognizerDelegate {
    private var theme: SegmentedControlTheme
    private var _items: [SegmentedControlItem]
    private var _selectedIndex: Int = 0
    
    private var validLayout: SegmentedControlLayout?
    
    private let selectionNode: ASImageNode
    private var itemNodes: [SegmentedControlItemNode]
    private var dividerNodes: [ASDisplayNode]
    
    private var gestureRecognizer: UIPanGestureRecognizer?
    private var gestureSelectedIndex: Int?
    
    public var items: [SegmentedControlItem] {
        get {
            return self._items
        }
        set {
            let previousItems = self._items
            self._items = newValue
            guard previousItems != newValue else {
                return
            }
            
            self.itemNodes.forEach { $0.removeFromSupernode() }
            self.itemNodes = self._items.map { item in
                let itemNode = SegmentedControlItemNode()
                itemNode.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
                itemNode.titleNode.maximumNumberOfLines = 1
                itemNode.titleNode.truncationMode = .byTruncatingTail
                itemNode.setTitle(item.title, with: textFont, with: self.theme.textColor, for: .normal)
                itemNode.setTitle(item.title, with: selectedTextFont, with: self.theme.textColor, for: .selected)
                itemNode.setTitle(item.title, with: selectedTextFont, with: self.theme.textColor, for: [.selected, .highlighted])
                return itemNode
            }
            self.setupButtons()
            self.itemNodes.forEach(self.addSubnode(_:))
            
            let dividersCount = self._items.count > 2 ? self._items.count - 1 : 0
            if self.dividerNodes.count != dividersCount {
                self.dividerNodes.forEach { $0.removeFromSupernode() }
                self.dividerNodes = (0 ..< dividersCount).map { _ in ASDisplayNode() }
            }
            
            if let layout  = self.validLayout {
                let _ = self.updateLayout(layout, transition: .immediate)
            }
            
            self.updatePointerInteraction()
        }
    }
    
    public var selectedIndex: Int {
        get {
            return self._selectedIndex
        }
        set {
            guard newValue != self._selectedIndex else {
                return
            }
            self._selectedIndex = newValue
            if let layout = self.validLayout {
                let _ = self.updateLayout(layout, transition: .immediate)
            }
            
            self.updatePointerInteraction()
        }
    }
    
    public func setSelectedIndex(_ index: Int, animated: Bool) {
        guard index != self._selectedIndex else {
            return
        }
        self._selectedIndex = index
        if let layout = self.validLayout {
            let _ = self.updateLayout(layout, transition: .animated(duration: 0.2, curve: .easeInOut))
        }
        
        self.updatePointerInteraction()
    }
    
    public var selectedIndexChanged: (Int) -> Void = { _ in }
    public var selectedIndexShouldChange: (Int, @escaping (Bool) -> Void) -> Void = { _, f in
        f(true)
    }
    
    public init(theme: SegmentedControlTheme, items: [SegmentedControlItem], selectedIndex: Int) {
        self.theme = theme
        self._items = items
        self._selectedIndex = selectedIndex
        
        self.selectionNode = ASImageNode()
        self.selectionNode.displaysAsynchronously = false
        self.selectionNode.displayWithoutProcessing = true
        
        self.itemNodes = items.map { item in
            let itemNode = SegmentedControlItemNode()
            itemNode.contentEdgeInsets = UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 8.0)
            itemNode.titleNode.maximumNumberOfLines = 1
            itemNode.titleNode.truncationMode = .byTruncatingTail
            itemNode.accessibilityLabel = item.title
            itemNode.accessibilityTraits = [.button]
            itemNode.setTitle(item.title, with: textFont, with: theme.textColor, for: .normal)
            itemNode.setTitle(item.title, with: selectedTextFont, with: theme.textColor, for: .selected)
            itemNode.setTitle(item.title, with: selectedTextFont, with: theme.textColor, for: [.selected, .highlighted])
            return itemNode
        }
        
        let dividersCount = items.count > 2 ? items.count - 1 : 0
        self.dividerNodes = (0 ..< dividersCount).map { _ in
            let node = ASDisplayNode()
            node.backgroundColor = theme.dividerColor
            return node
        }
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 9.0
        
        self.addSubnode(self.selectionNode)
        self.itemNodes.forEach(self.addSubnode(_:))
        self.setupButtons()
        self.dividerNodes.forEach(self.addSubnode(_:))

        self.backgroundColor = self.theme.backgroundColor
        self.selectionNode.image = generateSelectionImage(theme: self.theme)
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
       
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        gestureRecognizer.delegate = self
        self.view.addGestureRecognizer(gestureRecognizer)
        self.gestureRecognizer = gestureRecognizer
    }
    
    private func updatePointerInteraction() {
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
         
            if i == self.selectedIndex {
                itemNode.pointerInteraction = PointerInteraction(view: itemNode.view, customInteractionView: self.selectionNode.view, style: .lift)
            } else {
                itemNode.pointerInteraction = PointerInteraction(view: itemNode.view, style: .insetRectangle(2.0, 2.0))
            }
        }
    }
    
    private func setupButtons() {
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            itemNode.addTarget(self, action: #selector(self.buttonPressed(_:)), forControlEvents: .touchUpInside)
            itemNode.highligthedChanged = { [weak self, weak itemNode] highlighted in
                if let strongSelf = self, let itemNode = itemNode {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
                    if strongSelf.selectedIndex == i {
                        if let gestureRecognizer = strongSelf.gestureRecognizer, case .began = gestureRecognizer.state {
                        } else {
                            strongSelf.updateButtonsHighlights(highlightedIndex: highlighted ? i : nil, gestureSelectedIndex: strongSelf.gestureSelectedIndex)
                        }
                    } else if highlighted {
                        transition.updateAlpha(node: itemNode, alpha: 0.4)
                    }
                    if !highlighted {
                        transition.updateAlpha(node: itemNode, alpha: 1.0)
                    }
                }
            }
        }
        
        self.updatePointerInteraction()
    }
    
    private func updateButtonsHighlights(highlightedIndex: Int?, gestureSelectedIndex: Int?) {
        let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
        if highlightedIndex == nil && gestureSelectedIndex == nil {
            transition.updateTransformScale(node: self.selectionNode, scale: 1.0)
        } else {
            transition.updateTransformScale(node: self.selectionNode, scale: 0.92)
        }
        for i in 0 ..< self.itemNodes.count {
            let itemNode = self.itemNodes[i]
            if i == highlightedIndex || i == gestureSelectedIndex {
                transition.updateTransformScale(node: itemNode, scale: 0.92)
            } else {
                transition.updateTransformScale(node: itemNode, scale: 1.0)
            }
        }
    }
    
    private func updateButtonsHighlights() {
        let transition = ContainedViewLayoutTransition.animated(duration: 0.25, curve: .easeInOut)
        if let gestureSelectedIndex = self.gestureSelectedIndex {
            for i in 0 ..< self.itemNodes.count {
                let itemNode = self.itemNodes[i]
                transition.updateTransformScale(node: itemNode, scale: i == gestureSelectedIndex ? 0.92 : 1.0)
            }
        } else {
            for itemNode in self.itemNodes {
                transition.updateTransformScale(node: itemNode, scale: 1.0)
            }
        }
    }
    
    public func updateTheme(_ theme: SegmentedControlTheme) {
        guard theme != self.theme else {
            return
        }
        self.theme = theme
        
        self.backgroundColor = self.theme.backgroundColor
        self.selectionNode.image = generateSelectionImage(theme: self.theme)
        
        for itemNode in self.itemNodes {
            if let title = itemNode.attributedTitle(for: .normal)?.string {
                itemNode.setTitle(title, with: textFont, with: self.theme.textColor, for: .normal)
                itemNode.setTitle(title, with: selectedTextFont, with: self.theme.textColor, for: .selected)
                itemNode.setTitle(title, with: selectedTextFont, with: self.theme.textColor, for: [.selected, .highlighted])
            }
        }
        
        for dividerNode in self.dividerNodes {
            dividerNode.backgroundColor = theme.dividerColor
        }
    }
    
    public func updateLayout(_ layout: SegmentedControlLayout, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = layout
                
        let width: CGFloat
        let height: CGFloat
        switch layout {
            case let .stretchToFill(targetWidth):
                width = targetWidth
                height = 32.0
            case let .sizeToFit(maximumWidth, minimumWidth, targetHeight):
                var calculatedWidth: CGFloat = 0.0
                var maxWidth: CGFloat = 0.0
                for item in self.itemNodes {
                    let size = item.calculateSizeThatFits(CGSize(width: maximumWidth, height: targetHeight))
                    maxWidth = max(maxWidth, size.width)
                }
                calculatedWidth = ceil(maxWidth * CGFloat(self.itemNodes.count))
                
                width = max(minimumWidth, min(maximumWidth, calculatedWidth))
                height = targetHeight
        }

        let selectedIndex: Int
        if let gestureSelectedIndex = self.gestureSelectedIndex {
            selectedIndex = gestureSelectedIndex
        } else {
            selectedIndex = self.selectedIndex
        }
        
        let size = CGSize(width: width, height: height)
        if !self.itemNodes.isEmpty {
            let itemSize = CGSize(width: floorToScreenPixels(size.width / CGFloat(self.itemNodes.count)), height: size.height)
            
            transition.updateBounds(node: self.selectionNode, bounds: CGRect(origin: CGPoint(), size: itemSize))
            transition.updatePosition(node: self.selectionNode, position: CGPoint(x: itemSize.width / 2.0 + itemSize.width * CGFloat(selectedIndex), y: size.height / 2.0))
            
            for i in 0 ..< self.itemNodes.count {
                let itemNode = self.itemNodes[i]
                let _ = itemNode.measure(itemSize)
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: itemSize.width * CGFloat(i), y: (size.height - itemSize.height) / 2.0), size: itemSize))
                
                let isSelected = selectedIndex == i
                if itemNode.isSelected != isSelected {
                    if case .animated = transition {
                        UIView.transition(with: itemNode.view, duration: 0.2, options: .transitionCrossDissolve, animations: {
                            itemNode.isSelected = isSelected
                        }, completion: nil)
                    } else {
                        itemNode.isSelected = isSelected
                    }
                    if isSelected {
                        itemNode.accessibilityTraits.insert(.selected)
                    } else {
                        itemNode.accessibilityTraits.remove(.selected)
                    }
                }
            }
        }
        
        if !self.dividerNodes.isEmpty {
            let dividerSize = CGSize(width: 1.0, height: 16.0)
            let delta: CGFloat = size.width / CGFloat(self.dividerNodes.count + 1)
            for i in 0 ..< self.dividerNodes.count {
                let dividerNode = self.dividerNodes[i]
                transition.updateFrame(node: dividerNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(delta * CGFloat(i + 1) - dividerSize.width / 2.0), y: (size.height - dividerSize.height) / 2.0), size: dividerSize))
                
                let dividerAlpha: CGFloat
                if (selectedIndex - 1 ... selectedIndex).contains(i) {
                    dividerAlpha = 0.0
                } else {
                    dividerAlpha = 1.0
                }
                transition.updateAlpha(node: dividerNode, alpha: dividerAlpha)
            }
        }
        
        return size
    }
    
    @objc private func buttonPressed(_ button: SegmentedControlItemNode) {
        guard let index = self.itemNodes.firstIndex(of: button) else {
            return
        }
        
        self.selectedIndexShouldChange(index, { [weak self] commit in
            if let strongSelf = self, commit {
                strongSelf._selectedIndex = index
                strongSelf.selectedIndexChanged(index)
                if let layout = strongSelf.validLayout {
                    let _ = strongSelf.updateLayout(layout, transition: .animated(duration: 0.2, curve: .slide))
                }
                
                strongSelf.updatePointerInteraction()
            }
        })
    }
    
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return self.selectionNode.frame.contains(gestureRecognizer.location(in: self.view))
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: self.view)
        switch recognizer.state {
            case .changed:
                if !self.selectionNode.frame.contains(location) {
                    let point = CGPoint(x: max(0.0, min(self.bounds.width, location.x)), y: 1.0)
                    for i in 0 ..< self.itemNodes.count {
                        let itemNode = self.itemNodes[i]
                        if itemNode.frame.contains(point) {
                            if i != self.gestureSelectedIndex {
                                self.gestureSelectedIndex = i
                                self.updateButtonsHighlights(highlightedIndex: nil, gestureSelectedIndex: i)
                                if let layout = self.validLayout {
                                    let _ = self.updateLayout(layout, transition: .animated(duration: 0.35, curve: .slide))
                                }
                            }
                            break
                        }
                    }
                }
            case .ended:
                if let gestureSelectedIndex = self.gestureSelectedIndex {
                    if gestureSelectedIndex != self.selectedIndex  {
                        self.selectedIndexShouldChange(gestureSelectedIndex, { [weak self] commit in
                            if let strongSelf = self {
                                if commit {
                                    strongSelf._selectedIndex = gestureSelectedIndex
                                    strongSelf.selectedIndexChanged(gestureSelectedIndex)
                                    
                                    strongSelf.updatePointerInteraction()
                                } else {
                                    if let layout = strongSelf.validLayout {
                                        let _ = strongSelf.updateLayout(layout, transition: .animated(duration: 0.2, curve: .slide))
                                    }
                                }
                            }
                        })
                    }
                    self.gestureSelectedIndex = nil
                }
                self.updateButtonsHighlights(highlightedIndex: nil, gestureSelectedIndex: nil)
            default:
                break
        }
    }
}
