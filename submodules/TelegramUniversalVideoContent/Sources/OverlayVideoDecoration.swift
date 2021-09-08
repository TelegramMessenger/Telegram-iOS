import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import UniversalMediaPlayer
import LegacyComponents
import AccountContext
import RadialStatusNode
import AppBundle

private func setupArrowFrame(size: CGSize, edge: OverlayMediaItemMinimizationEdge, view: TGEmbedPIPPullArrowView) {
    let arrowX: CGFloat
    switch edge {
    case .left:
        view.transform = .identity
        arrowX = size.width - 40.0 + floor((40.0 - view.bounds.size.width) / 2.0)
    case .right:
        view.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        arrowX = floor((40.0 - view.bounds.size.width) / 2.0)
    }
    
    view.frame = CGRect(origin: CGPoint(x: arrowX, y: floor((size.height - view.bounds.size.height) / 2.0)), size: view.bounds.size)
}

private let backgroundImage = UIImage(bundleImageName: "Chat/Message/OverlayPlainVideoShadow")?.precomposed().resizableImage(withCapInsets: UIEdgeInsets(top: 22.0, left: 25.0, bottom: 26.0, right: 25.0), resizingMode: .stretch)

final class OverlayVideoDecoration: UniversalVideoDecoration {
    private let contentDimensions: CGSize
    
    let backgroundNode: ASDisplayNode?
    let contentContainerNode: ASDisplayNode
    let foregroundNode: ASDisplayNode?
    
    private let unminimize: () -> Void
    private let controlsAreShowingUpdated: (Bool) -> Void
    
    private let shadowNode: ASImageNode
    private let foregroundContainerNode: ASDisplayNode
    private let controlsNode: PictureInPictureVideoControlsNode
    private let statusNode: RadialStatusNode
    private var minimizedBlurView: UIVisualEffectView?
    private var minimizedArrowView: TGEmbedPIPPullArrowView?
    private var minimizedEdge: OverlayMediaItemMinimizationEdge?
    
    private var contentNode: (ASDisplayNode & UniversalVideoContentNode)?
    
    private let statusDisposable = MetaDisposable()
    
    private var validLayoutSize: CGSize?
    
