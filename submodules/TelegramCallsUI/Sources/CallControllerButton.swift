import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AppBundle

private let labelFont = Font.regular(13.0)

final class CallControllerButtonItemNode: HighlightTrackingButtonNode {
    struct Content: Equatable {
        enum Appearance: Equatable {
            enum Color {
                case red
                case green
            }
            
            case blurred(isFilled: Bool)
            case color(Color)
        }
        
        enum Image {
            case camera
            case mute
            case flipCamera
            case bluetooth
            case speaker
            case accept
            case end
        }
        
        var appearance: Appearance
        var image: Image
    }
    
    private let contentContainer: ASDisplayNode
    private let effectView: UIVisualEffectView
    private let contentNode: ASImageNode
    private let overlayHighlightNode: ASImageNode
    private let textNode: ImmediateTextNode
    
    private let largeButtonSize: CGFloat = 72.0
    
    private(set) var currentContent: Content?
    private(set) var currentText: String = ""
    
    init() {
        self.contentContainer = ASDisplayNode()
        
        self.effectView = UIVisualEffectView()
        self.effectView.effect = UIBlurEffect(style: .light)
        self.effectView.layer.cornerRadius = self.largeButtonSize / 2.0
        self.effectView.clipsToBounds = true
        self.effectView.isUserInteractionEnabled = false
        
        self.contentNode = ASImageNode()
        self.contentNode.isUserInteractionEnabled = false
        
        self.overlayHighlightNode = ASImageNode()
        self.overlayHighlightNode.isUserInteractionEnabled = false
        self.overlayHighlightNode.alpha = 0.0
        
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        super.init(pointerStyle: nil)
        
        self.addSubnode(self.contentContainer)
        self.contentContainer.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        
        self.addSubnode(self.textNode)
        
        self.contentContainer.view.addSubview(self.effectView)
        self.contentContainer.addSubnode(self.contentNode)
        self.contentContainer.addSubnode(self.overlayHighlightNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.overlayHighlightNode.alpha = 1.0
            } else {
                strongSelf.overlayHighlightNode.alpha = 0.0
                strongSelf.overlayHighlightNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
            }
        }
    }
    
    func update(size: CGSize, content: Content, text: String, transition: ContainedViewLayoutTransition) {
        let scaleFactor = size.width / self.largeButtonSize
        
        let isSmall = self.largeButtonSize > size.width
        
        self.effectView.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        self.contentNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        self.overlayHighlightNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: self.largeButtonSize, height: self.largeButtonSize))
        
        if self.currentContent != content {
            self.currentContent = content
            
            switch content.appearance {
            case .blurred:
                self.effectView.isHidden = false
            case .color:
                self.effectView.isHidden = true
            }
            
            let contentImage = generateImage(CGSize(width: self.largeButtonSize, height: self.largeButtonSize), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                var fillColor: UIColor = .clear
                var drawOverMask = false
                context.setBlendMode(.normal)
                var imageScale: CGFloat = 1.0
                switch content.appearance {
                case let .blurred(isFilled):
                    if isFilled {
                        fillColor = .white
                        drawOverMask = true
                        context.setBlendMode(.copy)
                    }
                    let smallButtonSize: CGFloat = 60.0
                    imageScale = self.largeButtonSize / smallButtonSize
                case let .color(color):
                    switch color {
                    case .red:
                        fillColor = UIColor(rgb: 0xd92326)
                    case .green:
                        fillColor = UIColor(rgb: 0x74db58)
                    }
                }
                
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                
                var image: UIImage?
                
                switch content.image {
                case .camera:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallCameraButton"), color: .white)
                case .mute:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallMuteButton"), color: .white)
                case .flipCamera:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallSwitchCameraButton"), color: .white)
                case .bluetooth:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallBluetoothButton"), color: .white)
                case .speaker:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallSpeakerButton"), color: .white)
                case .accept:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallAcceptButton"), color: .white)
                case .end:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Call/CallDeclineButton"), color: .white)
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
            if transition.isAnimated, let contentImage = contentImage, let previousContent = self.contentNode.image {
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
                    }
                }
                
                context.setFillColor(fillColor.cgColor)
                context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            })
        }
        
        transition.updatePosition(node: self.contentContainer, position: CGPoint(x: size.width / 2.0, y: size.height / 2.0))
        transition.updateSublayerTransformScale(node: self.contentContainer, scale: scaleFactor)
        
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
