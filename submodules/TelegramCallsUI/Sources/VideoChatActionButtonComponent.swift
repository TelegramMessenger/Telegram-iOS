import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AppBundle

final class VideoChatActionButtonComponent: Component {
    enum Content: Equatable {
        fileprivate enum IconType {
            case video
            case leave
        }
        
        case video(isActive: Bool)
        case leave
        
        fileprivate var iconType: IconType {
            switch self {
            case .video:
                return .video
            case .leave:
                return .leave
            }
        }
    }
    
    enum MicrophoneState {
        case connecting
        case muted
        case unmuted
    }
    
    let content: Content
    let microphoneState: MicrophoneState
    let isCollapsed: Bool

    init(
        content: Content,
        microphoneState: MicrophoneState,
        isCollapsed: Bool
    ) {
        self.content = content
        self.microphoneState = microphoneState
        self.isCollapsed = isCollapsed
    }

    static func ==(lhs: VideoChatActionButtonComponent, rhs: VideoChatActionButtonComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.microphoneState != rhs.microphoneState {
            return false
        }
        if lhs.isCollapsed != rhs.isCollapsed {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let icon = ComponentView<Empty>()
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()

        private var component: VideoChatActionButtonComponent?
        private var isUpdating: Bool = false
        
        private var contentImage: UIImage?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: VideoChatActionButtonComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let titleText: String
            let backgroundColor: UIColor
            let iconDiameter: CGFloat
            switch component.content {
            case let .video(isActive):
                titleText = "video"
                switch component.microphoneState {
                case .connecting:
                    backgroundColor = UIColor(white: 1.0, alpha: 0.1)
                case .muted:
                    backgroundColor = isActive ? UIColor(rgb: 0x002E5D) : UIColor(rgb: 0x027FFF)
                case .unmuted:
                    backgroundColor = isActive ? UIColor(rgb: 0x124B21) : UIColor(rgb: 0x34C659)
                }
                iconDiameter = 60.0
            case .leave:
                titleText = "leave"
                backgroundColor = UIColor(rgb: 0x47191E)
                iconDiameter = 22.0
            }
            
            if self.contentImage == nil || previousComponent?.content.iconType != component.content.iconType {
                switch component.content.iconType {
                case .video:
                    self.contentImage = UIImage(bundleImageName: "Call/CallCameraButton")?.precomposed().withRenderingMode(.alwaysTemplate)
                case .leave:
                    self.contentImage = generateImage(CGSize(width: 28.0, height: 28.0), opaque: false, rotatedContext: { size, context in
                        let bounds = CGRect(origin: CGPoint(), size: size)
                        context.clear(bounds)
                        
                        context.setLineWidth(4.0 - UIScreenPixel)
                        context.setLineCap(.round)
                        context.setStrokeColor(UIColor.white.cgColor)
                        
                        context.move(to: CGPoint(x: 2.0 + UIScreenPixel, y: 2.0 + UIScreenPixel))
                        context.addLine(to: CGPoint(x: 26.0 - UIScreenPixel, y: 26.0 - UIScreenPixel))
                        context.strokePath()
                        
                        context.move(to: CGPoint(x: 26.0 - UIScreenPixel, y: 2.0 + UIScreenPixel))
                        context.addLine(to: CGPoint(x: 2.0 + UIScreenPixel, y: 26.0 - UIScreenPixel))
                        context.strokePath()
                    })
                }
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.regular(13.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: 90.0, height: 100.0)
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
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: CGRect(origin: CGPoint(), size: size))
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: size.height + 8.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                alphaTransition.setAlpha(view: titleView, alpha: component.isCollapsed ? 0.0 : 1.0)
            }
            
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(Image(
                    image: self.contentImage,
                    tintColor: .white,
                    size: CGSize(width: iconDiameter, height: iconDiameter)
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - iconSize.width) * 0.5), y: floor((size.height - iconSize.height) * 0.5)), size: iconSize)
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: iconFrame)
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
