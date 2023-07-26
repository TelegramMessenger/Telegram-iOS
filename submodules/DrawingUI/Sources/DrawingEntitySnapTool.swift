import Foundation
import UIKit

private let snapTimeout = 1.0

class DrawingEntitySnapTool {
    enum SnapType {
        case centerX
        case centerY
        case top
        case left
        case right
        case bottom
        case rotation(CGFloat?)
        
        static var allPositionTypes: [SnapType] {
            return [
                .centerX,
                .centerY,
                .top,
                .left,
                .right,
                .bottom
            ]
        }
    }
    
    struct SnapState {
        let skipped: CGFloat
        let waitForLeave: Bool
    }
    
    private var topEdgeState: SnapState?
    private var leftEdgeState: SnapState?
    private var rightEdgeState: SnapState?
    private var bottomEdgeState: SnapState?
    
    private var xState: SnapState?
    private var yState: SnapState?
    
    private var rotationState: (angle: CGFloat, skipped: CGFloat, waitForLeave: Bool)?
    
    var onSnapUpdated: (SnapType, Bool) -> Void = { _, _ in }
    
    var previousTopEdgeSnapTimestamp: Double?
    var previousLeftEdgeSnapTimestamp: Double?
    var previousRightEdgeSnapTimestamp: Double?
    var previousBottomEdgeSnapTimestamp: Double?
    
    var previousXSnapTimestamp: Double?
    var previousYSnapTimestamp: Double?
    var previousRotationSnapTimestamp: Double?
    
    func reset() {
        self.topEdgeState = nil
        self.leftEdgeState = nil
        self.rightEdgeState = nil
        self.bottomEdgeState = nil
        self.xState = nil
        self.yState = nil
    
        for type in SnapType.allPositionTypes {
            self.onSnapUpdated(type, false)
        }
    }
    
    func rotationReset() {
        self.rotationState = nil
        self.onSnapUpdated(.rotation(nil), false)
    }
    
    func maybeSkipFromStart(entityView: DrawingEntityView, position: CGPoint) {
        self.topEdgeState = nil
        self.leftEdgeState = nil
        self.rightEdgeState = nil
        self.bottomEdgeState = nil
        
        self.xState = nil
        self.yState = nil
        
        let snapXDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        let snapYDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        
        if let snapLocation = (entityView.superview as? DrawingEntitiesView)?.getEntityCenterPosition() {
            if position.x > snapLocation.x - snapXDelta && position.x < snapLocation.x + snapXDelta {
                self.xState = SnapState(skipped: 0.0, waitForLeave: true)
            }
            
            if position.y > snapLocation.y - snapYDelta && position.y < snapLocation.y + snapYDelta {
                self.yState = SnapState(skipped: 0.0, waitForLeave: true)
            }
        }
    }
        
