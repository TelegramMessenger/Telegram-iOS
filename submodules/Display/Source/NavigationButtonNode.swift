import UIKit
import AsyncDisplayKit

public protocol NavigationButtonCustomDisplayNode {
    var isHighlightable: Bool { get }
}

private final class NavigationButtonItemNode: ImmediateTextNode {
    private func fontForCurrentState() -> UIFont {
        return self.bold ? UIFont.boldSystemFont(ofSize: 17.0) : UIFont.systemFont(ofSize: 17.0)
    }
    
    private func attributesForCurrentState() -> [NSAttributedString.Key: AnyObject] {
        return [
            NSAttributedString.Key.font: self.fontForCurrentState(),
            NSAttributedString.Key.foregroundColor: self.isEnabled ? self.color : self.disabledColor
        ]
    }
    
    private var setEnabledListener: Int?
    
    var item: UIBarButtonItem? {
        didSet {
            if self.item !== oldValue {
                if let oldValue = oldValue, let setEnabledListener = self.setEnabledListener {
                    oldValue.removeSetEnabledListener(setEnabledListener)
                    self.setEnabledListener = nil
                }
                
                if let item = self.item {
                    self.setEnabledListener = item.addSetEnabledListener { [weak self] value in
                        self?.isEnabled = value
                    }
                    self.accessibilityHint = item.accessibilityHint
                    self.accessibilityLabel = item.accessibilityLabel
                }
            }
        }
    }
    
    private var _text: String?
    public var text: String {
        get {
            return _text ?? ""
        }
        set(value) {
            _text = value
            
            self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            if _image == nil {
                self.item?.accessibilityLabel = value
            }
        }
    }
    
    private(set) var imageNode: ASImageNode?
    private let imageRippleNode: ASImageNode
    
    private var _image: UIImage?
    public var image: UIImage? {
        get {
            return _image
        } set(value) {
            _image = value
            
            if let _ = value {
                if self.imageNode == nil {
                    let imageNode = ASImageNode()
                    imageNode.displayWithoutProcessing = true
                    imageNode.displaysAsynchronously = false
                    self.imageNode = imageNode
                    if self.imageRippleNode.supernode != nil {
                        self.imageRippleNode.image = nil
                        self.imageRippleNode.removeFromSupernode()
                    }
                    
                    self.addSubnode(imageNode)
                }
                self.imageNode?.image = image
            } else if let imageNode = self.imageNode {
                imageNode.removeFromSupernode()
                self.imageNode = nil
                if self.imageRippleNode.supernode != nil {
                    self.imageRippleNode.image = nil
                    self.imageRippleNode.removeFromSupernode()
                }
            }
            
            self.invalidateCalculatedLayout()
            self.setNeedsLayout()
        }
    }
    
    public var node: ASDisplayNode? {
        didSet {
            if self.node !== oldValue {
                oldValue?.removeFromSupernode()
                if let node = self.node {
                    self.addSubnode(node)
                    self.invalidateCalculatedLayout()
                    self.setNeedsLayout()
                }
            }
        }
    }
    
