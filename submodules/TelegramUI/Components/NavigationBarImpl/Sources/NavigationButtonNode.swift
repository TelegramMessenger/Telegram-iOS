import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import MultilineTextComponent
import AppBundle

let glassBackArrowImage: UIImage? = {
    let imageSize = CGSize(width: 44.0, height: 44.0)
    let topRightPoint = CGPoint(x: 24.6, y: 14.0)
    let centerPoint = CGPoint(x: 17.0, y: imageSize.height * 0.5)
    return generateImage(imageSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: topRightPoint)
        context.addLine(to: centerPoint)
        context.addLine(to: CGPoint(x: topRightPoint.x, y: size.height - topRightPoint.y))
        context.strokePath()
    })?.withRenderingMode(.alwaysTemplate)
}()

let glassCloseImage: UIImage? = {
    return generateTintedImage(image: UIImage(bundleImageName: "Navigation/Close"), color: .white)?.withRenderingMode(.alwaysTemplate)
}()

private final class ItemComponent: Component {
    enum Content: Equatable {
        case back
        case item(UIBarButtonItem)
    }
    
    let color: UIColor
    let content: Content
    
    init(
        color: UIColor,
        content: Content
    ) {
        self.color = color
        self.content = content
    }
    
    static func ==(lhs: ItemComponent, rhs: ItemComponent) -> Bool {
        if lhs.color != rhs.color {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var iconView: UIImageView?
        private var title: ComponentView<Empty>?
        
        private var component: ItemComponent?
        private weak var state: EmptyComponentState?
        var isUpdating: Bool = false
        
        private var setEnabledListener: Int?
        private var setTitleListener: Int?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if component.content != self.component?.content {
                if case let .item(item) = self.component?.content {
                    if let setEnabledListener = self.setEnabledListener {
                        self.setEnabledListener = nil
                        item.removeSetEnabledListener(setEnabledListener)
                    }
                    if let setTitleListener = self.setTitleListener {
                        self.setTitleListener = nil
                        item.removeSetTitleListener(setTitleListener)
                    }
                }
                
                switch component.content {
                case .back:
                    break
                case let .item(item):
                    self.setEnabledListener = item.addSetEnabledListener { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                    self.setTitleListener = item.addSetTitleListener { [weak self] _ in
                        guard let self else {
                            return
                        }
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate)
                        }
                    }
                }
            }
            
            self.component = component
            self.state = state
            
            var iconImage: UIImage?
            var titleString: String?
            switch component.content {
            case .back:
                iconImage = glassBackArrowImage
            case let .item(item):
                if item.image != nil {
                    iconImage = item.image
                } else if let title = item.title {
                    if title == "___close" {
                        iconImage = glassCloseImage
                    } else {
                        titleString = title
                    }
                }
            }
            
            var size = CGSize(width: 44.0, height: 44.0)
            
            if let iconImage {
                let iconView: UIImageView
                var iconTransition = transition
                if let current = self.iconView {
                    iconView = current
                } else {
                    iconTransition = iconTransition.withAnimation(.none)
                    iconView = UIImageView()
                    self.iconView = iconView
                }
                iconView.image = iconImage
                iconView.tintColor = component.color
                
                let iconFrame = iconImage.size.centered(in: CGRect(origin: CGPoint(), size: size))
                iconTransition.setFrame(view: iconView, frame: iconFrame)
            } else if let iconView = self.iconView {
                self.iconView = nil
                iconView.removeFromSuperview()
            }
            
            if let titleString {
                let titleFont: UIFont
                if case let .item(item) = component.content, case .done = item.style {
                    titleFont = Font.bold(17.0)
                } else {
                    titleFont = Font.medium(17.0)
                }
                
                let title: ComponentView<Empty>
                if let current = self.title {
                    title = current
                } else {
                    title = ComponentView()
                    self.title = title
                }
                let titleSize = title.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: titleString, font: titleFont, textColor: component.color))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 200.0, height: 100.0)
                )
                
                let titleInset: CGFloat = 6.0
                size.width = titleInset * 2.0 + titleSize.width
                
                let titleFrame = CGRect(origin: CGPoint(x: titleInset, y: floorToScreenPixels((size.height - titleSize.height) * 0.5)), size: titleSize)
                if let titleView = title.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    titleView.frame = titleFrame
                }
            } else if let title = self.title {
                self.title = nil
                if let titleView = title.view {
                    titleView.removeFromSuperview()
                }
            }
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class NavigationButtonItemNode: ImmediateTextNode {
    private let isGlass: Bool
    
    private func fontForCurrentState() -> UIFont {
        return self.bold ? Font.semibold(17.0) : Font.medium(17.0)
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
                if self.item?.accessibilityLabel == nil {
                    self.item?.accessibilityLabel = value
                }
            }
        }
    }
    
    private(set) var imageNode: ASImageNode?
    
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
                if self.imageNode?.image?.renderingMode == .alwaysTemplate {
                    self.imageNode?.tintColor = self.color
                } else {
                    self.imageNode?.tintColor = nil
                }
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
                    self.updatePointerInteraction()
                }
            }
        }
    }
    
    public var color: UIColor = UIColor(rgb: 0x0088ff) {
        didSet {
            if self.imageNode?.image?.renderingMode == .alwaysTemplate {
                self.imageNode?.tintColor = self.color
            }
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
    
    init(isGlass: Bool) {
        self.isGlass = isGlass
        
        super.init()
        
        self.isAccessibilityElement = true
        
        self.isUserInteractionEnabled = true
        self.isExclusiveTouch = true
        if !isGlass {
            self.hitTestSlop = UIEdgeInsets(top: -16.0, left: -10.0, bottom: -16.0, right: -10.0)
        }
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
            pointerStyle = .insetRectangle(-8.0, 2.0)
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
        if let touch = touches.first, !self.isGlass {
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


public final class NavigationButtonNodeImpl: ContextControllerSourceNode, NavigationButtonNode {
    private let isGlass: Bool
    private var isBack: Bool = false
    
    private var nodes: [NavigationButtonItemNode] = []
    
    private var disappearingNodes: [(frame: CGRect, size: CGSize, node: NavigationButtonItemNode)] = []
    
    public var singleCustomNode: ASDisplayNode? {
        for node in self.nodes {
            return node.node
        }
        return nil
    }
    
    public var mainContentNode: ASDisplayNode? {
        return self.nodes.first
    }
    
    public var pressed: (Int) -> () = { _ in }
    public var highlightChanged: (Int, Bool) -> () = { _, _ in }
    
    public var color: UIColor = UIColor(rgb: 0x0088ff) {
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
    
    override public var accessibilityElements: [Any]? {
        get {
            return self.nodes
        } set(value) {
        }
    }
    
    public init(isGlass: Bool) {
        self.isGlass = isGlass
        
        super.init()
        
        self.isAccessibilityElement = false
        self.isGestureEnabled = false
    }
    
    public var manualText: String {
        return self.nodes.first?.text ?? ""
    }
    
    public var manualAlpha: CGFloat = 1.0 {
        didSet {
            for node in self.nodes {
                node.alpha = self.manualAlpha
            }
        }
    }
    
    public var contentsColor: UIColor?
    
    public func updateManualAlpha(alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        for node in self.nodes {
            transition.updateAlpha(node: node, alpha: alpha)
        }
    }
    
    public func updateManualText(_ text: String, isBack: Bool = true) {
        self.isBack = isBack
        
        let node: NavigationButtonItemNode
        if self.nodes.count > 0 {
            node = self.nodes[0]
        } else {
            node = NavigationButtonItemNode(isGlass: self.isGlass)
            node.color = self.color
            node.layer.layerTintColor = self.contentsColor?.cgColor
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
        if !self.isGlass {
            node.hitTestSlop = isBack ? UIEdgeInsets(top: 0.0, left: -20.0, bottom: 0.0, right: 0.0) : UIEdgeInsets()
        }
        
        if 1 < self.nodes.count {
            for i in 1 ..< self.nodes.count {
                self.nodes[i].removeFromSupernode()
            }
            self.nodes.removeSubrange(1...)
        }
    }
    
    public func updateItems(_ items: [UIBarButtonItem], animated: Bool) {
        for i in 0 ..< items.count {
            let node: NavigationButtonItemNode
            if self.nodes.count > i {
                node = self.nodes[i]
            } else {
                node = NavigationButtonItemNode(isGlass: self.isGlass)
                node.color = self.color
                node.layer.layerTintColor = self.contentsColor?.cgColor
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
            if items[i].title == "___close" {
                //node.image = glassCloseImage
                node.image = generateTintedImage(image: UIImage(bundleImageName: "Navigation/Close"), color: self.color)
            } else {
                node.image = items[i].image
                node.text = items[i].title ?? ""
            }
            node.bold = items[i].style == .done
            node.isEnabled = items[i].isEnabled
            node.node = items[i].customDisplayNode
            
            if animated {
                node.layer.animateAlpha(from: 0.0, to: self.manualAlpha, duration: 0.16)
                node.layer.animateScale(from: 0.001, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            }
        }
        if items.count < self.nodes.count {
            for i in items.count ..< self.nodes.count {
                let itemNode = self.nodes[i]
                if animated {
                    disappearingNodes.append((itemNode.frame, self.bounds.size, itemNode))
                    itemNode.layer.animateAlpha(from: self.manualAlpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self, weak itemNode] _ in
                        guard let itemNode else {
                            return
                        }
                            
                        itemNode.removeFromSupernode()
                        
                        guard let self else {
                            return
                        }
                        if let index = self.disappearingNodes.firstIndex(where: { $0.node === itemNode }) {
                            self.disappearingNodes.remove(at: index)
                        }
                    })
                    itemNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                } else {
                    itemNode.removeFromSupernode()
                }
            }
            self.nodes.removeSubrange(items.count...)
        }
    }
    
    public func updateLayout(constrainedSize: CGSize, isLandscape: Bool, isLeftAligned: Bool) -> CGSize {
        var nodeOrigin = CGPoint(x: 0.0, y: 0.0)
        var totalHeight: CGFloat = 0.0
        for i in 0 ..< self.nodes.count {
            if i != 0 && !self.isGlass {
                nodeOrigin.x += 15.0
            }

            let node = self.nodes[i]

            var nodeSize = node.updateLayout(constrainedSize)
            var nodeInset: CGFloat = 0.0
            if self.isGlass {
                if node.image == nil && node.node == nil {
                    nodeInset += 12.0
                }
                if nodeSize.width + nodeInset * 2.0 < 44.0 {
                    nodeInset = floorToScreenPixels((44.0 - nodeSize.width) * 0.5)
                }
            }

            nodeSize.width = ceil(nodeSize.width)
            nodeSize.height = ceil(nodeSize.height)
            totalHeight = max(totalHeight, nodeSize.height)
            node.frame = CGRect(origin: CGPoint(x: nodeOrigin.x + nodeInset, y: floor((totalHeight - nodeSize.height) / 2.0)), size: nodeSize)
            nodeOrigin.x += nodeInset + node.bounds.width + nodeInset
            if isLandscape && !self.isGlass {
                nodeOrigin.x += 16.0
            }

            if !self.isGlass && node.node == nil && node.imageNode != nil && i == self.nodes.count - 1 {
                nodeOrigin.x -= 5.0
            }
        }
        
        /*if !isLeftAligned {
            for disappearingNode in self.disappearingNodes {
                disappearingNode.node.frame = disappearingNode.frame.offsetBy(dx: nodeOrigin.x - disappearingNode.size.width, dy: (totalHeight - disappearingNode.size.height) * 0.5)
            }
        }*/
        
        return CGSize(width: nodeOrigin.x, height: totalHeight)
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.nodes.count == 1 {
            if self.isGlass && self.isBack {
                if self.bounds.contains(point) {
                    return self.nodes[0].view
                }
            }
            if self.bounds.contains(point) {
                return self.nodes[0].view.hitTest(self.view.convert(point, to: self.nodes[0].view), with: event)
            } else {
                return nil
            }
        } else {
            return super.hitTest(point, with: event)
        }
    }
    
    var isEmpty: Bool {
        if self.isBack {
            return false
        }
        for node in self.nodes {
            if node.bounds.width != 0.0 {
                return false
            }
        }
        return true
    }
}
