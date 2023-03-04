import Foundation
import UIKit
import Display
import AsyncDisplayKit
import AnimatedStickerNode
import TelegramAnimatedStickerNode

private final class NewRatingStarNode: ASDisplayNode {
    private var wasSelect: Bool = false
    var completion: ((Int) -> ())?
    var index: Int = 0
    private var animationNode: AnimatedStickerNode
    private var animatedSize: CGSize = .zero
    private let starLayer = CAShapeLayer()
    override init() {
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        super.init()

        self.animatedSize = CGSize(width: 100, height: 100)
        layer.addSublayer(starLayer)
        starLayer.fillColor = UIColor.clear.cgColor
        starLayer.strokeColor = UIColor.white.cgColor
        starLayer.lineWidth = 2
       
        addSubnode(animationNode)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(select))
        view.addGestureRecognizer(tapGesture)
    }
    
    func updateLayout() {
        animationNode.frame = CGRect(x: (bounds.width - animatedSize.width) / 2, y: (bounds.height - animatedSize.height) / 2, width: animatedSize.width, height: animatedSize.height)
        starLayer.path = starPathInRect(rect: bounds).cgPath
        starLayer.frame = CGRect(x: (bounds.width - 32) / 2, y: (bounds.width - 32) / 2, width: 32, height: 32)
    }
    
    func animateIn() {
        starLayer.fillColor = UIColor.white.cgColor
        starLayer.animateKeyframes(values: [1, 1.1, 1] as [NSNumber], duration: 0.2, keyPath: "transform.scale", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
    }
    
    func animateSicker(onCompleted: @escaping () -> ()) {
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "AnimatedSticker"), width: Int(animatedSize.width), height: Int(animatedSize.height), playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        animationNode.updateLayout(size: animatedSize)
        animationNode.visibility = true
        animationNode.playOnce()
        animationNode.completed = { _ in
            onCompleted()
        }
    }
    
    @objc func select() {
        guard !wasSelect else {
            return
        }
        completion?(index)
        wasSelect = true
    }
}

final class NewRatingCallNode: ASDisplayNode {
    private let titleTextNode: ASTextNode
    private let infoTextNode: ASTextNode
    private let backgroundLayer: CAShapeLayer
    private var starts: [NewRatingStarNode] = []
    private let buttonContainer: ASDisplayNode
    private var wasSelected: Bool = false
    var onRate: ((Int) -> ())?
    
    override init() {
        self.titleTextNode = ASTextNode()
        self.titleTextNode.displaysAsynchronously = false
        
        self.infoTextNode = ASTextNode()
        self.infoTextNode.displaysAsynchronously = false
        
        self.buttonContainer = ASButtonNode()
        self.buttonContainer.displaysAsynchronously = false
        
        self.backgroundLayer = CAShapeLayer()
        
        super.init()

        titleTextNode.attributedText = NSAttributedString(string: "Rate This Call", font: Font.bold(16), textColor: UIColor.white, paragraphAlignment: .center)
        
        infoTextNode.attributedText = NSAttributedString(string: "Please rate the quality of this call.", font: Font.regular(16), textColor: UIColor.white, paragraphAlignment: .center)
        
        
        layer.addSublayer(backgroundLayer)
        addSubnode(titleTextNode)
        addSubnode(infoTextNode)
        addSubnode(buttonContainer)
        
        for index in 0...4 {
            let star = NewRatingStarNode()
            star.index = index
            star.completion = { [weak self] index in
                self?.animateOnTap(index: index)
            }
            
            starts.append(star)
            addSubnode(star)
        }
    }
    
    func animateOnTap(index: Int) {
        guard !wasSelected else {
            return
        }
        (0...index).forEach { starts[$0].animateIn() }
        if [3,4].contains(index) {
            starts[index].animateSicker { [weak self] in
                self?.onRate?(index+1)
            }
        }
        wasSelected = true
    }

