import Foundation
import UIKit
import Display
import AsyncDisplayKit

public class AnimatedCountLabelNode: ASDisplayNode {
    public struct Layout {
        public var size: CGSize
        public var isTruncated: Bool
    }
    
    public enum Segment: Equatable {
        case number(Int, NSAttributedString)
        case text(Int, NSAttributedString)
        
        public static func ==(lhs: Segment, rhs: Segment) -> Bool {
            switch lhs {
            case let .number(number, text):
                if case let .number(rhsNumber, rhsText) = rhs, number == rhsNumber, text.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            case let .text(index, text):
                if case let .text(rhsIndex, rhsText) = rhs, index == rhsIndex, text.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    fileprivate enum ResolvedSegment: Equatable {
        public enum Key: Hashable {
            case number(Int)
            case text(Int)
        }
        
        case number(id: Int, value: Int, string: NSAttributedString)
        case text(id: Int, string: NSAttributedString)
        
        public static func ==(lhs: ResolvedSegment, rhs: ResolvedSegment) -> Bool {
            switch lhs {
            case let .number(id, number, text):
                if case let .number(rhsId, rhsNumber, rhsText) = rhs, id == rhsId, number == rhsNumber, text.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            case let .text(index, text):
                if case let .text(rhsIndex, rhsText) = rhs, index == rhsIndex, text.isEqual(to: rhsText) {
                    return true
                } else {
                    return false
                }
            }
        }
        
        public var attributedText: NSAttributedString {
            switch self {
            case let .number(_, _, text):
                return text
            case let .text(_, text):
                return text
            }
        }
        
        var key: Key {
            switch self {
            case let .number(id, _, _):
                return .number(id)
            case let .text(index, _):
                return .text(index)
            }
        }
    }
    
    fileprivate var resolvedSegments: [ResolvedSegment.Key: (ResolvedSegment, TextNode)] = [:]
    
    public var reverseAnimationDirection: Bool = false
    
    override public init() {
        super.init()
    }
    
    public func asyncLayout() -> (CGSize, [Segment]) -> (Layout, (Bool) -> Void) {
        var segmentLayouts: [ResolvedSegment.Key: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)] = [:]
        let wasEmpty = self.resolvedSegments.isEmpty
        for (segmentKey, segmentAndTextNode) in self.resolvedSegments {
            segmentLayouts[segmentKey] = TextNode.asyncLayout(segmentAndTextNode.1)
        }
        let reverseAnimationDirection = self.reverseAnimationDirection
        
        return { [weak self] size, initialSegments in
            var segments: [ResolvedSegment] = []
            loop: for segment in initialSegments {
                switch segment {
                case let .number(value, string):
                    if string.string.isEmpty {
                        continue loop
                    }
                    let attributes = string.attributes(at: 0, longestEffectiveRange: nil, in: NSRange(location: 0, length: 1))
                    
                    var remainingValue = value
                    
                    let insertPosition = segments.count
                    
                    while true {
                        let digitValue = remainingValue % 10
                        
                        segments.insert(.number(id: 1000 - segments.count, value: value, string: NSAttributedString(string: "\(digitValue)", attributes: attributes)), at: insertPosition)
                        remainingValue /= 10
                        if remainingValue == 0 {
                            break
                        }
                    }
                case let .text(id, string):
                    segments.append(.text(id: id, string: string))
                }
            }
            
            for segment in segments {
                if segmentLayouts[segment.key] == nil {
                    segmentLayouts[segment.key] = TextNode.asyncLayout(nil)
                }
            }
            
            var contentSize = CGSize()
            var remainingSize = size
            
            var calculatedSegments: [ResolvedSegment.Key: (TextNodeLayout, CGFloat, () -> TextNode)] = [:]
            var isTruncated = false
            
            var validKeys: [ResolvedSegment.Key] = []
            
            for segment in segments {
                validKeys.append(segment.key)
                let (layout, apply) = segmentLayouts[segment.key]!(TextNodeLayoutArguments(attributedString: segment.attributedText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: remainingSize, alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets(), lineColor: nil, textShadowColor: nil, textStroke: nil))
                var effectiveSegmentWidth = layout.size.width
                if case .number = segment {
                    //effectiveSegmentWidth = ceil(effectiveSegmentWidth / 2.0) * 2.0
                } else if segment.attributedText.string == " " {
                    effectiveSegmentWidth = max(effectiveSegmentWidth, 4.0)
                }
                calculatedSegments[segment.key] = (layout, effectiveSegmentWidth, apply)
                contentSize.width += effectiveSegmentWidth
                contentSize.height = max(contentSize.height, layout.size.height)
                remainingSize.width = max(0.0, remainingSize.width - layout.size.width)
                if layout.truncated {
                    isTruncated = true
                }
            }
            
            return (Layout(size: contentSize, isTruncated: isTruncated), { animated in
                guard let strongSelf = self else {
                    return
                }
                let transition: ContainedViewLayoutTransition
                if animated && !wasEmpty {
                    transition = .animated(duration: 0.2, curve: .easeInOut)
                } else {
                    transition = .immediate
                }
                
                var currentOffset = CGPoint()
                for segment in segments {
                    var animation: (CGFloat, Double)?
                    if let (currentSegment, currentTextNode) = strongSelf.resolvedSegments[segment.key] {
                        if case let .number(_, currentValue, currentString) = currentSegment, case let .number(_, updatedValue, updatedString) = segment, animated, !wasEmpty, currentValue != updatedValue, currentString.string != updatedString.string, let snapshot = currentTextNode.layer.snapshotContentTree() {
                            var fromAlpha: CGFloat = 1.0
                            if let presentation = currentTextNode.layer.presentation() {
                                fromAlpha = CGFloat(presentation.opacity)
                            }
                            var offsetY: CGFloat
                            if currentValue > updatedValue {
                                offsetY = -floor(currentTextNode.bounds.height * 0.6)
                            } else {
                                offsetY = floor(currentTextNode.bounds.height * 0.6)
                            }
                            if reverseAnimationDirection {
                                offsetY = -offsetY
                            }
                            animation = (-offsetY, 0.2)
                            snapshot.frame = currentTextNode.frame
                            strongSelf.layer.addSublayer(snapshot)
                            snapshot.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offsetY), duration: 0.2, removeOnCompletion: false, additive: true)
                            snapshot.animateScale(from: 1.0, to: 0.3, duration: 0.2, removeOnCompletion: false)
                            snapshot.animateAlpha(from: fromAlpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshot] _ in
                                snapshot?.removeFromSuperlayer()
                            })
                        }
                    }
                    
                    let (layout, effectiveSegmentWidth, apply) = calculatedSegments[segment.key]!
                    let textNode = apply()
                    let textFrame = CGRect(origin: currentOffset, size: layout.size)
                    if textNode.frame.isEmpty {
                        textNode.frame = textFrame
                        if animated, !wasEmpty, animation == nil {
                            textNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                            textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                    } else if textNode.frame != textFrame {
                        transition.updateFrameAdditive(node: textNode, frame: textFrame)
                    }
                    currentOffset.x += effectiveSegmentWidth
                    if let (_, currentTextNode) = strongSelf.resolvedSegments[segment.key] {
                        if currentTextNode !== textNode {
                            currentTextNode.removeFromSupernode()
                            strongSelf.addSubnode(textNode)
                        }
                    } else {
                        strongSelf.addSubnode(textNode)
                        textNode.displaysAsynchronously = false
                        textNode.isUserInteractionEnabled = false
                    }
                    if let (offset, duration) = animation {
                        textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: duration, additive: true)
                        textNode.layer.animateScale(from: 0.3, to: 1.0, duration: duration)
                        textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
                    }
                    strongSelf.resolvedSegments[segment.key] = (segment, textNode)
                }
                
                var removeKeys: [ResolvedSegment.Key] = []
                for key in strongSelf.resolvedSegments.keys {
                    if !validKeys.contains(key) {
                        removeKeys.append(key)
                    }
                }
                
                for key in removeKeys {
                    guard let (_, textNode) = strongSelf.resolvedSegments.removeValue(forKey: key) else {
                        continue
                    }
                    if animated {
                        textNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2, removeOnCompletion: false)
                        textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textNode] _ in
                            textNode?.removeFromSupernode()
                        })
                    } else {
                        textNode.removeFromSupernode()
                    }
                }
            })
        }
    }
}