    func update(entityView: DrawingEntityView, velocity: CGPoint, delta: CGPoint, updatedPosition: CGPoint, size: CGSize) -> CGPoint {
        var updatedPosition = updatedPosition
        
        guard let snapCenterLocation = (entityView.superview as? DrawingEntitiesView)?.getEntityCenterPosition() else {
            return updatedPosition
        }
        let snapEdgeLocations = (entityView.superview as? DrawingEntitiesView)?.getEntityEdgePositions()
        
        let currentTimestamp = CACurrentMediaTime()
        
        let snapDelta: CGFloat = (entityView.superview?.frame.width ?? 0.0) * 0.02
        let snapVelocity: CGFloat = snapDelta * 12.0
        let snapSkipTranslation: CGFloat = snapDelta * 2.0
        
        let topPoint = updatedPosition.y - size.height / 2.0
        let leftPoint = updatedPosition.x - size.width / 2.0
        let rightPoint = updatedPosition.x + size.width / 2.0
        let bottomPoint = updatedPosition.y + size.height / 2.0
        
        func process(
            state: SnapState?,
            velocity: CGFloat,
            delta: CGFloat,
            value: CGFloat,
            snapVelocity: CGFloat,
            snapToValue: CGFloat?,
            snapDelta: CGFloat,
            snapSkipTranslation: CGFloat,
            previousSnapTimestamp: Double?,
            onSnapUpdated: (Bool) -> Void
        ) -> (
            value: CGFloat,
            state: SnapState?,
            snapTimestamp: Double?
        ) {
            var updatedValue = value
            var updatedState = state
            var updatedPreviousSnapTimestamp = previousSnapTimestamp
            if abs(velocity) < snapVelocity || state?.waitForLeave == true {
                if let snapToValue {
                    if let state {
                        let skipped = state.skipped
                        let waitForLeave = state.waitForLeave
                        if waitForLeave {
                            if value > snapToValue - snapDelta * 2.0 && value < snapToValue + snapDelta * 2.0  {
                                
                            } else {
                                updatedState = nil
                            }
                        } else if abs(skipped) < snapSkipTranslation {
                            updatedState = SnapState(skipped: skipped + delta, waitForLeave: false)
                            updatedValue = snapToValue
                        } else {
                            updatedState = SnapState(skipped: snapSkipTranslation, waitForLeave: true)
                            onSnapUpdated(false)
                        }
                    } else {
                        if value > snapToValue - snapDelta && value < snapToValue + snapDelta {
                            if let previousSnapTimestamp, currentTimestamp - previousSnapTimestamp < snapTimeout {
                                
                            } else {
                                updatedPreviousSnapTimestamp = currentTimestamp
                                updatedState = SnapState(skipped: 0.0, waitForLeave: false)
                                updatedValue = snapToValue
                                onSnapUpdated(true)
                            }
                        }
                    }
                }
            } else {
                updatedState = nil
                onSnapUpdated(false)
            }
            return (updatedValue, updatedState, updatedPreviousSnapTimestamp)
        }
        
        let (updatedXValue, updatedXState, updatedXPreviousTimestamp) = process(
            state: self.xState,
            velocity: velocity.x,
            delta: delta.x,
            value: updatedPosition.x,
            snapVelocity: snapVelocity,
            snapToValue: snapCenterLocation.x,
            snapDelta: snapDelta,
            snapSkipTranslation: snapSkipTranslation,
            previousSnapTimestamp: self.previousXSnapTimestamp,
            onSnapUpdated: { [weak self] snapped in
                self?.onSnapUpdated(.centerX, snapped)
            }
        )
        self.xState = updatedXState
        self.previousXSnapTimestamp = updatedXPreviousTimestamp
        
        let (updatedYValue, updatedYState, updatedYPreviousTimestamp) = process(
            state: self.yState,
            velocity: velocity.y,
            delta: delta.y,
            value: updatedPosition.y,
            snapVelocity: snapVelocity,
            snapToValue: snapCenterLocation.y,
            snapDelta: snapDelta,
            snapSkipTranslation: snapSkipTranslation,
            previousSnapTimestamp: self.previousYSnapTimestamp,
            onSnapUpdated: { [weak self] snapped in
                self?.onSnapUpdated(.centerY, snapped)
            }
        )
        self.yState = updatedYState
        self.previousYSnapTimestamp = updatedYPreviousTimestamp
        
        if let snapEdgeLocations {
            if updatedXState == nil {
                let (updatedXLeftEdgeValue, updatedLeftEdgeState, updatedLeftEdgePreviousTimestamp) = process(
                    state: self.leftEdgeState,
                    velocity: velocity.x,
                    delta: delta.x,
                    value: leftPoint,
                    snapVelocity: snapVelocity,
                    snapToValue: snapEdgeLocations.left,
                    snapDelta: snapDelta,
                    snapSkipTranslation: snapSkipTranslation,
                    previousSnapTimestamp: self.previousLeftEdgeSnapTimestamp,
                    onSnapUpdated: { [weak self] snapped in
                        self?.onSnapUpdated(.left, snapped)
                    }
                )
                self.leftEdgeState = updatedLeftEdgeState
                self.previousLeftEdgeSnapTimestamp = updatedLeftEdgePreviousTimestamp
                
                if updatedLeftEdgeState != nil {
                    updatedPosition.x = updatedXLeftEdgeValue + size.width / 2.0
                    
                    self.rightEdgeState = nil
                    self.previousRightEdgeSnapTimestamp = nil
                } else {
                    let (updatedXRightEdgeValue, updatedRightEdgeState, updatedRightEdgePreviousTimestamp) = process(
                        state: self.rightEdgeState,
                        velocity: velocity.x,
                        delta: delta.x,
                        value: rightPoint,
                        snapVelocity: snapVelocity,
                        snapToValue: snapEdgeLocations.right,
                        snapDelta: snapDelta,
                        snapSkipTranslation: snapSkipTranslation,
                        previousSnapTimestamp: self.previousRightEdgeSnapTimestamp,
                        onSnapUpdated: { [weak self] snapped in
                            self?.onSnapUpdated(.right, snapped)
                        }
                    )
                    self.rightEdgeState = updatedRightEdgeState
                    self.previousRightEdgeSnapTimestamp = updatedRightEdgePreviousTimestamp
                    
                    updatedPosition.x = updatedXRightEdgeValue - size.width / 2.0
                }
            } else {
                updatedPosition.x = updatedXValue
            }
            
            if updatedYState == nil {
                let (updatedYTopEdgeValue, updatedTopEdgeState, updatedTopEdgePreviousTimestamp) = process(
                    state: self.topEdgeState,
                    velocity: velocity.y,
                    delta: delta.y,
                    value: topPoint,
                    snapVelocity: snapVelocity,
                    snapToValue: snapEdgeLocations.top,
                    snapDelta: snapDelta,
                    snapSkipTranslation: snapSkipTranslation,
                    previousSnapTimestamp: self.previousTopEdgeSnapTimestamp,
                    onSnapUpdated: { [weak self] snapped in
                        self?.onSnapUpdated(.top, snapped)
                    }
                )
                self.topEdgeState = updatedTopEdgeState
                self.previousTopEdgeSnapTimestamp = updatedTopEdgePreviousTimestamp
                
                if updatedTopEdgeState != nil {
                    updatedPosition.y = updatedYTopEdgeValue + size.height / 2.0
                    
                    self.bottomEdgeState = nil
                    self.previousBottomEdgeSnapTimestamp = nil
                } else {
                    let (updatedYBottomEdgeValue, updatedBottomEdgeState, updatedBottomEdgePreviousTimestamp) = process(
                        state: self.bottomEdgeState,
                        velocity: velocity.y,
                        delta: delta.y,
                        value: bottomPoint,
                        snapVelocity: snapVelocity,
                        snapToValue: snapEdgeLocations.bottom,
                        snapDelta: snapDelta,
                        snapSkipTranslation: snapSkipTranslation,
                        previousSnapTimestamp: self.previousBottomEdgeSnapTimestamp,
                        onSnapUpdated: { [weak self] snapped in
                            self?.onSnapUpdated(.bottom, snapped)
                        }
                    )
                    self.bottomEdgeState = updatedBottomEdgeState
                    self.previousBottomEdgeSnapTimestamp = updatedBottomEdgePreviousTimestamp
                    
                    updatedPosition.y = updatedYBottomEdgeValue - size.height / 2.0
                }
            } else {
                updatedPosition.y = updatedYValue
            }
        } else {
            updatedPosition.x = updatedXValue
            updatedPosition.y = updatedYValue
        }
        
        return updatedPosition
    }
    