    func updateLayout() {
        backgroundLayer.frame = bounds
        let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: bounds.size), cornerRadius: 14).cgPath
        
        backgroundLayer.path = path
        backgroundLayer.fillColor = UIColor.white.withAlphaComponent(0.25).cgColor
        
        let titleTextSize = titleTextNode.measure(CGSize(width: bounds.width, height: .infinity))
        titleTextNode.frame = CGRect(x: (bounds.width - titleTextSize.width) / 2, y: 20, width: titleTextSize.width, height: titleTextSize.height)
        
        let infoTextSize = infoTextNode.measure(CGSize(width: bounds.width, height: .infinity))
        infoTextNode.frame = CGRect(x: (bounds.width - infoTextSize.width) / 2, y: titleTextNode.frame.maxY + 10, width: infoTextSize.width, height: infoTextSize.height)
        
        let starOffset = 50 * 5 - 8.5
        
        buttonContainer.frame = CGRect(x: (bounds.width - starOffset) / 2, y: infoTextNode.frame.maxY + 15.25, width: starOffset, height: 42)
        
        var prevStarOffset = buttonContainer.frame.minX
        
        for star in starts {
            star.frame = CGRect(x: prevStarOffset, y: infoTextNode.frame.maxY + 15.25, width: 42, height: 42)
            star.updateLayout()
            prevStarOffset += star.bounds.width + 8.5
        }
        
        setNeedsDisplay()
    }
}

