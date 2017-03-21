import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore

public struct TransformImageArguments: Equatable {
    public let corners: ImageCorners
    
    public let imageSize: CGSize
    public let boundingSize: CGSize
    public let intrinsicInsets: UIEdgeInsets
    
    public var drawingSize: CGSize {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGSize(width: self.boundingSize.width + cornersExtendedEdges.left + cornersExtendedEdges.right + self.intrinsicInsets.left + self.intrinsicInsets.right, height: self.boundingSize.height + cornersExtendedEdges.top + cornersExtendedEdges.bottom + self.intrinsicInsets.top + self.intrinsicInsets.bottom)
    }
    
    public var drawingRect: CGRect {
        let cornersExtendedEdges = self.corners.extendedEdges
        return CGRect(x: cornersExtendedEdges.left + self.intrinsicInsets.left, y: cornersExtendedEdges.top + self.intrinsicInsets.top, width: self.boundingSize.width, height: self.boundingSize.height);
    }
    
    public var insets: UIEdgeInsets {
        let cornersExtendedEdges = self.corners.extendedEdges
        return UIEdgeInsets(top: cornersExtendedEdges.top + self.intrinsicInsets.top, left: cornersExtendedEdges.left + self.intrinsicInsets.left, bottom: cornersExtendedEdges.bottom + self.intrinsicInsets.bottom, right: cornersExtendedEdges.right + self.intrinsicInsets.right)
    }
}

public func ==(lhs: TransformImageArguments, rhs: TransformImageArguments) -> Bool {
    return lhs.imageSize == rhs.imageSize && lhs.boundingSize == rhs.boundingSize && lhs.corners == rhs.corners
}

public class TransformImageNode: ASDisplayNode {
    public var imageUpdated: (() -> Void)?
    public var alphaTransitionOnFirstUpdate = false
    private var disposable = MetaDisposable()
    
    private var argumentsPromise = ValuePromise<TransformImageArguments>(ignoreRepeated: true)
    
    deinit {
        self.disposable.dispose()
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
        
        self.disposable.set((result |> deliverOnMainQueue).start(next: {[weak self] next in
            if dispatchOnDisplayLink {
                displayLinkDispatcher.dispatch { [weak self] in
                    if let strongSelf = self {
                        if strongSelf.alphaTransitionOnFirstUpdate && strongSelf.contents == nil {
                            strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                        strongSelf.contents = next?.cgImage
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
}
