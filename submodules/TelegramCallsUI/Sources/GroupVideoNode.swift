import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import ContextUI

final class GroupVideoNode: ASDisplayNode {
    static let useBlurTransparency: Bool = !UIAccessibility.isReduceTransparencyEnabled

    enum Position {
        case tile
        case list
        case mainstage
    }
    
    enum LayoutMode {
        case fillOrFitToSquare
        case fillHorizontal
        case fillVertical
        case fit
    }
    
    let sourceContainerNode: PinchSourceContainerNode
    private let containerNode: ASDisplayNode
    private let videoViewContainer: UIView
    private let videoView: PresentationCallVideoView
    
    private let backdropVideoViewContainer: UIView
    private let backdropVideoView: PresentationCallVideoView?
    private var backdropEffectView: UIVisualEffectView?
    
    private var effectView: UIVisualEffectView?
    private var isBlurred: Bool = false

    private var isEnabled: Bool = false
        
    private var validLayout: (CGSize, LayoutMode)?
    
    var tapped: (() -> Void)?
    
    private let readyPromise = ValuePromise(false)
    var ready: Signal<Bool, NoError> {
        return self.readyPromise.get()
    }
    
    public var isMainstageExclusive = false
    
    init(videoView: PresentationCallVideoView, backdropVideoView: PresentationCallVideoView?) {
        self.sourceContainerNode = PinchSourceContainerNode()
        self.containerNode = ASDisplayNode()
        self.videoViewContainer = UIView()
        self.videoViewContainer.isUserInteractionEnabled = false
        self.videoView = videoView
        
        self.backdropVideoViewContainer = UIView()
        self.backdropVideoViewContainer.isUserInteractionEnabled = false
        self.backdropVideoView = backdropVideoView
                
        super.init()
                
        if let backdropVideoView = backdropVideoView {
            self.backdropVideoViewContainer.addSubview(backdropVideoView.view)
            self.view.addSubview(self.backdropVideoViewContainer)
            
            let effect: UIVisualEffect
            if #available(iOS 13.0, *) {
                effect = UIBlurEffect(style: .systemThinMaterialDark)
            } else {
                effect = UIBlurEffect(style: .dark)
            }
            let backdropEffectView = UIVisualEffectView(effect: effect)
            self.view.addSubview(backdropEffectView)
            self.backdropEffectView = backdropEffectView
        }
        
        self.videoViewContainer.addSubview(self.videoView.view)
        self.addSubnode(self.sourceContainerNode)
        self.containerNode.view.addSubview(self.videoViewContainer)
        self.sourceContainerNode.contentNode.addSubnode(self.containerNode)
                
        self.clipsToBounds = true
        