public final class ImmediateAnimatedCountLabelNode: AnimatedCountLabelNode {
    public var segments: [AnimatedCountLabelNode.Segment] = []
    
    private var constrainedSize: CGSize?
    
    public func updateLayout(size: CGSize, animated: Bool) -> CGSize {
        self.constrainedSize = size
        
        let makeLayout = self.asyncLayout()
        let (layout, apply) = makeLayout(size, self.segments)
        let _ = apply(animated)
        return layout.size
    }
    
    public func makeCopy() -> ASDisplayNode {
        let node = ImmediateAnimatedCountLabelNode()
        node.frame = self.frame
        node.segments = self.segments
        if let subnodes = self.subnodes {
            for subnode in subnodes {
                if let subnode = subnode as? ASImageNode {
                    let copySubnode = ASImageNode()
                    copySubnode.isLayerBacked = subnode.isLayerBacked
                    copySubnode.image = subnode.image
                    copySubnode.displaysAsynchronously = false
                    copySubnode.displayWithoutProcessing = true
                    copySubnode.frame = subnode.frame
                    copySubnode.alpha = subnode.alpha
                    node.addSubnode(copySubnode)
                }
            }
        }
        if let constrainedSize = self.constrainedSize {
            let _ = node.updateLayout(size: constrainedSize, animated: false)
        }
        return node
    }
}
