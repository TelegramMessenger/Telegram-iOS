import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import BundleIconComponent
import MetalEngine
import CallScreen
import TelegramCore
import AccountContext
import SwiftSignalKit
import DirectMediaImageCache
import FastBlur

private func blurredAvatarImage(_ dataImage: UIImage) -> UIImage? {
    let imageContextSize = CGSize(width: 64.0, height: 64.0)
    if let imageContext = DrawingContext(size: imageContextSize, scale: 1.0, clear: true) {
        imageContext.withFlippedContext { c in
            if let cgImage = dataImage.cgImage {
                c.draw(cgImage, in: CGRect(origin: CGPoint(), size: imageContextSize))
            }
        }
        
        telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
        
        return imageContext.generateImage()
    } else {
        return nil
    }
}

private let activityBorderImage: UIImage = {
    return generateStretchableFilledCircleImage(diameter: 20.0, color: nil, strokeColor: .white, strokeWidth: 2.0)!.withRenderingMode(.alwaysTemplate)
}()

final class VideoChatParticipantVideoComponent: Component {
    let strings: PresentationStrings
    let call: PresentationGroupCall
    let participant: GroupCallParticipantsContext.Participant
    let isMyPeer: Bool
    let isPresentation: Bool
    let isSpeaking: Bool
    let isExpanded: Bool
    let isUIHidden: Bool
    let contentInsets: UIEdgeInsets
    let controlInsets: UIEdgeInsets
    let interfaceOrientation: UIInterfaceOrientation
    let action: (() -> Void)?
    
    init(
        strings: PresentationStrings,
        call: PresentationGroupCall,
        participant: GroupCallParticipantsContext.Participant,
        isMyPeer: Bool,
        isPresentation: Bool,
        isSpeaking: Bool,
        isExpanded: Bool,
        isUIHidden: Bool,
        contentInsets: UIEdgeInsets,
        controlInsets: UIEdgeInsets,
        interfaceOrientation: UIInterfaceOrientation,
        action: (() -> Void)?
    ) {
        self.strings = strings
        self.call = call
        self.participant = participant
        self.isMyPeer = isMyPeer
        self.isPresentation = isPresentation
        self.isSpeaking = isSpeaking
        self.isExpanded = isExpanded
        self.isUIHidden = isUIHidden
        self.contentInsets = contentInsets
        self.controlInsets = controlInsets
        self.interfaceOrientation = interfaceOrientation
        self.action = action
    }
    
    static func ==(lhs: VideoChatParticipantVideoComponent, rhs: VideoChatParticipantVideoComponent) -> Bool {
        if lhs.participant != rhs.participant {
            return false
        }
        if lhs.isMyPeer != rhs.isMyPeer {
            return false
        }
        if lhs.isPresentation != rhs.isPresentation {
            return false
        }
        if lhs.isSpeaking != rhs.isSpeaking {
            return false
        }
        if lhs.isExpanded != rhs.isExpanded {
            return false
        }
        if lhs.isUIHidden != rhs.isUIHidden {
            return false
        }
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        if lhs.controlInsets != rhs.controlInsets {
            return false
        }
        if lhs.interfaceOrientation != rhs.interfaceOrientation {
            return false
        }
        if (lhs.action == nil) != (rhs.action == nil) {
            return false
        }
        return true
    }
    
    private struct VideoSpec: Equatable {
        var resolution: CGSize
        var rotationAngle: Float
        var followsDeviceOrientation: Bool
        
        init(resolution: CGSize, rotationAngle: Float, followsDeviceOrientation: Bool) {
            self.resolution = resolution
            self.rotationAngle = rotationAngle
            self.followsDeviceOrientation = followsDeviceOrientation
        }
    }
    
    private struct ReferenceLocation: Equatable {
        var containerWidth: CGFloat
        var positionX: CGFloat
        
        init(containerWidth: CGFloat, positionX: CGFloat) {
            self.containerWidth = containerWidth
            self.positionX = positionX
        }
    }
    
    private final class AnimationHint {
        enum Kind {
            case videoAvailabilityChanged
        }
        
        let kind: Kind
        
