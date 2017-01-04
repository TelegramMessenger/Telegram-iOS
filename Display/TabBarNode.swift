import Foundation
import UIKit
import AsyncDisplayKit

private let separatorHeight: CGFloat = 1.0 / UIScreen.main.scale
private func tabBarItemImage(_ image: UIImage?, title: String, tintColor: UIColor) -> UIImage {
    let font = Font.regular(10.0)
    let titleSize = (title as NSString).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: [NSFontAttributeName: font], context: nil).size
    
    let imageSize: CGSize
    if let image = image {
        imageSize = image.size
    } else {
        imageSize = CGSize()
    }
    
    let size = CGSize(width: max(ceil(titleSize.width), imageSize.width), height: 45.0)
    
    UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
    if let context = UIGraphicsGetCurrentContext() {
        context.setFillColor(UIColor(0xf7f7f7).cgColor)
        context.fill(CGRect(origin: CGPoint(), size: size))
        
        if let image = image {
            let imageRect = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - imageSize.width) / 2.0), y: 0.0), size: imageSize)
            context.saveGState()
            context.translateBy(x: imageRect.midX, y: imageRect.midY)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -imageRect.midX, y: -imageRect.midY)
            context.clip(to: imageRect, mask: image.cgImage!)
            context.setFillColor(tintColor.cgColor)
            context.fill(imageRect)
            context.restoreGState()
        }
    }
    
    (title as NSString).draw(at: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - 3.0), withAttributes: [NSFontAttributeName: font, NSForegroundColorAttributeName: tintColor])
    
    let image = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    
    return image
}

private let badgeImage = generateStretchableFilledCircleImage(diameter: 18.0, color: UIColor(0xff3b30), backgroundColor: nil)
private let badgeFont = Font.regular(13.0)

private final class TabBarNodeContainer {
    let item: UITabBarItem
    let updateBadgeListenerIndex: Int
    
    let imageNode: ASImageNode
    let badgeBackgroundNode: ASImageNode
    let badgeTextNode: ASTextNode
    
    var badgeValue: String?
    var appliedBadgeValue: String?
    
    init(item: UITabBarItem, imageNode: ASImageNode, updateBadge: @escaping (String) -> Void) {
        self.item = item
        
        self.imageNode = imageNode
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isLayerBacked = true
        self.badgeBackgroundNode.displayWithoutProcessing = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.image = badgeImage
        
        self.badgeTextNode = ASTextNode()
        self.badgeTextNode.maximumNumberOfLines = 1
        self.badgeTextNode.isLayerBacked = true
        self.badgeTextNode.displaysAsynchronously = false
        
        self.badgeValue = item.badgeValue ?? ""
        self.updateBadgeListenerIndex = UITabBarItem_addSetBadgeListener(item, { value in
            updateBadge(value ?? "")
        })
    }
    
    deinit {
        item.removeSetBadgeListener(self.updateBadgeListenerIndex)
    }
}

class TabBarNode: ASDisplayNode {
    var tabBarItems: [UITabBarItem] = [] {
        didSet {
            self.reloadTabBarItems()
        }
    }
    
    var selectedIndex: Int? {
        didSet {
            if self.selectedIndex != oldValue {
                if let oldValue = oldValue {
                    self.updateNodeImage(oldValue)
                }
                
                if let selectedIndex = self.selectedIndex {
                    self.updateNodeImage(selectedIndex)
                }
            }
        }
    }
    
    private let itemSelected: (Int) -> Void
    
    let separatorNode: ASDisplayNode
    private var tabBarNodeContainers: [TabBarNodeContainer] = []
    
    init(itemSelected: @escaping (Int) -> Void) {
        self.itemSelected = itemSelected
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(0xb2b2b2)
        self.separatorNode.isOpaque = true
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.isOpaque = true
        self.backgroundColor = UIColor(0xf7f7f7)
        
        self.addSubnode(self.separatorNode)
    }
    
