import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AppBundle
import SemanticStatusNode
import AnimationUI

private let labelFont = Font.regular(13.0)

final class NewCallControllerButtonItemNode: HighlightTrackingButtonNode {
    struct Content: Equatable {
        enum Appearance: Equatable {
            enum Color: Equatable {
                case red
                case green
                case custom(UInt32, CGFloat)
            }
            
            case blurred(isFilled: Bool)
            case color(Color)
            
            var isFilled: Bool {
                if case let .blurred(isFilled) = self {
                    return isFilled
                } else {
                    return false
                }
            }
        }
        
        enum Image {
            case cameraOff
            case cameraOn
            case camera
            case mute
            case flipCamera
            case bluetooth
            case speaker
            case airpods
            case airpodsPro
            case airpodsMax
            case headphones
            case accept
            case end
            case cancel
            case share
            case screencast
        }
        
        var appearance: Appearance
        var image: Image
        var isEnabled: Bool
        var hasProgress: Bool
        
        init(appearance: Appearance, image: Image, isEnabled: Bool = true, hasProgress: Bool = false) {
            self.appearance = appearance
            self.image = image
            self.isEnabled = isEnabled
            self.hasProgress = hasProgress
        }
    }
    
    let foregroundLayer: CALayer
    let foregroundMaskLayer: CAShapeLayer
    let backgroundLayer: CALayer
    let backgroundMaskLayer: CAShapeLayer
    
    private let wrapperNode: ASDisplayNode
    private let contentContainer: ASDisplayNode
    private let effectView: UIVisualEffectView
    private let imageLayer: CAShapeLayer
    private var animationNode: AnimationNode?
    private let overlayHighlightNode: ASImageNode
    private var statusNode: SemanticStatusNode?
    let textNode: ImmediateTextNode
    
    private let largeButtonSize: CGFloat
    
    private var size: CGSize?
    private(set) var currentContent: Content?
    private(set) var currentText: String = ""
    var displayLink: CADisplayLink?
    
