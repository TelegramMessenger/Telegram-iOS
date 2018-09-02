import Foundation
import AsyncDisplayKit
import Display
import Lottie

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

private enum ItemListRevealOptionAlignment {
    case left
    case right
}

private final class ItemListRevealOptionNode: ASDisplayNode {
    private let titleNode: ASTextNode
    private let iconNode: ASImageNode?
    var alignment: ItemListRevealOptionAlignment?
    
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
        
//        if let url = frameworkBundle.url(forResource: "anim_mute", withExtension: "json") {
//            let animView = LOTAnimationView(contentsOf: url)
//            animView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 50.0, height: 50.0))
//            self.animView = animView
//            self.view.addSubview(animView)
//            animView.loopAnimation = true
//            animView.logHierarchyKeypaths()
//            animView.setValue(UIColor.green, forKeypath: "Outlines.Group 1.Fill 1.Color", atFrame: 0)
//            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0, execute: {
//                animView.play()
//            })
//        }
    }
    
    func updateLayout(baseSize: CGSize, alignment: ItemListRevealOptionAlignment, extendedWidth: CGFloat, transition: ContainedViewLayoutTransition) {
        var animateAdditive = false
        if transition.isAnimated, self.alignment != alignment {
            animateAdditive = true
        }
        self.alignment = alignment
        let titleSize = self.titleNode.calculatedSize
        var contentRect = CGRect(origin: CGPoint(), size: baseSize)
        switch alignment {
            case .left:
                contentRect.origin.x = 0.0
            case .right:
                contentRect.origin.x = extendedWidth - contentRect.width
        }
        if let iconNode = self.iconNode, let image = iconNode.image {
            let titleIconSpacing: CGFloat = 3.0
            let iconFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - image.size.width) / 2.0), y: contentRect.minY + floor((baseSize.height - image.size.height - titleIconSpacing - titleSize.height) / 2.0)), size: image.size)
            if animateAdditive {
                transition.animatePositionAdditive(node: iconNode, offset: CGPoint(x: iconNode.frame.minX - iconFrame.minX, y: 0.0))
            }
            iconNode.frame = iconFrame
            let titleFrame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width) / 2.0), y: contentRect.minY + floor((baseSize.height - image.size.height - titleIconSpacing - titleSize.height) / 2.0) + image.size.height + titleIconSpacing), size: titleSize)
            if animateAdditive {
                transition.animatePositionAdditive(node: self.titleNode, offset: CGPoint(x: self.titleNode.frame.minX - titleFrame.minX, y: 0.0))
            }
            self.titleNode.frame = titleFrame
        } else {
            self.titleNode.frame = CGRect(origin: CGPoint(x: contentRect.minX + floor((baseSize.width - titleSize.width) / 2.0), y: contentRect.minY + floor((baseSize.height - titleSize.height) / 2.0)), size: titleSize)
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let titleSize = self.titleNode.measure(constrainedSize)
        var maxWidth = titleSize.width
        if let iconNode = self.iconNode, let image = iconNode.image {
            maxWidth = max(image.size.width, maxWidth)
        }
        return CGSize(width: max(74.0, maxWidth + 20.0), height: constrainedSize.height)
    }
}

final class ItemListRevealOptionsNode: ASDisplayNode {
    private let optionSelected: (ItemListRevealOption) -> Void
    private let tapticAction: () -> Void
    
    private var options: [ItemListRevealOption] = []
    
    private var optionNodes: [ItemListRevealOptionNode] = []
    private var revealOffset: CGFloat = 0.0
    private var rightInset: CGFloat = 0.0
    
    init(optionSelected: @escaping (ItemListRevealOption) -> Void, tapticAction: @escaping () -> Void) {
        self.optionSelected = optionSelected
        self.tapticAction = tapticAction
        
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
            var extendedWidth = nodeWidth
            var alignment: ItemListRevealOptionAlignment = .left
            var nodeTransition = transition
            if self.optionNodes.count == 1 {
                extendedWidth = nodeWidth * max(1.0, abs(revealFactor))
                if abs(revealFactor) > 1.7 {
                    alignment = .right
                }
            }
            if let nodeAlignment = node.alignment, alignment != nodeAlignment {
                nodeTransition = .animated(duration: 0.2, curve: .spring)
                if alignment == .right || !transition.isAnimated {
                    self.tapticAction()
                }
            }
            transition.updateFrame(node: node, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(leftOffset * revealFactor), y: 0.0), size: CGSize(width: extendedWidth, height: size.height)))
            node.updateLayout(baseSize: CGSize(width: nodeWidth, height: size.height), alignment: alignment, extendedWidth: extendedWidth, transition: nodeTransition)
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
    
    func isDisplayingExtendedAction() -> Bool {
        if self.optionNodes.count != 1 {
            return false
        }
        for node in self.optionNodes {
            if let alignment = node.alignment, case .right = alignment {
                return true
            }
        }
        return false
    }
}
