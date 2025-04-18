import Foundation
import UIKit
import Display
import BatchVideoRendering
import AccountContext
import TelegramCore
import AVFoundation
import SwiftSignalKit
import PhotoResources

open class GifVideoLayer: AVSampleBufferDisplayLayer, BatchVideoRenderingContext.Target {
    private let context: AccountContext
    private let batchVideoContext: BatchVideoRenderingContext
    private let userLocation: MediaResourceUserLocation
    private let file: FileMediaReference?
    
    private var batchVideoTargetHandle: BatchVideoRenderingContext.TargetHandle?
    public var batchVideoRenderingTargetState: BatchVideoRenderingContext.TargetState?
    
    private var thumbnailDisposable: Disposable?
    
    private var isReadyToRender: Bool = false
    
    public var started: (() -> Void)?
    
    public var shouldBeAnimating: Bool = false {
        didSet {
            if self.shouldBeAnimating == oldValue {
                return
            }
            self.updateShouldBeRendering()
        }
    }
    
    public init(context: AccountContext, batchVideoContext: BatchVideoRenderingContext, userLocation: MediaResourceUserLocation, file: FileMediaReference?, synchronousLoad: Bool) {
        self.context = context
        self.batchVideoContext = batchVideoContext
        self.userLocation = userLocation
        self.file = file
        
        super.init()
        
        self.videoGravity = .resizeAspectFill
        
        if let file = self.file {
            if let dimensions = file.media.dimensions {
                self.thumbnailDisposable = (mediaGridMessageVideo(postbox: context.account.postbox, userLocation: userLocation, videoReference: file, synchronousLoad: synchronousLoad, nilForEmptyResult: true)
                |> deliverOnMainQueue).start(next: { [weak self] transform in
                    guard let strongSelf = self else {
                        return
                    }
                    let boundingSize = CGSize(width: 93.0, height: 93.0)
                    let imageSize = dimensions.cgSize.aspectFilled(boundingSize)
                    
                    if let image = transform(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), resizeMode: .fill(.clear)))?.generateImage() {
                        Queue.mainQueue().async {
                            if let strongSelf = self {
                                strongSelf.contents = image.cgImage
                                strongSelf.setupVideo()
                                strongSelf.started?()
                            }
                        }
                    } else {
                        strongSelf.setupVideo()
                    }
                })
            } else {
                self.setupVideo()
            }
        }
    }
    
    override public init(layer: Any) {
        guard let layer = layer as? GifVideoLayer else {
            preconditionFailure()
        }
        
        self.context = layer.context
        self.batchVideoContext = layer.batchVideoContext
        self.userLocation = layer.userLocation
        self.file = layer.file
        
        super.init(layer: layer)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.thumbnailDisposable?.dispose()
    }
    
    private func setupVideo() {
        self.isReadyToRender = true
        self.updateShouldBeRendering()
    }
    
    private func updateShouldBeRendering() {
        let shouldBeRendering = self.shouldBeAnimating && self.isReadyToRender
        
        if shouldBeRendering, let file = self.file {
            if self.batchVideoTargetHandle == nil {
                self.batchVideoTargetHandle = self.batchVideoContext.add(target: self, file: file, userLocation: self.userLocation)
            }
        } else {
            self.batchVideoTargetHandle = nil
        }
    }
    
    public func setSampleBuffer(sampleBuffer: CMSampleBuffer) {
        if #available(iOS 17.0, *) {
            self.sampleBufferRenderer.enqueue(sampleBuffer)
        } else {
            self.enqueue(sampleBuffer)
        }
    }
}
