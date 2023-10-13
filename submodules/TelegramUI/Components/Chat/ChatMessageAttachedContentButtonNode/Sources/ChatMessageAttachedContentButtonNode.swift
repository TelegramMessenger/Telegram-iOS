import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState
import ShimmerEffect

private let buttonFont = Font.semibold(13.0)

public final class ChatMessageAttachedContentButtonNode: HighlightTrackingButtonNode {
    private let textNode: TextNode
    private let iconNode: ASImageNode
    private let highlightedTextNode: TextNode
    private let backgroundNode: ASImageNode
    private let shimmerEffectNode: ShimmerEffectForegroundNode
    
    private var regularImage: UIImage?
    private var highlightedImage: UIImage?
    private var regularIconImage: UIImage?
    private var highlightedIconImage: UIImage?
    
    public var pressed: (() -> Void)?
  
    private var titleColor: UIColor?
    
    public init() {
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.highlightedTextNode = TextNode()
        self.highlightedTextNode.isUserInteractionEnabled = false
        
        self.shimmerEffectNode = ShimmerEffectForegroundNode()
        self.shimmerEffectNode.cornerRadius = 5.0
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.shimmerEffectNode)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.highlightedTextNode)
        self.highlightedTextNode.isHidden = true
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.image = strongSelf.highlightedImage
                    strongSelf.iconNode.image = strongSelf.highlightedIconImage
                    strongSelf.textNode.isHidden = true
                    strongSelf.highlightedTextNode.isHidden = false
                    
                    let scale = (strongSelf.bounds.width - 10.0) / strongSelf.bounds.width
                    strongSelf.layer.animateScale(from: 1.0, to: scale, duration: 0.15, removeOnCompletion: false)
                } else {
                    if let presentationLayer = strongSelf.layer.presentation() {
                        strongSelf.layer.animateScale(from: CGFloat((presentationLayer.value(forKeyPath: "transform.scale.y") as? NSNumber)?.floatValue ?? 1.0), to: 1.0, duration: 0.25, removeOnCompletion: false)
                    }
                    if let snapshot = strongSelf.view.snapshotView(afterScreenUpdates: false) {
                        strongSelf.view.addSubview(snapshot)
                        
                        snapshot.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                            snapshot.removeFromSuperview()
                        })
                    }
                    
                    strongSelf.backgroundNode.image = strongSelf.regularImage
                    strongSelf.iconNode.image = strongSelf.regularIconImage
                    strongSelf.textNode.isHidden = false
                    strongSelf.highlightedTextNode.isHidden = true
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
        self.shimmerEffectNode.isHidden = false
        self.shimmerEffectNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        let backgroundFrame = self.backgroundNode.frame
        self.shimmerEffectNode.frame = backgroundFrame
        self.shimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: backgroundFrame.size), within: backgroundFrame.size)
        self.shimmerEffectNode.update(backgroundColor: .clear, foregroundColor: titleColor.withAlphaComponent(0.3), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
    }
    
    public func stopShimmering() {
        self.shimmerEffectNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
            self?.shimmerEffectNode.isHidden = true
        })
    }
    
    public static func asyncLayout(_ current: ChatMessageAttachedContentButtonNode?) -> (_ width: CGFloat, _ regularImage: UIImage, _ highlightedImage: UIImage, _ iconImage: UIImage?, _ highlightedIconImage: UIImage?, _ cornerIcon: Bool, _ title: String, _ titleColor: UIColor, _ highlightedTitleColor: UIColor, _ inProgress: Bool) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageAttachedContentButtonNode)) {
        let previousRegularImage = current?.regularImage
        let previousHighlightedImage = current?.highlightedImage
        let previousRegularIconImage = current?.regularIconImage
        let previousHighlightedIconImage = current?.highlightedIconImage
        
        let maybeMakeTextLayout = (current?.textNode).flatMap(TextNode.asyncLayout)
        let maybeMakeHighlightedTextLayout = (current?.highlightedTextNode).flatMap(TextNode.asyncLayout)
        
        return { width, regularImage, highlightedImage, iconImage, highlightedIconImage, cornerIcon, title, titleColor, highlightedTitleColor, inProgress in
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
            
            let makeHighlightedTextLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeHighlightedTextLayout = maybeMakeHighlightedTextLayout {
                makeHighlightedTextLayout = maybeMakeHighlightedTextLayout
            } else {
                makeHighlightedTextLayout = TextNode.asyncLayout(targetNode.highlightedTextNode)
            }
            
            var updatedRegularImage: UIImage?
            if regularImage !== previousRegularImage {
                updatedRegularImage = regularImage
            }
            
            var updatedHighlightedImage: UIImage?
            if highlightedImage !== previousHighlightedImage {
                updatedHighlightedImage = highlightedImage
            }
            
            var updatedRegularIconImage: UIImage?
            if iconImage !== previousRegularIconImage {
                updatedRegularIconImage = iconImage
            }
            
            var updatedHighlightedIconImage: UIImage?
            if highlightedIconImage !== previousHighlightedIconImage {
                updatedHighlightedIconImage = highlightedIconImage
            }
            
            var iconWidth: CGFloat = 0.0
            if let iconImage = iconImage {
                iconWidth = iconImage.size.width + 5.0
            }
            
            let labelInset: CGFloat = 8.0
            
            let (textSize, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: buttonFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, width - labelInset * 2.0 - iconWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
            
            let (_, highlightedTextApply) = makeHighlightedTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: buttonFont, textColor: highlightedTitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, width - labelInset * 2.0), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
            
            return (textSize.size.width + labelInset * 2.0, { refinedWidth in
                return (CGSize(width: refinedWidth, height: 33.0), {
                    targetNode.accessibilityLabel = title
                    
                    targetNode.titleColor = titleColor
                    
                    if let updatedRegularImage = updatedRegularImage {
                        targetNode.regularImage = updatedRegularImage
                        if !targetNode.textNode.isHidden {
                            targetNode.backgroundNode.image = updatedRegularImage
                        }
                    }
                    if let updatedHighlightedImage = updatedHighlightedImage {
                        targetNode.highlightedImage = updatedHighlightedImage
                        if targetNode.textNode.isHidden {
                            targetNode.backgroundNode.image = updatedHighlightedImage
                        }
                    }
                    if let updatedRegularIconImage = updatedRegularIconImage {
                        targetNode.regularIconImage = updatedRegularIconImage
                        if !targetNode.textNode.isHidden {
                            targetNode.iconNode.image = updatedRegularIconImage
                        }
                    }
                    if let updatedHighlightedIconImage = updatedHighlightedIconImage {
                        targetNode.highlightedIconImage = updatedHighlightedIconImage
                        if targetNode.iconNode.isHidden {
                            targetNode.iconNode.image = updatedHighlightedIconImage
                        }
                    }
                    
                    let _ = textApply()
                    let _ = highlightedTextApply()
                    
                    let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: refinedWidth, height: 33.0))
                    var textFrame = CGRect(origin: CGPoint(x: floor((refinedWidth - textSize.size.width) / 2.0), y: floor((34.0 - textSize.size.height) / 2.0)), size: textSize.size)
                    targetNode.backgroundNode.frame = backgroundFrame
                    if let image = targetNode.iconNode.image {
                        if cornerIcon {
                            targetNode.iconNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - image.size.width - 5.0, y: 5.0), size: image.size)
                        } else {
                            textFrame.origin.x += floor(image.size.width / 2.0)
                            targetNode.iconNode.frame = CGRect(origin: CGPoint(x: textFrame.minX - image.size.width - 5.0, y: textFrame.minY + 2.0), size: image.size)
                        }
                        if targetNode.iconNode.supernode == nil {
                            targetNode.addSubnode(targetNode.iconNode)
                        }
                    } else if targetNode.iconNode.supernode != nil {
                        targetNode.iconNode.removeFromSupernode()
                    }
                    
                    targetNode.textNode.frame = textFrame
                    targetNode.highlightedTextNode.frame = targetNode.textNode.frame
                    
                    return targetNode
                })
            })
        }
    }
}
