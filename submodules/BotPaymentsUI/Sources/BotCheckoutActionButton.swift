import Foundation
import UIKit
import AsyncDisplayKit
import Display
import PassKit

enum BotCheckoutActionButtonState: Equatable {
    case loading
    case active(String)
    case inactive(String)
    case applePay
    
    static func ==(lhs: BotCheckoutActionButtonState, rhs: BotCheckoutActionButtonState) -> Bool {
        switch lhs {
            case .loading:
                if case .loading = rhs {
                    return true
                } else {
                    return false
                }
            case let .active(title):
                if case .active(title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .inactive(title):
                if case .inactive(title) = rhs {
                    return true
                } else {
                    return false
                }
            case .applePay:
                if case .applePay = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private let titleFont = Font.semibold(17.0)

final class BotCheckoutActionButton: HighlightableButtonNode {
    static var diameter: CGFloat = 48.0
    
    private var inactiveFillColor: UIColor
    private var activeFillColor: UIColor
    private var foregroundColor: UIColor
    
    private let progressBackgroundNode: ASImageNode
    private let inactiveBackgroundNode: ASImageNode
    private let activeBackgroundNode: ASImageNode
    private var applePayButton: UIButton?
    private let labelNode: TextNode
    
    private var state: BotCheckoutActionButtonState?
    private var validLayout: CGSize?
    
    init(inactiveFillColor: UIColor, activeFillColor: UIColor, foregroundColor: UIColor) {
        self.inactiveFillColor = inactiveFillColor
        self.activeFillColor = activeFillColor
        self.foregroundColor = foregroundColor
        
        self.progressBackgroundNode = ASImageNode()
        self.progressBackgroundNode.displaysAsynchronously = false
        self.progressBackgroundNode.displayWithoutProcessing = true
        self.progressBackgroundNode.isLayerBacked = true
        self.progressBackgroundNode.image = generateImage(CGSize(width: BotCheckoutActionButton.diameter, height: BotCheckoutActionButton.diameter), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            let strokeWidth: CGFloat = 2.0
            context.setFillColor(activeFillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
            
            context.setFillColor(inactiveFillColor.cgColor)
            context.fillEllipse(in: CGRect(origin: CGPoint(x: strokeWidth, y: strokeWidth), size: CGSize(width: size.width - strokeWidth * 2.0, height: size.height - strokeWidth * 2.0)))
            let cutout: CGFloat = 10.0
            context.fill(CGRect(origin: CGPoint(x: floor((size.width - cutout) / 2.0), y: 0.0), size: CGSize(width: cutout, height: cutout)))
        })
        
        self.inactiveBackgroundNode = ASImageNode()
        self.inactiveBackgroundNode.displaysAsynchronously = false
        self.inactiveBackgroundNode.displayWithoutProcessing = true
        self.inactiveBackgroundNode.isLayerBacked = true
        self.inactiveBackgroundNode.image = generateStretchableFilledCircleImage(diameter: BotCheckoutActionButton.diameter, color: self.foregroundColor, strokeColor: activeFillColor, strokeWidth: 2.0)
        self.inactiveBackgroundNode.alpha = 0.0
        
        self.activeBackgroundNode = ASImageNode()
        self.activeBackgroundNode.displaysAsynchronously = false
        self.activeBackgroundNode.displayWithoutProcessing = true
        self.activeBackgroundNode.isLayerBacked = true
        self.activeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: BotCheckoutActionButton.diameter, color: activeFillColor)
        
        self.labelNode = TextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.progressBackgroundNode)
        self.addSubnode(self.inactiveBackgroundNode)
        self.addSubnode(self.activeBackgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    func setState(_ state: BotCheckoutActionButtonState) {
        if self.state != state {
            let previousState = self.state
            self.state = state
            
            if let validLayout = self.validLayout, let previousState = previousState {
                switch state {
                    case .loading:
                        self.inactiveBackgroundNode.layer.animateFrame(from: self.inactiveBackgroundNode.frame, to: self.progressBackgroundNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                        if !self.inactiveBackgroundNode.alpha.isZero {
                            self.inactiveBackgroundNode.alpha = 0.0
                            self.inactiveBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                        }
                        self.activeBackgroundNode.layer.animateFrame(from: self.activeBackgroundNode.frame, to: self.progressBackgroundNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                        self.activeBackgroundNode.alpha = 0.0
                        self.activeBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                        self.labelNode.alpha = 0.0
                        self.labelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                        
                        self.progressBackgroundNode.alpha = 1.0
                        self.progressBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    
                        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                        basicAnimation.duration = 0.8
                        basicAnimation.fromValue = NSNumber(value: Float(0.0))
                        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
                        basicAnimation.repeatCount = Float.infinity
                        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        
                        self.progressBackgroundNode.layer.add(basicAnimation, forKey: "progressRotation")
                    case let .active(title):
                        if case .active = previousState {
                            let makeLayout = TextNode.asyncLayout(self.labelNode)
                            let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: self.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: validLayout, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                            self.labelNode.frame = CGRect(origin: CGPoint(x: floor((validLayout.width - labelLayout.size.width) / 2.0), y: floor((validLayout.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                            let _ = labelApply()
                        } else {
                            self.inactiveBackgroundNode.layer.animateFrame(from: self.progressBackgroundNode.frame, to: self.activeBackgroundNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                            self.inactiveBackgroundNode.alpha = 1.0
                            self.progressBackgroundNode.alpha = 0.0
                            
                            self.activeBackgroundNode.layer.animateFrame(from: self.progressBackgroundNode.frame, to: self.activeBackgroundNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                            self.activeBackgroundNode.alpha = 1.0
                            self.activeBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        
                            let makeLayout = TextNode.asyncLayout(self.labelNode)
                            let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: self.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: validLayout, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                            self.labelNode.frame = CGRect(origin: CGPoint(x: floor((validLayout.width - labelLayout.size.width) / 2.0), y: floor((validLayout.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                            let _ = labelApply()
                            self.labelNode.alpha = 1.0
                            self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                    case let .inactive(title):
                        if case .inactive = previousState {
                            let makeLayout = TextNode.asyncLayout(self.labelNode)
                            let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: self.activeFillColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: validLayout, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                            self.labelNode.frame = CGRect(origin: CGPoint(x: floor((validLayout.width - labelLayout.size.width) / 2.0), y: floor((validLayout.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                            let _ = labelApply()
                        } else {
                            self.inactiveBackgroundNode.layer.animateFrame(from: self.inactiveBackgroundNode.frame, to: self.activeBackgroundNode.frame, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                            self.inactiveBackgroundNode.alpha = 1.0
                            self.progressBackgroundNode.alpha = 0.0
                            
                            self.activeBackgroundNode.alpha = 0.0
                            
                            let makeLayout = TextNode.asyncLayout(self.labelNode)
                            let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: self.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: validLayout, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                            self.labelNode.frame = CGRect(origin: CGPoint(x: floor((validLayout.width - labelLayout.size.width) / 2.0), y: floor((validLayout.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                            let _ = labelApply()
                            self.labelNode.alpha = 1.0
                            self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                        }
                    case .applePay:
                        if case .applePay = previousState {
                            
                        } else {
                            
                        }
                }
            } else {
                switch state {
                    case .loading:
                        self.labelNode.alpha = 0.0
                        self.progressBackgroundNode.alpha = 1.0
                        self.activeBackgroundNode.alpha = 0.0
                    
                        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
                        basicAnimation.duration = 0.8
                        basicAnimation.fromValue = NSNumber(value: Float(0.0))
                        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
                        basicAnimation.repeatCount = Float.infinity
                        basicAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        
                        self.progressBackgroundNode.layer.add(basicAnimation, forKey: "progressRotation")
                    case .active:
                        self.labelNode.alpha = 1.0
                        self.progressBackgroundNode.alpha = 0.0
                        self.inactiveBackgroundNode.alpha = 0.0
                        self.activeBackgroundNode.alpha = 1.0
                    case .inactive:
                        self.labelNode.alpha = 1.0
                        self.progressBackgroundNode.alpha = 0.0
                        self.inactiveBackgroundNode.alpha = 1.0
                        self.activeBackgroundNode.alpha = 0.0
                    case .applePay:
                        self.labelNode.alpha = 0.0
                        self.progressBackgroundNode.alpha = 0.0
                        self.inactiveBackgroundNode.alpha = 0.0
                        self.activeBackgroundNode.alpha = 0.0
                        if self.applePayButton == nil {
                            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                                let applePayButton = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
                                self.view.addSubview(applePayButton)
                                self.applePayButton = applePayButton
                            }
                        }
                }
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        transition.updateFrame(node: self.progressBackgroundNode, frame: CGRect(origin: CGPoint(x: floor((size.width - BotCheckoutActionButton.diameter) / 2.0), y: 0.0), size: CGSize(width: BotCheckoutActionButton.diameter, height: BotCheckoutActionButton.diameter)))
        transition.updateFrame(node: self.inactiveBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: BotCheckoutActionButton.diameter)))
        transition.updateFrame(node: self.activeBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: BotCheckoutActionButton.diameter)))
        if let applePayButton = self.applePayButton {
            applePayButton.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: BotCheckoutActionButton.diameter))
        }
        
        var labelSize = self.labelNode.bounds.size
        if let state = self.state {
            switch state {
                case let .active(title):
                    let makeLayout = TextNode.asyncLayout(self.labelNode)
                    let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: self.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: size, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    let _ = labelApply()
                    labelSize = labelLayout.size
                case let .inactive(title):
                    let makeLayout = TextNode.asyncLayout(self.labelNode)
                    let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: self.activeFillColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: size, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    let _ = labelApply()
                    labelSize = labelLayout.size
                default:
                    break
            }
        }
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: floor((size.width - labelSize.width) / 2.0), y: floor((size.height - labelSize.height) / 2.0)), size: labelSize))
    }
}
