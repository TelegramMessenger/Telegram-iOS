import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import LottieComponent
import VoiceChatActionButton
import CallScreen
import MetalEngine
import SwiftSignalKit
import AccountContext
import RadialStatusNode

private final class BlobView: UIView {
    let blobsLayer: CallBlobsLayer
    
    private let maxLevel: CGFloat
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    private var audioLevel: CGFloat = 0.0
    var presentationAudioLevel: CGFloat = 0.0
    
    var scaleUpdated: ((CGFloat) -> Void)? {
        didSet {
        }
    }
    
    private(set) var isAnimating = false

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = true
    
    init(
        frame: CGRect,
        maxLevel: CGFloat
    ) {
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })
        
        self.maxLevel = maxLevel
        
        self.blobsLayer = CallBlobsLayer()
        
        super.init(frame: frame)

        self.addSubnode(self.hierarchyTrackingNode)
        
        self.layer.addSublayer(self.blobsLayer)
        
        self.displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let self else {
                return
            }

            if !self.isCurrentlyInHierarchy {
                return
            }
            
            self.presentationAudioLevel = self.presentationAudioLevel * 0.9 + self.audioLevel * 0.1
            self.updateAudioLevel()
        }

        updateInHierarchy = { [weak self] value in
            guard let self else {
                return
            }
            self.isCurrentlyInHierarchy = value
            if value {
                self.startAnimating()
            } else {
                self.stopAnimating()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func setColor(_ color: UIColor) {
    }
    
    public func updateLevel(_ level: CGFloat, immediately: Bool) {
        let normalizedLevel = min(1, max(level / maxLevel, 0))
        
        self.audioLevel = normalizedLevel
        if immediately {
            self.presentationAudioLevel = normalizedLevel
        }
    }
    
    private func updateAudioLevel() {
        let additionalAvatarScale = CGFloat(max(0.0, min(self.presentationAudioLevel * 18.0, 5.0)) * 0.05)
        let blobAmplificationFactor: CGFloat = 2.0
        let blobScale = 1.0 + additionalAvatarScale * blobAmplificationFactor
        self.blobsLayer.transform = CATransform3DMakeScale(blobScale, blobScale, 1.0)
        
        self.scaleUpdated?(blobScale)
    }
    
    public func startAnimating() {
        guard !self.isAnimating else { return }
        self.isAnimating = true
        
        self.updateBlobsState()
        
        self.displayLinkAnimator?.isPaused = false
    }
    
    public func stopAnimating() {
        self.stopAnimating(duration: 0.15)
    }
    
    public func stopAnimating(duration: Double) {
        guard isAnimating else { return }
        self.isAnimating = false
        
        self.updateBlobsState()
        
        self.displayLinkAnimator?.isPaused = true
    }
    
    private func updateBlobsState() {
        /*if self.isAnimating {
            if self.mediumBlob.frame.size != .zero {
                self.mediumBlob.startAnimating()
                self.bigBlob.startAnimating()
            }
        } else {
            self.mediumBlob.stopAnimating()
            self.bigBlob.stopAnimating()
        }*/
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        //self.mediumBlob.frame = bounds
        //self.bigBlob.frame = bounds
        
        let blobsFrame = bounds.insetBy(dx: floor(bounds.width * 0.12), dy: floor(bounds.height * 0.12))
        self.blobsLayer.position = blobsFrame.center
        self.blobsLayer.bounds = CGRect(origin: CGPoint(), size: blobsFrame.size)
        
        self.updateBlobsState()
    }
}

private final class GlowView: UIView {
    let maskGradientLayer: SimpleGradientLayer
    
    override init(frame: CGRect) {
        self.maskGradientLayer = SimpleGradientLayer()
        self.maskGradientLayer.type = .radial
        self.maskGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.maskGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.maskGradientLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, color: UIColor, transition: ComponentTransition, colorTransition: ComponentTransition) {
        transition.setFrame(layer: self.maskGradientLayer, frame: CGRect(origin: CGPoint(), size: size))
        colorTransition.setGradientColors(layer: self.maskGradientLayer, colors: [color.withMultipliedAlpha(1.0), color.withMultipliedAlpha(0.0)])
    }
}

final class VideoChatMicButtonComponent: Component {
    enum ScheduledState: Equatable {
        case start
        case toggleSubscription(isSubscribed: Bool)
    }
    
    enum Content: Equatable {
        case connecting
        case muted
        case unmuted(pushToTalk: Bool)
        case raiseHand(isRaised: Bool)
        case scheduled(state: ScheduledState)
    }
    
    let call: VideoChatCall
    let strings: PresentationStrings
    let content: Content
    let isCollapsed: Bool
    let updateUnmutedStateIsPushToTalk: (Bool?) -> Void
    let raiseHand: () -> Void
    let scheduleAction: () -> Void

    init(
        call: VideoChatCall,
        strings: PresentationStrings,
        content: Content,
        isCollapsed: Bool,
        updateUnmutedStateIsPushToTalk: @escaping (Bool?) -> Void,
        raiseHand: @escaping () -> Void,
        scheduleAction: @escaping () -> Void
    ) {
        self.call = call
        self.strings = strings
        self.content = content
        self.isCollapsed = isCollapsed
        self.updateUnmutedStateIsPushToTalk = updateUnmutedStateIsPushToTalk
        self.raiseHand = raiseHand
        self.scheduleAction = scheduleAction
    }

    static func ==(lhs: VideoChatMicButtonComponent, rhs: VideoChatMicButtonComponent) -> Bool {
        if lhs.call != rhs.call {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        if lhs.isCollapsed != rhs.isCollapsed {
            return false
        }
        return true
    }

    final class View: HighlightTrackingButton {
        private let background: UIImageView
        private var disappearingBackgrounds: [UIImageView] = []
        private var progressIndicator: RadialStatusNode?
        private let title = ComponentView<Empty>()
        private var subtitle: ComponentView<Empty>?
        private let icon: VoiceChatActionButtonIconNode
        
        private var glowView: GlowView?
        private var blobView: BlobView?

        private var component: VideoChatMicButtonComponent?
        private var isUpdating: Bool = false
        
        private var beginTrackingTimestamp: Double = 0.0
        private var beginTrackingWasPushToTalk: Bool = false
        
        private var audioLevelDisposable: Disposable?
        
        override init(frame: CGRect) {
            self.background = UIImageView()
            self.icon = VoiceChatActionButtonIconNode(isColored: false)
            
            super.init(frame: frame)
        }
        
        deinit {
            self.audioLevelDisposable?.dispose()
        }
        
        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
            self.beginTrackingTimestamp = CFAbsoluteTimeGetCurrent()
            if let component = self.component {
                switch component.content {
                case .connecting, .unmuted, .raiseHand, .scheduled:
                    self.beginTrackingWasPushToTalk = false
                case .muted:
                    self.beginTrackingWasPushToTalk = true
                    component.updateUnmutedStateIsPushToTalk(true)
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
                case .raiseHand:
                    self.icon.playRandomAnimation()
                    
                    component.raiseHand()
                case .scheduled:
                    component.scheduleAction()
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
            
            let previousComponent = self.component
            self.component = component
            
            if let previousComponent, previousComponent.call != component.call {
                self.audioLevelDisposable?.dispose()
                self.audioLevelDisposable = nil
            }
            
            let alphaTransition: ComponentTransition = transition.animation.isImmediate ? .immediate : .easeInOut(duration: 0.2)
            
            let titleText: String
            var subtitleText: String?
            var isEnabled = true
            switch component.content {
            case .connecting:
                titleText = component.strings.VoiceChat_Connecting
                isEnabled = false
            case .muted:
                titleText = component.strings.VoiceChat_Unmute
            case let .unmuted(isPushToTalk):
                titleText = isPushToTalk ? component.strings.VoiceChat_Live : component.strings.VoiceChat_Mute
            case let .raiseHand(isRaised):
                if isRaised {
                    titleText = component.strings.VoiceChat_AskedToSpeak
                    subtitleText = component.strings.VoiceChat_AskedToSpeakHelp
                } else {
                    titleText = component.strings.VoiceChat_MutedByAdmin
                    subtitleText = component.strings.VoiceChat_MutedByAdminHelp
                }
            case let .scheduled(state):
                switch state {
                case .start:
                    titleText = component.strings.VoiceChat_StartNow
                case let .toggleSubscription(isSubscribed):
                    if isSubscribed {
                        titleText = component.strings.VoiceChat_CancelReminder
                    } else {
                        titleText = component.strings.VoiceChat_SetReminder
                    }
                }
            }
            self.isEnabled = isEnabled
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleText, font: Font.regular(15.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: 180.0, height: 100.0)
            )
            
            let size = CGSize(width: availableSize.width, height: availableSize.height)
            
            if self.background.superview == nil {
                self.background.isUserInteractionEnabled = false
                self.addSubview(self.background)
                self.background.frame = CGRect(origin: CGPoint(), size: CGSize(width: 116.0, height: 116.0))
            }
            
            if case .connecting = component.content {
                let progressIndicator: RadialStatusNode
                if let current = self.progressIndicator {
                    progressIndicator = current
                } else {
                    progressIndicator = RadialStatusNode(backgroundNodeColor: .clear)
                    self.progressIndicator = progressIndicator
                }
                progressIndicator.transitionToState(.progress(color: UIColor(rgb: 0x0080FF), lineWidth: 3.0, value: nil, cancelEnabled: false, animateRotation: true))
                
                let progressIndicatorView = progressIndicator.view
                if progressIndicatorView.superview == nil {
                    self.addSubview(progressIndicatorView)
                    progressIndicatorView.center = CGRect(origin: CGPoint(), size: size).center
                    progressIndicatorView.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 116.0, height: 116.0))
                    progressIndicatorView.layer.transform = CATransform3DMakeScale(size.width / 116.0, size.width / 116.0, 1.0)
                } else {
                    transition.setPosition(view: progressIndicatorView, position: CGRect(origin: CGPoint(), size: size).center)
                    transition.setScale(view: progressIndicatorView, scale: size.width / 116.0)
                }
            } else if let progressIndicator = self.progressIndicator {
                self.progressIndicator = nil
                if !transition.animation.isImmediate {
                    let progressIndicatorView = progressIndicator.view
                    progressIndicatorView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak progressIndicatorView] _ in
                        progressIndicatorView?.removeFromSuperview()
                    })
                } else {
                    progressIndicator.view.removeFromSuperview()
                }
            }
            
            if previousComponent?.content != component.content {
                let backgroundContentsTransition: ComponentTransition
                if !transition.animation.isImmediate {
                    backgroundContentsTransition = .easeInOut(duration: 0.2)
                } else {
                    backgroundContentsTransition = .immediate
                }
                let backgroundImage = generateImage(CGSize(width: 200.0, height: 200.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.addEllipse(in: CGRect(origin: CGPoint(), size: size))
                    context.clip()
                    
                    switch component.content {
                    case .connecting:
                        context.setFillColor(UIColor(white: 0.1, alpha: 1.0).cgColor)
                        context.fill(CGRect(origin: CGPoint(), size: size))
                    case .muted, .unmuted, .raiseHand, .scheduled:
                        let colors: [UIColor]
                        if case .muted = component.content {
                            colors = [UIColor(rgb: 0x0080FF), UIColor(rgb: 0x00A1FE)]
                        } else if case .raiseHand = component.content {
                            colors = [UIColor(rgb: 0x3252EF), UIColor(rgb: 0xC64688)]
                        } else if case .scheduled = component.content {
                            colors = [UIColor(rgb: 0x3252EF), UIColor(rgb: 0xC64688)]
                        } else {
                            colors = [UIColor(rgb: 0x33C659), UIColor(rgb: 0x0BA8A5)]
                        }
                        let gradientColors = colors.map { $0.cgColor } as CFArray
                        let colorSpace = DeviceGraphicsContextSettings.shared.colorSpace
                        
                        var locations: [CGFloat] = [0.0, 1.0]
                        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
                        
                        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: size.height), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
                    }
                })!
                if let previousImage = self.background.image {
                    let previousBackground = UIImageView()
                    previousBackground.center = self.background.center
                    previousBackground.bounds = self.background.bounds
                    previousBackground.layer.transform = self.background.layer.transform
                    previousBackground.image = previousImage
                    self.insertSubview(previousBackground, aboveSubview: self.background)
                    self.disappearingBackgrounds.append(previousBackground)
                    
                    self.background.image = backgroundImage
                    backgroundContentsTransition.setAlpha(view: previousBackground, alpha: 0.0, completion: { [weak self, weak previousBackground] _ in
                        guard let self, let previousBackground else {
                            return
                        }
                        previousBackground.removeFromSuperview()
                        self.disappearingBackgrounds.removeAll(where: { $0 === previousBackground })
                    })
                } else {
                    self.background.image = backgroundImage
                }
                
                if !transition.animation.isImmediate, let previousComponent, case .connecting = previousComponent.content {
                    self.layer.animateSublayerScale(from: 1.0, to: 1.07, duration: 0.12, removeOnCompletion: false, completion: { [weak self] completed in
                        if let self, completed {
                            self.layer.removeAnimation(forKey: "sublayerTransform.scale")
                            self.layer.animateSublayerScale(from: 1.07, to: 1.0, duration: 0.12, removeOnCompletion: true)
                        }
                    })
                }
            }
            
            transition.setPosition(view: self.background, position: CGRect(origin: CGPoint(), size: size).center)
            transition.setScale(view: self.background, scale: size.width / 116.0)
            for disappearingBackground in self.disappearingBackgrounds {
                transition.setPosition(view: disappearingBackground, position: CGRect(origin: CGPoint(), size: size).center)
                transition.setScale(view: disappearingBackground, scale: size.width / 116.0)
            }
            
            var titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) * 0.5), y: size.height + 16.0), size: titleSize)
            if subtitleText != nil {
                titleFrame.origin.y -= 5.0
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                alphaTransition.setAlpha(view: titleView, alpha: component.isCollapsed ? 0.0 : 1.0)
            }
            
            if let subtitleText {
                let subtitle: ComponentView<Empty>
                var subtitleTransition = transition
                if let current = self.subtitle {
                    subtitle = current
                } else {
                    subtitleTransition = subtitleTransition.withAnimation(.none)
                    subtitle = ComponentView()
                    self.subtitle = subtitle
                }
                let subtitleSize = subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: subtitleText, font: Font.regular(13.0), textColor: .white))
                    )),
                    environment: {},
                    containerSize: CGSize(width: 180.0, height: 100.0)
                )
                let subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) * 0.5), y: titleFrame.maxY + 1.0), size: subtitleSize)
                if let subtitleView = subtitle.view {
                    if subtitleView.superview == nil {
                        subtitleView.isUserInteractionEnabled = false
                        self.addSubview(subtitleView)
                        
                        subtitleView.alpha = 0.0
                        transition.animateScale(view: subtitleView, from: 0.001, to: 1.0)
                    }
                    subtitleTransition.setPosition(view: subtitleView, position: subtitleFrame.center)
                    subtitleView.bounds = CGRect(origin: CGPoint(), size: subtitleFrame.size)
                    alphaTransition.setAlpha(view: subtitleView, alpha: component.isCollapsed ? 0.0 : 1.0)
                }
            } else if let subtitle = self.subtitle {
                self.subtitle = nil
                if let subtitleView = subtitle.view {
                    transition.setScale(view: subtitleView, scale: 0.001)
                    alphaTransition.setAlpha(view: subtitleView, alpha: 0.0, completion: { [weak subtitleView] _ in
                        subtitleView?.removeFromSuperview()
                    })
                }
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
            case .raiseHand:
                self.icon.enqueueState(.hand)
            case let .scheduled(state):
                switch state {
                case .start:
                    self.icon.enqueueState(.start)
                case let .toggleSubscription(isSubscribed):
                    if isSubscribed {
                        self.icon.enqueueState(.unsubscribe)
                    } else {
                        self.icon.enqueueState(.subscribe)
                    }
                }
            }
            
            switch component.content {
            case .muted, .unmuted, .raiseHand, .scheduled:
                let blobSize = CGRect(origin: CGPoint(), size: CGSize(width: 116.0, height: 116.0)).insetBy(dx: -40.0, dy: -40.0).size
                
                let blobTintTransition: ComponentTransition
                
                let blobView: BlobView
                if let current = self.blobView {
                    blobView = current
                    blobTintTransition = .easeInOut(duration: 0.2)
                } else {
                    blobTintTransition = .immediate
                    blobView = BlobView(frame: CGRect(), maxLevel: 1.5)
                    blobView.isUserInteractionEnabled = false
                    self.blobView = blobView
                    self.insertSubview(blobView, at: 0)
                    blobView.center = CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5)
                    blobView.bounds = CGRect(origin: CGPoint(), size: blobSize)
                    
                    ComponentTransition.immediate.setScale(view: blobView, scale: 0.001)
                    if !transition.animation.isImmediate {
                        blobView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                    }
                }
                
                transition.setPosition(view: blobView, position: CGPoint(x: availableSize.width * 0.5, y: availableSize.height * 0.5))
                transition.setScale(view: blobView, scale: availableSize.width / 116.0)
                
                let blobsColor: UIColor
                if case .muted = component.content {
                    blobsColor = UIColor(rgb: 0x0086FF)
                } else if case .raiseHand = component.content {
                    blobsColor = UIColor(rgb: 0x914BAD)
                } else if case .scheduled = component.content {
                    blobsColor = UIColor(rgb: 0x914BAD)
                } else {
                    blobsColor = UIColor(rgb: 0x33C758)
                }
                blobTintTransition.setTintColor(layer: blobView.blobsLayer, color: blobsColor)
                
                switch component.content {
                case .unmuted:
                    if self.audioLevelDisposable == nil {
                        self.audioLevelDisposable = (component.call.myAudioLevelAndSpeaking
                        |> deliverOnMainQueue).startStrict(next: { [weak self] value, _ in
                            guard let self, let blobView = self.blobView else {
                                return
                            }
                            blobView.updateLevel(CGFloat(value), immediately: false)
                        })
                    }
                case .connecting, .muted, .raiseHand, .scheduled:
                    if let audioLevelDisposable = self.audioLevelDisposable {
                        self.audioLevelDisposable = nil
                        audioLevelDisposable.dispose()
                        blobView.updateLevel(0.0, immediately: false)
                    }
                }
                
                var glowFrame = CGRect(origin: CGPoint(), size: availableSize)
                if component.isCollapsed {
                    glowFrame = glowFrame.insetBy(dx: -20.0, dy: -20.0)
                } else {
                    glowFrame = glowFrame.insetBy(dx: -60.0, dy: -60.0)
                }
                
                let glowView: GlowView
                if let current = self.glowView {
                    glowView = current
                } else {
                    glowView = GlowView(frame: CGRect())
                    glowView.isUserInteractionEnabled = false
                    self.glowView = glowView
                    self.insertSubview(glowView, aboveSubview: blobView)
                    
                    transition.animateScale(view: glowView, from: 0.001, to: 1.0)
                    glowView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                
                let glowColor: UIColor
                if case .muted = component.content {
                    glowColor = UIColor(rgb: 0x0086FF)
                } else if case .raiseHand = component.content {
                    glowColor = UIColor(rgb: 0x3252EF)
                } else if case .scheduled = component.content {
                    glowColor = UIColor(rgb: 0x3252EF)
                } else {
                    glowColor = UIColor(rgb: 0x33C758)
                }
                glowView.update(size: glowFrame.size, color: glowColor.withMultipliedAlpha(component.isCollapsed ? 0.5 : 0.7), transition: transition, colorTransition: blobTintTransition)
                transition.setFrame(view: glowView, frame: glowFrame)
            default:
                if let blobView = self.blobView {
                    self.blobView = nil
                    transition.setScale(view: blobView, scale: 0.001, completion: { [weak blobView] _ in
                        blobView?.removeFromSuperview()
                    })
                }
                
                if let glowView = self.glowView {
                    self.glowView = nil
                    transition.setScale(view: glowView, scale: 0.001, completion: { [weak glowView] _ in
                        glowView?.removeFromSuperview()
                    })
                }
                
                if let audioLevelDisposable = self.audioLevelDisposable {
                    self.audioLevelDisposable = nil
                    audioLevelDisposable.dispose()
                }
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
