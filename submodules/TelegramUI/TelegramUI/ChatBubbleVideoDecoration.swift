import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import UniversalMediaPlayer

final class ChatBubbleVideoDecoration: UniversalVideoDecoration {
    private let nativeSize: CGSize
    private let contentMode: InteractiveMediaNodeContentMode
    
    let corners: ImageCorners
    let backgroundNode: ASDisplayNode? = nil
    let contentContainerNode: ASDisplayNode
    let foregroundNode: ASDisplayNode? = nil
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    init(corners: ImageCorners, nativeSize: CGSize, contentMode: InteractiveMediaNodeContentMode, backgroundColor: UIColor) {
        self.corners = corners
        self.nativeSize = nativeSize
        self.contentMode = contentMode
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.backgroundColor = backgroundColor
        self.contentContainerNode.clipsToBounds = true
        
        self.updateCorners(corners)
    }
    
    func updateCorners(_ corners: ImageCorners) {
        if isRoundEqualCorners(corners) {
            self.contentContainerNode.cornerRadius = corners.topLeft.radius
            self.contentContainerNode.layer.mask = nil
        } else {
            self.contentContainerNode.cornerRadius = 0
            
            let boundingSize: CGSize = CGSize(width: max(corners.topLeft.radius, corners.bottomLeft.radius) + max(corners.topRight.radius, corners.bottomRight.radius), height: max(corners.topLeft.radius, corners.topRight.radius) + max(corners.bottomLeft.radius, corners.bottomRight.radius))
            let size: CGSize = CGSize(width: boundingSize.width + corners.extendedEdges.left + corners.extendedEdges.right, height: boundingSize.height + corners.extendedEdges.top + corners.extendedEdges.bottom)
            let arguments = TransformImageArguments(corners: corners, imageSize: size, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
            let context = DrawingContext(size: size, clear: true)
            context.withContext { ctx in
                ctx.setFillColor(UIColor.black.cgColor)
                ctx.fill(arguments.drawingRect)
            }
            addCorners(context, arguments: arguments)
            
            if let maskImage = context.generateImage() {
                let mask = CALayer()
                mask.contents = maskImage.cgImage
                mask.contentsScale = maskImage.scale
                mask.contentsCenter = CGRect(x: max(corners.topLeft.radius, corners.bottomLeft.radius) / maskImage.size.width, y: max(corners.topLeft.radius, corners.topRight.radius) / maskImage.size.height, width: (maskImage.size.width - max(corners.topLeft.radius, corners.bottomLeft.radius) - max(corners.topRight.radius, corners.bottomRight.radius)) / maskImage.size.width, height: (maskImage.size.height - max(corners.topLeft.radius, corners.topRight.radius) - max(corners.bottomLeft.radius, corners.bottomRight.radius)) / maskImage.size.height)
                
                self.contentContainerNode.layer.mask = mask
                self.contentContainerNode.layer.mask?.frame = self.contentContainerNode.bounds
            }
        }
    }
    
    func updateContentNode(_ contentNode: (UniversalVideoContentNode & ASDisplayNode)?) {
        if self.contentNode !== contentNode {
            let previous = self.contentNode
            self.contentNode = contentNode
            
            if let previous = previous {
                if previous.supernode === self.contentContainerNode {
                    previous.removeFromSupernode()
                }
            }
            
            if let contentNode = contentNode {
                if contentNode.supernode !== self.contentContainerNode {
                    self.contentContainerNode.addSubnode(contentNode)
                    if let size = self.validLayoutSize {
                        var scaledSize: CGSize
                        switch self.contentMode {
                            case .aspectFit:
                                scaledSize = self.nativeSize.aspectFitted(size)
                            case .aspectFill:
                                scaledSize = self.nativeSize.aspectFilled(size)
                        }
                        if abs(scaledSize.width - size.width) < 2.0 {
                            scaledSize.width = size.width
                        }
                        if abs(scaledSize.height - size.height) < 2.0 {
                            scaledSize.height = size.height
                        }
                        
                        contentNode.frame = CGRect(origin: CGPoint(x: floor((size.width - scaledSize.width) / 2.0), y: floor((size.height - scaledSize.height) / 2.0)), size: scaledSize)
                        contentNode.updateLayout(size: scaledSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    func updateContentNodeSnapshot(_ snapshot: UIView?) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        if let backgroundNode = self.backgroundNode {
            transition.updateFrame(node: backgroundNode, frame: bounds)
        }
        if let foregroundNode = self.foregroundNode {
            transition.updateFrame(node: foregroundNode, frame: bounds)
        }
        transition.updateFrame(node: self.contentContainerNode, frame: bounds)
        if let maskLayer = self.contentContainerNode.layer.mask {
            transition.updateFrame(layer: maskLayer, frame: bounds)
        }
        if let contentNode = self.contentNode {
            var scaledSize: CGSize
            switch self.contentMode {
                case .aspectFit:
                    scaledSize = self.nativeSize.aspectFitted(size)
                case .aspectFill:
                    scaledSize = self.nativeSize.aspectFilled(size)
            }
            if abs(scaledSize.width - size.width) < 2.0 {
                scaledSize.width = size.width
            }
            if abs(scaledSize.height - size.height) < 2.0 {
                scaledSize.height = size.height
            }
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(x: floor((size.width - scaledSize.width) / 2.0), y: floor((size.height - scaledSize.height) / 2.0)), size: scaledSize))
            contentNode.updateLayout(size: scaledSize, transition: transition)
        }
    }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
    }
    
    func tap() {
    }
}

