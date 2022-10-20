import Foundation
import UIKit
import AsyncDisplayKit
import Display

public enum RadialStatusNodeState: Equatable {
    case none
    case download(UIColor)
    case play(UIColor)
    case pause(UIColor)
    case progress(color: UIColor, lineWidth: CGFloat?, value: CGFloat?, cancelEnabled: Bool, animateRotation: Bool)
    case cloudProgress(color: UIColor, strokeBackgroundColor: UIColor, lineWidth: CGFloat, value: CGFloat?)
    case check(UIColor)
    case customIcon(UIImage)
    case secretTimeout(color: UIColor, icon: UIImage?, beginTime: Double, timeout: Double, sparks: Bool)
    
    public static func ==(lhs: RadialStatusNodeState, rhs: RadialStatusNodeState) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .download(lhsColor):
                if case let .download(rhsColor) = rhs, lhsColor.isEqual(rhsColor) {
                    return true
                } else {
                    return false
                }
            case let .play(lhsColor):
                if case let .play(rhsColor) = rhs, lhsColor.isEqual(rhsColor) {
                    return true
                } else {
                    return false
                }
            case let .pause(lhsColor):
                if case let .pause(rhsColor) = rhs, lhsColor.isEqual(rhsColor) {
                    return true
                } else {
                    return false
                }
            case let .progress(lhsColor, lhsLineWidth, lhsValue, lhsCancelEnabled, lhsAnimateRotation):
                if case let .progress(rhsColor, rhsLineWidth, rhsValue, rhsCancelEnabled, rhsAnimateRotation) = rhs, lhsColor.isEqual(rhsColor), lhsValue == rhsValue, lhsLineWidth == rhsLineWidth, lhsCancelEnabled == rhsCancelEnabled, lhsAnimateRotation == rhsAnimateRotation {
                    return true
                } else {
                    return false
                }
            case let .cloudProgress(lhsColor, lhsStrokeBackgroundColor, lhsLineWidth, lhsValue):
                if case let .cloudProgress(rhsColor, rhsStrokeBackgroundColor, rhsLineWidth, rhsValue) = rhs, lhsColor.isEqual(rhsColor), lhsStrokeBackgroundColor.isEqual(rhsStrokeBackgroundColor), lhsLineWidth.isEqual(to: rhsLineWidth), lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .check(lhsColor):
                if case let .check(rhsColor) = rhs, lhsColor.isEqual(rhsColor) {
                    return true
                } else {
                    return false
                }
            case let .customIcon(lhsImage):
                if case let .customIcon(rhsImage) = rhs, lhsImage === rhsImage {
                    return true
                } else {
                    return false
                }
            case let .secretTimeout(lhsColor, lhsIcon, lhsBeginTime, lhsTimeout, lhsSparks):
                if case let .secretTimeout(rhsColor, rhsIcon, rhsBeginTime, rhsTimeout, rhsSparks) = rhs, lhsColor.isEqual(rhsColor), lhsIcon === rhsIcon, lhsBeginTime.isEqual(to: rhsBeginTime), lhsTimeout.isEqual(to: rhsTimeout), lhsSparks == rhsSparks {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func isPrimarilyEqual(to rhs: RadialStatusNodeState) -> Bool {
        switch self {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case .download:
                if case .download = rhs{
                    return true
                } else {
                    return false
                }
            case .play:
                if case .play = rhs {
                    return true
                } else {
                    return false
                }
            case .pause:
                if case .pause = rhs {
                    return true
                } else {
                    return false
                }
            case let .progress(lhsColor, lhsLineWidth, lhsValue, lhsCancelEnabled, lhsAnimateRotation):
                if case let .progress(rhsColor, rhsLineWidth, rhsValue, rhsCancelEnabled, rhsAnimateRotation) = rhs, lhsColor.isEqual(rhsColor), lhsValue == rhsValue, lhsLineWidth == rhsLineWidth, lhsCancelEnabled == rhsCancelEnabled, lhsAnimateRotation == rhsAnimateRotation {
                    return true
                } else {
                    return false
                }
            case let .cloudProgress(lhsColor, lhsStrokeBackgroundColor, lhsLineWidth, lhsValue):
                if case let .cloudProgress(rhsColor, rhsStrokeBackgroundColor, rhsLineWidth, rhsValue) = rhs, lhsColor.isEqual(rhsColor), lhsStrokeBackgroundColor.isEqual(rhsStrokeBackgroundColor), lhsLineWidth.isEqual(to: rhsLineWidth), lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case .check:
                if case .check = rhs {
                    return true
                } else {
                    return false
                }
            case let .customIcon(lhsImage):
                if case let .customIcon(rhsImage) = rhs, lhsImage === rhsImage {
                    return true
                } else {
                    return false
                }
            case let .secretTimeout(lhsColor, lhsIcon, lhsBeginTime, lhsTimeout, lhsSparks):
                if case let .secretTimeout(rhsColor, rhsIcon, rhsBeginTime, rhsTimeout, rhsSparks) = rhs, lhsColor.isEqual(rhsColor), lhsIcon === rhsIcon, lhsBeginTime.isEqual(to: rhsBeginTime), lhsTimeout.isEqual(to: rhsTimeout), lhsSparks == rhsSparks {
                    return true
                } else {
                    return false
                }
        }
    }
    
    func backgroundColor(color: UIColor) -> UIColor? {
        switch self {
            case .none:
                return nil
            default:
                return color
        }
    }
    
    func contentNode(current: RadialStatusContentNode?, synchronous: Bool) -> RadialStatusContentNode? {
        switch self {
            case .none:
                return nil
            case let .download(color):
                return RadialDownloadContentNode(color: color)
            case let .play(color):
                return RadialStatusIconContentNode(icon: .play(color), synchronous: synchronous)
            case let .pause(color):
                return RadialStatusIconContentNode(icon: .pause(color), synchronous: synchronous)
            case let .customIcon(image):
                return RadialStatusIconContentNode(icon: .custom(image), synchronous: synchronous)
            case let .check(color):
                return RadialCheckContentNode(color: color)
            case let .progress(color, lineWidth, value, cancelEnabled, animateRotation):
                if let current = current as? RadialProgressContentNode, current.displayCancel == cancelEnabled, current.animateRotation == animateRotation {
                    if !current.color.isEqual(color) {
                        current.color = color
                    }
                    current.progress = value
                    return current
                } else {
                    let node = RadialProgressContentNode(color: color, lineWidth: lineWidth, displayCancel: cancelEnabled, animateRotation: animateRotation)
                    node.progress = value
                    return node
                }
            case let .cloudProgress(color, strokeLineColor, lineWidth, value):
                if let current = current as? RadialCloudProgressContentNode {
                    if !current.color.isEqual(color) {
                        current.color = color
                    }
                    current.progress = value
                    return current
                } else {
                    let node = RadialCloudProgressContentNode(color: color, backgroundStrokeColor: strokeLineColor, lineWidth: lineWidth)
                    node.progress = value
                    return node
                }
            case let .secretTimeout(color, icon, beginTime, timeout, sparks):
                return RadialStatusSecretTimeoutContentNode(color: color, beginTime: beginTime, timeout: timeout, icon: icon, sparks: sparks)
        }
    }
}

public final class RadialStatusNode: ASControlNode {
    public var backgroundNodeColor: UIColor {
        didSet {
            self.transitionToBackgroundColor(self.state.backgroundColor(color: self.backgroundNodeColor), previousContentNode: nil, animated: false, synchronous: false, completion: {})
        }
    }

