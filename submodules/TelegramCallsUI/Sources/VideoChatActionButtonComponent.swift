import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AppBundle
import TelegramAudio

final class VideoChatActionButtonComponent: Component {
    enum Content: Equatable {
        enum BluetoothType: Equatable {
            case generic
            case airpods
            case airpodsPro
            case airpodsMax
        }
        
        enum Audio: Equatable {
            case none
            case builtin
            case speaker
            case headphones
            case bluetooth(BluetoothType)
        }
        
        fileprivate enum IconType: Equatable {
            enum Audio: Equatable {
                case speaker
                case headphones
                case bluetooth(BluetoothType)
            }
            
            case audio(audio: Audio)
            case video
            case leave
        }
        
        case audio(audio: Audio, isEnabled: Bool)
        case video(isActive: Bool)
        case leave
        
        fileprivate var iconType: IconType {
            switch self {
            case let .audio(audio, _):
                let mappedAudio: IconType.Audio
                switch audio {
                case .none, .builtin, .speaker:
                    mappedAudio = .speaker
                case .headphones:
                    mappedAudio = .headphones
                case let .bluetooth(type):
                    mappedAudio = .bluetooth(type)
                }
                return .audio(audio: mappedAudio)
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
        case raiseHand
        case scheduled
    }
    
    let strings: PresentationStrings
    let content: Content
    let microphoneState: MicrophoneState
    let isCollapsed: Bool

    init(
        strings: PresentationStrings,
        content: Content,
        microphoneState: MicrophoneState,
        isCollapsed: Bool
    ) {
        self.strings = strings
        self.content = content
        self.microphoneState = microphoneState
        self.isCollapsed = isCollapsed
    }

    static func ==(lhs: VideoChatActionButtonComponent, rhs: VideoChatActionButtonComponent) -> Bool {
        if lhs.strings !== rhs.strings {
            return false
        }
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
        private let background: UIImageView
        private let title = ComponentView<Empty>()

        private var component: VideoChatActionButtonComponent?
        private var isUpdating: Bool = false
        
        private var contentImage: UIImage?
        
        override init(frame: CGRect) {
            self.background = UIImageView()
            
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
            var isEnabled: Bool = true
            switch component.content {
            case let .audio(audio, isEnabledValue):
                var isActive = false
                switch audio {
                case .none, .builtin:
                    titleText = component.strings.Call_Speaker
                case .speaker:
                    isEnabled = isEnabledValue
                    isActive = isEnabledValue
                    titleText = component.strings.Call_Speaker
                case .headphones:
                    titleText = component.strings.Call_Audio
                case .bluetooth:
                    titleText = component.strings.Call_Audio
                }
                switch component.microphoneState {
                case .connecting:
                    backgroundColor = UIColor(white: 0.1, alpha: 1.0)
                case .muted:
                    backgroundColor = !isActive ? UIColor(rgb: 0x002E5D) : UIColor(rgb: 0x027FFF)
                case .unmuted:
                    backgroundColor = !isActive ? UIColor(rgb: 0x124B21) : UIColor(rgb: 0x34C659)
                case .raiseHand, .scheduled:
                    backgroundColor = !isActive ? UIColor(rgb: 0x23306B) : UIColor(rgb: 0x3252EF)
                }
                iconDiameter = 60.0
            case let .video(isActive):
                titleText = component.strings.VoiceChat_Video
                switch component.microphoneState {
                case .connecting:
                    backgroundColor = UIColor(white: 0.1, alpha: 1.0)
                case .muted:
                    backgroundColor = !isActive ? UIColor(rgb: 0x002E5D) : UIColor(rgb: 0x027FFF)
                case .unmuted:
                    backgroundColor = !isActive ? UIColor(rgb: 0x124B21) : UIColor(rgb: 0x34C659)
                case .raiseHand, .scheduled:
                    backgroundColor = UIColor(rgb: 0x3252EF)
                }
                iconDiameter = 60.0
            case .leave:
                titleText = component.strings.VoiceChat_Leave
                backgroundColor = UIColor(rgb: 0x47191E)
                iconDiameter = 22.0
            }
            
            if self.contentImage == nil || previousComponent?.content.iconType != component.content.iconType {
                switch component.content.iconType {
                case let .audio(audio):
                    let iconName: String
                    switch audio {
                    case .speaker:
                        iconName = "Call/CallSpeakerButton"
                    case .headphones:
                        iconName = "Call/CallHeadphonesButton"
                    case let .bluetooth(type):
                        switch type {
                        case .generic:
                            iconName = "Call/CallBluetoothButton"
                        case .airpods:
                            iconName = "Call/CallAirpodsButton"
                        case .airpodsPro:
                            iconName = "Call/CallAirpodsProButton"
                        case .airpodsMax:
                            iconName = "Call/CallAirpodsMaxButton"
                        }
                    }
                    self.contentImage = UIImage(bundleImageName: iconName)?.precomposed().withRenderingMode(.alwaysTemplate)
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
            
            if self.background.superview == nil {
                self.addSubview(self.background)
                self.background.image = generateStretchableFilledCircleImage(diameter: 56.0, color: .white)?.withRenderingMode(.alwaysTemplate)
                self.background.tintColor = backgroundColor
            }
            transition.setFrame(view: self.background, frame: CGRect(origin: CGPoint(), size: size))
            
            let tintTransition: ComponentTransition
            if !transition.animation.isImmediate {
                tintTransition = .easeInOut(duration: 0.2)
            } else {
                tintTransition = .immediate
            }
            tintTransition.setTintColor(layer: self.background.layer, color: backgroundColor)
            
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
                transition.setAlpha(view: iconView, alpha: isEnabled ? 1.0 : 0.6)
            }
            
            self.isEnabled = isEnabled
            self.isUserInteractionEnabled = isEnabled
            
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
