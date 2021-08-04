import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import ContextUI

enum VideoNodeLayoutMode {
    case fillOrFitToSquare
    case fillHorizontal
    case fillVertical
    case fit
}

final class GroupVideoNode: ASDisplayNode, PreviewVideoNode {
    enum Position {
        case tile
        case list
        case mainstage
    }
    
    let sourceContainerNode: PinchSourceContainerNode
    private let containerNode: ASDisplayNode
    private let videoViewContainer: UIView
    private let videoView: VideoRenderingView

    private let debugTextNode: ImmediateTextNode
    
    private let backdropVideoViewContainer: UIView
    private let backdropVideoView: VideoRenderingView?

    private var effectView: UIVisualEffectView?
    private var isBlurred: Bool = false

    private var isEnabled: Bool = false
    private var isBlurEnabled: Bool = false
        
    private var validLayout: (CGSize, VideoNodeLayoutMode)?
    
    var tapped: (() -> Void)?
    
    private let readyPromise = ValuePromise(false)
    var ready: Signal<Bool, NoError> {
        return self.readyPromise.get()
    }
    
    public var isMainstageExclusive = false
    
    init(videoView: VideoRenderingView, backdropVideoView: VideoRenderingView?) {
        self.sourceContainerNode = PinchSourceContainerNode()
        self.containerNode = ASDisplayNode()
        self.videoViewContainer = UIView()
        self.videoViewContainer.isUserInteractionEnabled = false
        self.videoView = videoView
        
        self.backdropVideoViewContainer = UIView()
        self.backdropVideoViewContainer.isUserInteractionEnabled = false
        self.backdropVideoView = backdropVideoView

        self.debugTextNode = ImmediateTextNode()
                
        super.init()

        if let backdropVideoView = backdropVideoView {
            self.backdropVideoViewContainer.addSubview(backdropVideoView)
            self.view.addSubview(self.backdropVideoViewContainer)
        }

        self.videoViewContainer.addSubview(self.videoView)
        self.addSubnode(self.sourceContainerNode)
        self.containerNode.view.addSubview(self.videoViewContainer)
        self.containerNode.addSubnode(self.debugTextNode)
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
        self.backdropVideoView?.updateIsEnabled(isEnabled && self.isBlurEnabled)
    }
    
    func updateIsBlurred(isBlurred: Bool, light: Bool = false, animated: Bool = true) {
        if self.hasScheduledUnblur {
            self.hasScheduledUnblur = false
        }
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
    
    private var hasScheduledUnblur = false
    func flip(withBackground: Bool) {
        if withBackground {
            self.backgroundColor = .black
        }
        var snapshotView: UIView?
        if let snapshot = self.videoView.snapshotView(afterScreenUpdates: false) {
            snapshotView = snapshot
            snapshot.transform = self.videoView.transform
            snapshot.frame = self.videoView.frame
            self.videoView.superview?.insertSubview(snapshot, aboveSubview: self.videoView)
        }
        UIView.transition(with: withBackground ? self.videoViewContainer : self.view, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
            UIView.performWithoutAnimation {
                self.updateIsBlurred(isBlurred: true, light: false, animated: false)
            }
        }) { finished in
            self.backgroundColor = nil
            self.hasScheduledUnblur = true
            if let snapshotView = snapshotView {
                Queue.mainQueue().after(0.3) {
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    if self.hasScheduledUnblur {
                        self.updateIsBlurred(isBlurred: false)
                    }
                }
            } else {
                Queue.mainQueue().after(0.4) {
                    if self.hasScheduledUnblur {
                        self.updateIsBlurred(isBlurred: false)
                    }
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

    func updateDebugInfo(text: String) {
        self.debugTextNode.attributedText = NSAttributedString(string: text, font: Font.regular(14.0), textColor: .white)
        if let (size, layoutMode) = self.validLayout {
            self.updateLayout(size: size, layoutMode: layoutMode, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, layoutMode: VideoNodeLayoutMode, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, layoutMode)

        let debugTextSize = self.debugTextNode.updateLayout(CGSize(width: 200.0, height: 200.0))
        if size.height > size.width + 100.0 {
            self.debugTextNode.frame = CGRect(origin: CGPoint(x: 5.0, y: 44.0), size: debugTextSize)
        } else {
            self.debugTextNode.frame = CGRect(origin: CGPoint(x: 5.0, y: 5.0), size: debugTextSize)
        }

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

        self.videoView.alpha = 0.995
        
        let normalizedVideoSize = rotatedVideoFrame.size.aspectFilled(CGSize(width: 1080.0, height: 1080.0))
        transition.updatePosition(layer: self.videoView.layer, position: rotatedVideoFrame.center)
        transition.updateBounds(layer: self.videoView.layer, bounds: CGRect(origin: CGPoint(), size: normalizedVideoSize))
        
        let transformScale: CGFloat = rotatedVideoFrame.width / normalizedVideoSize.width
        transition.updateTransformScale(layer: self.videoViewContainer.layer, scale: transformScale)
        
        if let backdropVideoView = self.backdropVideoView {
            backdropVideoView.alpha = 0.995

            let topFrame = rotatedVideoFrame
            
            rotatedVideoSize = filledSize
            var rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((size.width - rotatedVideoSize.width) / 2.0), y: floor((size.height - rotatedVideoSize.height) / 2.0)), size: rotatedVideoSize)
            rotatedVideoFrame.origin.x = floor(rotatedVideoFrame.origin.x)
            rotatedVideoFrame.origin.y = floor(rotatedVideoFrame.origin.y)
            rotatedVideoFrame.size.width = ceil(rotatedVideoFrame.size.width)
            rotatedVideoFrame.size.height = ceil(rotatedVideoFrame.size.height)

            self.isBlurEnabled = !topFrame.contains(rotatedVideoFrame)
            
            let normalizedVideoSize = rotatedVideoFrame.size.aspectFilled(CGSize(width: 1080.0, height: 1080.0))

            let effectiveBlurEnabled = self.isEnabled && self.isBlurEnabled

            if effectiveBlurEnabled {
                self.backdropVideoView?.updateIsEnabled(true)
            }

            transition.updatePosition(layer: backdropVideoView.layer, position: rotatedVideoFrame.center, force: true, completion: { [weak self] value in
                guard let strongSelf = self, value else {
                    return
                }
                if !(strongSelf.isEnabled && strongSelf.isBlurEnabled) {
                    strongSelf.backdropVideoView?.updateIsEnabled(false)
                }
            })

            transition.updateBounds(layer: backdropVideoView.layer, bounds: CGRect(origin: CGPoint(), size: normalizedVideoSize))
            
            let transformScale: CGFloat = rotatedVideoFrame.width / normalizedVideoSize.width

            transition.updateTransformScale(layer: self.backdropVideoViewContainer.layer, scale: transformScale)
            
            let transition: ContainedViewLayoutTransition = .immediate
            transition.updateTransformRotation(view: backdropVideoView, angle: angle)
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
        transition.updateTransformRotation(view: self.videoView, angle: angle)
    }
    
    var snapshotView: UIView?
    func storeSnapshot() {
        if self.frame.size.width == 180.0 {
            self.snapshotView = self.view.snapshotView(afterScreenUpdates: false)
        }
    }
}