    private let enableBlur: Bool

    public private(set) var state: RadialStatusNodeState = .none
    
    private var backgroundNode: NavigationBackgroundNode?
    private var currentBackgroundNodeColor: UIColor?

    private var contentNode: RadialStatusContentNode?
    private var nextContentNode: RadialStatusContentNode?
    
    public init(backgroundNodeColor: UIColor, enableBlur: Bool = false) {
        self.enableBlur = enableBlur
        self.backgroundNodeColor = backgroundNodeColor
        
        super.init()
    }
    
    public func transitionToState(_ state: RadialStatusNodeState, animated: Bool = true, synchronous: Bool = false, completion: @escaping () -> Void = {}) {
        var animated = animated
        if self.state != state {
            let fromState = self.state
            self.state = state
            
            if fromState.isPrimarilyEqual(to: state) {
                animated = false
            }
            
            let contentNode = state.contentNode(current: self.contentNode, synchronous: synchronous)
            if contentNode !== self.contentNode {
                self.transitionToContentNode(contentNode, state: state, fromState: fromState, backgroundColor: state.backgroundColor(color: self.backgroundNodeColor), animated: animated, synchronous: synchronous, completion: completion)
            } else {
                self.transitionToBackgroundColor(state.backgroundColor(color: self.backgroundNodeColor), previousContentNode: nil, animated: animated, synchronous: synchronous, completion: completion)
            }
        } else {
            completion()
        }
    }
    
