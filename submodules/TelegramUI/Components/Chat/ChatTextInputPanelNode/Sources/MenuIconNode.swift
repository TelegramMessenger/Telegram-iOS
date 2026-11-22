import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import ManagedAnimationNode

enum MenuIconNodeState: Equatable {
    case menu
    case app
    case close
}

final class MenuIconNode: ManagedAnimationNode {
    private let duration: Double = 0.33
    var iconState: MenuIconNodeState = .menu
    
    init() {
        super.init(size: CGSize(width: 30.0, height: 30.0))
        
        self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
    }
    
    func enqueueState(_ state: MenuIconNodeState, animated: Bool) {
        guard self.iconState != state else {
            return
        }
        
        let previousState = self.iconState
        self.iconState = state
        
        switch previousState {
            case .close:
                switch state {
                    case .menu:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_closemenu"), frames: .range(startFrame: 0, endFrame: 20), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .app:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 0, endFrame: 22), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 22, endFrame: 22), duration: 0.01))
                        }
                    case .close:
                        break
                }
            case .menu:
                switch state {
                    case .close:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 20), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 20, endFrame: 20), duration: 0.01))
                        }
                    case .app:
                        self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 22, endFrame: 22), duration: 0.01))
                    case .menu:
                        break
                }
            case .app:
                switch state {
                    case .close:
                        if animated {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 22, endFrame: 0), duration: self.duration))
                        } else {
                            self.trackTo(item: ManagedAnimationItem(source: .local("anim_webview"), frames: .range(startFrame: 0, endFrame: 0), duration: 0.01))
                        }
                    case .menu:
                        self.trackTo(item: ManagedAnimationItem(source: .local("anim_menuclose"), frames: .range(startFrame: 0, endFrame: 20), duration: 0.01))
                    case .app:
                        break
            }
        }
    }
}
