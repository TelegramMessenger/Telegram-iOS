import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import Svg

private func generateNumberOffsets() -> [CGPoint] {
    return [
        CGPoint(x: 0.25, y: -0.33),
        CGPoint(x: 0.24749999999999983, y: -0.495),
        CGPoint(x: 0.0, y: -1.4025),
        CGPoint(x: 0.33, y: -0.495),
        CGPoint(x: 0.33, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.49500000000000005, y: 0.0),
        CGPoint(x: 0.66, y: 0.0),
        CGPoint(x: 0.66, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.165, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.66, y: 0.0),
        CGPoint(x: 0.66, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.495, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.49500000000000005, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.66, y: 0.0),
        CGPoint(x: 0.41250000000000003, y: 0.0),
        CGPoint(x: 0.49500000000000005, y: 0.0),
        CGPoint(x: 0.2475, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 1.2375, y: 0.0),
        CGPoint(x: 1.0725, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 1.32, y: 0.0),
        CGPoint(x: 0.9900000000000001, y: 0.0),
        CGPoint(x: 1.5675000000000001, y: 0.0),
        CGPoint(x: 0.9075000000000001, y: 0.0),
        CGPoint(x: 1.155, y: 0.0),
        CGPoint(x: 1.155, y: 0.0),
        CGPoint(x: 0.8250000000000001, y: 0.41250000000000003),
        CGPoint(x: 0.66, y: 1.32),
        CGPoint(x: 0.33, y: 1.32),
        CGPoint(x: 0.41250000000000003, y: 0.41250000000000003),
        CGPoint(x: 0.49500000000000005, y: 0.2475),
        CGPoint(x: 0.41250000000000003, y: 0.33),
        CGPoint(x: 0.5775, y: 0.49500000000000005),
        CGPoint(x: 0.7425, y: 0.9075000000000001),
        CGPoint(x: 0.41250000000000003, y: 0.49500000000000005),
        CGPoint(x: 0.5775, y: 0.5775),
        CGPoint(x: 1.32, y: -0.9075),
        CGPoint(x: 0.49500000000000005, y: -0.41250000000000003),
        CGPoint(x: 0.2475, y: -0.9075),
        CGPoint(x: 0.7425, y: -0.66),
        CGPoint(x: 0.9075000000000001, y: -0.49500000000000005),
        CGPoint(x: 0.66, y: -0.165),
        CGPoint(x: 1.155, y: -0.16499999999999998),
        CGPoint(x: 0.9075000000000001, y: 0.0),
        CGPoint(x: 0.8250000000000001, y: 0.0),
        CGPoint(x: 0.9900000000000001, y: -0.0825),
        CGPoint(x: 0.8250000000000001, y: 0.08249999999999998),
        CGPoint(x: 0.41250000000000003, y: 0.0),
        CGPoint(x: 0.41250000000000003, y: 0.0),
        CGPoint(x: 1.2375, y: 0.0),
        CGPoint(x: 0.9900000000000001, y: 0.0),
        CGPoint(x: 0.9900000000000001, y: 0.0),
        CGPoint(x: 1.0725, y: 0.0),
        CGPoint(x: 0.8250000000000001, y: 0.0),
        CGPoint(x: 0.8250000000000001, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.9075000000000001, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.99, y: 0.0),
        CGPoint(x: 0.41250000000000003, y: 0.0),
        CGPoint(x: 0.66, y: 0.0),
        CGPoint(x: 0.7425, y: 0.0),
        CGPoint(x: 0.9900000000000001, y: 0.0),
        CGPoint(x: 0.66, y: 0.0),
        CGPoint(x: 0.5775, y: 0.0),
        CGPoint(x: 1.2375, y: 0.0),
        CGPoint(x: 0.9900000000000001, y: 0.0),
        CGPoint(x: 1.32, y: 0.0),
        CGPoint(x: 1.155, y: 0.0),
        CGPoint(x: 0.9900000000000001, y: 0.0),
        CGPoint(x: 1.0725, y: 0.0),
        CGPoint(x: 1.2375, y: 0.0),
        CGPoint(x: 0.8250000000000001, y: 0.0),
        CGPoint(x: 1.0725, y: 0.0),
        CGPoint(x: 0.9075000000000001, y: 0.0),
        CGPoint(x: 1.155, y: 0.0),
        CGPoint(x: 0.8250000000000001, y: 0.0),
        CGPoint(x: 1.155, y: 0.0),
        CGPoint(x: 1.0725, y: 0.0),
        CGPoint(x: 1.2375, y: 0.0),
        CGPoint(x: 1.155, y: 0.0),
        CGPoint(x: 1.32, y: 0.0),
    ]
}

