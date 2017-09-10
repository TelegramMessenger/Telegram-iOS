import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

private let backgroundImage = UIImage(bundleImageName: "Chat/Message/OverlayPlainVideoShadow")?.precomposed().resizableImage(withCapInsets: UIEdgeInsets(top: 22.0, left: 25.0, bottom: 26.0, right: 25.0), resizingMode: .stretch)

final class OverlayVideoDecoration: UniversalVideoDecoration {
    let backgroundNode: ASDisplayNode?
    let contentContainerNode: ASDisplayNode
    let foregroundNode: ASDisplayNode?
    
    private let shadowNode: ASImageNode
    private let controlsNode: PictureInPictureVideoControlsNode
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private var validLayoutSize: CGSize?
    
    init(togglePlayPause: @escaping () -> Void, expand: @escaping () -> Void, close: @escaping () -> Void) {
        self.shadowNode = ASImageNode()
        self.shadowNode.image = backgroundImage
        self.backgroundNode = self.shadowNode
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.backgroundColor = .black
        
        self.controlsNode = PictureInPictureVideoControlsNode(leave: {
            expand()
        }, playPause: {
            togglePlayPause()
        }, close: {
            close()
        })
        self.controlsNode.alpha = 0.0
        self.foregroundNode = self.controlsNode
        
        //self.controlsNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(controlsNodeTapGesture(_:))))
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
                    if let validLayoutSize = self.validLayoutSize {
                        contentNode.frame = CGRect(origin: CGPoint(), size: validLayoutSize)
                        contentNode.updateLayout(size: validLayoutSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let shadowInsets = UIEdgeInsets(top: 2.0, left: 3.0, bottom: 4.0, right: 3.0)
        transition.updateFrame(node: self.shadowNode, frame: CGRect(origin: CGPoint(x: -shadowInsets.left, y: -shadowInsets.top), size: CGSize(width: size.width + shadowInsets.left + shadowInsets.right, height: size.height + shadowInsets.top + shadowInsets.bottom)))
        
        transition.updateFrame(node: self.controlsNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        self.controlsNode.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
    }
    
    func tap() {
        if self.controlsNode.alpha.isZero {
            self.controlsNode.alpha = 1.0
            self.controlsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        } else {
            self.controlsNode.alpha = 0.0
            self.controlsNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
        }
    }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
        self.controlsNode.status = status |> map { value -> MediaPlayerStatus in
            if let value = value {
                return value
            } else {
                return MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: 0.0, timestamp: 0.0, status: .paused)
            }
        }
    }
}
