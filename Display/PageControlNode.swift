import Foundation
import AsyncDisplayKit

public final class PageControlNode: ASDisplayNode {
    private let dotSize: CGFloat
    private let dotSpacing: CGFloat
    private let dotColor: UIColor
    private var dotNodes: [ASImageNode] = []
    
    private let normalDotImage: UIImage

    public init(dotSize: CGFloat = 7.0, dotSpacing: CGFloat = 9.0, dotColor: UIColor) {
        self.dotSize = dotSize
        self.dotSpacing = dotSpacing
        self.dotColor = dotColor
        self.normalDotImage = generateFilledCircleImage(diameter: dotSize, color: dotColor)!
        
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
                    dotNode.displayWithoutProcessing = true
                    dotNode.isUserInteractionEnabled = false
                    self.dotNodes.append(dotNode)
                    self.addSubnode(dotNode)
                }
            }
        }
    }
    
    public func setPage(_ pageValue: CGFloat) {
        let page = max(0.0, min(CGFloat(self.pagesCount - 1), pageValue))
        
        for i in 0 ..< self.dotNodes.count {
            var alpha: CGFloat = 0.0
            let delta = abs(CGFloat(i) - page)
            if delta >= 1.0 {
                alpha = 0.5
            } else {
                alpha = 1.0 - delta
                alpha *= alpha * alpha
            }
            if alpha < 0.5 {
                alpha = 0.5
            }
            
            self.dotNodes[i].alpha = alpha
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