    private func reloadTabBarItems() {
        for node in self.tabBarNodeContainers {
            node.imageNode.removeFromSupernode()
            node.badgeBackgroundNode.removeFromSupernode()
            node.badgeTextNode.removeFromSupernode()
        }
        
        var tabBarNodeContainers: [TabBarNodeContainer] = []
        for i in 0 ..< self.tabBarItems.count {
            let item = self.tabBarItems[i]
            let node = ASImageNode()
            node.displaysAsynchronously = false
            node.displayWithoutProcessing = true
            node.isLayerBacked = true
            if let selectedIndex = self.selectedIndex , selectedIndex == i {
                node.image = tabBarItemImage(item.selectedImage, title: item.title ?? "", tintColor: UIColor(0x007ee5))
            } else {
                node.image = tabBarItemImage(item.image, title: item.title ?? "", tintColor: UIColor(0x929292))
            }
            let container = TabBarNodeContainer(item: item, imageNode: node, updateBadge: { [weak self] value in
                self?.updateNodeBadge(i, value: value)
            })
            tabBarNodeContainers.append(container)
            self.addSubnode(node)
        }
        
        for container in tabBarNodeContainers {
            self.addSubnode(container.badgeBackgroundNode)
            self.addSubnode(container.badgeTextNode)
        }
        
        self.tabBarNodeContainers = tabBarNodeContainers
        
        self.setNeedsLayout()
    }
    
    private func updateNodeImage(_ index: Int) {
        if index < self.tabBarNodeContainers.count && index < self.tabBarItems.count {
            let node = self.tabBarNodeContainers[index].imageNode
            let item = self.tabBarItems[index]
            
            if let selectedIndex = self.selectedIndex , selectedIndex == index {
                node.image = tabBarItemImage(item.selectedImage, title: item.title ?? "", tintColor: UIColor(0x007ee5))
            } else {
                node.image = tabBarItemImage(item.image, title: item.title ?? "", tintColor: UIColor(0x929292))
            }
        }
    }
    
    private func updateNodeBadge(_ index: Int, value: String) {
        self.tabBarNodeContainers[index].badgeValue = value
        if self.tabBarNodeContainers[index].badgeValue != self.tabBarNodeContainers[index].appliedBadgeValue {
            self.layout()
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -separatorHeight), size: CGSize(width: size.width, height: separatorHeight))
        
        if self.tabBarNodeContainers.count != 0 {
            let distanceBetweenNodes = size.width / CGFloat(self.tabBarNodeContainers.count)
            
            let internalWidth = distanceBetweenNodes * CGFloat(self.tabBarNodeContainers.count - 1)
            let leftNodeOriginX = (size.width - internalWidth) / 2.0
            
            for i in 0 ..< self.tabBarNodeContainers.count {
                let container = self.tabBarNodeContainers[i]
                let node = container.imageNode
                node.measure(CGSize(width: internalWidth, height: size.height))
                
                let originX = floor(leftNodeOriginX + CGFloat(i) * distanceBetweenNodes - node.calculatedSize.width / 2.0)
                node.frame = CGRect(origin: CGPoint(x: originX, y: 4.0), size: node.calculatedSize)
                
                if container.badgeValue != container.appliedBadgeValue {
                    container.appliedBadgeValue = container.badgeValue
                    if let badgeValue = container.badgeValue, !badgeValue.isEmpty {
                        container.badgeTextNode.attributedText = NSAttributedString(string: badgeValue, font: badgeFont, textColor: .white)
                        container.badgeBackgroundNode.isHidden = false
                        container.badgeTextNode.isHidden = false
                    } else {
                        container.badgeBackgroundNode.isHidden = true
                        container.badgeTextNode.isHidden = true
                    }
                }
                
                if !container.badgeBackgroundNode.isHidden {
                    let badgeSize = container.badgeTextNode.measure(CGSize(width: 200.0, height: 100.0))
                    let backgroundSize = CGSize(width: max(18.0, badgeSize.width + 10.0 + 1.0), height: 18.0)
                    let backgroundFrame = CGRect(origin: CGPoint(x: floor(originX + node.calculatedSize.width / 2.0) - 5.0, y: 2.0), size: backgroundSize)
                    container.badgeBackgroundNode.frame = backgroundFrame
                    container.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: 3.0), size: badgeSize)
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if let touch = touches.first {
            let location = touch.location(in: self.view)
            var closestNode: (Int, CGFloat)?
            
            for i in 0 ..< self.tabBarNodeContainers.count {
                let node = self.tabBarNodeContainers[i].imageNode
                let distance = abs(location.x - node.position.x)
                if let previousClosestNode = closestNode {
                    if previousClosestNode.1 > distance {
                        closestNode = (i, distance)
                    }
                } else {
                    closestNode = (i, distance)
                }
            }
            
            if let closestNode = closestNode {
                self.itemSelected(closestNode.0)
            }
        }
    }
}
