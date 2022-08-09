import Foundation
import UIKit
import ComponentFlow
import ManagedAnimationNode

enum PlayPauseIconNodeState: Equatable {
    case play
    case pause
}

private final class PlayPauseIconNode: ManagedAnimationNode {
    private let duration: Double = 0.35
    private var iconState: PlayPauseIconNodeState = .play
    
    init() {
        super.init(size: CGSize(width: 40.0, height: 40.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
    }
    
    func enqueueState(_ state: PlayPauseIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .pause:
                switch state {
                    case .play:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 83), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .pause:
                        break
                }
            case .play:
                switch state {
                    case .pause:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 0, endFrame: 41), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_playpause"), frames: .range(startFrame: 41, endFrame: 41), duration: 0.01))
                        }
                    case .play:
                        break
                }
        }
    }
}

final class PlayPauseIconComponent: Component {
    let state: PlayPauseIconNodeState
    let tintColor: UIColor?
    let size: CGSize
    
    init(state: PlayPauseIconNodeState, tintColor: UIColor?, size: CGSize) {
        self.state = state
        self.tintColor = tintColor
        self.size = size
    }

    static func ==(lhs: PlayPauseIconComponent, rhs: PlayPauseIconComponent) -> Bool {
        if lhs.state != rhs.state {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var component: PlayPauseIconComponent?
        private var animationNode: PlayPauseIconNode
                
        override init(frame: CGRect) {
            self.animationNode = PlayPauseIconNode()
            
            super.init(frame: frame)

            self.addSubview(self.animationNode.view)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PlayPauseIconComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.component?.state != component.state {
                self.component = component
                
                self.animationNode.enqueueState(component.state, animated: true)
            }
            
            self.animationNode.customColor = component.tintColor
          
            let animationSize = component.size
            let size = CGSize(width: min(animationSize.width, availableSize.width), height: min(animationSize.height, availableSize.height))
            self.animationNode.view.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.height - animationSize.height) / 2.0)), size: animationSize)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
