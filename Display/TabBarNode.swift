import Foundation
import UIKit
import AsyncDisplayKit

private let separatorHeight: CGFloat = 1.0 / UIScreen.mainScreen().scale
private func tabBarItemImage(image: UIImage?, title: String, tintColor: UIColor) -> UIImage {
    let font = Font.regular(10.0)
    let titleSize = (title as NSString).boundingRectWithSize(CGSize(width: CGFloat.max, height: CGFloat.max), options: [.UsesLineFragmentOrigin], attributes: [NSFontAttributeName: font], context: nil).size
    
    let imageSize: CGSize
    if let image = image {
        imageSize = image.size
    } else {
        imageSize = CGSize()
    }
    
    let size = CGSize(width: max(ceil(titleSize.width), imageSize.width), height: 45.0)
    
    UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
    let context = UIGraphicsGetCurrentContext()
    
    CGContextSetFillColorWithColor(context, UIColor(0xf7f7f7).CGColor)
    CGContextFillRect(context, CGRect(origin: CGPoint(), size: size))
    
    if let image = image {
        let imageRect = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - imageSize.width) / 2.0), y: 0.0), size: imageSize)
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, imageRect.midX, imageRect.midY)
        CGContextScaleCTM(context, 1.0, -1.0)
        CGContextTranslateCTM(context, -imageRect.midX, -imageRect.midY)
        CGContextClipToMask(context, imageRect, image.CGImage)
        CGContextSetFillColorWithColor(context, tintColor.CGColor)
        CGContextFillRect(context, imageRect)
        CGContextRestoreGState(context)
    }
    
    (title as NSString).drawAtPoint(CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - 3.0), withAttributes: [NSFontAttributeName: font, NSForegroundColorAttributeName: tintColor])
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image
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
    
    private let itemSelected: Int -> Void
    
    let separatorNode: ASDisplayNode
    private var tabBarNodes: [ASImageNode] = []
    
    init(itemSelected: Int -> Void) {
        self.itemSelected = itemSelected
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(0xb2b2b2)
        self.separatorNode.opaque = true
        self.separatorNode.layerBacked = true
        
        super.init()
        
        self.opaque = true
        self.backgroundColor = UIColor(0xf7f7f7)
        
        self.addSubnode(self.separatorNode)
    }
    
    private func reloadTabBarItems() {
        for node in self.tabBarNodes {
            node.removeFromSupernode()
        }
        
        var tabBarNodes: [ASImageNode] = []
        for i in 0 ..< self.tabBarItems.count {
            let item = self.tabBarItems[i]
            let node = ASImageNode()
            node.displaysAsynchronously = false
            node.displayWithoutProcessing = true
            node.layerBacked = true
            if let selectedIndex = self.selectedIndex where selectedIndex == i {
                node.image = tabBarItemImage(item.selectedImage, title: item.title ?? "", tintColor: UIColor.blueColor())
            } else {
                node.image = tabBarItemImage(item.image, title: item.title ?? "", tintColor: UIColor(0x929292))
            }
            tabBarNodes.append(node)
            self.addSubnode(node)
        }
        
        self.tabBarNodes = tabBarNodes
        
        self.setNeedsLayout()
    }
    
    private func updateNodeImage(index: Int) {
        if index < self.tabBarNodes.count && index < self.tabBarItems.count {
            let node = self.tabBarNodes[index]
            let item = self.tabBarItems[index]
            
            if let selectedIndex = self.selectedIndex where selectedIndex == index {
                node.image = tabBarItemImage(item.selectedImage, title: item.title ?? "", tintColor: UIColor.blueColor())
            } else {
                node.image = tabBarItemImage(item.image, title: item.title ?? "", tintColor: UIColor(0x929292))
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.separatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -separatorHeight), size: CGSize(width: size.width, height: separatorHeight))
        
        if self.tabBarNodes.count != 0 {
            let distanceBetweenNodes = size.width / CGFloat(self.tabBarNodes.count)
            
            let internalWidth = distanceBetweenNodes * CGFloat(self.tabBarNodes.count - 1)
            let leftNodeOriginX = (size.width - internalWidth) / 2.0
            
            for i in 0 ..< self.tabBarNodes.count {
                let node = self.tabBarNodes[i]
                node.measure(CGSize(width: internalWidth, height: size.height))
                
                node.frame = CGRect(origin: CGPoint(x: floor(leftNodeOriginX + CGFloat(i) * distanceBetweenNodes - node.calculatedSize.width / 2.0), y: 4.0), size: node.calculatedSize)
            }
        }
    }
    
    override func touchesBegan(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        super.touchesBegan(touches, withEvent: event)
        
        if let touch = touches.first as? UITouch {
            let location = touch.locationInView(self.view)
            var closestNode: (Int, CGFloat)?
            
            for i in 0 ..< self.tabBarNodes.count {
                let node = self.tabBarNodes[i]
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