import Foundation
import UIKit
import Display
import ComponentFlow
import MetalEngine

private let shadowImage: UIImage? = {
    UIImage(named: "Call/VideoGradient")?.precomposed()
}()

final class VideoContainerView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        var cornerRadius: CGFloat
        var isMinimized: Bool
        var isAnimatingOut: Bool
        
        init(size: CGSize, insets: UIEdgeInsets, cornerRadius: CGFloat, isMinimized: Bool, isAnimatingOut: Bool) {
            self.size = size
            self.insets = insets
            self.cornerRadius = cornerRadius
            self.isMinimized = isMinimized
            self.isAnimatingOut = isAnimatingOut
        }
    }
    
    private struct VideoMetrics: Equatable {
        var resolution: CGSize
        var rotationAngle: Float
        
        init(resolution: CGSize, rotationAngle: Float) {
            self.resolution = resolution
            self.rotationAngle = rotationAngle
        }
    }
    
    private let videoLayer: PrivateCallVideoLayer
    let blurredContainerLayer: SimpleLayer
    
    private let topShadowView: UIImageView
    private let bottomShadowView: UIImageView
    
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
                    videoMetrics = VideoMetrics(resolution: CGSize(width: CGFloat(currentOutput.y.width), height: CGFloat(currentOutput.y.height)), rotationAngle: currentOutput.rotationAngle)
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
                videoMetrics = VideoMetrics(resolution: CGSize(width: CGFloat(currentOutput.y.width), height: CGFloat(currentOutput.y.height)), rotationAngle: currentOutput.rotationAngle)
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
        self.blurredContainerLayer = SimpleLayer()
        
        self.topShadowView = UIImageView()
        self.topShadowView.transform = CGAffineTransformMakeScale(1.0, -1.0)
        self.bottomShadowView = UIImageView()
        
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.black
        self.blurredContainerLayer.backgroundColor = UIColor.black.cgColor
        
        self.layer.addSublayer(self.videoLayer)
        self.blurredContainerLayer.addSublayer(self.videoLayer.blurredLayer)
        
        self.topShadowView.image = shadowImage
        self.bottomShadowView.image = shadowImage
        self.addSubview(self.topShadowView)
        self.addSubview(self.bottomShadowView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func update(transition: Transition) {
        guard let params = self.params else {
            return
        }
        self.update(params: params, transition: transition)
    }
    
    func update(size: CGSize, insets: UIEdgeInsets, cornerRadius: CGFloat, isMinimized: Bool, isAnimatingOut: Bool, transition: Transition) {
        let params = Params(size: size, insets: insets, cornerRadius: cornerRadius, isMinimized: isMinimized, isAnimatingOut: isAnimatingOut)
        if self.params == params {
            return
        }
        
        self.layer.masksToBounds = true
        if self.layer.animation(forKey: "cornerRadius") == nil {
            self.layer.cornerRadius = self.params?.cornerRadius ?? 0.0
        }
        
        self.params = params
        
        transition.setCornerRadius(layer: self.layer, cornerRadius: params.cornerRadius, completion: { [weak self] completed in
            guard let self, let params = self.params, completed else {
                return
            }
            if !params.isAnimatingOut {
                self.layer.masksToBounds = false
                self.layer.cornerRadius = 0.0
            }
        })
        
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
        
        if params.isMinimized {
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
            let effectiveVideoFrame = videoSize.centered(around: rotatedVideoFrame.center)
            
            transition.setPosition(layer: self.videoLayer, position: rotatedVideoFrame.center)
            transition.setBounds(layer: self.videoLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoSize))
            transition.setPosition(layer: self.videoLayer.blurredLayer, position: rotatedVideoFrame.center)
            transition.setBounds(layer: self.videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoSize))
            
            transition.setTransform(layer: self.videoLayer, transform: CATransform3DMakeRotation(CGFloat(videoMetrics.rotationAngle), 0.0, 0.0, 1.0))
            transition.setTransform(layer: self.videoLayer.blurredLayer, transform: CATransform3DMakeRotation(CGFloat(videoMetrics.rotationAngle), 0.0, 0.0, 1.0))
            
            transition.setCornerRadius(layer: self.videoLayer, cornerRadius: 10.0)
            
            self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)))
            
            let topShadowHeight: CGFloat = floor(effectiveVideoFrame.height * 0.2)
            let topShadowFrame = CGRect(origin: effectiveVideoFrame.origin, size: CGSize(width: effectiveVideoFrame.width, height: topShadowHeight))
            transition.setPosition(view: self.topShadowView, position: topShadowFrame.center)
            transition.setBounds(view: self.topShadowView, bounds: CGRect(origin: CGPoint(x: effectiveVideoFrame.minX, y: effectiveVideoFrame.maxY - topShadowHeight), size: topShadowFrame.size))
            transition.setAlpha(view: self.topShadowView, alpha: 0.0)
            
            let bottomShadowHeight: CGFloat = 200.0
            transition.setFrame(view: self.bottomShadowView, frame: CGRect(origin: CGPoint(x: 0.0, y: params.size.height - bottomShadowHeight), size: CGSize(width: params.size.width, height: bottomShadowHeight)))
            transition.setAlpha(view: self.bottomShadowView, alpha: 0.0)
        } else {
            var rotatedResolution = videoMetrics.resolution
            var videoIsRotated = false
            if videoMetrics.rotationAngle == Float.pi * 0.5 || videoMetrics.rotationAngle == Float.pi * 3.0 / 2.0 {
                rotatedResolution = CGSize(width: rotatedResolution.height, height: rotatedResolution.width)
                videoIsRotated = true
            }
            
            var videoSize = rotatedResolution.aspectFitted(params.size)
            let boundingAspectRatio = params.size.width / params.size.height
            let videoAspectRatio = videoSize.width / videoSize.height
            if abs(boundingAspectRatio - videoAspectRatio) < 0.15 {
                videoSize = rotatedResolution.aspectFilled(params.size)
            }
            
            let videoResolution = rotatedResolution.aspectFittedOrSmaller(CGSize(width: 1280, height: 1280)).aspectFittedOrSmaller(CGSize(width: videoSize.width * 3.0, height: videoSize.height * 3.0))
            let rotatedVideoResolution = videoIsRotated ? CGSize(width: videoResolution.height, height: videoResolution.width) : videoResolution
            
            let rotatedVideoSize = videoIsRotated ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
            let rotatedBoundingSize = params.size
            let rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((rotatedBoundingSize.width - rotatedVideoSize.width) * 0.5), y: floor((rotatedBoundingSize.height - rotatedVideoSize.height) * 0.5)), size: rotatedVideoSize)
            
            transition.setPosition(layer: self.videoLayer, position: rotatedVideoFrame.center)
            transition.setBounds(layer: self.videoLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoFrame.size))
            transition.setPosition(layer: self.videoLayer.blurredLayer, position: rotatedVideoFrame.center)
            transition.setBounds(layer: self.videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoFrame.size))
            
            transition.setTransform(layer: self.videoLayer, transform: CATransform3DMakeRotation(CGFloat(videoMetrics.rotationAngle), 0.0, 0.0, 1.0))
            transition.setTransform(layer: self.videoLayer.blurredLayer, transform: CATransform3DMakeRotation(CGFloat(videoMetrics.rotationAngle), 0.0, 0.0, 1.0))
            
            if !params.isAnimatingOut {
                self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)))
            }
            
            let topShadowHeight: CGFloat = 200.0
            let topShadowFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.size.width, height: topShadowHeight))
            transition.setPosition(view: self.topShadowView, position: topShadowFrame.center)
            transition.setBounds(view: self.topShadowView, bounds: CGRect(origin: CGPoint(), size: topShadowFrame.size))
            transition.setAlpha(view: self.topShadowView, alpha: 1.0)
            
            let bottomShadowHeight: CGFloat = 200.0
            transition.setFrame(view: self.bottomShadowView, frame: CGRect(origin: CGPoint(x: 0.0, y: params.size.height - bottomShadowHeight), size: CGSize(width: params.size.width, height: bottomShadowHeight)))
            transition.setAlpha(view: self.bottomShadowView, alpha: 1.0)
        }
    }
}