    private func transitionToContentNode(_ node: RadialStatusContentNode?, state: RadialStatusNodeState, fromState: RadialStatusNodeState, backgroundColor: UIColor?, animated: Bool, synchronous: Bool = false, completion: @escaping () -> Void) {
        if let contentNode = self.contentNode {
            self.nextContentNode = node
            contentNode.enqueueReadyForTransition { [weak contentNode, weak self] in
                if let strongSelf = self, let previousContentNode = contentNode, strongSelf.contentNode === contentNode {
                    if animated {
                        let nextContentNode = strongSelf.nextContentNode
                        strongSelf.contentNode = nextContentNode
                        previousContentNode.prepareAnimateOut(completion: { delay in
                            if let contentNode = strongSelf.contentNode, nextContentNode === contentNode {
                                strongSelf.addSubnode(contentNode)
                                contentNode.frame = strongSelf.bounds
                                contentNode.prepareAnimateIn(from: fromState)
                                if strongSelf.isNodeLoaded {
                                    contentNode.layout()
                                    contentNode.animateIn(from: fromState, delay: delay)
                                }
                            }
                            strongSelf.transitionToBackgroundColor(strongSelf.contentNode != nil ? backgroundColor : nil, previousContentNode: previousContentNode, animated: animated, synchronous: synchronous, completion: completion)
                        })
                        previousContentNode.animateOut(to: state, completion: { [weak contentNode] in
                            if let strongSelf = self, let contentNode = contentNode {
                                if contentNode !== strongSelf.contentNode {
                                    contentNode.removeFromSupernode()
                                }
                            }
                        })
                    } else {
                        previousContentNode.removeFromSupernode()
                        strongSelf.contentNode = strongSelf.nextContentNode
                        if let contentNode = strongSelf.contentNode {
                            strongSelf.addSubnode(contentNode)
                            contentNode.frame = strongSelf.bounds
                            contentNode.prepareAnimateIn(from: fromState)
                            if strongSelf.isNodeLoaded {
                                contentNode.layout()
                            }
                        }
                        strongSelf.transitionToBackgroundColor(backgroundColor, previousContentNode: nil, animated: animated, synchronous: synchronous, completion: completion)
                    }
                }
            }
        } else {
            self.contentNode = node
            if let contentNode = self.contentNode {
                contentNode.frame = self.bounds
                contentNode.prepareAnimateIn(from: nil)
                self.addSubnode(contentNode)
                if animated, self.isNodeLoaded {
                    switch state {
                        case .check, .progress:
                            contentNode.layout()
                            contentNode.animateIn(from: fromState, delay: 0.0)
                        default:
                            break
                    }
                }
            }
            self.transitionToBackgroundColor(backgroundColor, previousContentNode: nil, animated: animated, synchronous: synchronous, completion: completion)
        }
    }
    
    private func transitionToBackgroundColor(_ color: UIColor?, previousContentNode: RadialStatusContentNode?, animated: Bool, synchronous: Bool, completion: @escaping () -> Void) {
        let currentColor = self.currentBackgroundNodeColor
        
        var updated = false
        if let color = color, let currentColor = currentColor {
            updated = !color.isEqual(currentColor)
        } else if (currentColor != nil) != (color != nil) {
            updated = true
        }
        
        if updated {
            if let color = color {
                if let backgroundNode = self.backgroundNode {
                    backgroundNode.updateColor(color: color, transition: .immediate)
                    self.currentBackgroundNodeColor = color

                    completion()
                } else {
                    let backgroundNode = NavigationBackgroundNode(color: color, enableBlur: self.enableBlur)
                    self.currentBackgroundNodeColor = color

                    backgroundNode.frame = self.bounds
                    backgroundNode.update(size: backgroundNode.bounds.size, cornerRadius: backgroundNode.bounds.size.height / 2.0, transition: .immediate)
                    self.backgroundNode = backgroundNode
                    self.insertSubnode(backgroundNode, at: 0)
                    
                    if animated {
                        backgroundNode.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2, removeOnCompletion: false)
                        backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                            completion()
                        })
                    } else {
                        completion()
                    }
                }
            } else if let backgroundNode = self.backgroundNode {
                self.backgroundNode = nil
                self.currentBackgroundNodeColor = nil
                if animated {
                    backgroundNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    previousContentNode?.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                    backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak backgroundNode] _ in
                        backgroundNode?.removeFromSupernode()
                        completion()
                    })
                } else {
                    backgroundNode.removeFromSupernode()
                    completion()
                }
            }
        } else {
            completion()
        }
    }
    
    override public func layout() {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.frame = self.bounds
            backgroundNode.update(size: backgroundNode.bounds.size, cornerRadius: backgroundNode.bounds.size.height / 2.0, transition: .immediate)
        }
        if let contentNode = self.contentNode {
            contentNode.frame = self.bounds
        }
    }
}