        init(kind: Kind) {
            self.kind = kind
        }
    }
    
    final class View: HighlightTrackingButton {
        private var component: VideoChatParticipantVideoComponent?
        private weak var componentState: EmptyComponentState?
        private var isUpdating: Bool = false
        private var previousSize: CGSize?
        
        private let backgroundGradientView: UIImageView
        
        private let muteStatus = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        
        private var blurredAvatarDisposable: Disposable?
        private var blurredAvatarView: UIImageView?
        
        private var videoSource: AdaptedCallVideoSource?
        private var videoDisposable: Disposable?
        private var videoBackgroundLayer: SimpleLayer?
        private var videoLayer: PrivateCallVideoLayer?
        private var videoSpec: VideoSpec?
        
        private var awaitingFirstVideoFrameForUnpause: Bool = false
        private var videoStatus: ComponentView<Empty>?
        private var activityBorderView: UIImageView?
        
        private var referenceLocation: ReferenceLocation?
        private var loadingEffectView: VideoChatVideoLoadingEffectView?
        
        override init(frame: CGRect) {
            self.backgroundGradientView = UIImageView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundGradientView)
            
            //TODO:release optimize
            self.clipsToBounds = true
            self.layer.cornerRadius = 10.0
            
            self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.videoDisposable?.dispose()
            self.blurredAvatarDisposable?.dispose()
        }
        
        @objc private func pressed() {
            guard let component = self.component, let action = component.action else {
                return
            }
            action()
        }
        
