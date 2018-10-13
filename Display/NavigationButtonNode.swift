import UIKit
import AsyncDisplayKit

private final class NavigationButtonItemNode: ASTextNode {
    private func fontForCurrentState() -> UIFont {
        return self.bold ? UIFont.boldSystemFont(ofSize: 17.0) : UIFont.systemFont(ofSize: 17.0)
    }
    
    private func attributesForCurrentState() -> [NSAttributedStringKey : AnyObject] {
        return [
            NSAttributedStringKey.font: self.fontForCurrentState(),
            NSAttributedStringKey.foregroundColor: self.isEnabled ? self.color : self.disabledColor
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
        }
    }
    
    private var imageNode: ASImageNode?
    
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
                    self.addSubnode(imageNode)
                }
                self.imageNode?.image = image
            } else if let imageNode = self.imageNode {
                imageNode.removeFromSupernode()
                self.imageNode = nil
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
    
    public var color: UIColor = UIColor(rgb: 0x007ee5) {
        didSet {
            if let text = self._text {
                self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
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
    
    override public init() {
        super.init()
        
        self.isUserInteractionEnabled = true
        self.isExclusiveTouch = true
        self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        self.displaysAsynchronously = false
    }
    
    func updateLayout(_ constrainedSize: CGSize) -> CGSize {
        let superSize = super.calculateSizeThatFits(constrainedSize)
        
        if let node = self.node {
            let nodeSize = node.measure(constrainedSize)
            let size = CGSize(width: max(nodeSize.width, superSize.width), height: max(nodeSize.height, superSize.height))
            node.frame = CGRect(origin: CGPoint(), size: nodeSize)
            return size
        } else if let imageNode = self.imageNode {
            let nodeSize = imageNode.image?.size ?? CGSize()
            let size = CGSize(width: max(nodeSize.width, superSize.width), height: max(nodeSize.height, superSize.height))
            imageNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - nodeSize.width) / 2.0) + 5.0, y: floorToScreenPixels((size.height - nodeSize.height) / 2.0)), size: nodeSize)
            return size
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
        
        self.updateHighlightedState(self.touchInsideApparentBounds(touches.first!), animated: true)
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.updateHighlightedState(false, animated: false)
        
        let previousTouchCount = self.touchCount
        self.touchCount = max(0, self.touchCount - touches.count)
        
        if previousTouchCount != 0 && self.touchCount == 0 && self.isEnabled && self.touchInsideApparentBounds(touches.first!) {
            self.pressed()
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
            
            let alpha: CGFloat = !self.isEnabled ? 1.0 : (highlighted ? 0.4 : 1.0)
            
            /*if animated {
             UIView.animate(withDuration: 0.3, delay: 0.0, options: UIViewAnimationOptions.beginFromCurrentState, animations: { () -> Void in
             self.alpha = alpha
             }, completion: nil)
             }
             else {*/
            self.alpha = alpha
            self.highlightChanged(highlighted)
            //}
        }
    }
    
    public override var isEnabled: Bool {
        get {
            return super.isEnabled
        }
        set(value) {
            if self.isEnabled != value {
                super.isEnabled = value
                
                self.attributedText = NSAttributedString(string: text, attributes: self.attributesForCurrentState())
            }
        }
    }
}


final class NavigationButtonNode: ASDisplayNode {
    private var nodes: [NavigationButtonItemNode] = []
    
    public var pressed: (Int) -> () = { _ in }
    public var highlightChanged: (Int, Bool) -> () = { _, _ in }
    
    public var color: UIColor = UIColor(rgb: 0x007ee5) {
        didSet {
            if !self.color.isEqual(oldValue) {
                for node in self.nodes {
                    node.color = self.color
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
    
    override init() {
        super.init()
    }
    
    var manualText: String {
        return self.nodes.first?.text ?? ""
    }
    
    func updateManualText(_ text: String) {
        let node: NavigationButtonItemNode
        if self.nodes.count > 0 {
            node = self.nodes[0]
        } else {
            node = NavigationButtonItemNode()
            node.color = self.color
            node.highlightChanged = { [weak node, weak self] value in
                if let strongSelf = self, let node = node {
                    if let index = strongSelf.nodes.index(where: { $0 === node }) {
                        strongSelf.highlightChanged(index, value)
                    }
                }
            }
            node.pressed = { [weak self, weak node] in
                if let strongSelf = self, let node = node {
                    if let index = strongSelf.nodes.index(where: { $0 === node }) {
                        strongSelf.pressed(index)
                    }
                }
            }
            self.nodes.append(node)
            self.addSubnode(node)
        }
        node.item = nil
        node.text = text
        node.image = nil
        node.bold = false
        node.isEnabled = true
        node.node = nil
        
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
                node.highlightChanged = { [weak node, weak self] value in
                    if let strongSelf = self, let node = node {
                        if let index = strongSelf.nodes.index(where: { $0 === node }) {
                            strongSelf.highlightChanged(index, value)
                        }
                    }
                }
                node.pressed = { [weak self, weak node] in
                    if let strongSelf = self, let node = node {
                        if let index = strongSelf.nodes.index(where: { $0 === node }) {
                            strongSelf.pressed(index)
                        }
                    }
                }
                self.nodes.append(node)
                self.addSubnode(node)
            }
            node.item = items[i]
            node.text = items[i].title ?? ""
            node.image = items[i].image
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
    
    func updateLayout(constrainedSize: CGSize) -> CGSize                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            {
        var nodeOrigin = CGPoint()
        var totalSize = CGSize()
        for node in self.nodes {
            if !totalSize.width.isZero {
                totalSize.width += 16.0
                nodeOrigin.x += 16.0
            }
            var nodeSize = node.updateLayout(constrainedSize)
            nodeSize.width = ceil(nodeSize.width)
            nodeSize.height = ceil(nodeSize.height)
            totalSize.width += nodeSize.width
            totalSize.height = max(totalSize.height, nodeSize.height)
            node.frame = CGRect(origin: nodeOrigin, size: nodeSize)
            nodeOrigin.x += node.bounds.width
        }
        return totalSize
    }
}