        videoView.setOnFirstFrameReceived({ [weak self] _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.readyPromise.set(true)
                if let (size, layoutMode) = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, layoutMode: layoutMode, transition: .immediate)
                }
            }
        })
        
        videoView.setOnOrientationUpdated({ [weak self] _, _ in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                if let (size, layoutMode) = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, layoutMode: layoutMode, transition: .immediate)
                }
            }
        })
        
        self.containerNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }

    func updateIsEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled

        self.videoView.updateIsEnabled(isEnabled)
        self.backdropVideoView?.updateIsEnabled(isEnabled)
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
        var snapshotView: UIView?
        if let snapshot = self.videoView.view.snapshotView(afterScreenUpdates: false) {
            snapshotView = snapshot
            snapshot.transform = self.videoView.view.transform
            snapshot.frame = self.videoView.view.frame
            self.videoView.view.superview?.insertSubview(snapshot, aboveSubview: self.videoView.view)
        }
        UIView.transition(with: withBackground ? self.videoViewContainer : self.view, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
            UIView.performWithoutAnimation {
                self.updateIsBlurred(isBlurred: true, light: false, animated: false)
            }
        }) { finished in
            self.backgroundColor = nil
            if let snapshotView = snapshotView {
                Queue.mainQueue().after(0.3) {
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    self.updateIsBlurred(isBlurred: false)
                }
            } else {
                Queue.mainQueue().after(0.4) {
                    self.updateIsBlurred(isBlurred: false)
                }
            }
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.tapped?()
        }
    }
    
    var aspectRatio: CGFloat {
        let orientation = self.videoView.getOrientation()
        var aspect = self.videoView.getAspect()
        if aspect <= 0.01 {
            aspect = 3.0 / 4.0
        }
        let rotatedAspect: CGFloat
        switch orientation {
        case .rotation0:
            rotatedAspect = 1.0 / aspect
        case .rotation90:
            rotatedAspect = aspect
        case .rotation180:
            rotatedAspect = 1.0 / aspect
        case .rotation270:
            rotatedAspect = aspect
        }
        return rotatedAspect
    }
    
    func updateLayout(size: CGSize, layoutMode: LayoutMode, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, layoutMode)
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.sourceContainerNode.update(size: size, transition: .immediate)
        transition.updateFrameAsPositionAndBounds(node: self.sourceContainerNode, frame: bounds)
        transition.updateFrameAsPositionAndBounds(node: self.containerNode, frame: bounds)
        transition.updateFrameAsPositionAndBounds(layer: self.videoViewContainer.layer, frame: bounds)
        transition.updateFrameAsPositionAndBounds(layer: self.backdropVideoViewContainer.layer, frame: bounds)
        
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
        let videoSize = rotatedVideoSize
        
        var containerSize = size
        if switchOrientation {
            rotatedVideoSize = CGSize(width: rotatedVideoSize.height, height: rotatedVideoSize.width)
            containerSize = CGSize(width: containerSize.height, height: containerSize.width)
        }
        
        let fittedSize = rotatedVideoSize.aspectFitted(containerSize)
        let filledSize = rotatedVideoSize.aspectFilled(containerSize)
        var squareSide = size.height
        if !size.height.isZero && size.width / size.height < 1.2 {
            squareSide = max(size.width, size.height)
        }
        let filledToSquareSize = rotatedVideoSize.aspectFilled(CGSize(width: squareSide, height: squareSide))
        
        switch layoutMode {
            case .fit:
                rotatedVideoSize = fittedSize
            case .fillOrFitToSquare:
                rotatedVideoSize = filledToSquareSize
            case .fillHorizontal:
                if videoSize.width > videoSize.height {
                    rotatedVideoSize = filledSize
                } else {
                    rotatedVideoSize = fittedSize
                }
            case .fillVertical:
                if videoSize.width < videoSize.height {
                    rotatedVideoSize = filledSize
                } else {
                    rotatedVideoSize = fittedSize
                }
        }
        
        var rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((size.width - rotatedVideoSize.width) / 2.0), y: floor((size.height - rotatedVideoSize.height) / 2.0)), size: rotatedVideoSize)
        rotatedVideoFrame.origin.x = floor(rotatedVideoFrame.origin.x)
        rotatedVideoFrame.origin.y = floor(rotatedVideoFrame.origin.y)
        rotatedVideoFrame.size.width = ceil(rotatedVideoFrame.size.width)
        rotatedVideoFrame.size.height = ceil(rotatedVideoFrame.size.height)

        self.videoView.view.alpha = 0.995
        
        let normalizedVideoSize = rotatedVideoFrame.size.aspectFilled(CGSize(width: 1080.0, height: 1080.0))
        transition.updatePosition(layer: self.videoView.view.layer, position: rotatedVideoFrame.center)
        transition.updateBounds(layer: self.videoView.view.layer, bounds: CGRect(origin: CGPoint(), size: normalizedVideoSize))
        
        let transformScale: CGFloat = rotatedVideoFrame.width / normalizedVideoSize.width
        transition.updateTransformScale(layer: self.videoViewContainer.layer, scale: transformScale)
        
        if let backdropVideoView = self.backdropVideoView {
            backdropVideoView.view.alpha = 0.995

            let topFrame = rotatedVideoFrame
            
            rotatedVideoSize = filledSize
            var rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((size.width - rotatedVideoSize.width) / 2.0), y: floor((size.height - rotatedVideoSize.height) / 2.0)), size: rotatedVideoSize)
            rotatedVideoFrame.origin.x = floor(rotatedVideoFrame.origin.x)
            rotatedVideoFrame.origin.y = floor(rotatedVideoFrame.origin.y)
            rotatedVideoFrame.size.width = ceil(rotatedVideoFrame.size.width)
            rotatedVideoFrame.size.height = ceil(rotatedVideoFrame.size.height)

            let isBlurEnabled = !topFrame.contains(rotatedVideoFrame)
            
            let normalizedVideoSize = rotatedVideoFrame.size.aspectFilled(CGSize(width: 1080.0, height: 1080.0))
            if isBlurEnabled {
                self.backdropVideoView?.updateIsEnabled(self.isEnabled)
                self.backdropVideoView?.view.isHidden = false
                self.backdropEffectView?.isHidden = false
            }
            transition.updatePosition(layer: backdropVideoView.view.layer, position: rotatedVideoFrame.center, force: true, completion: { [weak self] value in
                guard let strongSelf = self, value else {
                    return
                }
                if !isBlurEnabled {
                    strongSelf.backdropVideoView?.updateIsEnabled(false)
                    strongSelf.backdropVideoView?.view.isHidden = true
                    strongSelf.backdropEffectView?.isHidden = false
                }
            })
            transition.updateBounds(layer: backdropVideoView.view.layer, bounds: CGRect(origin: CGPoint(), size: normalizedVideoSize))
            
            let transformScale: CGFloat = rotatedVideoFrame.width / normalizedVideoSize.width

            transition.updateTransformScale(layer: self.backdropVideoViewContainer.layer, scale: transformScale)
            
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateTransformRotation(view: backdropVideoView.view, angle: angle)
        }
        
        if let backdropEffectView = self.backdropEffectView {
            let maxSide = max(bounds.width, bounds.height) + 32.0
            let squareBounds = CGRect(x: (bounds.width - maxSide) / 2.0, y: (bounds.height - maxSide) / 2.0, width: maxSide, height: maxSide)
            
            if case let .animated(duration, .spring) = transition {
                UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 500.0, initialSpringVelocity: 0.0, options: .layoutSubviews, animations: {
                    backdropEffectView.frame = squareBounds
                })
            } else {
                transition.animateView {
                    backdropEffectView.frame = squareBounds
                }
            }
        }
        
        if let effectView = self.effectView {
            if case let .animated(duration, .spring) = transition {
                UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: 500.0, initialSpringVelocity: 0.0, options: .layoutSubviews, animations: {
                    effectView.frame = bounds
                })
            } else {
                transition.animateView {
                    effectView.frame = bounds
                }
            }
        }
        
        let transition: ContainedViewLayoutTransition = .immediate
        transition.updateTransformRotation(view: self.videoView.view, angle: angle)
    }
    
    var snapshotView: UIView?
    func storeSnapshot() {
        if self.frame.size.width == 180.0 {
            self.snapshotView = self.view.snapshotView(afterScreenUpdates: false)
        }
    }
}
