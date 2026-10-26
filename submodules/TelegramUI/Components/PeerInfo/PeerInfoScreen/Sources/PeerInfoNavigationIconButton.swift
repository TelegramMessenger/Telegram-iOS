import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ContextUI
import LottieSettings
import ManagedAnimationNode
import TelegramPresentationData
import PeerInfoPaneNode

private enum MoreIconNodeState: Equatable {
    case more
    case search
    case sort
    case moreToSearch(Float)
}

private final class MoreIconNode: ManagedAnimationNode {
    private let duration: Double = 0.21
    private var iconState: MoreIconNodeState = .more
    
    init(lottieSettings: LottieRenderingSettings) {
        super.init(size: CGSize(width: 30.0, height: 30.0), lottieSettings: lottieSettings)
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_moretosearch"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
    }
        
    func play() {
        if case .more = self.iconState {
            self.trackTo(item: ManagedAnimationItem(source: .local("anim_moredots"), frames: .range(startFrame: 0, endFrame: 46), duration: 0.76))
        }
    }
    
    func enqueueState(_ state: MoreIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        var source: ManagedAnimationSource = .local("anim_moretosearch")
        
        let totalLength: Int = 90
        if animated {
            switch previousState {
                case .more:
                    switch state {
                        case .more:
                            break
                        case .search:
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        case .sort:
                            source = .local("anim_moretosort_l")
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double(progress)
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: frame), duration: duration))
                    }
                case .search:
                    switch state {
                        case .more:
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                        case .search:
                            break
                        case .sort:
                            source = .local("anim_sorttosearch")
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double((1.0 - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: frame), duration: duration))
                    }
                case .sort:
                    switch state {
                        case .more:
                            source = .local("anim_moretosort_l")
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                        case .search:
                            source = .local("anim_sorttosearch")
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        case .sort:
                           break
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double((1.0 - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: frame), duration: duration))
                    }
                case let .moreToSearch(currentProgress):
                    let currentFrame = Int(currentProgress * Float(totalLength))
                    switch state {
                        case .more:
                            let duration = self.duration * Double(currentProgress)
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: 0), duration: duration))
                        case .search:
                            let duration = self.duration * (1.0 - Double(currentProgress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: totalLength), duration: duration))
                        case .sort:
                            break
                        case let .moreToSearch(progress):
                            let frame = Int(progress * Float(totalLength))
                            let duration = self.duration * Double(abs(currentProgress - progress))
                            self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: currentFrame, endFrame: frame), duration: duration))
                    }
            }
        } else {
            switch state {
                case .more:
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
                case .search:
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: totalLength), duration: 0.0))
                case .sort:
                    source = .local("anim_moretosort_l")
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: totalLength), duration: 0.0))
                case let .moreToSearch(progress):
                    let frame = Int(progress * Float(totalLength))
                    self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: frame, endFrame: frame), duration: 0.0))
            }
        }
    }
}

/// The profile's more / search / sort button: one node whose icon animates between the three, hosted by the bar as a
/// node item. A `HighlightableButtonNode` keeps its own touches in the bar, so a tap and the context-menu gesture both
/// reach the profile with the source a context menu is extracted from.
final class PeerInfoNavigationIconButton: HighlightableButtonNode {
    let containerNode: ContextControllerSourceNode
    let contextSourceNode: ContextReferenceContentNode
    private let animationNode: MoreIconNode
    private(set) var key: PeerInfoHeaderNavigationButtonKey?

    var action: ((ContextReferenceContentNode, ContextGesture?) -> Void)?

    init() {
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        self.contextSourceNode = ContextReferenceContentNode()
        self.animationNode = MoreIconNode(lottieSettings: .noAccountFallback)
        self.animationNode.customColor = .white

        super.init(pointerStyle: .insetRectangle(0.0, 0.0))

        self.isAccessibilityElement = true
        self.accessibilityTraits = .button

        self.containerNode.addSubnode(self.contextSourceNode)
        self.contextSourceNode.addSubnode(self.animationNode)
        self.addSubnode(self.containerNode)

        self.containerNode.activated = { [weak self] gesture, _ in
            guard let self else {
                return
            }
            self.action?(self.contextSourceNode, gesture)
        }
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }

    @objc private func pressed() {
        self.animationNode.play()
        self.action?(self.contextSourceNode, nil)
    }

    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 44.0, height: 44.0)
    }

    override func layout() {
        super.layout()
        let bounds = self.bounds
        self.containerNode.frame = bounds
        self.contextSourceNode.frame = bounds
        let animationSize = CGSize(width: 30.0, height: 30.0)
        self.animationNode.frame = CGRect(origin: CGPoint(x: floor((bounds.width - animationSize.width) / 2.0), y: floor((bounds.height - animationSize.height) / 2.0)), size: animationSize)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.bounds.contains(point) {
            return super.hitTest(self.bounds.center, with: event)
        }
        return nil
    }

    /// The key the slot shows; the icon animates from the previous one (the first is set as is).
    func update(key: PeerInfoHeaderNavigationButtonKey, strings: PresentationStrings) {
        let state: MoreIconNodeState
        switch key {
        case .search:
            state = .search
            self.accessibilityLabel = strings.Common_Search
        case .sort:
            state = .sort
            self.accessibilityLabel = strings.Common_More
        default:
            state = .more
            self.accessibilityLabel = strings.Common_More
        }
        let isFirst = self.key == nil
        self.key = key
        self.containerNode.isGestureEnabled = key == .more
        self.animationNode.enqueueState(state, animated: !isFirst)
    }

    func updateContentsColor(_ color: UIColor, transition: ContainedViewLayoutTransition) {
        transition.updateTintColor(layer: self.animationNode.imageNode.layer, color: color)
    }
}
