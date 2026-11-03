import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AppBundle

enum LegacyCallControllerButtonType {
    case mute
    case end
    case accept
    case speaker
    case bluetooth
    case switchCamera
}

private let buttonSize = CGSize(width: 75.0, height: 75.0)

private func generateEmptyButtonImage(icon: UIImage?, strokeColor: UIColor?, fillColor: UIColor, knockout: Bool = false, angle: CGFloat = 0.0) -> UIImage? {
    return generateImage(buttonSize, contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.copy)
        if let strokeColor = strokeColor {
            context.setFillColor(strokeColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: 1.5, y: 1.5), size: CGSize(width: size.width - 3.0, height: size.height - 3.0)))
        } else {
            context.setFillColor(fillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        }
        
        if let icon = icon {
            if !angle.isZero {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.rotate(by: angle)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            let imageSize = icon.size
            let imageRect = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floor((size.width - imageSize.height) / 2.0)), size: imageSize)
            if knockout {
                context.setBlendMode(.copy)
                context.clip(to: imageRect, mask: icon.cgImage!)
                context.setFillColor(UIColor.clear.cgColor)
                context.fill(imageRect)
            } else {
                context.setBlendMode(.normal)
                context.draw(generateTintedImage(image: icon, color: .white)!.cgImage!, in: imageRect)
            }
        }
    })
}

private func generateFilledButtonImage(color: UIColor, icon: UIImage?, angle: CGFloat = 0.0) -> UIImage? {
    return generateImage(buttonSize, contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setBlendMode(.normal)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        if let icon = icon {
            if !angle.isZero {
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.rotate(by: angle)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            }
            context.draw(icon.cgImage!, in: CGRect(origin: CGPoint(x: floor((size.width - icon.size.width) / 2.0), y: floor((size.height - icon.size.height) / 2.0)), size: icon.size))
        }
    })
}

private let emptyStroke = UIColor(white: 1.0, alpha: 0.8)
private let emptyHighlightedFill = UIColor(white: 1.0, alpha: 0.3)
private let invertedFill = UIColor(white: 1.0, alpha: 1.0)

private let labelFont = Font.regular(14.5)

final class LegacyCallControllerButtonNode: HighlightTrackingButtonNode {
    private var type: LegacyCallControllerButtonType
    
    private var regularImage: UIImage?
    private var highlightedImage: UIImage?
    private var filledImage: UIImage?
    
    private let backgroundNode: ASImageNode
    private let labelNode: ASTextNode?
    
