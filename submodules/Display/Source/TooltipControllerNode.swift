import Foundation
import UIKit
import AsyncDisplayKit

final class TooltipControllerNode: ASDisplayNode {
    private let baseFontSize: CGFloat
    
    private let dismiss: (Bool) -> Void
    
    private var validLayout: ContainerViewLayout?
    
    private let containerNode: ContextMenuContainerNode
    private let imageNode: ASImageNode
    private let textNode: ImmediateTextNode
    private var contentNode: TooltipControllerCustomContentNode?
    
    private let dismissByTapOutside: Bool
    
    var sourceRect: CGRect?
    var arrowOnBottom: Bool = true
    
    var padding: CGFloat = 8.0
    
    private var dismissedByTouchOutside = false
    private var dismissByTapOutsideSource = false
    
    init(content: TooltipControllerContent, baseFontSize: CGFloat, dismiss: @escaping (Bool) -> Void, dismissByTapOutside: Bool, dismissByTapOutsideSource: Bool) {
        self.baseFontSize = baseFontSize
        
        self.dismissByTapOutside = dismissByTapOutside
        self.dismissByTapOutsideSource = dismissByTapOutsideSource
        
        self.containerNode = ContextMenuContainerNode()
        self.containerNode.backgroundColor = UIColor(white: 0.0, alpha: 0.8)
        
        self.imageNode = ASImageNode()
        self.imageNode.image = content.image
        
        self.textNode = ImmediateTextNode()
        if case let .attributedText(text) = content {
            self.textNode.attributedText = text
        } else {
            self.textNode.attributedText = NSAttributedString(string: content.text, font: Font.regular(floor(baseFontSize * 14.0 / 17.0)), textColor: .white, paragraphAlignment: .center)
        }
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        self.textNode.maximumNumberOfLines = 0
        
        self.dismiss = dismiss
        
        if case let .custom(contentNode) = content {
            self.contentNode = contentNode
        }
        
        super.init()
        
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.textNode)
        self.contentNode.flatMap { self.containerNode.addSubnode($0) }
        
        self.addSubnode(self.containerNode)
    }
    
    func updateText(_ text: String, transition: ContainedViewLayoutTransition) {
        if transition.isAnimated, let copyLayer = self.textNode.layer.snapshotContentTree() {
            copyLayer.frame = self.textNode.layer.frame
            self.textNode.layer.superlayer?.addSublayer(copyLayer)
            transition.updateAlpha(layer: copyLayer, alpha: 0.0, completion: { [weak copyLayer] _ in
                copyLayer?.removeFromSuperlayer()
            })
            self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
        }
        self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(floor(self.baseFontSize * 14.0 / 17.0)), textColor: .white, paragraphAlignment: .center)
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout, transition: transition)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        let maxWidth = layout.size.width - 20.0
        
        let contentSize: CGSize
        
        if let contentNode = self.contentNode {
            contentSize = contentNode.updateLayout(size: layout.size)
            contentNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        } else {
            var imageSize = CGSize()
            var imageSizeWithInset = CGSize()
            if let image = self.imageNode.image {
                imageSize = image.size
                imageSizeWithInset = CGSize(width: image.size.width + 12.0, height: image.size.height)
            }
            
            var textSize = self.textNode.updateLayout(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
            textSize.width = ceil(textSize.width / 2.0) * 2.0
            textSize.height = ceil(textSize.height / 2.0) * 2.0
           
            contentSize = CGSize(width: imageSizeWithInset.width + textSize.width + 12.0, height: textSize.height + 34.0)
            
            let textFrame = CGRect(origin: CGPoint(x: 6.0 + imageSizeWithInset.width, y: 17.0), size: textSize)
            if transition.isAnimated, textFrame.size != self.textNode.frame.size {
                transition.animatePositionAdditive(node: self.textNode, offset: CGPoint(x: textFrame.minX - self.textNode.frame.minX, y: 0.0))
            }
            
            let imageFrame = CGRect(origin: CGPoint(x: 10.0, y: floor((contentSize.height - imageSize.height) / 2.0)), size: imageSize)
            self.imageNode.frame = imageFrame
            self.textNode.frame = textFrame
        }
            
        let sourceRect: CGRect = self.sourceRect ?? CGRect(origin: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0), size: CGSize())
        
        let insets = layout.insets(options: [.statusBar, .input])
        
        let verticalOrigin: CGFloat
        var arrowOnBottom = true
        if sourceRect.minY - 54.0 > insets.top {
            verticalOrigin = sourceRect.minY - contentSize.height
        } else {
            verticalOrigin = min(layout.size.height - insets.bottom - contentSize.height, sourceRect.maxY)
            arrowOnBottom = false
        }
        self.arrowOnBottom = arrowOnBottom
        
        let horizontalOrigin: CGFloat = floor(min(max(self.padding, sourceRect.midX - contentSize.width / 2.0), layout.size.width - contentSize.width - self.padding))
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: horizontalOrigin, y: verticalOrigin), size: contentSize))
        self.containerNode.relativeArrowPosition = (sourceRect.midX - horizontalOrigin, arrowOnBottom)
        
        self.containerNode.updateLayout(transition: transition)
    }
    
    func animateIn() {
        self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        self.contentNode?.animateIn()
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func hide() {
        self.containerNode.alpha = 0.0
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let event = event {
            var eventIsPresses = false
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                eventIsPresses = event.type == .presses
            }
            if event.type == .touches || eventIsPresses {
                let pointInside = self.containerNode.frame.contains(point)
                if self.containerNode.frame.contains(point) || self.dismissByTapOutside {
                    if !self.dismissedByTouchOutside {
                        self.dismissedByTouchOutside = true
                        self.dismiss(pointInside)
                    }
                } else if self.dismissByTapOutsideSource, let sourceRect = self.sourceRect, !sourceRect.contains(point) {
                    if !self.dismissedByTouchOutside {
                        self.dismissedByTouchOutside = true
                        self.dismiss(false)
                    }
                }
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
}

