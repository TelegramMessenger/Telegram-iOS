import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import StickerResources

final class StickerPreviewControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let presentationData: PresentationData
    
    private let dimNode: ASDisplayNode
    
    private var textNode: ASTextNode
    private var imageNode: TransformImageNode
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private var item: StickerPackItem?
    
    var dismiss: (() -> Void)?
    var cancel: (() -> Void)?
    
    init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = presentationData.theme.list.plainBackgroundColor.withAlphaComponent(0.6)
        
        self.textNode = ASTextNode()
        self.imageNode = TransformImageNode()
        self.imageNode.addSubnode(self.textNode)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.imageNode)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let boundingSize = CGSize(width: 180.0, height: 180.0)
        
        if let item = self.item, let dimensitons = item.file.dimensions {
            let textSpacing: CGFloat = 10.0
            let textSize = self.textNode.measure(CGSize(width: 100.0, height: 100.0))
            
            let imageSize = dimensitons.cgSize.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            let imageFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - imageSize.width) / 2.0), y: (layout.size.height - imageSize.height - textSpacing - textSize.height) / 4.0), size: imageSize)
            self.imageNode.frame = imageFrame
            
            self.textNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - textSize.width) / 2.0), y: -textSize.height - textSpacing), size: textSize)
        }
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.cancel?()
        }
    }
    
    func animateIn(sourceNode: ASDisplayNode?) {
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        if let sourceNode = sourceNode {
            let location = sourceNode.view.convert(CGPoint(x: sourceNode.bounds.midX, y: sourceNode.bounds.midY), to: self.view)
            self.imageNode.layer.animateSpring(from: NSValue(cgPoint: location), to: NSValue(cgPoint: self.imageNode.layer.position), keyPath: "position", duration: 0.6, damping: 100.0)
            self.imageNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, damping: 100.0)
        }
        
        self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    func animateOut(targetNode: ASDisplayNode?, completion: (() -> Void)? = nil) {
        var dimCompleted = false
        var itemCompleted = false
        
        let internalCompletion: () -> Void = { [weak self] in
            if let strongSelf = self, dimCompleted && itemCompleted {
                strongSelf.dismiss?()
            }
            completion?()
        }
        
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { _ in
            dimCompleted = true
            internalCompletion()
        })
        
        if let targetNode = targetNode {
            let location = targetNode.view.convert(CGPoint(x: targetNode.bounds.midX, y: targetNode.bounds.midY), to: self.view)
            self.imageNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.2, removeOnCompletion: false)
            self.imageNode.layer.animatePosition(from: self.imageNode.layer.position, to: location, duration: 0.25, removeOnCompletion: false, completion: { _ in
                itemCompleted = true
                internalCompletion()
            })
            self.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        } else {
            self.imageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false, completion: { _ in
                itemCompleted = true
                internalCompletion()
            })
        }
    }
    
    func updateItem(_ item: StickerPackItem) {
        var animateIn = false
        if let _ = self.item {
            animateIn = true
            let previousImageNode = self.imageNode
            previousImageNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            previousImageNode.layer.animateSpring(from: 1.0 as NSNumber, to: 0.4 as NSNumber, keyPath: "transform.scale", duration: 0.4, damping: 88.0, removeOnCompletion: false, completion: { [weak previousImageNode] _ in
                previousImageNode?.removeFromSupernode()
            })
            
            self.imageNode = TransformImageNode()
            self.textNode = ASTextNode()
            self.imageNode.addSubnode(self.textNode)
            self.addSubnode(self.imageNode)
        }
        
        self.item = item
        
        for case let .Sticker(text, _, _) in item.file.attributes {
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(32.0), textColor: .black)
            break
        }
        self.imageNode.setSignal(chatMessageSticker(account: context.account, file: item.file, small: false, onlyFullSize: false))
        
        if let (layout, navigationBarHeight) = self.containerLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
        
        if animateIn {
            self.imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
            self.imageNode.layer.animateSpring(from: 0.5 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.7, damping: 88.0)
        }
    }
}
