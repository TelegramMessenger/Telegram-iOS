import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AppBundle
import SemanticStatusNode
import AnimationUI

private let labelFont = Font.regular(13.0)

final class CallControllerButtonItemNode: HighlightTrackingButtonNode {
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
    
    private let wrapperNode: ASDisplayNode
    private let contentContainer: ASDisplayNode
    private let effectView: UIVisualEffectView
    private let contentBackgroundNode: ASImageNode
    private let contentNode: ASImageNode
    private var animationNode: AnimationNode?
    private let overlayHighlightNode: ASImageNode
    private var statusNode: SemanticStatusNode?
    let textNode: ImmediateTextNode
    
    private let largeButtonSize: CGFloat
    
    private var size: CGSize?
    private(set) var currentContent: Content?
    private(set) var currentText: String = ""
    
    init(largeButtonSize: CGFloat = 72.0) {
        self.largeButtonSize = largeButtonSize
        
        self.wrapperNode = ASDisplayNode()
        self.contentContainer = ASDisplayNode()
        
        self.effectView = UIVisualEffectView()
        self.effectView.effect = UIBlurEffect(style: .light)
        self.effectView.layer.cornerRadius = self.largeButtonSize / 2.0
        self.effectView.clipsToBounds = true
        self.effectView.isUserInteractionEnabled = false
        
        self.contentBackgroundNode = ASImageNode()
        self.contentBackgroundNode.isUserInteractionEnabled = false
        
        self.contentNode = ASImageNode()
        self.contentNode.isUserInteractionEnabled = false
        
        self.overlayHighlightNode = ASImageNode()
        self.overlayHighlightNode.isUserInteractionEnabled = false
        self.overlayHighlightNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        super.init(pointerStyle: nil)
        
        self.addSubnode(self.wrapperNode)
        self.wrapperNode.addSubnode(self.contentContainer)
        self.contentContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        
        self.wrapperNode.addSubnode(self.textNode)
        
        self.contentContainer.view.addSubview(self.effectView)
        self.contentContainer.addSubnode(self.contentBackgroundNode)
        self.contentContainer.addSubnode(self.contentNode)
        self.contentContainer.addSubnode(self.overlayHighlightNode)
        
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
    
    func update(size: CGSize, content: Content, text: String, transition: ContainedViewLayoutTransition) {
        let scaleFactor = size.width / self.largeButtonSize
        
        let isSmall = self.largeButtonSize > size.width
        
        self.effectView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        self.contentBackgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        self.contentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        self.overlayHighlightNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        
        if self.currentContent != content || self.size != size {
            let previousContent = self.currentContent
            self.currentContent = content
            self.size = size
            
            if content.hasProgress {
                let statusFrame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
                if self.statusNode == nil {
                    let statusNode = SemanticStatusNode(backgroundNodeColor: .white, foregroundNodeColor: .clear, cutout: statusFrame.insetBy(dx: 8.0, dy: 8.0))
                    self.statusNode = statusNode
                    self.contentContainer.insertSubnode(statusNode, belowSubnode: self.contentNode)
                    statusNode.transitionToState(.progress(value: nil, cancelEnabled: false, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 4.0, lineWidth: 3.0)), animated: false, completion: {})
                }
                if let statusNode = self.statusNode {
                    statusNode.frame = statusFrame
                    if transition.isAnimated {
                        statusNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                        statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
            } else if let statusNode = self.statusNode {
                self.statusNode = nil
                transition.updateAlpha(node: statusNode, alpha: 0.0, completion: { [weak statusNode] _ in
                    statusNode?.removeFromSupernode()
                })
            }
            
            switch content.appearance {
            case .blurred:
                self.effectView.isHidden = false
            case .color:
                self.effectView.isHidden = true
            }
            
            transition.updateAlpha(node: self.wrapperNode, alpha: content.isEnabled ? 1.0 : 0.4)
            self.wrapperNode.isUserInteractionEnabled = content.isEnabled
            
            let contentBackgroundImage: UIImage? = nil
            
            var animationName: String?
            switch content.image {
                case .cameraOff:
                    animationName = "anim_cameraoff"
                case .cameraOn:
                    animationName = "anim_cameraon"
                default:
                    break
            }
            
            if let animationName = animationName {
                let animationFrame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
                if self.animationNode == nil {
                    let animationNode = AnimationNode(animation: animationName, colors: nil, scale: 1.0)
                    self.animationNode = animationNode
                    self.contentContainer.insertSubnode(animationNode, aboveSubnode: self.contentNode)
                }
                if let animationNode = self.animationNode {
                    animationNode.bounds = animationFrame
                    animationNode.position = CGPoint(x: self.largeButtonSize / 2.0, y: self.largeButtonSize / 2.0)
                    if previousContent == nil {
                        animationNode.seekToEnd()
                    } else if previousContent?.image != content.image {
                        animationNode.setAnimation(name: animationName)
                        animationNode.play()
                    }
                }
            }
            
            let contentImage = generateImage(CGSize(width: self.largeButtonSize, height: self.largeButtonSize), contextGenerator: { size, context in
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
                        fillColor = UIColor(rgb: 0xd92326)
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
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallCameraButton"), color: imageColor)
                case .mute:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallMuteButton"), color: imageColor)
                case .flipCamera:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallSwitchCameraButton"), color: imageColor)
                case .bluetooth:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallBluetoothButton"), color: imageColor)
                case .speaker:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallSpeakerButton"), color: imageColor)
                case .airpods:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallAirpodsButton"), color: imageColor)
                case .airpodsPro:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallAirpodsProButton"), color: imageColor)
                case .airpodsMax:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallAirpodsMaxButton"), color: imageColor)
                case .headphones:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallHeadphonesButton"), color: imageColor)
                case .accept:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallAcceptButton"), color: imageColor)
                case .end:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallDeclineButton"), color: imageColor)
                case .cancel:
                    image = generateImage(CGSize(width: 28.0, height: 28.0), opaque: false, rotatedContext: { size, context in
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
            
            if transition.isAnimated, let contentBackgroundImage = contentBackgroundImage, let previousContent = self.contentBackgroundNode.image {
                self.contentBackgroundNode.image = contentBackgroundImage
                self.contentBackgroundNode.layer.animate(from: previousContent.cgImage!, to: contentBackgroundImage.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
            } else {
                self.contentBackgroundNode.image = contentBackgroundImage
            }
            
            if transition.isAnimated, let previousContent = previousContent, previousContent.image == .accept && content.image == .end {
                let rotation = CGFloat.pi / 4.0 * 3.0
                
                if let snapshotView = self.contentNode.view.snapshotContentTree() {
                    snapshotView.frame = self.contentNode.view.frame
                    self.contentContainer.view.addSubview(snapshotView)
                    
                    snapshotView.layer.animateRotation(from: 0.0, to: rotation, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.4, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
                self.contentNode.image = contentImage
                self.contentNode.layer.animateRotation(from: -rotation, to: 0.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
            } else if transition.isAnimated, let contentImage = contentImage, let previousContent = self.contentNode.image {
                self.contentNode.image = contentImage
                self.contentNode.layer.animate(from: previousContent.cgImage!, to: contentImage.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
            } else {
                self.contentNode.image = contentImage
            }
            
            self.overlayHighlightNode.image = generateImage(CGSize(width: self.largeButtonSize, height: self.largeButtonSize), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                let fillColor: UIColor
                context.setBlendMode(.normal)
                switch content.appearance {
                case let .blurred(isFilled):
                    if isFilled {
                        fillColor = UIColor(white: 0.0, alpha: 0.1)
                    } else {
                        fillColor = UIColor(white: 1.0, alpha: 0.2)
                    }
                case let .color(color):
                    switch color {
                    case .red:
                        fillColor = UIColor(rgb: 0xd92326).withMultipliedBrightnessBy(0.2).withAlphaComponent(0.2)
                    case .green:
                        fillColor = UIColor(rgb: 0x74db58).withMultipliedBrightnessBy(0.2).withAlphaComponent(0.2)
                    case let .custom(color, _):
                        fillColor = UIColor(rgb: color).withMultipliedBrightnessBy(0.2).withAlphaComponent(0.2)
                    }
                }
                
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            })
        }
        
        transition.updatePosition(node: self.contentContainer, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
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
    }
}
