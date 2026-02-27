import Foundation
import UIKit
import Display
import AsyncDisplayKit

public class CompositeTextNode: ASDisplayNode {
    public enum Component: Equatable {
        case text(NSAttributedString)
        case icon(UIImage)
    }
    
    public var components: [Component] = []
    
    private var textNodes: [Int: ImmediateTextNode] = [:]
    private var iconViews: [Int: UIImageView] = [:]
    
    public var imageTintColor: UIColor? {
        didSet {
            for (_, textNode) in self.textNodes {
                textNode.layer.layerTintColor = self.imageTintColor?.cgColor
            }
            for (_, iconView) in self.iconViews {
                iconView.tintColor = self.imageTintColor
            }
        }
    }
    
    public func update(constrainedSize: CGSize) -> CGSize {
        var validTextIds: [Int] = []
        var validIconIds: [Int] = []
        
        var size = CGSize()
        
        var nextTextId = 0
        var nextIconId = 0
        for component in self.components {
            switch component {
            case let .text(text):
                let id = nextTextId
                nextTextId += 1
                validTextIds.append(id)
                
                let textNode: ImmediateTextNode
                if let current = self.textNodes[id] {
                    textNode = current
                } else {
                    textNode = ImmediateTextNode()
                    textNode.maximumNumberOfLines = 1
                    textNode.insets = UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0)
                    textNode.layer.layerTintColor = self.imageTintColor?.cgColor
                    self.textNodes[id] = textNode
                    self.addSubnode(textNode)
                }
                textNode.attributedText = text
                
                let textSize = textNode.updateLayout(CGSize(width: max(1.0, constrainedSize.width - size.width), height: constrainedSize.height))
                
                textNode.frame = CGRect(origin: CGPoint(x: size.width - textNode.insets.left, y: -textNode.insets.top), size: textSize)
                size.width += textSize.width - textNode.insets.left - textNode.insets.right
                size.height = max(size.height, textSize.height - textNode.insets.top - textNode.insets.bottom)
            case let .icon(icon):
                let id = nextIconId
                nextIconId += 1
                validIconIds.append(id)
                
                let iconView: UIImageView
                if let current = self.iconViews[id] {
                    iconView = current
                } else {
                    iconView = UIImageView()
                    self.iconViews[id] = iconView
                    self.view.addSubview(iconView)
                }
                iconView.image = icon
                iconView.tintColor = self.imageTintColor
                
                let iconSize = icon.size
                if size.width != 0.0 {
                    size.width += 3.0
                }
                iconView.frame = CGRect(origin: CGPoint(x: size.width, y: 3.0 + UIScreenPixel), size: iconSize)
                size.width += iconSize.width
                size.width += 3.0
                size.height = max(size.height, iconSize.height)
            }
            
            if size.width >= constrainedSize.width {
                size.width = constrainedSize.width
                break
            }
        }
        
        var removeTextIds: [Int] = []
        for (id, textNode) in self.textNodes {
            if !validTextIds.contains(id) {
                textNode.removeFromSupernode()
                removeTextIds.append(id)
            }
        }
        for id in removeTextIds {
            self.textNodes.removeValue(forKey: id)
        }
        
        var removeIconIds: [Int] = []
        for (id, iconView) in self.iconViews {
            if !validIconIds.contains(id) {
                iconView.removeFromSuperview()
                removeIconIds.append(id)
            }
        }
        for id in removeIconIds {
            self.iconViews.removeValue(forKey: id)
        }
        
        return size
    }
}