    init() {
        self.largeButtonSize = 55
        
        self.wrapperNode = ASDisplayNode()
        self.contentContainer = ASDisplayNode()
        
        self.effectView = UIVisualEffectView()
        self.effectView.effect = UIBlurEffect(style: .light)
        self.effectView.layer.cornerRadius = self.largeButtonSize / 2.0
        self.effectView.clipsToBounds = true
        self.effectView.isUserInteractionEnabled = false
        
        self.overlayHighlightNode = ASImageNode()
        self.overlayHighlightNode.isUserInteractionEnabled = false
        self.overlayHighlightNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        imageLayer = CAShapeLayer()
        foregroundLayer = CALayer()
        foregroundMaskLayer = CAShapeLayer()
        backgroundLayer = CALayer()
        backgroundMaskLayer = CAShapeLayer()
        
        super.init(pointerStyle: nil)
        
        view.addSubview(self.effectView)
//        layer.addSublayer(imageLayer)
        
        layer.addSublayer(backgroundLayer)
        layer.addSublayer(foregroundLayer)
        addSubnode(self.textNode)
        addSubnode(self.overlayHighlightNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.overlayHighlightNode.alpha = 1.0
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.3, curve: .spring)
                transition.updateSublayerTransformScale(node: strongSelf, scale: 0.9)
            } else {
                strongSelf.overlayHighlightNode.alpha = 0.0
                strongSelf.overlayHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                let transition: ContainedViewLayoutTransition = .animated(duration: 0.5, curve: .spring)
                transition.updateSublayerTransformScale(node: strongSelf, scale: 1.0)
            }
        }
    }
    
    override func layout() {
        super.layout()
        self.wrapperNode.frame = self.bounds
    }
    private var isInitialParams = true

    func update(size: CGSize, content: Content, text: String, transition: ContainedViewLayoutTransition) {
        
        let scaleFactor = size.width / self.largeButtonSize
        
        let isSmall = self.largeButtonSize > size.width
        backgroundLayer.frame = bounds
        backgroundMaskLayer.frame = bounds
        foregroundMaskLayer.frame = bounds
        self.effectView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        imageLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))

        self.backgroundLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        self.foregroundLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        self.overlayHighlightNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        
        if self.currentContent != content || self.size != size {
            self.currentContent = content
            self.size = size
            
            switch content.appearance {
            case .blurred:
                self.effectView.isHidden = false
            case .color:
                self.effectView.isHidden = true
            }
            
            transition.updateAlpha(node: self.wrapperNode, alpha: content.isEnabled ? 1.0 : 0.4)
            self.wrapperNode.isUserInteractionEnabled = content.isEnabled
            
            let image = generateImage(content: content)
            
            foregroundLayer.contents = image?.cgImage
        }
        
        transition.updateSublayerTransformScale(node: self.contentContainer, scale: scaleFactor)
        if let animationNode = self.animationNode {
            transition.updateTransformScale(node: animationNode, scale: isSmall ? 1.35 : 1.12)
        }
        
        if self.currentText != text {
            self.textNode.attributedText = NSAttributedString(string: text, font: labelFont, textColor: .white)
        }
        let textSize = self.textNode.updateLayout(CGSize(width: 150.0, height: 100.0))
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: size.height + (isSmall ? 5.0 : 8.0)), size: textSize)
        if self.currentText.isEmpty {
            self.textNode.frame = textFrame
            if transition.isAnimated {
                self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            }
        } else {
            transition.updateFrameAdditiveToCenter(node: self.textNode, frame: textFrame)
        }
        self.currentText = text
        
        isInitialParams = false
    }
    
    var percent = 0.0
    @objc
    private func counter() {
        guard percent <= 1.0 else {
            stopDisplayLink()
            return
        }
        
        
    }
    
    func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(counter))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func generateImage(content: Content) -> UIImage? {
        return Display.generateImage(CGSize(width: self.largeButtonSize, height: self.largeButtonSize), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            var ellipseRect = CGRect(origin: CGPoint(), size: size)
            var fillColor: UIColor = .clear
            let imageColor: UIColor = .white
            var drawOverMask = false
            context.setBlendMode(.normal)
            let imageScale: CGFloat = 1.0
            switch content.appearance {
            case let .blurred(isFilled):
                if content.hasProgress {
                    fillColor = .white
                    drawOverMask = true
                    context.setBlendMode(.copy)
                    ellipseRect = ellipseRect.insetBy(dx: 7.0, dy: 7.0)
                } else {
                    if isFilled {
                        fillColor = .white
                        drawOverMask = true
                        context.setBlendMode(.copy)
                    }
                }
            case let .color(color):
                switch color {
                case .red:
                    fillColor = UIColor(hexString: "FF3B30")!
                case .green:
                    fillColor = UIColor(rgb: 0x74db58)
                case let .custom(color, alpha):
                    fillColor = UIColor(rgb: color, alpha: alpha)
                }
            }
            
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: ellipseRect)
            
            var image: UIImage?
            
            switch content.image {
            case .cameraOff, .cameraOn:
                image = nil
            case .camera:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/video"), color: imageColor)
            case .mute:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/mute"), color: imageColor)
            case .flipCamera:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/flip"), color: imageColor)
            case .bluetooth:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/bluetooth"), color: imageColor)
            case .speaker:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/speaker"), color: imageColor)
            case .airpods:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/airpods"), color: imageColor)
            case .airpodsPro:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/airpodspro"), color: imageColor)
            case .airpodsMax:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/airpodspromax"), color: imageColor)
            case .headphones:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallHeadphonesButton"), color: imageColor)
            case .accept:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallAcceptButton"), color: imageColor)
            case .end:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/end"), color: imageColor)
            case .cancel:
                image = Display.generateImage(CGSize(width: 28.0, height: 28.0), opaque: false, rotatedContext: { size, context in
                    let bounds = CGRect(origin: CGPoint(), size: size)
                    context.clear(bounds)
                    
                    context.setLineWidth(4.0 - UIScreenPixel)
                    context.setLineCap(.round)
                    context.setStrokeColor(imageColor.cgColor)
                    
                    context.move(to: CGPoint(x: 2.0 + UIScreenPixel, y: 2.0 + UIScreenPixel))
                    context.addLine(to: CGPoint(x: 26.0 - UIScreenPixel, y: 26.0 - UIScreenPixel))
                    context.strokePath()
                    
                    context.move(to: CGPoint(x: 26.0 - UIScreenPixel, y: 2.0 + UIScreenPixel))
                    context.addLine(to: CGPoint(x: 2.0 + UIScreenPixel, y: 26.0 - UIScreenPixel))
                    context.strokePath()
                })
            case .share:
                image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallShareButton"), color: imageColor)
            case .screencast:
                if let iconImage = generateTintedImage(image: UIImage(bundleImageName: "Call/ScreenSharePhone"), color: imageColor) {
                    image = generateScaledImage(image: iconImage, size: iconImage.size.aspectFitted(CGSize(width: 38.0, height: 38.0)))
                }
            }
            
            if let image = image {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: imageScale, y: imageScale)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                
                let imageRect = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
                if drawOverMask {
                    context.clip(to: imageRect, mask: image.cgImage!)
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    context.fill(CGRect(origin: CGPoint(), size: size))
                } else {
                    context.draw(image.cgImage!, in: imageRect)
                }
            }
        })
    }
}


