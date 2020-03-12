import Foundation
import UIKit
import Display
import AsyncDisplayKit

public final class ReactionSwipeGestureRecognizer: UIPanGestureRecognizer {
    private var validatedGesture = false
    
    private var firstLocation: CGPoint = CGPoint()
    private var currentLocation: CGPoint = CGPoint()
    private var currentReactions: [ReactionGestureItem] = []
    private var isActivated = false
    private var isAwaitingCompletion = false
    private weak var currentContainer: ReactionSelectionParentNode?
    private var activationTimer: Timer?
    
    public var availableReactions: (() -> [ReactionGestureItem])?
    public var getReactionContainer: (() -> ReactionSelectionParentNode?)?
    public var getAnchorPoint: (() -> CGPoint?)?
    public var shouldElevateAnchorPoint: (() -> Bool)?
    public var began: (() -> Void)?
    public var updateOffset: ((CGFloat, Bool) -> Void)?
    public var completed: ((ReactionGestureItem?) -> Void)?
    public var displayReply: ((CGFloat) -> Void)?
    public var activateReply: (() -> Void)?
    
    private var currentAnchorPoint: CGPoint?
    private var currentAnchorStartPoint: CGPoint?
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override public func reset() {
        super.reset()
        
        self.validatedGesture = false
        self.currentReactions = []
        self.isActivated = false
        self.isAwaitingCompletion = false
        self.activationTimer?.invalidate()
        self.activationTimer = nil
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let availableReactions = self.availableReactions?(), !availableReactions.isEmpty {
            self.currentReactions = availableReactions
            let touch = touches.first!
            self.firstLocation = touch.location(in: nil)
            self.currentLocation = self.firstLocation
        } else {
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.isAwaitingCompletion {
            return
        }
        guard let _ = self.view else {
            return
        }
        guard let location = touches.first?.location(in: nil) else {
            return
        }
        self.currentLocation = location
        
        var translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
        
        let absTranslationX: CGFloat = abs(translation.x)
        let absTranslationY: CGFloat = abs(translation.y)
        
        var updatedOffset = false
        
        if !self.validatedGesture {
            if translation.x > 0.0 {
                self.state = .failed
            } else if absTranslationY > 2.0 && absTranslationY > absTranslationX * 2.0 {
                self.state = .failed
            } else if absTranslationX > 2.0 && absTranslationY * 2.0 < absTranslationX {
                self.validatedGesture = true
                self.firstLocation = location
                translation = CGPoint()
                self.began?()
                self.updateOffset?(0.0, false)
                updatedOffset = true
                
                self.activationTimer?.invalidate()
                final class TimerTarget: NSObject {
                    let f: () -> Void
                    
                    init(_ f: @escaping () -> Void) {
                        self.f = f
                    }
                    
                    @objc func event() {
                        self.f()
                    }
                }
                let elevate = self.shouldElevateAnchorPoint?() ?? false
                
                let activationTimer = Timer(timeInterval: elevate ? 0.15 : 0.01, target: TimerTarget { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.activationTimer = nil
                    if strongSelf.validatedGesture {
                        let location = strongSelf.currentLocation
                        if !strongSelf.currentReactions.isEmpty, let reactionContainer = strongSelf.getReactionContainer?(), let localAnchorPoint = strongSelf.getAnchorPoint?() {
                            strongSelf.currentContainer = reactionContainer
                            //let reactionContainerLocation = reactionContainer.view.convert(localAnchorPoint, from: strongSelf.view)
                            let elevate = strongSelf.shouldElevateAnchorPoint?() ?? false
                            let reactionContainerLocation = reactionContainer.view.convert(location, from: nil).offsetBy(dx: 0.0, dy: elevate ? -44.0 : 22.0)
                            let reactionContainerTouchPoint = reactionContainer.view.convert(location, from: nil)
                            strongSelf.currentAnchorPoint = reactionContainerLocation
                            strongSelf.currentAnchorStartPoint = location
                            reactionContainer.displayReactions(strongSelf.currentReactions, at: reactionContainerLocation, touchPoint: reactionContainerTouchPoint)
                        }
                    }
                }, selector: #selector(TimerTarget.event), userInfo: nil, repeats: false)
                self.activationTimer = activationTimer
                RunLoop.main.add(activationTimer, forMode: .common)
            }
        }
        
        if self.validatedGesture {
            if !updatedOffset {
                self.updateOffset?(-min(0.0, translation.x), false)
            }
            if !self.isActivated {
                if absTranslationX > 40.0 {
                    self.isActivated = true
                    self.displayReply?(-min(0.0, translation.x))
                }
            } else {
                if let reactionContainer = self.currentContainer, let currentAnchorPoint = self.currentAnchorPoint, let currentAnchorStartPoint = self.currentAnchorStartPoint {
                    let anchorPoint = CGPoint(x: currentAnchorPoint.x + location.x - currentAnchorStartPoint.x, y: currentAnchorPoint.y)
                    let reactionContainerLocation = anchorPoint
                    let reactionContainerTouchPoint = reactionContainer.view.convert(location, from: nil)
                    reactionContainer.updateReactionsAnchor(point: reactionContainerLocation, touchPoint: reactionContainerTouchPoint)
                }
            }
            super.touchesMoved(touches, with: event)
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.isAwaitingCompletion {
            return
        }
        guard let location = touches.first?.location(in: nil) else {
            return
        }
        if self.validatedGesture {
            let translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
            if let reaction = self.currentContainer?.selectedReaction() {
                self.isAwaitingCompletion = true
                self.completed?(reaction)
            } else {
                if translation.x < -40.0 {
                    self.currentContainer?.dismissReactions(into: nil, hideTarget: false)
                    self.activateReply?()
                    self.state = .ended
                } else {
                    self.currentContainer?.dismissReactions(into: nil, hideTarget: false)
                    self.completed?(nil)
                    self.state = .cancelled
                    super.touchesEnded(touches, with: event)
                }
            }
        } else {
            self.currentContainer?.dismissReactions(into: nil, hideTarget: false)
            self.state = .cancelled
            super.touchesEnded(touches, with: event)
        }
    }
    
    public func complete(into targetNode: ASDisplayNode?, hideTarget: Bool) {
        if self.isAwaitingCompletion {
            self.currentContainer?.dismissReactions(into: targetNode, hideTarget: hideTarget)
            self.state = .ended
        }
    }
    
    public func cancel() {
        self.state = .cancelled
    }
}
