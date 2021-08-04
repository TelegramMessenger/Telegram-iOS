import Foundation
import UIKit
import AsyncDisplayKit
import Display
import PassKit
import ShimmerEffect

enum BotCheckoutActionButtonState: Equatable {
    case active(String)
    case applePay
    case placeholder
}

private let titleFont = Font.semibold(17.0)

final class BotCheckoutActionButton: HighlightableButtonNode {
    static var height: CGFloat = 52.0

    private var activeFillColor: UIColor
    private var foregroundColor: UIColor

    private let activeBackgroundNode: ASImageNode
    private var applePayButton: UIButton?
    private let labelNode: TextNode
    
    private var state: BotCheckoutActionButtonState?
    private var validLayout: (CGRect, CGSize)?

    private var placeholderNode: ShimmerEffectNode?
    
    init(activeFillColor: UIColor, foregroundColor: UIColor) {
        self.activeFillColor = activeFillColor
        self.foregroundColor = foregroundColor

        let diameter: CGFloat = 20.0
        
        self.activeBackgroundNode = ASImageNode()
        self.activeBackgroundNode.displaysAsynchronously = false
        self.activeBackgroundNode.displayWithoutProcessing = true
        self.activeBackgroundNode.isLayerBacked = true
        self.activeBackgroundNode.image = generateStretchableFilledCircleImage(diameter: diameter, color: activeFillColor)
        
        self.labelNode = TextNode()
        self.labelNode.displaysAsynchronously = false
        self.labelNode.isUserInteractionEnabled = false
        
        super.init()

        self.addSubnode(self.activeBackgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    func setState(_ state: BotCheckoutActionButtonState) {
        if self.state != state {
            let previousState = self.state
            self.state = state
            
            if let (absoluteRect, containerSize) = self.validLayout, let _ = previousState {
                self.updateLayout(absoluteRect: absoluteRect, containerSize: containerSize, transition: .immediate)
            }
        }
    }

    @objc private func applePayButtonPressed() {
        self.sendActions(forControlEvents: .touchUpInside, with: nil)
    }
    
    func updateLayout(absoluteRect: CGRect, containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        let size = absoluteRect.size

        self.validLayout = (absoluteRect, containerSize)

        transition.updateFrame(node: self.activeBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: BotCheckoutActionButton.height)))
        
        var labelSize = self.labelNode.bounds.size
        if let state = self.state {
            switch state {
            case let .active(title):
                if let applePayButton = self.applePayButton {
                    self.applePayButton = nil
                    applePayButton.removeFromSuperview()
                }

                if let placeholderNode = self.placeholderNode {
                    self.placeholderNode = nil
                    placeholderNode.removeFromSupernode()
                }

                let makeLayout = TextNode.asyncLayout(self.labelNode)
                let (labelLayout, labelApply) = makeLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: titleFont, textColor: self.foregroundColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: size, alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                let _ = labelApply()
                labelSize = labelLayout.size
            case .applePay:
                if self.applePayButton == nil {
                    if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                        let applePayButton: PKPaymentButton
                        if #available(iOS 14.0, *) {
                            applePayButton = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
                        } else {
                            applePayButton = PKPaymentButton(paymentButtonType: .buy, paymentButtonStyle: .black)
                        }
                        applePayButton.addTarget(self, action: #selector(self.applePayButtonPressed), for: .touchUpInside)
                        self.view.addSubview(applePayButton)
                        self.applePayButton = applePayButton
                    }
                }

                if let placeholderNode = self.placeholderNode {
                    self.placeholderNode = nil
                    placeholderNode.removeFromSupernode()
                }

                if let applePayButton = self.applePayButton {
                    applePayButton.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: BotCheckoutActionButton.height))
                }
            case .placeholder:
                if let applePayButton = self.applePayButton {
                    self.applePayButton = nil
                    applePayButton.removeFromSuperview()
                }

                let contentSize = CGSize(width: 80.0, height: 8.0)

                let shimmerNode: ShimmerEffectNode
                if let current = self.placeholderNode {
                    shimmerNode = current
                } else {
                    shimmerNode = ShimmerEffectNode()
                    self.placeholderNode = shimmerNode
                    self.addSubnode(shimmerNode)
                }
                shimmerNode.frame = CGRect(origin: CGPoint(x: floor((size.width - contentSize.width) / 2.0), y: floor((size.height - contentSize.height) / 2.0)), size: contentSize)
                shimmerNode.updateAbsoluteRect(CGRect(origin: CGPoint(x: absoluteRect.minX + shimmerNode.frame.minX, y: absoluteRect.minY + shimmerNode.frame.minY), size: contentSize), within: containerSize)

                var shapes: [ShimmerEffectNode.Shape] = []

                shapes.append(.roundedRectLine(startPoint: CGPoint(x: 0.0, y: 0.0), width: contentSize.width, diameter: contentSize.height))

                shimmerNode.update(backgroundColor: self.activeFillColor, foregroundColor: self.activeFillColor.mixedWith(UIColor.white, alpha: 0.25), shimmeringColor: self.activeFillColor.mixedWith(UIColor.white, alpha: 0.15), shapes: shapes, size: contentSize)
            }
        }
        
        transition.updateFrame(node: self.labelNode, frame: CGRect(origin: CGPoint(x: floor((size.width - labelSize.width) / 2.0), y: floor((size.height - labelSize.height) / 2.0)), size: labelSize))
    }
}