let numberOffsets: [CGPoint] = generateNumberOffsets()

public final class PeerInfoRatingComponent: Component {
    let backgroundColor: UIColor
    let borderColor: UIColor
    let foregroundColor: UIColor
    let level: Int
    let action: () -> Void
    let debugLevel: Bool
    
    public init(
        backgroundColor: UIColor,
        borderColor: UIColor,
        foregroundColor: UIColor,
        level: Int,
        action: @escaping () -> Void,
        debugLevel: Bool = false
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.foregroundColor = foregroundColor
        self.level = level
        self.action = action
        self.debugLevel = debugLevel
    }
    
    public static func ==(lhs: PeerInfoRatingComponent, rhs: PeerInfoRatingComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.borderColor != rhs.borderColor {
            return false
        }
        if lhs.foregroundColor != rhs.foregroundColor {
            return false
        }
        if lhs.level != rhs.level {
            return false
        }
        if lhs.debugLevel != rhs.debugLevel {
            return false
        }
        return true
    }
    
    private struct TextLayout {
        var size: CGSize
        var opticalBounds: CGRect
        
        init(size: CGSize, opticalBounds: CGRect) {
            self.size = size
            self.opticalBounds = opticalBounds
        }
    }
    
    public final class View: UIView {
        private let borderLayer: SimpleLayer
        private let backgroundLayer: SimpleLayer
        
        private var debugLevel: Int = 1
        
        private var component: PeerInfoRatingComponent?
        private weak var state: EmptyComponentState?
        
