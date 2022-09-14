import Foundation
import UIKit
import AsyncDisplayKit
import Display

public struct AuthorizationLayoutItemSpacing {
    public var weight: CGFloat
    public var maxValue: CGFloat
    
    public init(weight: CGFloat, maxValue: CGFloat) {
        self.weight = weight
        self.maxValue = maxValue
    }
}

public struct AuthorizationLayoutItem {
    public var node: ASDisplayNode?
    public var view: UIView?
    public var size: CGSize
    public var spacingBefore: AuthorizationLayoutItemSpacing
    public var spacingAfter: AuthorizationLayoutItemSpacing
    
    public init(node: ASDisplayNode, size: CGSize, spacingBefore: AuthorizationLayoutItemSpacing, spacingAfter: AuthorizationLayoutItemSpacing) {
        self.node = node
        self.size = size
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
    }


    public init(view: UIView, size: CGSize, spacingBefore: AuthorizationLayoutItemSpacing, spacingAfter: AuthorizationLayoutItemSpacing) {
        self.view = view
        self.size = size
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
    }
}

public final class SolvedAuthorizationLayoutItem {
    public let item: AuthorizationLayoutItem
    public var spacingBefore: CGFloat?
    public var spacingAfter: CGFloat?
    
    public init(item: AuthorizationLayoutItem) {
        self.item = item
    }
}

public func layoutAuthorizationItems(bounds: CGRect, items: [AuthorizationLayoutItem], transition: ContainedViewLayoutTransition, failIfDoesNotFit: Bool) -> Bool {
    var fixedHeight: CGFloat = 0.0
    var totalSpacerWeight: CGFloat = 0.0
    for item in items {
        fixedHeight += item.size.height
        totalSpacerWeight += item.spacingBefore.weight
        totalSpacerWeight += item.spacingAfter.weight
    }
    
    let solvedItems = items.map(SolvedAuthorizationLayoutItem.init)
    
    if failIfDoesNotFit && bounds.size.height - fixedHeight < 0.0 {
        return false
    }
    
    var remainingSpacersHeight = max(0.0, bounds.size.height - fixedHeight)
    
    for i in 0 ..< 3 {
        if i == 0 || i == 2 {
            while true {
                var hasUnsolvedItems = false
                
                for item in solvedItems {
                    if item.spacingBefore == nil {
                        hasUnsolvedItems = true
                        if item.item.spacingBefore.maxValue.isZero {
                            item.spacingBefore = 0.0
                        } else {
                            item.spacingBefore = floor(item.item.spacingBefore.weight * remainingSpacersHeight / totalSpacerWeight)
                        }
                    }
                    
                    if item.spacingAfter == nil {
                        hasUnsolvedItems = true
                        if item.item.spacingAfter.maxValue.isZero {
                            item.spacingAfter = 0.0
                        } else {
                            item.spacingAfter = floor(item.item.spacingAfter.weight * remainingSpacersHeight / totalSpacerWeight)
                        }
                    }
                }
                
                if !hasUnsolvedItems {
                    break
                }
            }
        } else {
            var updated = false
            for item in solvedItems {
                if !item.item.spacingBefore.maxValue.isZero {
                    if item.spacingBefore! > item.item.spacingBefore.maxValue {
                        updated = true
                    }
                }
                if !item.item.spacingAfter.maxValue.isZero {
                    if item.spacingAfter! > item.item.spacingAfter.maxValue {
                        updated = true
                    }
                }
            }
            
            if updated {
                for item in solvedItems {
                    if !item.item.spacingBefore.maxValue.isZero {
                        if item.spacingBefore! > item.item.spacingBefore.maxValue {
                            item.spacingBefore = item.item.spacingBefore.maxValue
                        } else {
                            item.spacingBefore = nil
                        }
                    }
                    if !item.item.spacingAfter.maxValue.isZero {
                        if item.spacingAfter! > item.item.spacingAfter.maxValue {
                            item.spacingAfter = item.item.spacingAfter.maxValue
                        } else {
                            item.spacingAfter = nil
                        }
                    }
                }
                
                fixedHeight = 0.0
                totalSpacerWeight = 0.0
                
                for item in solvedItems {
                    fixedHeight += item.item.size.height
                    if let spacingBefore = item.spacingBefore {
                        fixedHeight += spacingBefore
                    } else if !item.item.spacingBefore.maxValue.isZero {
                        totalSpacerWeight += item.item.spacingBefore.weight
                    }
                    if let spacingAfter = item.spacingAfter {
                        fixedHeight += spacingAfter
                    } else if !item.item.spacingAfter.maxValue.isZero {
                        totalSpacerWeight += item.item.spacingAfter.weight
                    }
                }
                
                remainingSpacersHeight = max(0.0, bounds.size.height - fixedHeight)
            }
        }
    }
    
    var totalHeight: CGFloat = 0.0
    for item in solvedItems {
        totalHeight += item.spacingBefore! + item.spacingAfter! + item.item.size.height
    }
    
    var verticalOrigin: CGFloat = bounds.minY + floor((bounds.size.height - totalHeight) / 2.0)
    for i in 0 ..< solvedItems.count {
        let item = solvedItems[i]
        verticalOrigin += item.spacingBefore!
        let itemFrame = CGRect(origin: CGPoint(x: floor((bounds.size.width - item.item.size.width) / 2.0), y: verticalOrigin), size: item.item.size)
        if let view = item.item.view {
            transition.updateFrame(view: view, frame: itemFrame)
        } else if let node = item.item.node {
            transition.updateFrame(node: node, frame: itemFrame)
        }
        verticalOrigin += item.item.size.height
        verticalOrigin += item.spacingAfter!
    }
    
    return true
}
