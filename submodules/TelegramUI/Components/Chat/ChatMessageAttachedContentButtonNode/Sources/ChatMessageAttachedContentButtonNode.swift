import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ShimmerEffect

private let buttonFont = Font.semibold(14.0)
private let sharedBackgroundImage = generateStretchableFilledCircleImage(radius: 6.0, color: UIColor.white)?.withRenderingMode(.alwaysTemplate)

public final class ChatMessageAttachedContentButtonNode: HighlightTrackingButtonNode {
    private let textNode: TextNode
    private var iconView: UIImageView?
    private var shimmerEffectNode: ShimmerEffectForegroundNode?
    
    private var backgroundView: UIImageView?
    
    private var regularIconImage: UIImage?
    
    public var pressed: (() -> Void)?
  
    private var titleColor: UIColor?
    
    public init() {
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.textNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let scale = (strongSelf.bounds.width - 10.0) / strongSelf.bounds.width
                    strongSelf.layer.animateScale(from: 1.0, to: scale, duration: 0.15, removeOnCompletion: false)
                } else {
                    if let presentationLayer = strongSelf.layer.presentation() {
                        strongSelf.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                    }
                }
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func buttonPressed() {
        self.pressed?()
    }
    
    public func startShimmering() {
        guard let titleColor = self.titleColor else {
            return
        }
        
        let shimmerEffectNode: ShimmerEffectForegroundNode
        if let current = self.shimmerEffectNode {
            shimmerEffectNode = current
        } else {
            shimmerEffectNode = ShimmerEffectForegroundNode()
            shimmerEffectNode.cornerRadius = 6.0
            self.insertSubnode(shimmerEffectNode, at: 0)
            self.shimmerEffectNode = shimmerEffectNode
        }
        
        shimmerEffectNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        let backgroundFrame = self.bounds
        shimmerEffectNode.frame = backgroundFrame
        shimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: backgroundFrame.size), within: backgroundFrame.size)
        shimmerEffectNode.update(backgroundColor: .clear, foregroundColor: titleColor.withAlphaComponent(0.3), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
    }
    
    public func stopShimmering() {
        guard let shimmerEffectNode = self.shimmerEffectNode else {
            return
        }
        self.shimmerEffectNode = nil
        shimmerEffectNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak shimmerEffectNode] _ in
            shimmerEffectNode?.removeFromSupernode()
        })
    }
    
    public typealias AsyncLayout = (_ width: CGFloat, _ sideInset: CGFloat?, _ iconImage: UIImage?, _ cornerIcon: Bool, _ title: String, _ titleColor: UIColor, _ inProgress: Bool, _ drawBackground: Bool) -> (CGFloat, (CGFloat, CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageAttachedContentButtonNode))
    public static func asyncLayout(_ current: ChatMessageAttachedContentButtonNode?) -> AsyncLayout {
        let previousRegularIconImage = current?.regularIconImage
        
        let maybeMakeTextLayout = (current?.textNode).flatMap(TextNode.asyncLayout)
        
        return { width, sideInset, iconImage, cornerIcon, title, titleColor, inProgress, drawBackground in
            let targetNode: ChatMessageAttachedContentButtonNode
            if let current = current {
                targetNode = current
            } else {
                targetNode = ChatMessageAttachedContentButtonNode()
            }
            
            let makeTextLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeTextLayout = maybeMakeTextLayout {
                makeTextLayout = maybeMakeTextLayout
            } else {
                makeTextLayout = TextNode.asyncLayout(targetNode.textNode)
            }
            
            var updatedRegularIconImage: UIImage?
            if iconImage !== previousRegularIconImage {
                updatedRegularIconImage = iconImage
            }
            
            var iconWidth: CGFloat = 0.0
            if let iconImage = iconImage {
                iconWidth = iconImage.size.width + 5.0
            }
            
            let labelInset: CGFloat = sideInset ?? 8.0
            
            let (textSize, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: buttonFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, width - labelInset * 2.0 - iconWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
            
            return (textSize.size.width + labelInset * 2.0, { refinedWidth, refinedHeight in
                let size = CGSize(width: refinedWidth, height: refinedHeight)
                return (size, { animation in
                    targetNode.accessibilityLabel = title
                    
                    targetNode.titleColor = titleColor
                    
                    let iconView: UIImageView
                    if let current = targetNode.iconView {
                        iconView = current
                    } else {
                        iconView = UIImageView()
                        targetNode.iconView = iconView
                        targetNode.view.addSubview(iconView)
                    }
                    iconView.tintColor = titleColor
                    
                    if let updatedRegularIconImage = updatedRegularIconImage {
                        targetNode.regularIconImage = updatedRegularIconImage
                        if !targetNode.textNode.isHidden {
                            iconView.image = updatedRegularIconImage.withRenderingMode(.alwaysTemplate)
                        }
                    }
                    
                    let _ = textApply()
                    
                    let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: refinedWidth, height: size.height))
                    
                    var textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((refinedWidth - textSize.size.width) / 2.0), y: floorToScreenPixels((backgroundFrame.height - textSize.size.height) / 2.0)), size: textSize.size)
                    if drawBackground {
                        textFrame.origin.y += 1.0
                    }
                    if let image = iconView.image {
                        let iconFrame: CGRect
                        if cornerIcon {
                            iconFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - image.size.width - 5.0, y: 5.0), size: image.size)
                        } else {
                            textFrame.origin.x += floor(image.size.width / 2.0)
                            iconFrame = CGRect(origin: CGPoint(x: textFrame.minX - image.size.width - 5.0, y: textFrame.minY + floorToScreenPixels((textFrame.height - image.size.height) * 0.5)), size: image.size)
                        }
                        
                        animation.animator.updateFrame(layer: iconView.layer, frame: iconFrame, completion: nil)
                    }
                    
                    targetNode.textNode.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
                    animation.animator.updatePosition(layer: targetNode.textNode.layer, position: textFrame.center, completion: nil)
                    
                    if drawBackground {
                        let backgroundView: UIImageView
                        if let current = targetNode.backgroundView {
                            backgroundView = current
                            animation.animator.updateFrame(layer: backgroundView.layer, frame: backgroundFrame, completion: nil)
                        } else {
                            backgroundView = UIImageView()
                            backgroundView.image = sharedBackgroundImage
                            targetNode.backgroundView = backgroundView
                            targetNode.view.insertSubview(backgroundView, at: 0)
                            backgroundView.frame = backgroundFrame
                        }
                        backgroundView.tintColor = titleColor.withMultipliedAlpha(0.1)
                    } else if let backgroundView = targetNode.backgroundView {
                        targetNode.backgroundView = nil
                        backgroundView.removeFromSuperview()
                    }
                    
                    return targetNode
                })
            })
        }
    }
}