        override public init(frame: CGRect) {
            self.borderLayer = SimpleLayer()
            self.backgroundLayer = SimpleLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.borderLayer)
            self.layer.addSublayer(self.backgroundLayer)
            
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.onTapGesture(_:))))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func onTapGesture(_ recognizer: UITapGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            if case .ended = recognizer.state {
                if component.debugLevel {
                    if self.debugLevel < 10 {
                        self.debugLevel += 1
                    } else {
                        self.debugLevel += 10
                    }
                    if self.debugLevel >= 110 {
                        self.debugLevel = 1
                    }
                    self.state?.updated(transition: .immediate)
                } else {
                    self.component?.action()
                }
            }
        }
        
        func update(component: PeerInfoRatingComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let size = CGSize(width: 30.0, height: 30.0)
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            let level: Int
            if component.debugLevel {
                level = self.debugLevel
            } else {
                level = component.level
            }
            
            let iconSize = CGSize(width: 26.0, height: 26.0)
            
            let alwaysRedraw: Bool = component.debugLevel
            
            if previousComponent?.level != level || previousComponent?.borderColor != component.borderColor || previousComponent?.foregroundColor != component.foregroundColor || previousComponent?.backgroundColor != component.backgroundColor || alwaysRedraw {
                let weight: CGFloat = UIFont.Weight.semibold.rawValue
                let width: CGFloat = -0.1
                
                let descriptor: UIFontDescriptor
                if #available(iOS 14.0, *) {
                    descriptor = UIFont.systemFont(ofSize: 10.0).fontDescriptor
                } else {
                    descriptor = UIFont.systemFont(ofSize: 10.0, weight: UIFont.Weight.semibold).fontDescriptor
                }

                let symbolicTraits = descriptor.symbolicTraits
                var updatedDescriptor: UIFontDescriptor? = descriptor.withSymbolicTraits(symbolicTraits)
                updatedDescriptor = updatedDescriptor?.withDesign(.default)
                if #available(iOS 14.0, *) {
                    updatedDescriptor = updatedDescriptor?.addingAttributes([
                        UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.weight: weight]
                    ])
                }
                if #available(iOS 16.0, *) {
                    updatedDescriptor = updatedDescriptor?.addingAttributes([
                        UIFontDescriptor.AttributeName.traits: [UIFontDescriptor.TraitKey.width: width]
                    ])
                }
                
                let font: UIFont
                if let updatedDescriptor {
                    font = UIFont(descriptor: updatedDescriptor, size: 10.0)
                } else {
                    font = UIFont(descriptor: descriptor, size: 10.0)
                }
                
                let attributedText = NSAttributedString(string: "\(level)", attributes: [
                    NSAttributedString.Key.font: font,
                    NSAttributedString.Key.foregroundColor: component.foregroundColor
                ])
                
                var boundingRect = attributedText.boundingRect(with: CGSize(width: 100.0, height: 100.0), options: .usesLineFragmentOrigin, context: nil)
                boundingRect.size.width = ceil(boundingRect.size.width)
                boundingRect.size.height = ceil(boundingRect.size.height)
                
                var textLayout: TextLayout?
                if let context = DrawingContext(size: boundingRect.size, scale: 0.0, opaque: false, clear: true) {
                    context.withContext { c in
                        UIGraphicsPushContext(c)
                        defer {
                            UIGraphicsPopContext()
                        }
                        
                        attributedText.draw(at: CGPoint())
                    }
                    var minFilledLineY = Int(context.scaledSize.height) - 1
                    var maxFilledLineY = 0
                    var minFilledLineX = Int(context.scaledSize.width) - 1
                    var maxFilledLineX = 0
                    for y in 0 ..< Int(context.scaledSize.height) {
                        let linePtr = context.bytes.advanced(by: max(0, y) * context.bytesPerRow).assumingMemoryBound(to: UInt32.self)
                        
                        for x in 0 ..< Int(context.scaledSize.width) {
                            let pixelPtr = linePtr.advanced(by: x)
                            if pixelPtr.pointee != 0 {
                                minFilledLineY = min(y, minFilledLineY)
                                maxFilledLineY = max(y, maxFilledLineY)
                                minFilledLineX = min(x, minFilledLineX)
                                maxFilledLineX = max(x, maxFilledLineX)
                            }
                        }
                    }
                    
                    var opticalBounds = CGRect()
                    if minFilledLineX <= maxFilledLineX && minFilledLineY <= maxFilledLineY {
                        opticalBounds.origin.x = CGFloat(minFilledLineX) / context.scale
                        opticalBounds.origin.y = CGFloat(minFilledLineY) / context.scale
                        opticalBounds.size.width = CGFloat(maxFilledLineX - minFilledLineX) / context.scale
                        opticalBounds.size.height = CGFloat(maxFilledLineY - minFilledLineY) / context.scale
                    }
                    
                    textLayout = TextLayout(size: boundingRect.size, opticalBounds: opticalBounds)
                }
                
                let levelIndex: Int
                if level < 0 {
                    levelIndex = 1
                } else if level <= 10 {
                    levelIndex = max(1, level)
                } else if level <= 90 {
                    levelIndex = (level / 10) * 10
                } else {
                    levelIndex = 90
                }
                
                let backgroundOffsetsY: [Int: CGFloat] = [
                    3: -0.8250000000000001,
                    7: 0.33,
                    40: 1.0,
                    60: 0.2475,
                    70: 0.33,
                    80: 0.2475,
                ]
                
                let borderImage = generateImage(iconSize, rotatedContext: { size, context in
                    UIGraphicsPushContext(context)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    if level < 0 {
                        return
                    }
                    
                    if let url = Bundle.main.url(forResource: "profile_level\(levelIndex)_outer", withExtension: "svg"), let data = try? Data(contentsOf: url) {
                        if let image = generateTintedImage(image: drawSvgImage(data, size, nil, nil, 0.0, false), color: component.borderColor) {
                            image.draw(in: CGRect(origin: CGPoint(x: 0.0, y: backgroundOffsetsY[levelIndex] ?? 0.0), size: size), blendMode: .normal, alpha: 1.0)
                        }
                    }
                })
                
                if let previousContents = self.borderLayer.contents, CFGetTypeID(previousContents as CFTypeRef) == CGImage.typeID {
                    self.borderLayer.contents = borderImage!.cgImage
                    alphaTransition.animateContentsImage(layer: self.borderLayer, from: previousContents as! CGImage, to: borderImage!.cgImage!, duration: 0.2, curve: .easeInOut)
                } else {
                    self.borderLayer.contents = borderImage!.cgImage
                }
                
                let backgroundImage = generateImage(iconSize, rotatedContext: { size, context in
                    UIGraphicsPushContext(context)
                    defer {
                        UIGraphicsPopContext()
                    }
                    
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    
                    if level < 0 {
                        if let image = generateTintedImage(image: UIImage(bundleImageName: "Peer Info/InlineRatingWarning"), color: component.backgroundColor) {
                            image.draw(in: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) * 0.5), y: floorToScreenPixels((size.height - image.size.height) * 0.5)), size: image.size))
                        }
                        return
                    }
                    
                    if let url = Bundle.main.url(forResource: "profile_level\(levelIndex)_inner", withExtension: "svg"), let data = try? Data(contentsOf: url) {
                        if let image = generateTintedImage(image: drawSvgImage(data, size, nil, nil, 0.0, false), color: component.backgroundColor) {
                            image.draw(in: CGRect(origin: CGPoint(x: 0.0, y: backgroundOffsetsY[levelIndex] ?? 0.0), size: size), blendMode: .normal, alpha: 1.0)
                        }
                    }
                    
                    if component.foregroundColor.alpha < 1.0 {
                        context.setBlendMode(.copy)
                    } else {
                        context.setBlendMode(.normal)
                    }
                    
                    if let textLayout {
                        let titleScale: CGFloat
                        if level < 0 {
                            if abs(level) < 10 {
                                titleScale = 0.8
                            } else if abs(level) < 100 {
                                titleScale = 0.6
                            } else {
                                titleScale = 0.4
                            }
                        } else if level < 10 {
                            titleScale = 1.0
                        } else if level < 100 {
                            titleScale = 0.8
                        } else {
                            titleScale = 0.6
                        }
                        
                        let textFrame = CGRect(origin: CGPoint(x: (size.width - textLayout.size.width) * 0.5, y: (size.height - textLayout.size.height) * 0.5), size: textLayout.size)
                        
                        context.saveGState()
                        context.translateBy(x: textFrame.midX, y: textFrame.midY)
                        context.scaleBy(x: titleScale, y: titleScale)
                        context.translateBy(x: -textFrame.midX, y: -textFrame.midY)
                        
                        var drawPoint: CGPoint
                        drawPoint = textFrame.origin
                        
                        if level >= 1 && level <= 99 {
                            let numberOffset = numberOffsets[level - 1]
                            drawPoint.x += numberOffset.x
                            drawPoint.y += numberOffset.y
                        } else {
                            drawPoint.x += -UIScreenPixel + -textLayout.opticalBounds.minX + (textFrame.width - textLayout.opticalBounds.width) * 0.5
                        }
                        
                        attributedText.draw(at: drawPoint)
                        
                        context.restoreGState()
                    }
                })
                if let previousContents = self.backgroundLayer.contents, CFGetTypeID(previousContents as CFTypeRef) == CGImage.typeID {
                    self.backgroundLayer.contents = backgroundImage!.cgImage
                    alphaTransition.animateContentsImage(layer: self.backgroundLayer, from: previousContents as! CGImage, to: backgroundImage!.cgImage!, duration: 0.2, curve: .easeInOut)
                } else {
                    self.backgroundLayer.contents = backgroundImage!.cgImage
                }
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) * 0.5), y: floorToScreenPixels((size.height - iconSize.height) * 0.5)), size: iconSize)
            transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
            transition.setFrame(layer: self.borderLayer, frame: backgroundFrame)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
