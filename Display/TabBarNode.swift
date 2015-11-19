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
    
    image?.drawAtPoint(CGPoint(x: floorToScreenPixels((size.width - imageSize.width) / 2.0), y: 0.0))
    
    (title as NSString).drawAtPoint(CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - 3.0), withAttributes: [NSFontAttributeName: font])
    
    CGContextSetBlendMode(context, .SourceIn)
    CGContextSetFillColorWithColor(context, tintColor.CGColor)
    //CGContextFillRect(context, CGRect(origin: CGPoint(), size: size))
    
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return image
}

class TabBarNode: ASDisplayNode {
    let separatorNode: ASDisplayNode
    
    var tabBarNodes: [ASImageNode] = []
    
    var tabBarItems: [UITabBarItem] = [] {
        didSet {
            self.reloadTabBarItems()
        }
    }
    
    override init() {
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
        for item in self.tabBarItems {
            let node = ASImageNode()
            node.displaysAsynchronously = false
            node.displayWithoutProcessing = true
            node.layerBacked = true
            node.image = tabBarItemImage(item.image, title: item.title ?? "", tintColor: UIColor.blueColor())
            tabBarNodes.append(node)
            self.addSubnode(node)
        }
        
        self.tabBarNodes = tabBarNodes
        
        self.setNeedsLayout()
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
}