        func update(component: VideoChatParticipantVideoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let previousComponent = self.component
            self.component = component
            self.componentState = state
            
            transition.setFrame(view: self.backgroundGradientView, frame: CGRect(origin: CGPoint(), size: availableSize))
            
            let alphaTransition: ComponentTransition
            if !transition.animation.isImmediate {
                alphaTransition = .easeInOut(duration: 0.2)
            } else {
                alphaTransition = .immediate
            }
            
            let videoAlphaTransition: ComponentTransition
            if let animationHint = transition.userData(AnimationHint.self), case .videoAvailabilityChanged = animationHint.kind {
                videoAlphaTransition = .easeInOut(duration: 0.2)
            } else {
                videoAlphaTransition = alphaTransition
            }
            
            let controlsAlpha: CGFloat = component.isUIHidden ? 0.0 : 1.0
            
            let nameColor = component.participant.peer.nameColor ?? .blue
            let nameColors = component.call.accountContext.peerNameColors.get(nameColor, dark: true)
            
            if previousComponent == nil {
                self.backgroundGradientView.image = generateGradientImage(size: CGSize(width: 8.0, height: 32.0), colors: [
                    nameColors.main.withMultiplied(hue: 1.0, saturation: 1.1, brightness: 1.3),
                    nameColors.main.withMultiplied(hue: 1.0, saturation: 1.2, brightness: 1.0)
                ], locations: [0.0, 1.0], direction: .vertical)
            }
            
            if let smallProfileImage = component.participant.peer.smallProfileImage {
                let blurredAvatarView: UIImageView
                if let current = self.blurredAvatarView {
                    blurredAvatarView = current
                    
                    transition.setFrame(view: blurredAvatarView, frame: CGRect(origin: CGPoint(), size: availableSize))
                } else {
                    blurredAvatarView = UIImageView()
                    blurredAvatarView.contentMode = .scaleAspectFill
                    self.blurredAvatarView = blurredAvatarView
                    self.insertSubview(blurredAvatarView, aboveSubview: self.backgroundGradientView)
                    
                    blurredAvatarView.frame = CGRect(origin: CGPoint(), size: availableSize)
                }
                
                if self.blurredAvatarDisposable == nil {
                    //TODO:release synchronous
                    if let imageCache = component.call.accountContext.imageCache as? DirectMediaImageCache, let peerReference = PeerReference(component.participant.peer) {
                        if let result = imageCache.getAvatarImage(peer: peerReference, resource: MediaResourceReference.avatar(peer: peerReference, resource: smallProfileImage.resource), immediateThumbnail: component.participant.peer.profileImageRepresentations.first?.immediateThumbnailData, size: 64, synchronous: false) {
                            if let image = result.image {
                                blurredAvatarView.image = blurredAvatarImage(image)
                            }
                            if let loadSignal = result.loadSignal {
                                self.blurredAvatarDisposable = (loadSignal
                                |> deliverOnMainQueue).startStrict(next: { [weak self] image in
                                    guard let self else {
                                        return
                                    }
                                    if let image {
                                        self.blurredAvatarView?.image = blurredAvatarImage(image)
                                    } else {
                                        self.blurredAvatarView?.image = nil
                                    }
                                })
                            }
                        }
                    }
                }
            } else {
                if let blurredAvatarView = self.blurredAvatarView {
                    self.blurredAvatarView = nil
                    blurredAvatarView.removeFromSuperview()
                }
                if let blurredAvatarDisposable = self.blurredAvatarDisposable {
                    self.blurredAvatarDisposable = nil
                    blurredAvatarDisposable.dispose()
                }
            }
            
            let muteStatusSize = self.muteStatus.update(
                transition: transition,
                component: AnyComponent(VideoChatMuteIconComponent(
                    color: .white,
                    content: component.isPresentation ? .screenshare : .mute(isFilled: true, isMuted: component.participant.muteState != nil && !component.isSpeaking)
                )),
                environment: {},
                containerSize: CGSize(width: 36.0, height: 36.0)
            )
            let muteStatusFrame: CGRect
            if component.isExpanded {
                muteStatusFrame = CGRect(origin: CGPoint(x: 5.0, y: availableSize.height - component.controlInsets.bottom + 1.0 - muteStatusSize.height), size: muteStatusSize)
            } else {
                muteStatusFrame = CGRect(origin: CGPoint(x: 1.0, y: availableSize.height - component.controlInsets.bottom + 3.0 - muteStatusSize.height), size: muteStatusSize)
            }
            if let muteStatusView = self.muteStatus.view {
                if muteStatusView.superview == nil {
                    self.addSubview(muteStatusView)
                    muteStatusView.alpha = controlsAlpha
                    
                    //TODO:release
                    muteStatusView.layer.shadowOpacity = 0.7
                    muteStatusView.layer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
                    muteStatusView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
                    muteStatusView.layer.shadowRadius = 8.0
                }
                transition.setPosition(view: muteStatusView, position: muteStatusFrame.center)
                transition.setBounds(view: muteStatusView, bounds: CGRect(origin: CGPoint(), size: muteStatusFrame.size))
                transition.setScale(view: muteStatusView, scale: component.isExpanded ? 1.0 : 0.7)
                alphaTransition.setAlpha(view: muteStatusView, alpha: controlsAlpha)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.participant.peer.debugDisplayTitle, font: Font.semibold(16.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 8.0 * 2.0 - 4.0, height: 100.0)
            )
            let titleFrame: CGRect
            if component.isExpanded {
                titleFrame = CGRect(origin: CGPoint(x: 36.0, y: availableSize.height - component.controlInsets.bottom - 8.0 - titleSize.height), size: titleSize)
            } else {
                titleFrame = CGRect(origin: CGPoint(x: 29.0, y: availableSize.height - component.controlInsets.bottom - 4.0 - titleSize.height), size: titleSize)
            }
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                    titleView.alpha = controlsAlpha
                    
                    //TODO:release
                    titleView.layer.shadowOpacity = 0.7
                    titleView.layer.shadowColor = UIColor(white: 0.0, alpha: 1.0).cgColor
                    titleView.layer.shadowOffset = CGSize(width: 0.0, height: 1.0)
                    titleView.layer.shadowRadius = 8.0
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                transition.setScale(view: titleView, scale: component.isExpanded ? 1.0 : 0.825)
                alphaTransition.setAlpha(view: titleView, alpha: controlsAlpha)
            }
            
            let videoDescription = component.isPresentation ? component.participant.presentationDescription : component.participant.videoDescription
            