    private let snapRotations: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    func maybeSkipFromStart(entityView: DrawingEntityView, rotation: CGFloat) {
        self.rotationState = nil
        
        let snapDelta: CGFloat = 0.01
        for snapRotation in self.snapRotations {
            let snapRotation = snapRotation * .pi
            if rotation > snapRotation - snapDelta && rotation < snapRotation + snapDelta {
                self.rotationState = (snapRotation, 0.0, true)
                break
            }
        }
    }
    
    func update(entityView: DrawingEntityView, velocity: CGFloat, delta: CGFloat, updatedRotation: CGFloat, skipMultiplier: CGFloat = 1.0) -> CGFloat {
        var updatedRotation = updatedRotation
        if updatedRotation < 0.0 {
            updatedRotation = 2.0 * .pi + updatedRotation
        } else if updatedRotation > 2.0 * .pi {
            while updatedRotation > 2.0 * .pi {
                updatedRotation -= 2.0 * .pi
            }
        }
        
        let currentTimestamp = CACurrentMediaTime()
        
        let snapDelta: CGFloat = 0.01
        let snapVelocity: CGFloat = snapDelta * 35.0
        let snapSkipRotation: CGFloat = snapDelta * 45.0 * skipMultiplier
        
        if abs(velocity) < snapVelocity || self.rotationState?.waitForLeave == true {
            if let (snapRotation, skipped, waitForLeave) = self.rotationState {
                if waitForLeave {
                    if updatedRotation > snapRotation - snapDelta * 2.0 && updatedRotation < snapRotation + snapDelta {
                        
                    } else {
                        self.rotationState = nil
                    }
                } else if abs(skipped) < snapSkipRotation {
                    self.rotationState = (snapRotation, skipped + delta, false)
                    updatedRotation = snapRotation
                } else {
                    self.rotationState = (snapRotation, snapSkipRotation, true)
                    self.onSnapUpdated(.rotation(nil), false)
                }
            } else {
                for snapRotation in self.snapRotations {
                    let snapRotation = snapRotation * .pi
                    if updatedRotation > snapRotation - snapDelta && updatedRotation < snapRotation + snapDelta {
                        if let previousRotationSnapTimestamp, currentTimestamp - previousRotationSnapTimestamp < snapTimeout {
                            
                        } else {
                            self.previousRotationSnapTimestamp = currentTimestamp
                            self.rotationState = (snapRotation, 0.0, false)
                            updatedRotation = snapRotation
                            self.onSnapUpdated(.rotation(snapRotation), true)
                        }
                        break
                    }
                }
            }
        } else {
            self.rotationState = nil
            self.onSnapUpdated(.rotation(nil), false)
        }
        
        return updatedRotation
    }
}
