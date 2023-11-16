import Foundation
import UIKit
import Display
import MetalEngine
import ComponentFlow

final class MinimizedVideoContainerView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        
        init(size: CGSize, insets: UIEdgeInsets) {
            self.size = size
            self.insets = insets
        }
    }
    
    private struct VideoMetrics: Equatable {
        var resolution: CGSize
        var rotationAngle: Float
        var sourceId: Int
        
        init(resolution: CGSize, rotationAngle: Float, sourceId: Int) {
            self.resolution = resolution
            self.rotationAngle = rotationAngle
            self.sourceId = sourceId
        }
    }
    
    private let videoLayer: PrivateCallVideoLayer
    
    private var params: Params?
    private var videoMetrics: VideoMetrics?
    private var appliedVideoMetrics: VideoMetrics?
    
    var video: VideoSource? {
        didSet {
            self.video?.updated = { [weak self] in
                guard let self else {
                    return
                }
                var videoMetrics: VideoMetrics?
                if let currentOutput = self.video?.currentOutput {
                    self.videoLayer.video = currentOutput
                    videoMetrics = VideoMetrics(resolution: CGSize(width: CGFloat(currentOutput.y.width), height: CGFloat(currentOutput.y.height)), rotationAngle: currentOutput.rotationAngle, sourceId: currentOutput.sourceId)
                } else {
                    self.videoLayer.video = nil
                }
                self.videoLayer.setNeedsUpdate()
                
                if self.videoMetrics != videoMetrics {
                    self.videoMetrics = videoMetrics
                    self.update(transition: .easeInOut(duration: 0.2))
                }
            }
            var videoMetrics: VideoMetrics?
            if let currentOutput = self.video?.currentOutput {
                self.videoLayer.video = currentOutput
                videoMetrics = VideoMetrics(resolution: CGSize(width: CGFloat(currentOutput.y.width), height: CGFloat(currentOutput.y.height)), rotationAngle: currentOutput.rotationAngle, sourceId: currentOutput.sourceId)
            } else {
                self.videoLayer.video = nil
            }
            self.videoLayer.setNeedsUpdate()
            
            if self.videoMetrics != videoMetrics {
                self.videoMetrics = videoMetrics
                self.update(transition: .easeInOut(duration: 0.2))
            }
        }
    }
    
    override init(frame: CGRect) {
        self.videoLayer = PrivateCallVideoLayer()
        self.videoLayer.masksToBounds = true
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.videoLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return nil
    }
    
    private func update(transition: Transition) {
        guard let params = self.params else {
            return
        }
        self.update(params: params, transition: transition)
    }
    
    func update(size: CGSize, insets: UIEdgeInsets, transition: Transition) {
        let params = Params(size: size, insets: insets)
        if self.params == params {
            return
        }
        self.params = params
        
        self.update(params: params, transition: transition)
    }
    
    private func update(params: Params, transition: Transition) {
        guard let videoMetrics = self.videoMetrics else {
            return
        }
        
        var transition = transition
        if self.appliedVideoMetrics == nil {
            transition = .immediate
        }
        self.appliedVideoMetrics = videoMetrics
        
        var rotatedResolution = videoMetrics.resolution
        var videoIsRotated = false
        if videoMetrics.rotationAngle == Float.pi * 0.5 || videoMetrics.rotationAngle == Float.pi * 3.0 / 2.0 {
            rotatedResolution = CGSize(width: rotatedResolution.height, height: rotatedResolution.width)
            videoIsRotated = true
        }
        
        let videoSize = rotatedResolution.aspectFitted(CGSize(width: 160.0, height: 160.0))
        
        let videoResolution = rotatedResolution.aspectFittedOrSmaller(CGSize(width: 1280, height: 1280)).aspectFittedOrSmaller(CGSize(width: videoSize.width * 3.0, height: videoSize.height * 3.0))
        let rotatedVideoResolution = videoIsRotated ? CGSize(width: videoResolution.height, height: videoResolution.width) : videoResolution
        
        let rotatedVideoSize = videoIsRotated ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
        let rotatedVideoFrame = CGRect(origin: CGPoint(x: params.size.width - params.insets.right - videoSize.width, y: params.size.height - params.insets.bottom - videoSize.height), size: videoSize)
        
        transition.setPosition(layer: self.videoLayer, position: rotatedVideoFrame.center)
        transition.setBounds(layer: self.videoLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoSize))
        transition.setPosition(layer: self.videoLayer.blurredLayer, position: rotatedVideoFrame.center)
        transition.setBounds(layer: self.videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoSize))
        
        transition.setTransform(layer: self.videoLayer, transform: CATransform3DMakeRotation(CGFloat(videoMetrics.rotationAngle), 0.0, 0.0, 1.0))
        transition.setTransform(layer: self.videoLayer.blurredLayer, transform: CATransform3DMakeRotation(CGFloat(videoMetrics.rotationAngle), 0.0, 0.0, 1.0))
        
        transition.setCornerRadius(layer: self.videoLayer, cornerRadius: 10.0)
        
        self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)))
    }
}
