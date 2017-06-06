import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox

private final class NotificationContainerControllerNodeView: UITracingLayerView {
    var hitTestImpl: ((CGPoint, UIEvent?) -> UIView?)?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.hitTestImpl?(point, event)
    }
}

private final class OverlayVideoContext {
    var player: MediaPlayer?
    let disposable = MetaDisposable()
    var playerNode: MediaPlayerNode?
    
    deinit {
        self.disposable.dispose()
    }
}

final class OverlayMediaControllerNode: ASDisplayNode {
    private var videoContexts: [WrappedManagedMediaId: OverlayVideoContext] = [:]
    private var validLayout: ContainerViewLayout?
    
    override init() {
        super.init(viewBlock: {
            return NotificationContainerControllerNodeView()
        }, didLoad: nil)
        
        (self.view as! NotificationContainerControllerNodeView).hitTestImpl = { [weak self] point, event in
            return self?.hitTest(point, with: event)
        }
    }
    
    deinit {
        for (_, context) in self.videoContexts {
            context.disposable.dispose()
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
        for (_, context) in self.videoContexts {
            if let playerNode = context.playerNode {
                let videoSize = CGSize(width: 100.0, height: 100.0)
                transition.updateFrame(node: playerNode, frame: CGRect(origin: CGPoint(x: layout.size.width - 4.0 - videoSize.width, y: 20.0 + 44.0 + 38.0 + 4.0), size: videoSize))
            }
        }
    }
    
    func addVideoContext(mediaManager: MediaManager, postbox: Postbox, id: ManagedMediaId, resource: MediaResource, priority: Int32) {
        let wrappedId = WrappedManagedMediaId(id: id)
        if self.videoContexts[wrappedId] == nil {
            let context = OverlayVideoContext()
            self.videoContexts[wrappedId] = context
            let (player, disposable) = mediaManager.videoContext(postbox: postbox, id: id, resource: resource, preferSoftwareDecoding: false, backgroundThread: false, priority: priority, initiatePlayback: true, activate: { [weak self] playerNode in
                if let strongSelf = self, let context = strongSelf.videoContexts[wrappedId] {
                    if context.playerNode !== playerNode {
                        if context.playerNode?.supernode === self {
                            context.playerNode?.removeFromSupernode()
                        }
                        
                        context.playerNode = playerNode
                    
                        strongSelf.addSubnode(playerNode)
                        playerNode.transformArguments = TransformImageArguments(corners: ImageCorners(radius: 50.0), imageSize: CGSize(width: 100.0, height: 100.0), boundingSize: CGSize(width: 100.0, height: 100.0), intrinsicInsets: UIEdgeInsets())
                        if let validLayout = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(validLayout, transition: .immediate)
                            playerNode.layer.animatePosition(from: CGPoint(x: 104.0, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                        }
                    }
                }
            }, deactivate: { [weak self] in
                if let strongSelf = self, let context = strongSelf.videoContexts[wrappedId], let playerNode = context.playerNode {
                    if let snapshot = playerNode.view.snapshotView(afterScreenUpdates: false) {
                        snapshot.frame = playerNode.view.frame
                        strongSelf.view.addSubview(snapshot)
                        let fromPosition = playerNode.layer.position
                        playerNode.layer.position = CGPoint(x: playerNode.layer.position.x + 104.0, y: playerNode.layer.position.y)
                        snapshot.layer.animatePosition(from: fromPosition, to: playerNode.layer.position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak snapshot] _ in
                            snapshot?.removeFromSuperview()
                        })
                    }
                    context.playerNode = nil
                    if playerNode.supernode === self {
                        playerNode.removeFromSupernode()
                    }
                    return .complete()
                } else {
                    return .complete()
                }
                
                /*return Signal { subscriber in
                    if let strongSelf = self, let context = strongSelf.videoContexts[wrappedId] {
                        if let playerNode = context.playerNode {
                            let fromPosition = playerNode.layer.position
                            playerNode.layer.position = CGPoint(x: playerNode.layer.position.x + 104.0, y: playerNode.layer.position.y)
                            context.playerNode = nil
                            playerNode.layer.animatePosition(from: fromPosition, to: playerNode.layer.position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                                subscriber.putCompletion()
                            })
                        } else {
                            subscriber.putCompletion()
                        }
                    } else {
                        subscriber.putCompletion()
                    }
                    return EmptyDisposable
                }*/
            })
            context.player = player
            context.disposable.set(disposable)
        }
    }
    
    /*func addVideoContext(id: ManagedMediaId, contextSignal: Signal<ManagedVideoContext, NoError>) {
        let wrappedId = WrappedManagedMediaId(id: id)
        if self.videoContexts[wrappedId] == nil {
            let context = OverlayVideoContext()
            self.videoContexts[wrappedId] = context
            
            context.disposable.set((contextSignal |> deliverOnMainQueue).start(next: { [weak self] videoContext in
                if let strongSelf = self, let context = strongSelf.videoContexts[wrappedId] {
                    if context.video?.playerNode !== videoContext.playerNode {
                        if context.video?.playerNode?.supernode === self {
                            context.video?.playerNode?.removeFromSupernode()
                        }
                        
                        context.video = videoContext
                        
                        if let playerNode = videoContext.playerNode {
                            strongSelf.addSubnode(playerNode)
                            playerNode.transformArguments = TransformImageArguments(corners: ImageCorners(radius: 50.0), imageSize: CGSize(width: 100.0, height: 100.0), boundingSize: CGSize(width: 100.0, height: 100.0), intrinsicInsets: UIEdgeInsets())
                            if let validLayout = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(validLayout, transition: .immediate)
                                playerNode.layer.animatePosition(from: CGPoint(x: 104.0, y: 0.0), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                            }
                        }
                    } else {
                        context.video = videoContext
                    }
                }
            }))
        }
    }*/
    
    func removeVideoContext(id: ManagedMediaId) {
        let wrappedId = WrappedManagedMediaId(id: id)
        if let context = self.videoContexts[wrappedId] {
            if let playerNode = context.playerNode {
                if let snapshot = playerNode.view.snapshotView(afterScreenUpdates: false) {
                    snapshot.frame = playerNode.view.frame
                    self.view.addSubview(snapshot)
                    let fromPosition = playerNode.layer.position
                    playerNode.layer.position = CGPoint(x: playerNode.layer.position.x + 104.0, y: playerNode.layer.position.y)
                    snapshot.layer.animatePosition(from: fromPosition, to: playerNode.layer.position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { [weak snapshot] _ in
                        snapshot?.removeFromSuperview()
                    })
                }
                
                context.playerNode = nil
                playerNode.removeFromSupernode()
                
            }
            context.disposable.dispose()
            self.videoContexts.removeValue(forKey: wrappedId)
        }
    }
}
