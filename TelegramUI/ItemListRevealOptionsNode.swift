import Foundation
import AsyncDisplayKit
import Display
//import Lottie

struct ItemListRevealOption: Equatable {
    let key: Int32
    let title: String
    let icon: UIImage?
    let color: UIColor
    let textColor: UIColor
    
    static func ==(lhs: ItemListRevealOption, rhs: ItemListRevealOption) -> Bool {
        if lhs.key != rhs.key {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        if !lhs.textColor.isEqual(rhs.textColor) {
            return false
        }
        if lhs.icon !== rhs.icon {
            return false
        }
        return true
    }
}

private let titleFontWithIcon = Font.regular(13.0)
private let titleFontWithoutIcon = Font.regular(17.0)

final class ItemListRevealOptionNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let iconNode: ASImageNode?
    
    //private var animView: LOTView?
    
    init(title: String, icon: UIImage?, color: UIColor, textColor: UIColor) {
        self.titleNode = ASTextNode()
        self.titleNode.attributedText = NSAttributedString(string: title, font: icon == nil ? titleFontWithoutIcon : titleFontWithIcon, textColor: textColor)
        
        if let icon = icon {
            let iconNode = ASImageNode()
            iconNode.image = generateTintedImage(image: icon, color: textColor)
            self.iconNode = iconNode
        } else {
            self.iconNode = nil
        }
        
        super.init()
        
        self.addSubnode(self.titleNode)
        if let iconNode = self.iconNode {
            self.addSubnode(iconNode)
        }
        self.backgroundColor = color
    }
    
    override func didLoad() {
        super.didLoad()
        
        /*if let url = frameworkBundle.url(forResource: "mute", withExtension: "json") {
            let animView = LOTAnimationView(contentsOf: url)
            animView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
            self.animView = animView
            self.view.addSubview(animView)
            animView.loopAnimation = true
            animView.logHierarchyKeypaths()
            animView.setValue(UIColor.green, forKeypath: "Outlines.Group 1.Fill 1.Color", atFrame: 0)
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: {
                animView.play()
            })
        }*/
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.measure(constrainedSize)
        var maxWidth = titleSize.width
        if let iconNode = self.iconNode, let image = iconNode.image {
            maxWidth = max(image.size.width, maxWidth)
        }
        return CGSize(width: max(74.0, maxWidth + 20.0), height: constrainedSize.height)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let titleSize = self.titleNode.calculatedSize
        if let iconNode = self.iconNode, let image = iconNode.image {
            let titleIconSpacing: CGFloat = 3.0
            iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height - titleIconSpacing - titleSize.height) / 2.0)), size: image.size)
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - image.size.height - titleIconSpacing - titleSize.height) / 2.0) + image.size.height + titleIconSpacing), size: titleSize)
        } else {
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
        }
    }
}

final class ItemListRevealOptionsNode: ASDisplayNode {
    private let optionSelected: (ItemListRevealOption) -> Void
    
    private var options: [ItemListRevealOption] = []
    
    private var optionNodes: [ItemListRevealOptionNode] = []
    private var revealOffset: CGFloat = 0.0
    private var rightInset: CGFloat = 0.0
    
    init(optionSelected: @escaping (ItemListRevealOption) -> Void) {
        self.optionSelected = optionSelected
        
        super.init()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setOptions(_ options: [ItemListRevealOption]) {
        if self.options != options {
            self.options = options
            for node in self.optionNodes {
                node.removeFromSupernode()
            }
            self.optionNodes = options.map { option in
                return ItemListRevealOptionNode(title: option.title, icon: option.icon, color: option.color, textColor: option.textColor)
            }
            for node in self.optionNodes {
                self.addSubnode(node)
            }
            self.invalidateCalculatedLayout()
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        var maxWidth: CGFloat = 0.0
        for node in self.optionNodes {
            let nodeSize = node.measure(constrainedSize)
            maxWidth = max(nodeSize.width, maxWidth)
        }
        return CGSize(width: maxWidth * CGFloat(self.optionNodes.count), height: constrainedSize.height)
    }
    
    func updateRevealOffset(offset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.revealOffset = offset
        self.rightInset = rightInset
        self.updateNodesLayout(transition: transition)
    }
    
    private func updateNodesLayout(transition: ContainedViewLayoutTransition) {
        let size = self.bounds.size
        if size.width.isLessThanOrEqualTo(0.0) || self.optionNodes.isEmpty {
            return
        }
        let basicNodeWidth = floorToScreenPixels(size.width / CGFloat(self.optionNodes.count))
        let lastNodeWidth = size.width - basicNodeWidth * CGFloat(self.optionNodes.count - 1)
        let revealFactor = min(1.0, self.revealOffset / (size.width + self.rightInset))
        var leftOffset: CGFloat = 0.0
        for i in 0 ..< self.optionNodes.count {
            let node = self.optionNodes[i]
            let nodeWidth = i == (self.optionNodes.count - 1) ? lastNodeWidth : basicNodeWidth
            transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(leftOffset * revealFactor), y: 0.0), size: CGSize(width: nodeWidth, height: size.height)))
            leftOffset += nodeWidth
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            let location = recognizer.location(in: self.view)
            for i in 0 ..< self.optionNodes.count {
                if self.optionNodes[i].frame.contains(location) {
                    self.optionSelected(self.options[i])
                    break
                }
            }
        }
    }
}
