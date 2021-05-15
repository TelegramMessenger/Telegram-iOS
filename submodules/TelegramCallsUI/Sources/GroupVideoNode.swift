import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext

final class GroupVideoNode: ASDisplayNode {
    private let videoViewContainer: UIView
    private let videoView: PresentationCallVideoView
    
    private let backdropVideoViewContainer: UIView
    private let backdropVideoView: PresentationCallVideoView?
    private var backdropEffectView: UIVisualEffectView?
    
    private var effectView: UIVisualEffectView?
    private var isBlurred: Bool = false
    
    private var validLayout: (CGSize, Bool)?
    
    var tapped: (() -> Void)?
    
    private let readyPromise = ValuePromise(false)
    var ready: Signal<Bool, NoError> {
        return self.readyPromise.get()
    }
    
    init(videoView: PresentationCallVideoView, backdropVideoView: PresentationCallVideoView?) {
        self.videoViewContainer = UIView()
        self.videoView = videoView
        
        self.backdropVideoViewContainer = UIView()
        self.backdropVideoView = backdropVideoView
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        if let backdropVideoView = backdropVideoView {
            self.backdropVideoViewContainer.addSubview(backdropVideoView.view)
            self.view.addSubview(self.backdropVideoViewContainer)
            
            if #available(iOS 13.0, *) {
                let backdropEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
                self.view.addSubview(backdropEffectView)
                self.backdropEffectView = backdropEffectView
            } else {
            }
        }
        
        self.videoViewContainer.addSubview(self.videoView.view)
        self.view.addSubview(self.videoViewContainer)
        
        self.clipsToBounds = true
        