    public var color: UIColor = UIColor(rgb: 0x007aff) {
        didSet {
            if let text = self._text {
                self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
    
    public var rippleColor: UIColor = UIColor(rgb: 0x000000, alpha: 0.05) {
        didSet {
            if self.imageRippleNode.image != nil {
                self.imageRippleNode.image = generateFilledCircleImage(diameter: 30.0, color: self.rippleColor)
            }
        }
    }
    
    public var disabledColor: UIColor = UIColor(rgb: 0xd0d0d0) {
        didSet {
            if let text = self._text {
                self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
    
    private var _bold: Bool = false
    public var bold: Bool {
        get {
            return _bold
        }
        set(value) {
            if _bold != value {
                _bold = value
                
                self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
    
    private var touchCount = 0
    public var pressed: () -> () = { }
    public var highlightChanged: (Bool) -> () = { _ in }
    
    override public var isAccessibilityElement: Bool {
        get {
            return true
        } set(value) {
            super.isAccessibilityElement = true
        }
    }
    
    override public var accessibilityLabel: String? {
        get {
            if let item = self.item, let accessibilityLabel = item.accessibilityLabel {
                return accessibilityLabel
            } else {
                return self.attributedText?.string
            }
        } set(value) {
            
        }
    }
    
    override public var accessibilityHint: String? {
        get {
            if let item = self.item, let accessibilityHint = item.accessibilityHint {
                return accessibilityHint
            } else {
                return nil
            }
        } set(value) {
            
        }
    }
    
    var pointerInteraction: PointerInteraction?
    
    override public init() {
        self.imageRippleNode = ASImageNode()
        self.imageRippleNode.displaysAsynchronously = false
        self.imageRippleNode.displayWithoutProcessing = true
        self.imageRippleNode.alpha = 0.0
        
        super.init()
        
        self.isAccessibilityElement = true
        
        self.isUserInteractionEnabled = true
        self.isExclusiveTouch = true
        self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        self.displaysAsynchronously = false
        
        self.verticalAlignment = .middle
        
        self.accessibilityTraits = .button
    }
    
    override func didLoad() {
        super.didLoad()
        self.updatePointerInteraction()
    }
    
    func updatePointerInteraction() {
        let pointerStyle: PointerStyle
        if self.node != nil {
            pointerStyle = .lift
        } else {
            pointerStyle = .default
        }
        self.pointerInteraction = PointerInteraction(node: self, style: pointerStyle)
    }
    
    override func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        var superSize = super.updateLayout(constrainedSize)
        
        if let node = self.node {
            let nodeSize = node.measure(constrainedSize)
            let size = CGSize(width: max(nodeSize.width, superSize.width), height: max(nodeSize.height, superSize.height))
            node.frame = CGRect(origin: CGPoint(), size: nodeSize)
            return size
        } else if let imageNode = self.imageNode {
            let nodeSize = imageNode.image?.size ?? CGSize()
            let size = CGSize(width: max(nodeSize.width, superSize.width), height: max(44.0, max(nodeSize.height, superSize.height)))
            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - nodeSize.width) / 2.0), y: floorToScreenPixels((size.height - nodeSize.height) / 2.0)), size: nodeSize)
            imageNode.frame = imageFrame
            self.imageRippleNode.frame = imageFrame
            return size
        } else {
            superSize.height = max(44.0, superSize.height)
        }
        return superSize
    }
    
    private func touchInsideApparentBounds(_ touch: UITouch) -> Bool {
        var apparentBounds = self.bounds
        let hitTestSlop = self.hitTestSlop
        apparentBounds.origin.x += hitTestSlop.left
        apparentBounds.size.width += -hitTestSlop.left - hitTestSlop.right
        apparentBounds.origin.y += hitTestSlop.top
        apparentBounds.size.height += -hitTestSlop.top - hitTestSlop.bottom
        
        return apparentBounds.contains(touch.location(in: self.view))
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.touchCount += touches.count
        self.updateHighlightedState(true, animated: false)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.updateHighlightedState(false, animated: false)
        
        let previousTouchCount = self.touchCount
        self.touchCount = max(0, self.touchCount - touches.count)
        
        var touchInside = true
        if let touch = touches.first {
            touchInside = self.touchInsideApparentBounds(touch)
        }
        if previousTouchCount != 0 && self.touchCount == 0 && self.isEnabled && touchInside {
            self.pressed()
        }
    }

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let node = self.node as? HighlightableButtonNode {
            let result = node.view.hitTest(self.view.convert(point, to: node.view), with: event)
            return result
        } else {
            let previousAlpha = self.alpha
            self.alpha = 1.0
            let result = super.hitTest(point, with: event)
            self.alpha = previousAlpha
            return result
        }
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        self.touchCount = max(0, self.touchCount - (touches?.count ?? 0))
        self.updateHighlightedState(false, animated: false)
    }
    
    private var _highlighted = false
    private func updateHighlightedState(_ highlighted: Bool, animated: Bool) {
        if _highlighted != highlighted {
            _highlighted = highlighted
            
            var shouldChangeHighlight = true
            if let node = self.node as? NavigationButtonCustomDisplayNode {
                shouldChangeHighlight = node.isHighlightable
            }
            
            if shouldChangeHighlight {
                if self.alpha > 0.0 {
                    self.alpha = !self.isEnabled ? 1.0 : (highlighted ? 0.4 : 1.0)
                }
                self.highlightChanged(highlighted)
            }
        }
    }
    
    public var isEnabled: Bool = true {
        didSet {
            if self.isEnabled != oldValue {
                self.attributedText = NSAttributedString(string: self.text, attributes: self.attributesForCurrentState())
                if let constrainedSize = self.constrainedSize {
                    let _ = self.updateLayout(constrainedSize)
                }
            }
        }
    }
}


public final class NavigationButtonNode: ContextControllerSourceNode {
    private var nodes: [NavigationButtonItemNode] = []
    
    public var singleCustomNode: ASDisplayNode? {
        for node in self.nodes {
            return node.node
        }
        return nil
    }
    
    public var pressed: (Int) -> () = { _ in }
    public var highlightChanged: (Int, Bool) -> () = { _, _ in }
    
    public var color: UIColor = UIColor(rgb: 0x007aff) {
        didSet {
            if !self.color.isEqual(oldValue) {
                for node in self.nodes {
                    node.color = self.color
                }
            }
        }
    }
    
    public var rippleColor: UIColor = UIColor(rgb: 0x000000, alpha: 0.05) {
        didSet {
            if !self.rippleColor.isEqual(oldValue) {
                for node in self.nodes {
                    node.rippleColor = self.rippleColor
                }
            }
        }
    }
    
    public var disabledColor: UIColor = UIColor(rgb: 0xd0d0d0) {
        didSet {
            if !self.disabledColor.isEqual(oldValue) {
                for node in self.nodes {
                    node.disabledColor = self.disabledColor
                }
            }
        }
    }
    
    override public var accessibilityElements: [Any]? {
        get {
            return self.nodes
        } set(value) {
        }
    }
    
    override public init() {
        super.init()
        
        self.isAccessibilityElement = false
        self.isGestureEnabled = false
    }
    
    var manualText: String {
        return self.nodes.first?.text ?? ""
    }
    
    var manualAlpha: CGFloat = 1.0 {
        didSet {
            for node in self.nodes {
                node.alpha = self.manualAlpha
            }
        }
    }
    
    func updateManualText(_ text: String, isBack: Bool = true) {
        let node: NavigationButtonItemNode
        if self.nodes.count > 0 {
            node = self.nodes[0]
        } else {
            node = NavigationButtonItemNode()
            node.color = self.color
            node.rippleColor = self.rippleColor
            node.highlightChanged = { [weak node, weak self] value in
                if let strongSelf = self, let node = node {
                    if let index = strongSelf.nodes.firstIndex(where: { $0 === node }) {
                        strongSelf.highlightChanged(index, value)
                    }
                }
            }
            node.pressed = { [weak self, weak node] in
                if let strongSelf = self, let node = node {
                    if let index = strongSelf.nodes.firstIndex(where: { $0 === node }) {
                        strongSelf.pressed(index)
                    }
                }
            }
            self.nodes.append(node)
            self.addSubnode(node)
        }
        node.alpha = self.manualAlpha
        node.item = nil
        node.image = nil
        node.text = text
        node.bold = false
        node.isEnabled = true
        node.node = nil
        node.hitTestSlop = isBack ? UIEdgeInsets(top: 0.0, left: -20.0, bottom: 0.0, right: 0.0) : UIEdgeInsets()
        
        if 1 < self.nodes.count {
            for i in 1 ..< self.nodes.count {
                self.nodes[i].removeFromSupernode()
            }
            self.nodes.removeSubrange(1...)
        }
    }
    
    func updateItems(_ items: [UIBarButtonItem]) {
        for i in 0 ..< items.count {
            let node: NavigationButtonItemNode
            if self.nodes.count > i {
                node = self.nodes[i]
            } else {
                node = NavigationButtonItemNode()
                node.color = self.color
                node.rippleColor = self.rippleColor
                node.highlightChanged = { [weak node, weak self] value in
                    if let strongSelf = self, let node = node {
                        if let index = strongSelf.nodes.firstIndex(where: { $0 === node }) {
                            strongSelf.highlightChanged(index, value)
                        }
                    }
                }
                node.pressed = { [weak self, weak node] in
                    if let strongSelf = self, let node = node {
                        if let index = strongSelf.nodes.firstIndex(where: { $0 === node }) {
                            strongSelf.pressed(index)
                        }
                    }
                }
                self.nodes.append(node)
                self.addSubnode(node)
            }
            node.alpha = self.manualAlpha
            node.item = items[i]
            node.image = items[i].image
            node.text = items[i].title ?? ""
            node.bold = items[i].style == .done
            node.isEnabled = items[i].isEnabled
            node.node = items[i].customDisplayNode
        }
        if items.count < self.nodes.count {
            for i in items.count ..< self.nodes.count {
                self.nodes[i].removeFromSupernode()
            }
            self.nodes.removeSubrange(items.count...)
        }
    }
    
    public func updateLayout(constrainedSize: CGSize, isLandscape: Bool) -> CGSize {
        var nodeOrigin = CGPoint()
        var totalHeight: CGFloat = 0.0
        for i in 0 ..< self.nodes.count {
            if i != 0 {
                nodeOrigin.x += 10.0
            }

            let node = self.nodes[i]

            var nodeSize = node.updateLayout(constrainedSize)

            nodeSize.width = ceil(nodeSize.width)
            nodeSize.height = ceil(nodeSize.height)
            totalHeight = max(totalHeight, nodeSize.height)
            node.frame = CGRect(origin: CGPoint(x: nodeOrigin.x, y: floor((totalHeight - nodeSize.height) / 2.0)), size: nodeSize)
            nodeOrigin.x += node.bounds.width
            if isLandscape {
                nodeOrigin.x += 16.0
            }

            if node.node == nil && node.imageNode != nil && i == self.nodes.count - 1 {
                nodeOrigin.x -= 5.0
            }
        }
        return CGSize(width: nodeOrigin.x, height: totalHeight)
    }
    
    func internalHitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.nodes.count == 1 {
            return self.nodes[0].view
        } else {
            return super.hitTest(point, with: event)
        }
    }
}