            var isEffectivelyPaused = false
            if let videoDescription, videoDescription.isPaused {
                isEffectivelyPaused = true
            } else if let previousComponent {
                let previousVideoDescription = previousComponent.isPresentation ? previousComponent.participant.presentationDescription : previousComponent.participant.videoDescription
                if let previousVideoDescription, previousVideoDescription.isPaused {
                    self.awaitingFirstVideoFrameForUnpause = true
                }
                if self.awaitingFirstVideoFrameForUnpause {
                    isEffectivelyPaused = true
                }
            }
            
            if let videoDescription {
                let videoBackgroundLayer: SimpleLayer
                if let current = self.videoBackgroundLayer {
                    videoBackgroundLayer = current
                } else {
                    videoBackgroundLayer = SimpleLayer()
                    videoBackgroundLayer.backgroundColor = UIColor(white: 0.1, alpha: 1.0).cgColor
                    videoBackgroundLayer.opacity = 0.0
                    self.videoBackgroundLayer = videoBackgroundLayer
                    if let blurredAvatarView = self.blurredAvatarView {
                        self.layer.insertSublayer(videoBackgroundLayer, above: blurredAvatarView.layer)
                    } else {
                        self.layer.insertSublayer(videoBackgroundLayer, above: self.backgroundGradientView.layer)
                    }
                    videoBackgroundLayer.isHidden = true
                }
                
                let videoLayer: PrivateCallVideoLayer
                if let current = self.videoLayer {
                    videoLayer = current
                } else {
                    videoLayer = PrivateCallVideoLayer()
                    self.videoLayer = videoLayer
                    videoLayer.opacity = 0.0
                    self.layer.insertSublayer(videoLayer.blurredLayer, above: videoBackgroundLayer)
                    self.layer.insertSublayer(videoLayer, above: videoLayer.blurredLayer)
                    
                    videoLayer.blurredLayer.opacity = 0.0
                    
                    if let input = (component.call as! PresentationGroupCallImpl).video(endpointId: videoDescription.endpointId) {
                        let videoSource = AdaptedCallVideoSource(videoStreamSignal: input)
                        self.videoSource = videoSource
                        
                        self.videoDisposable?.dispose()
                        self.videoDisposable = videoSource.addOnUpdated { [weak self] in
                            guard let self, let videoSource = self.videoSource, let videoLayer = self.videoLayer else {
                                return
                            }
                            
                            let videoOutput = videoSource.currentOutput
                            videoLayer.video = videoOutput
                            
                            if let videoOutput {
                                let videoSpec = VideoSpec(resolution: videoOutput.resolution, rotationAngle: videoOutput.rotationAngle, followsDeviceOrientation: videoOutput.followsDeviceOrientation)
                                if self.videoSpec != videoSpec || self.awaitingFirstVideoFrameForUnpause {
                                    self.awaitingFirstVideoFrameForUnpause = false
                                    
                                    self.videoSpec = videoSpec
                                    if !self.isUpdating {
                                        self.componentState?.updated(transition: ComponentTransition.immediate.withUserData(AnimationHint(kind: .videoAvailabilityChanged)), isLocal: true)
                                    }
                                }
                            } else {
                                if self.videoSpec != nil {
                                    self.videoSpec = nil
                                    if !self.isUpdating {
                                        self.componentState?.updated(transition: .immediate, isLocal: true)
                                    }
                                }
                            }
                        }
                    }
                }
                
                transition.setFrame(layer: videoBackgroundLayer, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if let videoSpec = self.videoSpec {
                    if videoBackgroundLayer.isHidden {
                        videoBackgroundLayer.isHidden = false
                    }
                    
                    videoAlphaTransition.setAlpha(layer: videoBackgroundLayer, alpha: 1.0)
                    
                    if isEffectivelyPaused {
                        videoAlphaTransition.setAlpha(layer: videoLayer, alpha: 0.0)
                        videoAlphaTransition.setAlpha(layer: videoLayer.blurredLayer, alpha: 0.9)
                    } else {
                        videoAlphaTransition.setAlpha(layer: videoLayer, alpha: 1.0)
                        videoAlphaTransition.setAlpha(layer: videoLayer.blurredLayer, alpha: 0.25)
                    }
                    
                    let rotationAngle = resolveCallVideoRotationAngle(angle: videoSpec.rotationAngle, followsDeviceOrientation: videoSpec.followsDeviceOrientation, interfaceOrientation: component.interfaceOrientation)
                    
                    var rotatedResolution = videoSpec.resolution
                    var videoIsRotated = false
                    if abs(rotationAngle - Float.pi * 0.5) < .ulpOfOne || abs(rotationAngle - Float.pi * 3.0 / 2.0) < .ulpOfOne {
                        videoIsRotated = true
                    }
                    if videoIsRotated {
                        rotatedResolution = CGSize(width: rotatedResolution.height, height: rotatedResolution.width)
                    }
                    
                    let videoSize = rotatedResolution.aspectFitted(availableSize)
                    let videoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - videoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                    let blurredVideoSize = rotatedResolution.aspectFilled(availableSize)
                    let blurredVideoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - blurredVideoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - blurredVideoSize.height) * 0.5)), size: blurredVideoSize)
                    
                    let videoResolution = rotatedResolution
                    
                    var rotatedVideoResolution = videoResolution
                    var rotatedVideoFrame = videoFrame
                    var rotatedBlurredVideoFrame = blurredVideoFrame
                    var rotatedVideoBoundsSize = videoFrame.size
                    var rotatedBlurredVideoBoundsSize = blurredVideoFrame.size
                    
                    if videoIsRotated {
                        rotatedVideoBoundsSize = CGSize(width: rotatedVideoBoundsSize.height, height: rotatedVideoBoundsSize.width)
                        rotatedVideoFrame = rotatedVideoFrame.size.centered(around: rotatedVideoFrame.center)
                        
                        rotatedBlurredVideoBoundsSize = CGSize(width: rotatedBlurredVideoBoundsSize.height, height: rotatedBlurredVideoBoundsSize.width)
                        rotatedBlurredVideoFrame = rotatedBlurredVideoFrame.size.centered(around: rotatedBlurredVideoFrame.center)
                    }
                    rotatedVideoResolution = rotatedVideoResolution.aspectFittedOrSmaller(CGSize(width: rotatedVideoFrame.width * UIScreenScale, height: rotatedVideoFrame.height * UIScreenScale))
                    
                    transition.setPosition(layer: videoLayer, position: rotatedVideoFrame.center)
                    transition.setBounds(layer: videoLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoBoundsSize))
                    transition.setTransform(layer: videoLayer, transform: CATransform3DMakeRotation(CGFloat(rotationAngle), 0.0, 0.0, 1.0))
                    videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)), edgeInset: 2)
                    
                    transition.setPosition(layer: videoLayer.blurredLayer, position: rotatedBlurredVideoFrame.center)
                    transition.setBounds(layer: videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: rotatedBlurredVideoBoundsSize))
                    transition.setTransform(layer: videoLayer.blurredLayer, transform: CATransform3DMakeRotation(CGFloat(rotationAngle), 0.0, 0.0, 1.0))
                }
            } else {
                if let videoBackgroundLayer = self.videoBackgroundLayer {
                    self.videoBackgroundLayer = nil
                    videoBackgroundLayer.removeFromSuperlayer()
                }
                if let videoLayer = self.videoLayer {
                    self.videoLayer = nil
                    videoLayer.blurredLayer.removeFromSuperlayer()
                    videoLayer.removeFromSuperlayer()
                }
                self.videoDisposable?.dispose()
                self.videoDisposable = nil
                self.videoSource = nil
                self.videoSpec = nil
            }
            
            var statusKind: VideoChatParticipantVideoStatusComponent.Kind?
            if component.isPresentation && component.isMyPeer {
                statusKind = .ownScreenshare
            } else if isEffectivelyPaused {
                statusKind = .paused
            }
            
            if let statusKind {
                let videoStatus: ComponentView<Empty>
                var videoStatusTransition = transition
                if let current = self.videoStatus {
                    videoStatus = current
                } else {
                    videoStatusTransition = videoStatusTransition.withAnimation(.none)
                    videoStatus = ComponentView()
                    self.videoStatus = videoStatus
                }
                let _ = videoStatus.update(
                    transition: videoStatusTransition,
                    component: AnyComponent(VideoChatParticipantVideoStatusComponent(
                        strings: component.strings,
                        kind: statusKind,
                        isExpanded: component.isExpanded
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                if let videoStatusView = videoStatus.view {
                    if videoStatusView.superview == nil {
                        videoStatusView.isUserInteractionEnabled = false
                        videoStatusView.alpha = 0.0
                        self.addSubview(videoStatusView)
                    }
                    videoStatusTransition.setFrame(view: videoStatusView, frame: CGRect(origin: CGPoint(), size: availableSize))
                    videoAlphaTransition.setAlpha(view: videoStatusView, alpha: 1.0)
                }
            } else if let videoStatus = self.videoStatus {
                self.videoStatus = nil
                if let videoStatusView = videoStatus.view {
                    videoAlphaTransition.setAlpha(view: videoStatusView, alpha: 0.0, completion: { [weak videoStatusView] _ in
                        videoStatusView?.removeFromSuperview()
                    })
                }
            }
            
            if videoDescription != nil && self.videoSpec == nil && !isEffectivelyPaused {
                if self.loadingEffectView == nil {
                    let loadingEffectView = VideoChatVideoLoadingEffectView(effectAlpha: 0.1, borderAlpha: 0.2, cornerRadius: 10.0, duration: 1.0)
                    self.loadingEffectView = loadingEffectView
                    loadingEffectView.alpha = 0.0
                    loadingEffectView.isUserInteractionEnabled = false
                    self.addSubview(loadingEffectView)
                    if let referenceLocation = self.referenceLocation {
                        self.updateHorizontalReferenceLocation(containerWidth: referenceLocation.containerWidth, positionX: referenceLocation.positionX, transition: .immediate)
                    }
                    videoAlphaTransition.setAlpha(view: loadingEffectView, alpha: 1.0)
                }
            } else if let loadingEffectView = self.loadingEffectView {
                self.loadingEffectView = nil
                
                videoAlphaTransition.setAlpha(view: loadingEffectView, alpha: 0.0, completion: { [weak loadingEffectView] _ in
                    loadingEffectView?.removeFromSuperview()
                })
            }
            
            if component.isSpeaking && !component.isExpanded {
                let activityBorderView: UIImageView
                if let current = self.activityBorderView {
                    activityBorderView = current
                } else {
                    activityBorderView = UIImageView()
                    self.activityBorderView = activityBorderView
                    self.addSubview(activityBorderView)
                    
                    activityBorderView.image = activityBorderImage
                    activityBorderView.tintColor = UIColor(rgb: 0x33C758)
                    
                    if let previousSize {
                        activityBorderView.frame = CGRect(origin: CGPoint(), size: previousSize)
                    }
                }
            } else if let activityBorderView = self.activityBorderView {
                if !transition.animation.isImmediate {
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    if activityBorderView.alpha != 0.0 {
                        alphaTransition.setAlpha(view: activityBorderView, alpha: 0.0, completion: { [weak self, weak activityBorderView] completed in
                            guard let self, let component = self.component, let activityBorderView, self.activityBorderView === activityBorderView, completed else {
                                return
                            }
                            if !component.isSpeaking {
                                activityBorderView.removeFromSuperview()
                                self.activityBorderView = nil
                            }
                        })
                    }
                } else {
                    self.activityBorderView = nil
                    activityBorderView.removeFromSuperview()
                }
            }
            
            if let activityBorderView = self.activityBorderView {
                transition.setFrame(view: activityBorderView, frame: CGRect(origin: CGPoint(), size: availableSize))
            }
            
            self.previousSize = availableSize
            
            return availableSize
        }
        
        func updateHorizontalReferenceLocation(containerWidth: CGFloat, positionX: CGFloat, transition: ComponentTransition) {
            self.referenceLocation = ReferenceLocation(containerWidth: containerWidth, positionX: positionX)
            
            if let loadingEffectView = self.loadingEffectView, let size = self.previousSize {
                transition.setFrame(view: loadingEffectView, frame: CGRect(origin: CGPoint(), size: size))
                loadingEffectView.update(size: size, containerWidth: containerWidth, offsetX: positionX, gradientWidth: floor(containerWidth * 0.8), transition: transition)
            }
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