    init(type: LegacyCallControllerButtonType, label: String?) {
        self.type = type
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = false
        self.backgroundNode.displaysAsynchronously = false
        
        if let label = label {
            let labelNode = ASTextNode()
            labelNode.attributedText = NSAttributedString(string: label, font: labelFont, textColor: .white)
            self.labelNode = labelNode
        } else {
            self.labelNode = nil
        }
        
        var regularImage: UIImage?
        var highlightedImage: UIImage?
        var filledImage: UIImage?
        
        switch type {
            case .mute:
                regularImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallMuteButton"), strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallMuteButton"), strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallMuteButton"), strokeColor: nil, fillColor: invertedFill, knockout: true)
            case .accept:
                regularImage = generateFilledButtonImage(color: UIColor(rgb: 0x74db58), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"), angle: CGFloat.pi * 3.0 / 4.0)
                highlightedImage = generateFilledButtonImage(color: UIColor(rgb: 0x74db58), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"), angle: CGFloat.pi * 3.0 / 4.0)
            case .end:
                regularImage = generateFilledButtonImage(color: UIColor(rgb: 0xd92326), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"))
                highlightedImage = generateFilledButtonImage(color: UIColor(rgb: 0xd92326), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"))
            case .speaker:
                regularImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallSpeakerButton"), strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallSpeakerButton"), strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallSpeakerButton"), strokeColor: nil, fillColor: invertedFill, knockout: true)
            case .bluetooth:
                regularImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/CallBluetoothButton"), strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/CallBluetoothButton"), strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/CallBluetoothButton"), strokeColor: nil, fillColor: invertedFill, knockout: true)
            case .switchCamera:
                let patternImage = generateTintedImage(image: UIImage(bundleImageName: "Call/CallSwitchCameraButton"), color: .white)
                regularImage = generateEmptyButtonImage(icon: patternImage, strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: patternImage, strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: patternImage, strokeColor: nil, fillColor: invertedFill, knockout: true)
        }
        
        self.regularImage = regularImage
        self.highlightedImage = highlightedImage
        self.filledImage = filledImage
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        
        if let labelNode = self.labelNode {
            self.addSubnode(labelNode)
        }
        
        self.backgroundNode.image = regularImage
        self.currentImage = regularImage
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                strongSelf.internalHighlighted = highlighted
                strongSelf.updateState(highlighted: highlighted, selected: strongSelf.isSelected)
            }
        }
    }
    
    private var internalHighlighted = false
    
    override var isSelected: Bool {
        didSet {
            self.updateState(highlighted: self.internalHighlighted, selected: self.isSelected)
        }
    }
    
    private var currentImage: UIImage?
    
    private func updateState(highlighted: Bool, selected: Bool) {
        let image: UIImage?
        if selected {
            image = self.filledImage
        } else if highlighted {
            image = self.highlightedImage
        } else {
            image = self.regularImage
        }
        
        if self.currentImage !== image {
            let currentContents = self.backgroundNode.layer.contents
            self.backgroundNode.layer.removeAnimation(forKey: "contents")
            if let currentContents = currentContents, let image = image {
                self.backgroundNode.image = image
                self.backgroundNode.layer.animate(from: currentContents as AnyObject, to: image.cgImage!, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: image === self.currentImage || image === self.filledImage ? 0.25 : 0.15)
            } else {
                self.backgroundNode.image = image
            }
            self.currentImage = image
        }
    }
    
    func updateType(_ type: LegacyCallControllerButtonType) {
        if self.type == type {
            return
        }
        self.type = type
        var regularImage: UIImage?
        var highlightedImage: UIImage?
        var filledImage: UIImage?
        
        switch type {
            case .mute:
                regularImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallMuteButton"), strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallMuteButton"), strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallMuteButton"), strokeColor: nil, fillColor: invertedFill, knockout: true)
            case .accept:
                regularImage = generateFilledButtonImage(color: UIColor(rgb: 0x74db58), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"), angle: CGFloat.pi * 3.0 / 4.0)
                highlightedImage = generateFilledButtonImage(color: UIColor(rgb: 0x74db58), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"), angle: CGFloat.pi * 3.0 / 4.0)
            case .end:
                regularImage = generateFilledButtonImage(color: UIColor(rgb: 0xd92326), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"))
                highlightedImage = generateFilledButtonImage(color: UIColor(rgb: 0xd92326), icon: UIImage(bundleImageName: "Call/LegacyCallPhoneButton"))
            case .speaker:
                regularImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallSpeakerButton"), strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallSpeakerButton"), strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/LegacyCallSpeakerButton"), strokeColor: nil, fillColor: invertedFill, knockout: true)
            case .bluetooth:
                regularImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/CallBluetoothButton"), strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/CallBluetoothButton"), strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: UIImage(bundleImageName: "Call/CallBluetoothButton"), strokeColor: nil, fillColor: invertedFill, knockout: true)
            case .switchCamera:
                let patternImage = generateTintedImage(image: UIImage(bundleImageName: "Call/CallSwitchCameraButton"), color: .white)
                regularImage = generateEmptyButtonImage(icon: patternImage, strokeColor: emptyStroke, fillColor: .clear)
                highlightedImage = generateEmptyButtonImage(icon: patternImage, strokeColor: emptyStroke, fillColor: emptyHighlightedFill)
                filledImage = generateEmptyButtonImage(icon: patternImage, strokeColor: nil, fillColor: invertedFill, knockout: true)
        }
        
        self.regularImage = regularImage
        self.highlightedImage = highlightedImage
        self.filledImage = filledImage
        
        self.updateState(highlighted: self.isHighlighted, selected: self.isSelected)
    }
    
    func animateRollTransition() {
        self.backgroundNode.layer.animate(from: 0.0 as NSNumber, to: (-CGFloat.pi * 5 / 4) as NSNumber, keyPath: "transform.rotation.z", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.3, removeOnCompletion: false)
        self.labelNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width))
        
        if let labelNode = self.labelNode {
            let labelSize = labelNode.measure(CGSize(width: 200.0, height: 100.0))
            labelNode.frame = CGRect(origin: CGPoint(x: floor((size.width - labelSize.width) / 2.0), y: 81.0), size: labelSize)
        }
    }
}
