import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import AVFoundation

public struct TransformImageNodeContentAnimations: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let firstUpdate = TransformImageNodeContentAnimations(rawValue: 1 << 0)
    public static let subsequentUpdates = TransformImageNodeContentAnimations(rawValue: 1 << 1)
}

open class TransformImageNode: ASDisplayNode {
    public var imageUpdated: ((UIImage?) -> Void)?
    public var contentAnimations: TransformImageNodeContentAnimations = []
    private var disposable = MetaDisposable()
    
    private var currentTransform: ((TransformImageArguments) -> DrawingContext?)?
    private var currentArguments: TransformImageArguments?
    public private(set) var image: UIImage?
    private var argumentsPromise = ValuePromise<TransformImageArguments>(ignoreRepeated: true)
    
    private var overlayColor: UIColor?
    private var overlayNode: ASDisplayNode?

    private var captureProtectedContentLayer: CaptureProtectedContentLayer?

    public var captureProtected: Bool = false {
        didSet {
            if self.captureProtected != oldValue {
                if self.captureProtected {
                    if self.captureProtectedContentLayer == nil {
                        let captureProtectedContentLayer = CaptureProtectedContentLayer()
                        self.captureProtectedContentLayer = captureProtectedContentLayer
                        if #available(iOS 13.0, *) {
                            captureProtectedContentLayer.preventsCapture = true
                            captureProtectedContentLayer.preventsDisplaySleepDuringVideoPlayback = false
                        }
                        captureProtectedContentLayer.frame = self.bounds
                        self.layer.addSublayer(captureProtectedContentLayer)
                        var hasImage = false
                        if let image = self.image {
                            hasImage = true
                            if let cmSampleBuffer = image.cmSampleBuffer {
                                captureProtectedContentLayer.enqueue(cmSampleBuffer)
                            }
                        }
                        if hasImage {
                            Queue.mainQueue().after(0.1) {
                                self.contents = nil
                            }
                        } else {
                            self.contents = nil
                        }
                    }
                } else if let captureProtectedContentLayer = self.captureProtectedContentLayer {
                    self.captureProtectedContentLayer = nil
                    captureProtectedContentLayer.removeFromSuperlayer()
                    self.contents = self.image?.cgImage
                }
            }
        }
    }

    open override var bounds: CGRect {
        didSet {
            if let captureProtectedContentLayer = self.captureProtectedContentLayer, super.bounds.size != oldValue.size {
                captureProtectedContentLayer.frame = super.bounds
            }
        }
    }

    open override var frame: CGRect {
        didSet {
            if let overlayNode = self.overlayNode {
                overlayNode.frame = self.bounds
            }
            if let captureProtectedContentLayer = self.captureProtectedContentLayer, super.bounds.size != oldValue.size {
                captureProtectedContentLayer.frame = super.bounds
            }
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override open func didLoad() {
        super.didLoad()
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *), !self.isLayerBacked {
            self.view.accessibilityIgnoresInvertColors = true
        }
    }
    
    public func reset() {
        self.disposable.set(nil)
        self.currentArguments = nil
        self.currentTransform = nil
        self.contents = nil
        self.image = nil
    }
    
    public func setSignal(_ signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, attemptSynchronously: Bool = false, dispatchOnDisplayLink: Bool = true) {
        let argumentsPromise = self.argumentsPromise
        
        let data = combineLatest(signal, argumentsPromise.get())
        
        let resultData: Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments), NoError>
        if attemptSynchronously {
            resultData = data
        } else {
            resultData = data
            |> deliverOn(Queue.concurrentDefaultQueue())
        }
        
        let result = resultData
        |> mapToThrottled { transform, arguments -> Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments, UIImage?)?, NoError> in
            return deferred {
                if let context = transform(arguments) {
                    return .single((transform, arguments, context.generateImage()))
                } else {
                    return .single(nil)
                }
            }
        }
        
        self.disposable.set((result |> deliverOnMainQueue).start(next: { [weak self] next in
            let apply: () -> Void = {
                if let strongSelf = self {
                    if strongSelf.contents == nil {
                        if strongSelf.contentAnimations.contains(.firstUpdate) && !attemptSynchronously {
                            strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                    } else if strongSelf.contentAnimations.contains(.subsequentUpdates) {
                        if let _ = strongSelf.captureProtectedContentLayer {
                        } else {
                            let tempLayer = CALayer()
                            tempLayer.frame = strongSelf.bounds
                            tempLayer.contentsGravity = strongSelf.layer.contentsGravity
                            tempLayer.contents = strongSelf.contents
                            strongSelf.layer.addSublayer(tempLayer)
                            tempLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak tempLayer] _ in
                                tempLayer?.removeFromSuperlayer()
                            })
                        }
                    }
                    
                    var imageUpdate: UIImage?
                    if let (transform, arguments, image) = next {
                        strongSelf.currentTransform = transform
                        strongSelf.currentArguments = arguments
                        if let captureProtectedContentLayer = strongSelf.captureProtectedContentLayer {
                            if let cmSampleBuffer = image?.cmSampleBuffer {
                                captureProtectedContentLayer.enqueue(cmSampleBuffer)
                            }
                        } else {
                            strongSelf.contents = image?.cgImage
                        }
                        strongSelf.image = image
                        imageUpdate = image
                    }
                    if let _ = strongSelf.overlayColor {
                        strongSelf.applyOverlayColor(animated: false)
                    }
                    if let imageUpdated = strongSelf.imageUpdated {
                        imageUpdated(imageUpdate)
                    }
                }
            }
            if dispatchOnDisplayLink && !attemptSynchronously {
                displayLinkDispatcher.dispatch {
                    apply()
                }
            } else {
                apply()
            }
        }))
    }
    
    public func asyncLayout() -> (TransformImageArguments) -> (() -> Void) {
        let currentTransform = self.currentTransform
        let currentArguments = self.currentArguments
        return { [weak self] arguments in
            let updatedImage: UIImage?
            if currentArguments != arguments {
                updatedImage = currentTransform?(arguments)?.generateImage()
            } else {
                updatedImage = nil
            }
            return {
                guard let strongSelf = self else {
                    return
                }
                if let image = updatedImage {
                    if let captureProtectedContentLayer = strongSelf.captureProtectedContentLayer {
                        if let cmSampleBuffer = image.cmSampleBuffer {
                            captureProtectedContentLayer.enqueue(cmSampleBuffer)
                        }
                    } else {
                        strongSelf.contents = image.cgImage
                    }
                    strongSelf.image = image
                    strongSelf.currentArguments = arguments
                    if let _ = strongSelf.overlayColor {
                        strongSelf.applyOverlayColor(animated: false)
                    }
                }
                strongSelf.argumentsPromise.set(arguments)
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

private class CaptureProtectedContentLayer: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }
}

open class TransformImageView: UIView {
    public var imageUpdated: ((UIImage?) -> Void)?
    public var contentAnimations: TransformImageNodeContentAnimations = []
    private var disposable = MetaDisposable()

    private var currentTransform: ((TransformImageArguments) -> DrawingContext?)?
    private var currentArguments: TransformImageArguments?
    private var argumentsPromise = ValuePromise<TransformImageArguments>(ignoreRepeated: true)
    public private(set) var image: UIImage?

    private var captureProtectedContentLayer: CaptureProtectedContentLayer?

    private var overlayColor: UIColor?
    private var overlayView: UIView?
    
    open override var bounds: CGRect {
        didSet {
            if let captureProtectedContentLayer = self.captureProtectedContentLayer, super.bounds.size != oldValue.size {
                captureProtectedContentLayer.frame = super.bounds
            }
        }
    }

    open override var frame: CGRect {
        didSet {
            if let overlayView = self.overlayView {
                overlayView.frame = self.bounds
            }
            if let captureProtectedContentLayer = self.captureProtectedContentLayer, super.bounds.size != oldValue.size {
                captureProtectedContentLayer.frame = super.bounds
            }
        }
    }

    public var captureProtected: Bool = false {
        didSet {
            if self.captureProtected != oldValue {
                if self.captureProtected {
                    if self.captureProtectedContentLayer == nil {
                        let captureProtectedContentLayer = CaptureProtectedContentLayer()
                        captureProtectedContentLayer.frame = self.bounds
                        self.layer.addSublayer(captureProtectedContentLayer)
                        if let image = self.image {
                            if let cmSampleBuffer = image.cmSampleBuffer {
                                captureProtectedContentLayer.enqueue(cmSampleBuffer)
                            }
                        }
                        self.layer.contents = nil
                    }
                } else if let captureProtectedContentLayer = self.captureProtectedContentLayer {
                    self.captureProtectedContentLayer = nil
                    captureProtectedContentLayer.removeFromSuperlayer()
                    self.layer.contents = self.image?.cgImage
                }
            }
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.accessibilityIgnoresInvertColors = true
        }
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable.dispose()
    }

    public func reset() {
        self.disposable.set(nil)
        self.currentArguments = nil
        self.currentTransform = nil
        self.layer.contents = nil
        self.image = nil
        self.captureProtectedContentLayer?.flushAndRemoveImage()
    }

    public func setSignal(_ signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>, attemptSynchronously: Bool = false, dispatchOnDisplayLink: Bool = true) {
        let argumentsPromise = self.argumentsPromise

        let data = combineLatest(signal, argumentsPromise.get())

        let resultData: Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments), NoError>
        if attemptSynchronously {
            resultData = data
        } else {
            resultData = data
            |> deliverOn(Queue.concurrentDefaultQueue())
        }

        let result = resultData
        |> mapToThrottled { transform, arguments -> Signal<((TransformImageArguments) -> DrawingContext?, TransformImageArguments, UIImage?)?, NoError> in
            return deferred {
                if let context = transform(arguments) {
                    return .single((transform, arguments, context.generateImage()))
                } else {
                    return .single(nil)
                }
            }
        }

        self.disposable.set((result |> deliverOnMainQueue).start(next: { [weak self] next in
            let apply: () -> Void = {
                if let strongSelf = self {
                    if strongSelf.image == nil {
                        if strongSelf.contentAnimations.contains(.firstUpdate) && !attemptSynchronously {
                            strongSelf.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                        }
                    } else if strongSelf.contentAnimations.contains(.subsequentUpdates) {
                        if let _ = strongSelf.captureProtectedContentLayer {
                        } else {
                            let tempLayer = CALayer()
                            tempLayer.frame = strongSelf.bounds
                            tempLayer.contentsGravity = strongSelf.layer.contentsGravity
                            tempLayer.contents = strongSelf.layer.contents
                            strongSelf.layer.addSublayer(tempLayer)
                            tempLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak tempLayer] _ in
                                tempLayer?.removeFromSuperlayer()
                            })
                        }
                    }

                    var imageUpdate: UIImage?
                    if let (transform, arguments, image) = next {
                        strongSelf.currentTransform = transform
                        strongSelf.currentArguments = arguments
                        if let captureProtectedContentLayer = strongSelf.captureProtectedContentLayer {
                            if let cmSampleBuffer = image?.cmSampleBuffer {
                                captureProtectedContentLayer.enqueue(cmSampleBuffer)
                            }
                        } else {
                            strongSelf.layer.contents = image?.cgImage
                        }
                        strongSelf.image = image
                        imageUpdate = image
                    }
                    if let _ = strongSelf.overlayColor {
                        strongSelf.applyOverlayColor(animated: false)
                    }
                    if let imageUpdated = strongSelf.imageUpdated {
                        imageUpdated(imageUpdate)
                    }
                }
            }
            if dispatchOnDisplayLink && !attemptSynchronously {
                displayLinkDispatcher.dispatch {
                    apply()
                }
            } else {
                apply()
            }
        }))
    }

    public func asyncLayout() -> (TransformImageArguments) -> (() -> Void) {
        let currentTransform = self.currentTransform
        let currentArguments = self.currentArguments
        return { [weak self] arguments in
            let updatedImage: UIImage?
            if currentArguments != arguments {
                updatedImage = currentTransform?(arguments)?.generateImage()
            } else {
                updatedImage = nil
            }
            return {
                guard let strongSelf = self else {
                    return
                }
                if let image = updatedImage {
                    strongSelf.layer.contents = image.cgImage
                    strongSelf.currentArguments = arguments
                    if let _ = strongSelf.overlayColor {
                        strongSelf.applyOverlayColor(animated: false)
                    }
                }
                strongSelf.argumentsPromise.set(arguments)
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
            } else if let overlayView = self.overlayView {
                self.overlayView = nil
                if animated {
                    overlayView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak overlayView] _ in
                        overlayView?.removeFromSuperview()
                    })
                } else {
                    overlayView.removeFromSuperview()
                }
            }
        }
    }

    private func applyOverlayColor(animated: Bool) {
        if let overlayColor = self.overlayColor {
            if let image = self.image {
                if let overlayView = self.overlayView {
                    (overlayView as! UIImageView).image = UIImage(cgImage: image.cgImage!).withRenderingMode(.alwaysTemplate)
                    overlayView.tintColor = overlayColor
                } else {
                    let overlayView = UIImageView()
                    overlayView.image = UIImage(cgImage: image.cgImage!).withRenderingMode(.alwaysTemplate)
                    overlayView.tintColor = overlayColor
                    overlayView.frame = self.bounds
                    self.addSubview(overlayView)
                    self.overlayView = overlayView
                }
            }
        }
    }
}