private func starPathInRect(rect: CGRect) -> UIBezierPath {
    let shape = UIBezierPath()
    shape.move(to: CGPoint(x: 14.13, y: 25.39))
    shape.addCurve(to: CGPoint(x: 15.14, y: 24.88), controlPoint1: CGPoint(x: 14.63, y: 25.09), controlPoint2: CGPoint(x: 14.88, y: 24.94))
    shape.addCurve(to: CGPoint(x: 15.86, y: 24.88), controlPoint1: CGPoint(x: 15.38, y: 24.83), controlPoint2: CGPoint(x: 15.62, y: 24.83))
    shape.addCurve(to: CGPoint(x: 16.87, y: 25.39), controlPoint1: CGPoint(x: 16.12, y: 24.94), controlPoint2: CGPoint(x: 16.37, y: 25.09))
    shape.addLine(to: CGPoint(x: 20.39, y: 27.51))
    shape.addCurve(to: CGPoint(x: 23.53, y: 28.94), controlPoint1: CGPoint(x: 22.08, y: 28.53), controlPoint2: CGPoint(x: 22.93, y: 29.04))
    shape.addCurve(to: CGPoint(x: 24.74, y: 28.06), controlPoint1: CGPoint(x: 24.05, y: 28.85), controlPoint2: CGPoint(x: 24.5, y: 28.53))
    shape.addCurve(to: CGPoint(x: 24.34, y: 24.63), controlPoint1: CGPoint(x: 25.02, y: 27.52), controlPoint2: CGPoint(x: 24.79, y: 26.55))
    shape.addLine(to: CGPoint(x: 23.41, y: 20.66))
    shape.addCurve(to: CGPoint(x: 23.24, y: 19.53), controlPoint1: CGPoint(x: 23.28, y: 20.09), controlPoint2: CGPoint(x: 23.21, y: 19.81))
    shape.addCurve(to: CGPoint(x: 23.46, y: 18.85), controlPoint1: CGPoint(x: 23.26, y: 19.29), controlPoint2: CGPoint(x: 23.34, y: 19.06))
    shape.addCurve(to: CGPoint(x: 24.26, y: 18.04), controlPoint1: CGPoint(x: 23.6, y: 18.62), controlPoint2: CGPoint(x: 23.82, y: 18.43))
    shape.addLine(to: CGPoint(x: 27.35, y: 15.38))
    shape.addCurve(to: CGPoint(x: 29.7, y: 12.83), controlPoint1: CGPoint(x: 28.85, y: 14.08), controlPoint2: CGPoint(x: 29.6, y: 13.43))
    shape.addCurve(to: CGPoint(x: 29.23, y: 11.4), controlPoint1: CGPoint(x: 29.78, y: 12.31), controlPoint2: CGPoint(x: 29.61, y: 11.78))
    shape.addCurve(to: CGPoint(x: 25.84, y: 10.72), controlPoint1: CGPoint(x: 28.8, y: 10.97), controlPoint2: CGPoint(x: 27.81, y: 10.89))
    shape.addLine(to: CGPoint(x: 21.77, y: 10.38))
    shape.addCurve(to: CGPoint(x: 20.65, y: 10.19), controlPoint1: CGPoint(x: 21.19, y: 10.33), controlPoint2: CGPoint(x: 20.9, y: 10.3))
    shape.addCurve(to: CGPoint(x: 20.07, y: 9.78), controlPoint1: CGPoint(x: 20.43, y: 10.1), controlPoint2: CGPoint(x: 20.23, y: 9.96))
    shape.addCurve(to: CGPoint(x: 19.55, y: 8.77), controlPoint1: CGPoint(x: 19.89, y: 9.57), controlPoint2: CGPoint(x: 19.77, y: 9.3))
    shape.addLine(to: CGPoint(x: 17.94, y: 5))
    shape.addCurve(to: CGPoint(x: 16.25, y: 2.01), controlPoint1: CGPoint(x: 17.18, y: 3.19), controlPoint2: CGPoint(x: 16.79, y: 2.29))
    shape.addCurve(to: CGPoint(x: 14.75, y: 2.01), controlPoint1: CGPoint(x: 15.78, y: 1.77), controlPoint2: CGPoint(x: 15.22, y: 1.77))
    shape.addCurve(to: CGPoint(x: 13.06, y: 5), controlPoint1: CGPoint(x: 14.21, y: 2.29), controlPoint2: CGPoint(x: 13.83, y: 3.19))
    shape.addLine(to: CGPoint(x: 11.45, y: 8.77))
    shape.addCurve(to: CGPoint(x: 10.93, y: 9.78), controlPoint1: CGPoint(x: 11.23, y: 9.3), controlPoint2: CGPoint(x: 11.11, y: 9.57))
    shape.addCurve(to: CGPoint(x: 10.35, y: 10.19), controlPoint1: CGPoint(x: 10.77, y: 9.96), controlPoint2: CGPoint(x: 10.57, y: 10.1))
    shape.addCurve(to: CGPoint(x: 9.23, y: 10.38), controlPoint1: CGPoint(x: 10.1, y: 10.3), controlPoint2: CGPoint(x: 9.81, y: 10.33))
    shape.addLine(to: CGPoint(x: 5.16, y: 10.72))
    shape.addCurve(to: CGPoint(x: 1.77, y: 11.4), controlPoint1: CGPoint(x: 3.19, y: 10.89), controlPoint2: CGPoint(x: 2.2, y: 10.97))
    shape.addCurve(to: CGPoint(x: 1.3, y: 12.83), controlPoint1: CGPoint(x: 1.39, y: 11.78), controlPoint2: CGPoint(x: 1.22, y: 12.31))
    shape.addCurve(to: CGPoint(x: 3.65, y: 15.38), controlPoint1: CGPoint(x: 1.4, y: 13.43), controlPoint2: CGPoint(x: 2.15, y: 14.08))
    shape.addLine(to: CGPoint(x: 6.74, y: 18.04))
    shape.addCurve(to: CGPoint(x: 7.54, y: 18.85), controlPoint1: CGPoint(x: 7.18, y: 18.43), controlPoint2: CGPoint(x: 7.4, y: 18.62))
    shape.addCurve(to: CGPoint(x: 7.76, y: 19.53), controlPoint1: CGPoint(x: 7.66, y: 19.06), controlPoint2: CGPoint(x: 7.74, y: 19.29))
    shape.addCurve(to: CGPoint(x: 7.59, y: 20.66), controlPoint1: CGPoint(x: 7.79, y: 19.81), controlPoint2: CGPoint(x: 7.72, y: 20.09))
    shape.addLine(to: CGPoint(x: 6.66, y: 24.63))
    shape.addCurve(to: CGPoint(x: 6.26, y: 28.06), controlPoint1: CGPoint(x: 6.21, y: 26.55), controlPoint2: CGPoint(x: 5.98, y: 27.52))
    shape.addCurve(to: CGPoint(x: 7.47, y: 28.94), controlPoint1: CGPoint(x: 6.5, y: 28.53), controlPoint2: CGPoint(x: 6.95, y: 28.85))
    shape.addCurve(to: CGPoint(x: 10.61, y: 27.51), controlPoint1: CGPoint(x: 8.07, y: 29.04), controlPoint2: CGPoint(x: 8.92, y: 28.53))
    shape.addLine(to: CGPoint(x: 14.13, y: 25.39))
    shape.close()
    
    return shape
}
