import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore

public class TransformImageNode: ASDisplayNode {
    public var imageUpdated: (() -> Void)?
    public var alphaTransitionOnFirstUpdate = false
    private var disposable = MetaDisposable()
    
    private var argumentsPromise = ValuePromise<TransformImageArguments>(ignoreRepeated: true)
    
    private var overlayColor: UIColor?
    private var overlayNode: ASDisplayNode?
    
    deinit {
        self.disposable.dispose()
    }
    
    override public var frame: CGRect {
        didSet {
            if let overlayNode = self.overlayNode {
                overlayNode.frame = self.bounds
            }
        }
    }
    
    func setSignal(account: Account, signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, dispatchOnDisplayLink: Bool = true) {
        let argumentsPromise = self.argumentsPromise
        
        let result = combineLatest(signal, argumentsPromise.get()) |> deliverOn(Queue.concurrentDefaultQueue() /*account.graphicsThreadPool*/) |> mapToThrottled { transform, arguments -> Signal<UIImage?, NoError> in
            return deferred {
                if let context = transform(arguments) {
                    return Signal<UIImage?, NoError>.single(context.generateImage())
                } else {
                    return Signal<UIImage?, NoError>.single(nil)
                }
            }
        }
        
        self.disposable.set((result |> deliverOnMainQueue).start(next: { [weak self] next in
            if dispatchOnDisplayLink {
                displayLinkDispatcher.dispatch {
                    if let strongSelf = self {
                        if strongSelf.alphaTransitionOnFirstUpdate && strongSelf.contents == nil {
                            strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                        strongSelf.contents = next?.cgImage
                        if let overlayColor = strongSelf.overlayColor {
                            strongSelf.applyOverlayColor(animated: false)
                        }
                        if let imageUpdated = strongSelf.imageUpdated {
                            imageUpdated()
                        }
                    }
                }
            } else {
                if let strongSelf = self {
                    if strongSelf.alphaTransitionOnFirstUpdate && strongSelf.contents == nil {
                        strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                    }
                    strongSelf.contents = next?.cgImage
                    if let overlayColor = strongSelf.overlayColor {
                        strongSelf.applyOverlayColor(animated: false)
                    }
                    if let imageUpdated = strongSelf.imageUpdated {
                        imageUpdated()
                    }
                }
            }
        }))
    }
    
    public func asyncLayout() -> (TransformImageArguments) -> (() -> Void) {
        return { arguments in
            self.argumentsPromise.set(arguments)
            
            return {
                
            }
        }
    }
    
    public class func asyncLayout(_ maybeNode: TransformImageNode?) -> (TransformImageArguments) -> (() -> TransformImageNode) {
        return { arguments in
            let node: TransformImageNode
            if let maybeNode = maybeNode {
                node = maybeNode
            } else {
                node = TransformImageNode()
            }
            return {
                node.argumentsPromise.set(arguments)
                return node
            }
        }
    }
    
    public func setOverlayColor(_ color: UIColor?, animated: Bool) {
        var updated = false
        if let overlayColor = self.overlayColor, let color = color {
            updated = !overlayColor.isEqual(color)
        } else if (self.overlayColor != nil) != (color != nil) {
            updated = true
        }
        if updated {
            self.overlayColor = color
            if let _ = self.overlayColor {
                self.applyOverlayColor(animated: animated)
            } else if let overlayNode = self.overlayNode {
                self.overlayNode = nil
                if animated {
                    overlayNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak overlayNode] _ in
                        overlayNode?.removeFromSupernode()
                    })
                } else {
                    overlayNode.removeFromSupernode()
                }
            }
        }
    }
    
    private func applyOverlayColor(animated: Bool) {
        if let overlayColor = self.overlayColor {
            if let contents = self.contents, CFGetTypeID(contents as CFTypeRef) == CGImage.typeID {
                if let overlayNode = self.overlayNode {
                    (overlayNode.view as! UIImageView).image = UIImage(cgImage: contents as! CGImage).withRenderingMode(.alwaysTemplate)
                    overlayNode.tintColor = overlayColor
                } else {
                    let overlayNode = ASDisplayNode(viewBlock: {
                        return UIImageView()
                    }, didLoad: nil)
                    overlayNode.displaysAsynchronously = false
                    (overlayNode.view as! UIImageView).image = UIImage(cgImage: contents as! CGImage).withRenderingMode(.alwaysTemplate)
                    overlayNode.tintColor = overlayColor
                    overlayNode.frame = self.bounds
                    self.addSubnode(overlayNode)
                    self.overlayNode = overlayNode
                }
            }
        }
    }
}
