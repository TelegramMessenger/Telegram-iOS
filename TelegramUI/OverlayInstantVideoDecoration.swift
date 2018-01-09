import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit

private let backgroundImage = UIImage(bundleImageName: "Chat/Message/OverlayInstantVideoShadow")?.precomposed()

final class OverlayInstantVideoDecoration: UniversalVideoDecoration {
    private let tapped: () -> Void
    
    let backgroundNode: ASDisplayNode?
    let contentContainerNode: ASDisplayNode
    let foregroundNode: ASDisplayNode?
    
    private let shadowNode: ASImageNode
    private let foregroundContainerNode: ASDisplayNode
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    private var contentNodeSnapshot: UIView?
    
    private var validLayoutSize: CGSize?
    
    init(tapped: @escaping () -> Void) {
        self.tapped = tapped
        
        self.shadowNode = ASImageNode()
        self.shadowNode.image = backgroundImage
        self.backgroundNode = self.shadowNode
        
        self.contentContainerNode = ASDisplayNode()
        self.contentContainerNode.backgroundColor = .white
        self.contentContainerNode.cornerRadius = 60.0
        self.contentContainerNode.clipsToBounds = true
        
        self.foregroundContainerNode = ASDisplayNode()
        //self.foregroundContainerNode.addSubnode(self.controlsNode)
        self.foregroundNode = self.foregroundContainerNode
        
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
    
    func updateContentNodeSnapshot(_ snapshot: UIView?) {
        if self.contentNodeSnapshot !== snapshot {
            self.contentNodeSnapshot?.removeFromSuperview()
            self.contentNodeSnapshot = snapshot
            
            if let snapshot = snapshot {
                self.contentContainerNode.view.addSubview(snapshot)
                if let validLayoutSize = self.validLayoutSize {
                    snapshot.frame = CGRect(origin: CGPoint(), size: validLayoutSize)
                }
            }
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let shadowInsets = UIEdgeInsets(top: 2.0, left: 3.0, bottom: 4.0, right: 3.0)
        transition.updateFrame(node: self.shadowNode, frame: CGRect(origin: CGPoint(x: -shadowInsets.left, y: -shadowInsets.top), size: CGSize(width: size.width + shadowInsets.left + shadowInsets.right, height: size.height + shadowInsets.top + shadowInsets.bottom)))
        
        transition.updateFrame(node: self.foregroundContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: CGRect(origin: CGPoint(), size: size))
            contentNode.updateLayout(size: size, transition: transition)
        }
        
        if let contentNodeSnapshot = self.contentNodeSnapshot {
            transition.updateFrame(layer: contentNodeSnapshot.layer, frame: CGRect(origin: CGPoint(), size: size))
        }
    }
    
    func tap() {
        self.tapped()
    }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
        /*self.controlsNode.status = status |> map { value -> MediaPlayerStatus in
            if let value = value {
                return value
            } else {
                return MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: 0.0, timestamp: 0.0, seekId: 0, status: .paused)
            }
        }*/
    }
}