    init(contentDimensions: CGSize, unminimize: @escaping () -> Void, togglePlayPause: @escaping () -> Void, expand: @escaping () -> Void, close: @escaping () -> Void, controlsAreShowingUpdated: @escaping (Bool) -> Void) {
        self.contentDimensions = contentDimensions
        
        self.unminimize = unminimize
        self.controlsAreShowingUpdated = controlsAreShowingUpdated
        
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
        
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 30.0, height: 30.0))
        
        self.foregroundContainerNode = ASDisplayNode()
        self.foregroundContainerNode.addSubnode(self.controlsNode)
        self.foregroundContainerNode.addSubnode(self.statusNode)
        self.foregroundNode = self.foregroundContainerNode
    }
    
    deinit {
        self.statusDisposable.dispose()
    }
    
    private func frameForContent(size: CGSize) -> CGRect {
        if !self.contentDimensions.width.isZero && !self.contentDimensions.height.isZero {
            let fittedSize = self.contentDimensions.aspectFittedWithOverflow(size, leeway: 10.0)
            return CGRect(origin: CGPoint(x: floor(size.width - fittedSize.width) / 2.0, y: floor(size.height - fittedSize.height) / 2.0), size: fittedSize)
        }
        return CGRect(origin: CGPoint(), size: size)
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
                        contentNode.frame = self.frameForContent(size: validLayoutSize)
                        contentNode.updateLayout(size: validLayoutSize, transition: .immediate)
                    }
                }
            }
        }
    }
    
    func updateContentNodeSnapshot(_ snapshot: UIView?) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayoutSize = size
        
        let contentFrame = self.frameForContent(size: size)
        
        let shadowInsets = UIEdgeInsets(top: 2.0, left: 3.0, bottom: 4.0, right: 3.0)
        transition.updateFrame(node: self.shadowNode, frame: CGRect(origin: CGPoint(x: -shadowInsets.left, y: -shadowInsets.top), size: CGSize(width: size.width + shadowInsets.left + shadowInsets.right, height: size.height + shadowInsets.top + shadowInsets.bottom)))
        
        transition.updateFrame(node: self.foregroundContainerNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        
        transition.updateFrame(node: self.controlsNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height)))
        self.controlsNode.updateLayout(size: size, transition: transition)
        
        if let minimizedBlurView = self.minimizedBlurView {
            minimizedBlurView.frame = CGRect(origin: CGPoint(), size: size)
        }
        
        if let minimizedArrowView = self.minimizedArrowView, let minimizedEdge = self.minimizedEdge {
            setupArrowFrame(size: size, edge: minimizedEdge, view: minimizedArrowView)
        }
        
        transition.updateFrame(node: self.contentContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        
        let progressSize = CGSize(width: 30.0, height: 30.0)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - progressSize.width) / 2.0), y: floorToScreenPixels((size.height - progressSize.height) / 2.0)), size: progressSize))
        
        if let contentNode = self.contentNode {
            transition.updateFrame(node: contentNode, frame: contentFrame)
            contentNode.updateLayout(size: contentFrame.size, transition: transition)
        }
    }
    
    func tap() {
        if self.minimizedEdge != nil {
            self.unminimize()
        } else {
            if self.controlsNode.alpha.isZero {
                self.controlsNode.alpha = 1.0
                self.controlsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                self.controlsAreShowingUpdated(true)
            } else {
                self.controlsNode.alpha = 0.0
                self.controlsNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                self.controlsAreShowingUpdated(false)
            }
        }
    }
    
    func showControls() {
        if self.controlsNode.alpha.isZero {
            self.controlsNode.alpha = 1.0
            self.controlsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            self.controlsAreShowingUpdated(true)
        }
    }
    
    func setStatus(_ status: Signal<MediaPlayerStatus?, NoError>) {
        self.controlsNode.status = status |> map { value -> MediaPlayerStatus in
            if let value = value {
                return value
            } else {
                return MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: 0.0, dimensions: CGSize(), timestamp: 0.0, baseRate: 1.0, seekId: 0, status: .paused, soundEnabled: true)
            }
        }
        
        self.statusDisposable.set((status |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            if let status = status, case .buffering = status.status {
                strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: nil, cancelEnabled: false, animateRotation: true))
            } else {
                strongSelf.statusNode.transitionToState(.none)
            }
        }))
    }
    
    func updateMinimizedEdge(_ edge: OverlayMediaItemMinimizationEdge?, adjusting: Bool) {
        if self.minimizedEdge == edge {
            if let minimizedArrowView = self.minimizedArrowView {
                minimizedArrowView.setAngled(!adjusting, animated: true)
            }
            return
        }
        
        self.minimizedEdge = edge
        
        if let edge = edge {
            if self.minimizedBlurView == nil {
                let minimizedBlurView = UIVisualEffectView(effect: nil)
                self.minimizedBlurView = minimizedBlurView
                if let validLayoutSize = self.validLayoutSize {
                    minimizedBlurView.frame = CGRect(origin: CGPoint(), size: validLayoutSize)
                }
                minimizedBlurView.isHidden = true
                self.foregroundContainerNode.view.addSubview(minimizedBlurView)
            }
            if self.minimizedArrowView == nil {
                let minimizedArrowView = TGEmbedPIPPullArrowView(frame: CGRect(origin: CGPoint(), size: CGSize(width: 8.0, height: 38.0)))
                minimizedArrowView.alpha = 0.0
                self.minimizedArrowView = minimizedArrowView
                self.minimizedBlurView?.contentView.addSubview(minimizedArrowView)
            }
            if let minimizedArrowView = self.minimizedArrowView {
                if let validLayoutSize = self.validLayoutSize {
                    setupArrowFrame(size: validLayoutSize, edge: edge, view: minimizedArrowView)
                }
                minimizedArrowView.setAngled(!adjusting, animated: true)
            }
        }
        
        let effect: UIBlurEffect? = edge != nil ? UIBlurEffect(style: .light) : nil
        
        if let edge = edge {
            self.minimizedBlurView?.isHidden = false

            switch edge {
                case .left:
                    break
                case .right:
                    break
            }
        }

        UIView.animate(withDuration: 0.35, animations: {
            self.minimizedBlurView?.effect = effect
            self.minimizedArrowView?.alpha = edge != nil ? 1.0 : 0.0;
        }, completion: { [weak self] finished in
            if let strongSelf = self {
                if finished && edge == nil {
                    strongSelf.minimizedBlurView?.isHidden = true
                }
            }
        })
    }
}
