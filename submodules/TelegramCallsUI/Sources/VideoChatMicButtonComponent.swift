import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import LottieComponent
import VoiceChatActionButton

final class VideoChatMicButtonComponent: Component {
    enum Content {
        case connecting
        case muted
        case unmuted
    }
    
    let content: Content
    let isCollapsed: Bool
    let updateUnmutedStateIsPushToTalk: (Bool?) -> Void

    init(
        content: Content,
        isCollapsed: Bool,
        updateUnmutedStateIsPushToTalk: @escaping (Bool?) -> Void
    ) {
        self.content = content
        self.isCollapsed = isCollapsed
        self.updateUnmutedStateIsPushToTalk = updateUnmutedStateIsPushToTalk
    }

    static func ==(lhs: VideoChatMicButtonComponent, rhs: VideoChatMicButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.isCollapsed != rhs.isCollapsed {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let icon: VoiceChatActionButtonIconNode

        private var component: VideoChatMicButtonComponent?
        private var isUpdating: Bool = false
        
        private var beginTrackingTimestamp: Double = 0.0
        private var beginTrackingWasPushToTalk: Bool = false
        
        override init(frame: CGRect) {
            self.icon = VoiceChatActionButtonIconNode(isColored: false)
            
            super.init(frame: frame)
        }
        
        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.beginTrackingTimestamp = CFAbsoluteTimeGetCurrent()
            if let component = self.component {
                switch component.content {
                case .connecting:
                    self.beginTrackingWasPushToTalk = false
                case .muted:
                    self.beginTrackingWasPushToTalk = true
                    component.updateUnmutedStateIsPushToTalk(true)
                case .unmuted:
                    self.beginTrackingWasPushToTalk = false
                }
            }
            
            return super.beginTracking(touch, with: event)
        }
        
        override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
            performEndOrCancelTracking()
            
            return super.endTracking(touch, with: event)
        }
        
        override func cancelTracking(with event: UIEvent?) {
            performEndOrCancelTracking()
            
            return super.cancelTracking(with: event)
        }
        
        private func performEndOrCancelTracking() {
            if let component = self.component {
                let timestamp = CFAbsoluteTimeGetCurrent()
                
                switch component.content {
                case .connecting:
                    break
                case .muted:
                    component.updateUnmutedStateIsPushToTalk(false)
                case .unmuted:
                    if self.beginTrackingWasPushToTalk {
                        if timestamp < self.beginTrackingTimestamp + 0.15 {
                            component.updateUnmutedStateIsPushToTalk(false)
                        } else {
                            component.updateUnmutedStateIsPushToTalk(nil)
                        }
                    } else {
                        component.updateUnmutedStateIsPushToTalk(nil)
                    }
                }
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: VideoChatMicButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let titleText: String
            let backgroundColor: UIColor
            var isEnabled = true
            switch component.content {
            case .connecting:
                titleText = "Connecting..."
                backgroundColor = UIColor(white: 1.0, alpha: 0.1)
                isEnabled = false
            case .muted:
                titleText = "Unmute"
                backgroundColor = UIColor(rgb: 0x0086FF)
            case .unmuted:
                titleText = "Mute"
                backgroundColor = UIColor(rgb: 0x34C659)
            }
            self.isEnabled = isEnabled
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.regular(15.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: 120.0, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: availableSize.height)
            
            let _ = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(
                    color: backgroundColor,
                    cornerRadius: size.width * 0.5,
                    smoothCorners: false
                )),
                environment: {},
                containerSize: size
            )
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    backgroundView.isUserInteractionEnabled = false
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: size.height + 16.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                alphaTransition.setAlpha(view: titleView, alpha: component.isCollapsed ? 0.0 : 1.0)
            }
            
            if self.icon.view.superview == nil {
                self.icon.view.isUserInteractionEnabled = false
                self.addSubview(self.icon.view)
            }
            let iconSize = CGSize(width: 100.0, height: 100.0)
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            
            transition.setPosition(view: self.icon.view, position: iconFrame.center)
            transition.setBounds(view: self.icon.view, bounds: CGRect(origin: CGPoint(), size: iconFrame.size))
            transition.setScale(view: self.icon.view, scale: component.isCollapsed ? ((iconSize.width - 24.0) / iconSize.width) : 1.0)
            
            switch component.content {
            case .connecting:
                self.icon.enqueueState(.mute)
            case .muted:
                self.icon.enqueueState(.mute)
            case .unmuted:
                self.icon.enqueueState(.unmute)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