        videoView.setOnFirstFrameReceived({ [weak self] _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.readyPromise.set(true)
                if let (size, isLandscape) = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, isLandscape: isLandscape, transition: .immediate)
                }
            }
        })
        
        videoView.setOnOrientationUpdated({ [weak self] _, _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let (size, isLandscape) = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, isLandscape: isLandscape, transition: .immediate)
                }
            }
        })
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func updateIsBlurred(isBlurred: Bool, light: Bool = false, animated: Bool = true) {
        if self.isBlurred == isBlurred {
            return
        }
        self.isBlurred = isBlurred
        
        if isBlurred {
            if self.effectView == nil {
                let effectView = UIVisualEffectView()
                self.effectView = effectView
                effectView.frame = self.bounds
                self.view.addSubview(effectView)
            }
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    self.effectView?.effect = UIBlurEffect(style: light ? .light : .dark)
                })
            } else {
                self.effectView?.effect = UIBlurEffect(style: light ? .light : .dark)
            }
        } else if let effectView = self.effectView {
            self.effectView = nil
            UIView.animate(withDuration: 0.3, animations: {
                effectView.effect = nil
            }, completion: { [weak effectView] _ in
                effectView?.removeFromSuperview()
            })
        }
    }
    
    func flip(withBackground: Bool) {
        if withBackground {
            self.backgroundColor = .black
        }
        UIView.transition(with: withBackground ? self.videoViewContainer : self.view, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
            UIView.performWithoutAnimation {
                self.updateIsBlurred(isBlurred: true, light: true, animated: false)
            }
        }) { finished in
            self.backgroundColor = nil
            Queue.mainQueue().after(0.5) {
                self.updateIsBlurred(isBlurred: false)
            }
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
    
    func updateLayout(size: CGSize, isLandscape: Bool, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, isLandscape)
        transition.updateFrameAsPositionAndBounds(layer: self.videoViewContainer.layer, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrameAsPositionAndBounds(layer: self.backdropVideoViewContainer.layer, frame: CGRect(origin: CGPoint(), size: size))
        
        let orientation = self.videoView.getOrientation()
        var aspect = self.videoView.getAspect()
        if aspect <= 0.01 {
            aspect = 3.0 / 4.0
        }
        
        let rotatedAspect: CGFloat
        let angle: CGFloat
        let switchOrientation: Bool
        switch orientation {
        case .rotation0:
            angle = 0.0
            rotatedAspect = 1 / aspect
            switchOrientation = false
        case .rotation90:
            angle = CGFloat.pi / 2.0
            rotatedAspect = aspect
            switchOrientation = true
        case .rotation180:
            angle = CGFloat.pi
            rotatedAspect = 1 / aspect
            switchOrientation = false
        case .rotation270:
            angle = CGFloat.pi * 3.0 / 2.0
            rotatedAspect = aspect
            switchOrientation = true
        }
        
        var rotatedVideoSize = CGSize(width: 100.0, height: rotatedAspect * 100.0)
    
        var containerSize = size
        if switchOrientation {
            rotatedVideoSize = CGSize(width: rotatedVideoSize.height, height: rotatedVideoSize.width)
            containerSize = CGSize(width: containerSize.height, height: containerSize.width)
        }
        
        let fittedSize = rotatedVideoSize.aspectFitted(containerSize)
        let filledSize = rotatedVideoSize.aspectFilled(containerSize)
        
        if isLandscape {
            rotatedVideoSize = fittedSize
        } else {
            rotatedVideoSize = filledSize
        }

        var rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((size.width - rotatedVideoSize.width) / 2.0), y: floor((size.height - rotatedVideoSize.height) / 2.0)), size: rotatedVideoSize)
        rotatedVideoFrame.origin.x = floor(rotatedVideoFrame.origin.x)
        rotatedVideoFrame.origin.y = floor(rotatedVideoFrame.origin.y)
        rotatedVideoFrame.size.width = ceil(rotatedVideoFrame.size.width)
        rotatedVideoFrame.size.height = ceil(rotatedVideoFrame.size.height)
        
        let videoSize = rotatedVideoFrame.size.aspectFilled(CGSize(width: 1080.0, height: 1080.0))
        transition.updatePosition(layer: self.videoView.view.layer, position: rotatedVideoFrame.center)
        transition.updateBounds(layer: self.videoView.view.layer, bounds: CGRect(origin: CGPoint(), size: videoSize))
        
        let transformScale: CGFloat = rotatedVideoFrame.width / videoSize.width
        transition.updateTransformScale(layer: self.videoViewContainer.layer, scale: transformScale)
        
        let transition: ContainedViewLayoutTransition = .immediate
        transition.updateTransformRotation(view: self.videoView.view, angle: angle)

        if let backdropVideoView = self.backdropVideoView {
            rotatedVideoSize = filledSize
            var rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((size.width - rotatedVideoSize.width) / 2.0), y: floor((size.height - rotatedVideoSize.height) / 2.0)), size: rotatedVideoSize)
            rotatedVideoFrame.origin.x = floor(rotatedVideoFrame.origin.x)
            rotatedVideoFrame.origin.y = floor(rotatedVideoFrame.origin.y)
            rotatedVideoFrame.size.width = ceil(rotatedVideoFrame.size.width)
            rotatedVideoFrame.size.height = ceil(rotatedVideoFrame.size.height)
            
            let videoSize = rotatedVideoFrame.size.aspectFilled(CGSize(width: 1080.0, height: 1080.0))
            transition.updatePosition(layer: backdropVideoView.view.layer, position: rotatedVideoFrame.center)
            transition.updateBounds(layer: backdropVideoView.view.layer, bounds: CGRect(origin: CGPoint(), size: videoSize))
            
            let transformScale: CGFloat = rotatedVideoFrame.width / videoSize.width
            transition.updateTransformScale(layer: self.backdropVideoViewContainer.layer, scale: transformScale)
            
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateTransformRotation(view: backdropVideoView.view, angle: angle)
        }
        
        if let backdropEffectView = self.backdropEffectView {
            transition.updateFrame(view: backdropEffectView, frame: self.bounds)
        }
        
        if let effectView = self.effectView {
            transition.updateFrame(view: effectView, frame: self.bounds)
        }
        
        // TODO: properly fix the issue
        // On iOS 13 and later metal layer transformation is broken if the layer does not require compositing
        self.videoView.view.alpha = 0.995
    }
}
