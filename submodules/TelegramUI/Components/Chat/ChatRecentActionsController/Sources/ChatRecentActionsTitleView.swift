import Foundation
import UIKit
import AsyncDisplayKit
import Display

private func generateArrowImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 8.0, height: 5.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.beginPath()
        context.move(to: CGPoint())
        context.addLine(to: CGPoint(x: size.width, y: 0.0))
        context.addLine(to: CGPoint(x: size.width / 2.0, y: size.height))
        context.closePath()
        context.fillPath()
    })
}

final class ChatRecentActionsTitleView: UIView {
    private let button: HighlightTrackingButtonNode
    private let titleNode: TextNode
    private let arrowNode: ASImageNode
    
    var color: UIColor {
        didSet {
            if self.color != oldValue {
                self.setNeedsLayout()
            }
        }
    }
    
    var pressed: (() -> Void)?
    
    var title: String = "" {
        didSet {
            if self.title != oldValue {
                self.setNeedsLayout()
            }
        }
    }
    
    init(color: UIColor) {
        self.color = color
        
        self.button = HighlightTrackingButtonNode()
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.arrowNode = ASImageNode()
        self.arrowNode.isLayerBacked = true
        self.arrowNode.displaysAsynchronously = false
        self.arrowNode.displayWithoutProcessing = true
        self.arrowNode.image = generateArrowImage(color: color)
        
        super.init(frame: CGRect())
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.arrowNode)
        self.addSubnode(self.button)
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: [.touchUpInside])
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.arrowNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.arrowNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.arrowNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.arrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        let makeLayout = TextNode.asyncLayout(self.titleNode)
        let (titleLayout, titleApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.title, font: Font.semibold(17.0), textColor: self.color), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: size, alignment: .center, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleLayout.size.width) / 2.0), y: floor((size.height - titleLayout.size.height) / 2.0)), size: titleLayout.size)
        self.titleNode.frame = titleFrame
        let _ = titleApply()
        
        if let image = self.arrowNode.image {
            self.arrowNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + 3.0, y: titleFrame.minY + 9.0), size: image.size)
        }
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
}
