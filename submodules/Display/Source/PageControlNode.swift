import Foundation
import UIKit
import AsyncDisplayKit

public final class PageControlNode: ASDisplayNode {
    private let dotSize: CGFloat
    private let dotSpacing: CGFloat
    public var dotColor: UIColor {
        didSet {
            if !oldValue.isEqual(self.dotColor) {
                let oldImage = self.normalDotImage
                self.normalDotImage = generateFilledCircleImage(diameter: dotSize, color: self.dotColor)!
                for dotNode in self.dotNodes {
                    if dotNode.image === oldImage {
                        dotNode.image = self.normalDotImage
                    }
                }
            }
        }
    }
    public var inactiveDotColor: UIColor {
        didSet {
            if !oldValue.isEqual(self.inactiveDotColor) {
                let oldImage = self.inactiveDotImage
                self.inactiveDotImage = generateFilledCircleImage(diameter: dotSize, color: self.inactiveDotColor)!
                for dotNode in self.dotNodes {
                    if dotNode.image === oldImage {
                        dotNode.image = self.inactiveDotImage
                    }
                }
            }
        }
    }
    private var dotNodes: [ASImageNode] = []
    
    private var normalDotImage: UIImage
    private var inactiveDotImage: UIImage

    public init(dotSize: CGFloat = 7.0, dotSpacing: CGFloat = 9.0, dotColor: UIColor, inactiveDotColor: UIColor) {
        self.dotSize = dotSize
        self.dotSpacing = dotSpacing
        self.dotColor = dotColor
        self.inactiveDotColor = inactiveDotColor
        self.normalDotImage = generateFilledCircleImage(diameter: dotSize, color: dotColor)!
        self.inactiveDotImage = generateFilledCircleImage(diameter: dotSize, color: inactiveDotColor)!
        
        super.init()
    }

    public var pagesCount: Int = 0 {
        didSet {
            if self.pagesCount != oldValue {
                while self.dotNodes.count > self.pagesCount {
                    self.dotNodes[self.dotNodes.count - 1].removeFromSupernode()
                    self.dotNodes.removeLast()
                }
                while self.dotNodes.count < self.pagesCount {
                    let dotNode = ASImageNode()
                    dotNode.image = self.normalDotImage
                    dotNode.displaysAsynchronously = false
                    dotNode.isUserInteractionEnabled = false
                    self.dotNodes.append(dotNode)
                    self.addSubnode(dotNode)
                }
            }
        }
    }
    
    public func setPage(_ pageValue: CGFloat) {
        let page = Int(round(pageValue))
        
        for i in 0 ..< self.dotNodes.count {
            if i != page {
                self.dotNodes[i].image = self.inactiveDotImage
            } else {
                self.dotNodes[i].image = self.normalDotImage
            }
        }
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: self.dotSize * CGFloat(self.pagesCount) + self.dotSpacing * max(CGFloat(self.pagesCount - 1), 0.0), height: self.dotSize)
    }
    
    override public func layout() {
        super.layout()
        
        let dotSize = CGSize(width: self.dotSize, height: self.dotSize)
        
        let nominalWidth = self.dotSize * CGFloat(self.pagesCount) + self.dotSpacing * max(CGFloat(self.pagesCount - 1), 0.0)

        let startX = floor((self.bounds.size.width - nominalWidth) / 2)
        
        for i in 0 ..< self.dotNodes.count {
            self.dotNodes[i].frame = CGRect(origin: CGPoint(x: startX + CGFloat(i) * (dotSize.width + self.dotSpacing), y: 0.0), size: dotSize)
        }
    }
}
