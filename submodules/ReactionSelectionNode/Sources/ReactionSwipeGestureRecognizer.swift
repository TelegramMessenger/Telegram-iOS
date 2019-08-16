import Foundation
import UIKit
import Display

public final class ReactionSwipeGestureRecognizer: UIPanGestureRecognizer {
    private var validatedGesture = false
    
    private var firstLocation: CGPoint = CGPoint()
    private var currentReactions: [ReactionGestureItem] = []
    private var isActivated = false
    private weak var currentContainer: ReactionSelectionParentNode?
    
    public var availableReactions: (() -> [ReactionGestureItem])?
    public var getReactionContainer: (() -> ReactionSelectionParentNode?)?
    public var updateOffset: ((CGFloat, Bool) -> Void)?
    public var completed: (() -> Void)?
    
    override public init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        
        self.maximumNumberOfTouches = 1
    }
    
    override public func reset() {
        super.reset()
        
        self.validatedGesture = false
        self.currentReactions = []
        self.isActivated = false
    }
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        if let availableReactions = self.availableReactions?(), !availableReactions.isEmpty {
            self.currentReactions = availableReactions
            let touch = touches.first!
            self.firstLocation = touch.location(in: nil)
        } else {
            self.state = .failed
        }
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let _ = self.view else {
            return
        }
        guard let location = touches.first?.location(in: nil) else {
            return
        }
        
        let translation = CGPoint(x: location.x - self.firstLocation.x, y: location.y - self.firstLocation.y)
        
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
                self.updateOffset?(translation.x, true)
                updatedOffset = true
            }
        }
        
        if self.validatedGesture {
            if !updatedOffset {
                self.updateOffset?(-min(0.0, translation.x), false)
            }
            if !self.isActivated {
                if absTranslationX > 40.0 {
                    self.isActivated = true
                    if !self.currentReactions.isEmpty, let reactionContainer = self.getReactionContainer?() {
                        self.currentContainer = reactionContainer
                        let reactionContainerLocation = reactionContainer.view.convert(location, from: nil)
                        reactionContainer.displayReactions(self.currentReactions, at: reactionContainerLocation)
                    }
                }
            } else {
                if let reactionContainer = self.currentContainer {
                    let reactionContainerLocation = reactionContainer.view.convert(location, from: nil)
                    reactionContainer.updateReactionsAnchor(point: reactionContainerLocation)
                }
            }
            super.touchesMoved(touches, with: event)
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if self.validatedGesture {
            self.completed?()
        }
        self.currentContainer?.dismissReactions()
        self.state = .ended
        
        super.touchesEnded(touches, with: event)
    }
}
