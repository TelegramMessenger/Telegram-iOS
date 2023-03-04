import Foundation
import UIKit
import Display
import AsyncDisplayKit

final class NewHintNode: ASDisplayNode {

    private let triangleLayer: CAShapeLayer
    private let imageNode: ASImageNode
    private let textNode: ASTextNode
    private let triangleWidth: Double = 19
    private let triangleHeight: Double = 7.5
    
    private let insets: CGFloat = 16
    private let betweenImageTextInsets: CGFloat = 6
    
    private let imageWidth: CGFloat = 10
    private let imageHeight: CGFloat = 20
    private let backgroundLayer: CAShapeLayer
    
    private let imageSize = CGSize(width: 9, height: 9)
     override init() {
         imageNode = ASImageNode()
         imageNode.displaysAsynchronously = false
         
         textNode = ASTextNode()
         textNode.displaysAsynchronously = false
         
         triangleLayer = CAShapeLayer()
         backgroundLayer = CAShapeLayer()
        super.init()
         
         layer.addSublayer(backgroundLayer)
         layer.addSublayer(triangleLayer)
        addSubnode(imageNode)
        addSubnode(textNode)
         let image = UIImage(bundleImageName: "Chat/Stickers/Lock")
         
         imageNode.image = generateTintedImage(image: UIGraphicsImageRenderer(size: imageSize).image { _ in
             image?.draw(in: CGRect(origin: .zero, size: imageSize))
         }, color: .white)
         
        textNode.attributedText = NSAttributedString(string: "Encryption key of this call", font: Font.regular(15), textColor: UIColor.white, paragraphAlignment: .center)
        textNode.textAlignment = .center
         
    }
    
    func updateLayout(hasVideo: Bool) {
        let bgColor = hasVideo ? UIColor.black.withAlphaComponent(0.5).cgColor : UIColor.white.withAlphaComponent(0.25).cgColor
        backgroundLayer.fillColor = bgColor
        triangleLayer.fillColor = bgColor
        let roundPath = UIBezierPath(roundedRect: CGRect(origin: .zero, size: bounds.size), cornerRadius: 14)
        
        self.backgroundLayer.path = roundPath.cgPath
        self.backgroundLayer.frame = bounds
        
        let textSize = textNode.measure(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        let textNodeSize = textNode.updateLayout(textSize)

        triangleLayer.frame = CGRect(x: bounds.width * 0.76,
                                    y: -triangleHeight,
                                    width: triangleWidth,
                                    height: triangleHeight)
            
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: triangleHeight))
        path.addLine(to: CGPoint(x: triangleWidth, y: triangleHeight))
        path.addLine(to: CGPoint(x: triangleWidth / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: triangleHeight))
        path.close()
        
        triangleLayer.path = path.cgPath
        

        imageNode.frame = CGRect(x: insets, y: (bounds.height - 19) / 2, width: 19, height: 19)
        textNode.frame = CGRect(x: imageNode.frame.maxY + betweenImageTextInsets,
                                y: (bounds.height - textSize.height) / 2,
                                width: textNodeSize.width,
                                height: textNodeSize.height)
    }
    
    
}
