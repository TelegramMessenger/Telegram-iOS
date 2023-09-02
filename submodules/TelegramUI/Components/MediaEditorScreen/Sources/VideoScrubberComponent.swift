import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import AudioWaveformComponent
import MultilineTextComponent

private let handleWidth: CGFloat = 14.0
private let scrubberHeight: CGFloat = 39.0
private let collapsedScrubberHeight: CGFloat = 26.0
private let borderHeight: CGFloat = 1.0 + UIScreenPixel
private let frameWidth: CGFloat = 24.0

private class VideoFrameLayer: SimpleShapeLayer {
    private let stripeLayer = SimpleShapeLayer()
    
    override func layoutSublayers() {
        super.layoutSublayers()
        
        if self.stripeLayer.superlayer == nil {
            self.stripeLayer.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.3).cgColor
            self.addSublayer(self.stripeLayer)
        }
        self.stripeLayer.frame = CGRect(x: self.bounds.width - UIScreenPixel, y: 0.0, width: UIScreenPixel, height: self.bounds.height)
    }
}

private final class HandleView: UIImageView {
    var hitTestSlop = UIEdgeInsets()
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.bounds.inset(by: self.hitTestSlop).contains(point)
    }
}

final class VideoScrubberComponent: Component {
    typealias EnvironmentType = Empty
    
    struct AudioData: Equatable {
        let artist: String?
        let title: String?
        let samples: Data?
        let peak: Int32
        let duration: Double
        let start: Double?
        let end: Double?
        let offset: Double?
    }
    
    let context: AccountContext
    let generationTimestamp: Double
    let audioOnly: Bool
    let duration: Double
    let startPosition: Double
    let endPosition: Double
    let position: Double
    let minDuration: Double
    let maxDuration: Double
    let isPlaying: Bool
    let frames: [UIImage]
    let framesUpdateTimestamp: Double
    let audioData: AudioData?
    let videoTrimUpdated: (Double, Double, Bool, Bool) -> Void
    let positionUpdated: (Double, Bool) -> Void
    let audioTrimUpdated: (Double, Double, Bool, Bool) -> Void
    let audioLongPressed: ((UIView) -> Void)?
    
    init(
        context: AccountContext,
        generationTimestamp: Double,
        audioOnly: Bool,
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double,
        isPlaying: Bool,
        frames: [UIImage],
        framesUpdateTimestamp: Double,
        audioData: AudioData?,
        videoTrimUpdated: @escaping (Double, Double, Bool, Bool) -> Void,
        positionUpdated: @escaping (Double, Bool) -> Void,
        audioTrimUpdated: @escaping (Double, Double, Bool, Bool) -> Void,
        audioLongPressed: ((UIView) -> Void)?
    ) {
        self.context = context
        self.generationTimestamp = generationTimestamp
        self.audioOnly = audioOnly
        self.duration = duration
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.position = position
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.isPlaying = isPlaying
        self.frames = frames
        self.framesUpdateTimestamp = framesUpdateTimestamp
        self.audioData = audioData
        self.videoTrimUpdated = videoTrimUpdated
        self.positionUpdated = positionUpdated
        self.audioTrimUpdated = audioTrimUpdated
        self.audioLongPressed = audioLongPressed
    }
    
    static func ==(lhs: VideoScrubberComponent, rhs: VideoScrubberComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.generationTimestamp != rhs.generationTimestamp {
            return false
        }
        if lhs.audioOnly != rhs.audioOnly {
            return false
        }
        if lhs.duration != rhs.duration {
            return false
        }
        if lhs.startPosition != rhs.startPosition {
            return false
        }
        if lhs.endPosition != rhs.endPosition {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        if lhs.minDuration != rhs.minDuration {
            return false
        }
        if lhs.maxDuration != rhs.maxDuration {
            return false
        }
        if lhs.isPlaying != rhs.isPlaying {
            return false
        }
        if lhs.framesUpdateTimestamp != rhs.framesUpdateTimestamp {
            return false
        }
        if lhs.audioData != rhs.audioData {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate{
        private let audioClippingView: UIView
        private let audioScrollView: UIScrollView
        private let audioContainerView: UIView
        private let audioBackgroundView: BlurredBackgroundView
        private let audioVibrancyView: UIVisualEffectView
        private let audioVibrancyContainer: UIView
        
        private let audioContentContainerView: UIView
        private let audioContentMaskView: UIImageView
        private let audioIconView: UIImageView
        private let audioTitle = ComponentView<Empty>()
                
        private let audioWaveform = ComponentView<Empty>()
        
        private let trimView = TrimView(frame: .zero)
        private let ghostTrimView = TrimView(frame: .zero)
        
        private let cursorView = HandleView()
        
        private let transparentFramesContainer = UIView()
        private let opaqueFramesContainer = UIView()
        
        private var transparentFrameLayers: [VideoFrameLayer] = []
        private var opaqueFrameLayers: [VideoFrameLayer] = []
        
        private var component: VideoScrubberComponent?
        private weak var state: EmptyComponentState?
        private var scrubberSize: CGSize?
        
        private var isAudioSelected = false
        private var isPanningPositionHandle = false
        
        private var displayLink: SharedDisplayLinkDriver.Link?
        private var positionAnimation: (start: Double, from: Double, to: Double, ended: Bool)?
        
        override init(frame: CGRect) {
            self.audioScrollView = UIScrollView()
            self.audioScrollView.decelerationRate = .fast
            self.audioScrollView.clipsToBounds = false
            self.audioScrollView.showsHorizontalScrollIndicator = false
            self.audioScrollView.showsVerticalScrollIndicator = false
            
            self.audioClippingView = UIView()
            self.audioClippingView.clipsToBounds = true
            
            self.audioContainerView = UIView()
            self.audioContainerView.clipsToBounds = true
            self.audioContainerView.layer.cornerRadius = 9.0
            self.audioContainerView.isUserInteractionEnabled = false
            
            self.audioBackgroundView = BlurredBackgroundView(color: UIColor(white: 0.0, alpha: 0.5), enableBlur: true)
            
            let style: UIBlurEffect.Style = .dark
            let blurEffect = UIBlurEffect(style: style)
            let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
            let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
            self.audioVibrancyView = vibrancyEffectView
            
            self.audioVibrancyContainer = UIView()
            self.audioVibrancyView.contentView.addSubview(self.audioVibrancyContainer)
            
            self.audioContentContainerView = UIView()
            self.audioContentContainerView.clipsToBounds = true

            self.audioContentMaskView = UIImageView()
            self.audioContentContainerView.mask = self.audioContentMaskView
            
            self.audioIconView = UIImageView(image: UIImage(bundleImageName: "Media Editor/SmallAudio"))
            
            super.init(frame: frame)
            
            self.clipsToBounds = false
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveKeyboardGestureRecognizer = true
            
            let positionImage = generateImage(CGSize(width: handleWidth, height: 50.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.setShadow(offset: .zero, blur: 2.0, color: UIColor(rgb: 0x000000, alpha: 0.55).cgColor)
                
                let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 6.0, y: 4.0), size: CGSize(width: 2.0, height: 42.0)), cornerRadius: 1.0)
                context.addPath(path.cgPath)
                context.fillPath()
            })?.stretchableImage(withLeftCapWidth: Int(handleWidth / 2.0), topCapHeight: 25)
            
            self.cursorView.image = positionImage
            self.cursorView.isUserInteractionEnabled = true
            self.cursorView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
                
            self.transparentFramesContainer.alpha = 0.5
            self.transparentFramesContainer.clipsToBounds = true
            self.transparentFramesContainer.layer.cornerRadius = 9.0
            
            self.opaqueFramesContainer.clipsToBounds = true
            self.opaqueFramesContainer.layer.cornerRadius = 9.0

            self.addSubview(self.audioClippingView)
            self.audioClippingView.addSubview(self.audioScrollView)
            self.audioScrollView.addSubview(self.audioContainerView)
            self.audioContainerView.addSubview(self.audioBackgroundView)
            self.audioBackgroundView.addSubview(self.audioVibrancyView)
                        
            self.addSubview(self.audioIconView)
            
            self.addSubview(self.transparentFramesContainer)
            self.addSubview(self.opaqueFramesContainer)
            self.addSubview(self.ghostTrimView)
            self.addSubview(self.trimView)
            
            self.addSubview(self.cursorView)
            
            self.cursorView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handlePositionHandlePan(_:))))
            
            self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] in
                self?.updateCursorPosition()
            }
            self.displayLink?.isPaused = true
            
            self.trimView.updated = { [weak self] transition in
                self?.state?.updated(transition: transition)
            }
            
            self.trimView.trimUpdated = { [weak self] startValue, endValue, updatedEnd, done in
                if let self, let component = self.component {
                    if self.isAudioSelected || component.audioOnly {
                        component.audioTrimUpdated(startValue, endValue, updatedEnd, done)
                    } else {
                        component.videoTrimUpdated(startValue, endValue, updatedEnd, done)
                    }
                }
            }
            
            self.ghostTrimView.trimUpdated = { [weak self] startValue, endValue, updatedEnd, done in
                if let self, let component = self.component {
                    component.videoTrimUpdated(startValue, endValue, updatedEnd, done)
                }
            }
            
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
            longPressGesture.delegate = self
            self.addGestureRecognizer(longPressGesture)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            self.addGestureRecognizer(tapGesture)
            
            let maskImage = generateImage(CGSize(width: 100.0, height: 50.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                
                var locations: [CGFloat] = [0.0, 0.75, 0.95, 1.0]
                let colors: [CGColor] = [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
                
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                
                context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
            })?.stretchableImage(withLeftCapWidth: 40, topCapHeight: 0)
            self.audioContentMaskView.image = maskImage
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.displayLink?.invalidate()
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let component = self.component, component.audioData != nil else {
                return false
            }
            let location = gestureRecognizer.location(in: self.audioContainerView)
            return self.audioContainerView.bounds.contains(location)
        }
                
        @objc private func longPressed(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard let component = self.component, component.audioData != nil, case .began = gestureRecognizer.state else {
                return
            }
            component.audioLongPressed?(self.audioClippingView)
        }
        
        @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let component = self.component, component.audioData != nil && !component.audioOnly else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            if location.y < self.frame.height / 2.0 {
                if self.isAudioSelected {
                    component.audioLongPressed?(self.audioClippingView)
                } else {
                    self.isAudioSelected = true
                }
            } else {
                self.isAudioSelected = false
            }
            self.state?.updated(transition: .easeInOut(duration: 0.25))
        }
        
        @objc private func handlePositionHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            let start = handleWidth
            let end = self.frame.width - handleWidth
            let length = end - start
            let fraction = (location.x - start) / length
            
            let position = max(component.startPosition, min(component.endPosition, component.duration * fraction))
            let transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningPositionHandle = true
                component.positionUpdated(position, false)
            case .ended, .cancelled:
                self.isPanningPositionHandle = false
                component.positionUpdated(position, true)
            default:
                break
            }
            self.state?.updated(transition: transition)
        }
        
        private func cursorFrame(size: CGSize, height: CGFloat, position: Double, duration : Double) -> CGRect {
            let cursorPadding: CGFloat = 8.0
            let cursorPositionFraction = duration > 0.0 ? position / duration : 0.0
            let cursorPosition = floorToScreenPixels(handleWidth - 1.0 + (size.width - handleWidth * 2.0 + 2.0) * cursorPositionFraction)
            var cursorFrame = CGRect(origin: CGPoint(x: cursorPosition - handleWidth / 2.0, y: -5.0 - UIScreenPixel), size: CGSize(width: handleWidth, height: height))
            cursorFrame.origin.x = max(self.ghostTrimView.leftHandleView.frame.maxX - cursorPadding, cursorFrame.origin.x)
            cursorFrame.origin.x = min(self.ghostTrimView.rightHandleView.frame.minX - handleWidth + cursorPadding, cursorFrame.origin.x)
            return cursorFrame
        }
        
        private func updateCursorPosition() {
            guard let component = self.component, let scrubberSize = self.scrubberSize else {
                return
            }
            let timestamp = CACurrentMediaTime()
            
            let updatedPosition: Double
            if let (start, from, to, _) = self.positionAnimation {
                let duration = to - from
                let fraction = duration > 0.0 ? (timestamp - start) / duration : 0.0
                updatedPosition = max(component.startPosition, min(component.endPosition, from + (to - from) * fraction))
                if fraction >= 1.0 {
                    self.positionAnimation = (start, from, to, true)
                }
            } else {
                let advance = component.isPlaying ? timestamp - component.generationTimestamp : 0.0
                updatedPosition = max(component.startPosition, min(component.endPosition, component.position + advance))
            }
            let cursorHeight: CGFloat = component.audioData != nil ? 80.0 : 50.0
            self.cursorView.frame = cursorFrame(size: scrubberSize, height: cursorHeight, position: updatedPosition, duration: component.duration)
        }
                
        func update(component: VideoScrubberComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let previousComponent = self.component
            let previousFramesUpdateTimestamp = self.component?.framesUpdateTimestamp
            self.component = component
            self.state = state
            
            var animateAudioAppearance = false
            if let previousComponent {
                if previousComponent.audioData == nil, component.audioData != nil {
                    self.positionAnimation = nil
//                    if !component.audioOnly {
//                        self.isAudioSelected = true
//                    }
                    animateAudioAppearance = true
                } else if previousComponent.audioData != nil, component.audioData == nil {
                    self.positionAnimation = nil
                    self.isAudioSelected = false
                    animateAudioAppearance = true
                }
            }
            
            let scrubberSpacing: CGFloat = 4.0
            
            var audioScrubberHeight: CGFloat = collapsedScrubberHeight
            var videoScrubberHeight: CGFloat = scrubberHeight
            
            let scrubberSize = CGSize(width: availableSize.width, height: scrubberHeight)
            self.scrubberSize = scrubberSize
            
            var audioTransition = transition
            var videoTransition = transition
            if animateAudioAppearance {
                audioTransition = .easeInOut(duration: 0.25)
                videoTransition = .easeInOut(duration: 0.25)
            }
            
            let totalWidth = scrubberSize.width - handleWidth
            var audioTotalWidth = scrubberSize.width
            
            var originY: CGFloat = 0
            var totalHeight = scrubberSize.height
            var audioAlpha: CGFloat = 0.0
            if let audioData = component.audioData {
                if component.audioOnly {
                    audioScrubberHeight = scrubberHeight
                    audioAlpha = 1.0
                } else {
                    totalHeight += collapsedScrubberHeight + scrubberSpacing
                    audioAlpha = 1.0
                    
                    originY += self.isAudioSelected ? scrubberHeight : collapsedScrubberHeight
                    originY += scrubberSpacing
                    
                    if self.isAudioSelected {
                        audioScrubberHeight = scrubberHeight
                        videoScrubberHeight = collapsedScrubberHeight
                    }
                    
                    if component.duration > 0.0 {
                        let audioFraction = audioData.duration / component.duration
                        audioTotalWidth = ceil(totalWidth * audioFraction)
                    }
                }
            } else {
                self.isAudioSelected = false
            }
            audioTransition.setAlpha(view: self.audioClippingView, alpha: audioAlpha)
            
            var audioClipOrigin: CGFloat = 0.0
            var audioClipWidth = availableSize.width + 18.0
            
            var deselectedAudioClipWidth: CGFloat = 0.0
            var deselectedAudioClipOrigin: CGFloat = 0.0
            if let audioData = component.audioData, !component.audioOnly {
                let duration: Double
                if component.duration > 0.0 {
                    if let end = audioData.end, let start = audioData.start {
                        duration = end - start
                    } else {
                        duration = component.duration
                    }
                    
                    let fraction = duration / component.duration
                    deselectedAudioClipWidth = availableSize.width * fraction
                    deselectedAudioClipOrigin = (audioData.start ?? 0.0) / component.duration * availableSize.width
                }
            }
            
            if !self.isAudioSelected {
                if let _ = component.audioData, !component.audioOnly {
                    audioClipOrigin = deselectedAudioClipOrigin
                    audioClipWidth = deselectedAudioClipWidth
                } else {
                    audioClipWidth = availableSize.width
                }
            }
            
            let audioClippingFrame = CGRect(origin: CGPoint(x: audioClipOrigin, y: 0.0), size: CGSize(width: audioClipWidth, height: audioScrubberHeight))
            let audioClippingBounds = CGRect(origin: CGPoint(x: audioClipOrigin, y: 0.0), size: CGSize(width: audioClipWidth, height: audioScrubberHeight))
            audioTransition.setFrame(view: self.audioClippingView, frame: audioClippingFrame)
            audioTransition.setBounds(view: self.audioClippingView, bounds: audioClippingBounds)
            
            self.audioScrollView.isUserInteractionEnabled = self.isAudioSelected
            audioTransition.setFrame(view: self.audioScrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: availableSize.width, height: audioScrubberHeight)))
            self.audioScrollView.contentSize = CGSize(width: audioTotalWidth, height: audioScrubberHeight)
            
            audioTransition.setCornerRadius(layer: self.audioClippingView.layer, cornerRadius: self.isAudioSelected ? 0.0 : 9.0)
            
            let audioContainerFrame = CGRect(origin: .zero, size: CGSize(width: audioTotalWidth, height: audioScrubberHeight))
            audioTransition.setFrame(view: self.audioContainerView, frame: audioContainerFrame)
            
            audioTransition.setFrame(view: self.audioBackgroundView, frame: CGRect(origin: .zero, size: audioContainerFrame.size))
            self.audioBackgroundView.update(size: audioContainerFrame.size, transition: audioTransition.containedViewLayoutTransition)
            audioTransition.setFrame(view: self.audioVibrancyView, frame: CGRect(origin: .zero, size: audioContainerFrame.size))
            audioTransition.setFrame(view: self.audioVibrancyContainer, frame: CGRect(origin: .zero, size: audioContainerFrame.size))
                        
            let containerFrame = CGRect(origin: .zero, size: CGSize(width: audioClipWidth, height: audioContainerFrame.height))
            var contentContainerOrigin = deselectedAudioClipOrigin + self.audioScrollView.contentOffset.x
            if self.isAudioSelected {
                contentContainerOrigin -= 6.0
            }
            audioTransition.setFrame(view: self.audioContentContainerView, frame: containerFrame.offsetBy(dx: contentContainerOrigin, dy: 0.0))
            audioTransition.setFrame(view: self.audioContentMaskView, frame: CGRect(origin: .zero, size: containerFrame.size))
            
            if let audioData = component.audioData, !component.audioOnly {
                var components: [String] = []
                if let artist = audioData.artist {
                    components.append(artist)
                }
                if let title = audioData.title {
                    components.append(title)
                }
                if components.isEmpty {
                    components.append("Audio")
                }
                let audioTitle = NSAttributedString(string: components.joined(separator: " • "), font: Font.semibold(13.0), textColor: .white)
                let audioTitleSize = self.audioTitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(audioTitle)
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                
                let spacing: CGFloat = 4.0
                let iconSize = CGSize(width: 14.0, height: 14.0)
                let totalWidth = iconSize.width + audioTitleSize.width + spacing
                
                audioTransition.setAlpha(view: self.audioIconView, alpha: self.isAudioSelected ? 0.0 : 1.0)
              
                let audioIconFrame = CGRect(origin: CGPoint(x: max(8.0, floorToScreenPixels((audioClipWidth - totalWidth) / 2.0)), y: floorToScreenPixels((audioScrubberHeight - iconSize.height) / 2.0)), size: iconSize)
                audioTransition.setBounds(view: self.audioIconView, bounds: CGRect(origin: .zero, size: audioIconFrame.size))
                audioTransition.setPosition(view: self.audioIconView, position: audioIconFrame.center)
                
                if let view = self.audioTitle.view {
                    if view.superview == nil {
                        view.alpha = 0.0
                        view.isUserInteractionEnabled = false
                        self.audioContainerView.addSubview(self.audioContentContainerView)
                        self.audioContentContainerView.addSubview(self.audioIconView)
                        self.audioContentContainerView.addSubview(view)
                    }
                    audioTransition.setAlpha(view: view, alpha: self.isAudioSelected ? 0.0 : 1.0)
                    
                    let audioTitleFrame = CGRect(origin: CGPoint(x: audioIconFrame.maxX + spacing, y: floorToScreenPixels((audioScrubberHeight - audioTitleSize.height) / 2.0)), size: audioTitleSize)
                    view.bounds = CGRect(origin: .zero, size: audioTitleFrame.size)
                    audioTransition.setPosition(view: view, position: audioTitleFrame.center)
                }
            } else {
                audioTransition.setAlpha(view: self.audioIconView, alpha: 0.0)
                if let view = self.audioTitle.view {
                    audioTransition.setAlpha(view: view, alpha: 0.0)
                }
            }
            
            if let audioData = component.audioData {
                let samples = audioData.samples ?? Data()
                
                if let view = self.audioWaveform.view, previousComponent?.audioData?.samples == nil && audioData.samples != nil, let snapshotView = view.snapshotView(afterScreenUpdates: false) {
                    snapshotView.frame = view.frame
                    self.audioVibrancyContainer.addSubview(snapshotView)
                    
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        snapshotView.removeFromSuperview()
                    })
                    
                    view.layer.animateScaleY(from: 0.01, to: 1.0, duration: 0.2)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                let audioWaveformSize = self.audioWaveform.update(
                    transition: transition,
                    component: AnyComponent(
                        AudioWaveformComponent(
                            backgroundColor: .clear,
                            foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.3),
                            shimmerColor: nil,
                            style: .middle,
                            samples: samples,
                            peak: audioData.peak,
                            status: .complete(),
                            seek: nil,
                            updateIsSeeking: nil
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: audioContainerFrame.width, height: scrubberHeight)
                )
                if let view = self.audioWaveform.view {
                    if view.superview == nil {
                        self.audioVibrancyContainer.addSubview(view)
                    }
                    audioTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isAudioSelected || component.audioOnly ? 0.0 : 6.0), size: audioWaveformSize))
                }
            }
            self.cursorView.isHidden = component.audioOnly
            
            let bounds = CGRect(origin: .zero, size: scrubberSize)
            
            if component.framesUpdateTimestamp != previousFramesUpdateTimestamp {
                for i in 0 ..< component.frames.count {
                    let transparentFrameLayer: VideoFrameLayer
                    let opaqueFrameLayer: VideoFrameLayer
                    if i >= self.transparentFrameLayers.count {
                        transparentFrameLayer = VideoFrameLayer()
                        transparentFrameLayer.masksToBounds = true
                        transparentFrameLayer.contentsGravity = .resizeAspectFill
                        self.transparentFramesContainer.layer.addSublayer(transparentFrameLayer)
                        self.transparentFrameLayers.append(transparentFrameLayer)
                        opaqueFrameLayer = VideoFrameLayer()
                        opaqueFrameLayer.masksToBounds = true
                        opaqueFrameLayer.contentsGravity = .resizeAspectFill
                        self.opaqueFramesContainer.layer.addSublayer(opaqueFrameLayer)
                        self.opaqueFrameLayers.append(opaqueFrameLayer)
                    } else {
                        transparentFrameLayer = self.transparentFrameLayers[i]
                        opaqueFrameLayer = self.opaqueFrameLayers[i]
                    }
                    transparentFrameLayer.contents = component.frames[i].cgImage
                    if let contents = opaqueFrameLayer.contents, (contents as! CGImage) !== component.frames[i].cgImage, opaqueFrameLayer.animation(forKey: "contents") == nil {
                        opaqueFrameLayer.contents = component.frames[i].cgImage
                        opaqueFrameLayer.animate(from: contents as AnyObject, to: component.frames[i].cgImage! as AnyObject, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
                    } else {
                        opaqueFrameLayer.contents = component.frames[i].cgImage
                    }
                }
            }
            
            var startPosition = component.startPosition
            var endPosition = component.endPosition
            if self.isAudioSelected, let audioData = component.audioData {
                if let start = audioData.start {
                    startPosition = start
                }
                if let end = audioData.end {
                    endPosition = end
                }
            }
                        
            self.trimView.isHollow = self.isAudioSelected
            let (leftHandleFrame, rightHandleFrame) = self.trimView.update(
                totalWidth: totalWidth,
                scrubberSize: scrubberSize,
                duration: component.duration,
                startPosition: startPosition,
                endPosition: endPosition,
                position: component.position,
                minDuration: component.minDuration,
                maxDuration: component.maxDuration,
                transition: transition
            )
            
            let (ghostLeftHandleFrame, ghostRightHandleFrame) = self.ghostTrimView.update(
                totalWidth: totalWidth,
                scrubberSize: CGSize(width: scrubberSize.width, height: collapsedScrubberHeight),
                duration: component.duration,
                startPosition: component.startPosition,
                endPosition: component.endPosition,
                position: component.position,
                minDuration: component.minDuration,
                maxDuration: component.maxDuration,
                transition: transition
            )
            
            var containerLeftEdge = leftHandleFrame.maxX
            var containerRightEdge = rightHandleFrame.minX
            if self.isAudioSelected && component.duration > 0.0 {
                containerLeftEdge = ghostLeftHandleFrame.maxX
                containerRightEdge = ghostRightHandleFrame.minX
            }
            
            transition.setAlpha(view: self.cursorView, alpha: self.trimView.isPanningTrimHandle || self.ghostTrimView.isPanningTrimHandle ? 0.0 : 1.0)
            if self.isPanningPositionHandle || !component.isPlaying {
                self.positionAnimation = nil
                self.displayLink?.isPaused = true
                
                let cursorHeight: CGFloat = component.audioData != nil ? 80.0 : 50.0
                let cursorPosition = component.position
//                if self.cursorView.alpha.isZero {
//                    cursorPosition = component.startPosition
//                }
                videoTransition.setFrame(view: self.cursorView, frame: cursorFrame(size: scrubberSize, height: cursorHeight, position: cursorPosition, duration: component.duration))
            } else {
                if let (_, _, end, ended) = self.positionAnimation {
                    if ended, component.position >= component.startPosition && component.position < end - 1.0 {
                        self.positionAnimation = (CACurrentMediaTime(), component.position, component.endPosition, false)
                    }
                } else {
                    self.positionAnimation = (CACurrentMediaTime(), component.position, component.endPosition, false)
                }
                self.displayLink?.isPaused = false
                self.updateCursorPosition()
            }
            
            videoTransition.setFrame(view: self.trimView, frame: bounds.offsetBy(dx: 0.0, dy: self.isAudioSelected ? 0.0 : originY))
            
            videoTransition.setFrame(view: self.ghostTrimView, frame: bounds.offsetBy(dx: 0.0, dy: originY))
            videoTransition.setAlpha(view: self.ghostTrimView, alpha: self.isAudioSelected ? 0.75 : 0.0)
            
            let handleInset: CGFloat = 7.0
            videoTransition.setFrame(view: self.transparentFramesContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: originY), size: CGSize(width: scrubberSize.width, height: videoScrubberHeight)))
            videoTransition.setFrame(view: self.opaqueFramesContainer, frame: CGRect(origin: CGPoint(x: containerLeftEdge - handleInset, y: originY), size: CGSize(width: containerRightEdge - containerLeftEdge + handleInset * 2.0, height: videoScrubberHeight)))
            videoTransition.setBounds(view: self.opaqueFramesContainer, bounds: CGRect(origin: CGPoint(x: containerLeftEdge - handleInset, y: 0.0), size: CGSize(width: containerRightEdge - containerLeftEdge + handleInset * 2.0, height: videoScrubberHeight)))
            
            videoTransition.setCornerRadius(layer: self.opaqueFramesContainer.layer, cornerRadius: self.isAudioSelected ? 9.0 : 0.0)
                        
            var frameAspectRatio = 0.66
            if let image = component.frames.first, image.size.height > 0.0 {
                frameAspectRatio = max(0.66, image.size.width / image.size.height)
            }
            let frameSize = CGSize(width: 39.0 * frameAspectRatio, height: 39.0)
            var frameOffset: CGFloat = 0.0
            for i in 0 ..< component.frames.count {
                if i < self.transparentFrameLayers.count {
                    let transparentFrameLayer = self.transparentFrameLayers[i]
                    let opaqueFrameLayer = self.opaqueFrameLayers[i]
                    let frame = CGRect(origin: CGPoint(x: frameOffset, y: floorToScreenPixels((videoScrubberHeight - frameSize.height) / 2.0)), size: frameSize)
                    
                    transparentFrameLayer.bounds = CGRect(origin: .zero, size: frame.size)
                    opaqueFrameLayer.bounds = CGRect(origin: .zero, size: frame.size)
                    
                    videoTransition.setPosition(layer: transparentFrameLayer, position: frame.center)
                    videoTransition.setPosition(layer: opaqueFrameLayer, position: frame.center)
                }
                frameOffset += frameSize.width
            }
            
            return CGSize(width: availableSize.width, height: totalHeight)
        }
        
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
            return self.bounds.inset(by: hitTestSlop).contains(point)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private class TrimView: UIView {
    fileprivate let leftHandleView = HandleView()
    fileprivate let rightHandleView = HandleView()
    private let borderView = UIImageView()
    private let zoneView = HandleView()
    
    private let leftCapsuleView = UIView()
    private let rightCapsuleView = UIView()
    
    fileprivate var isPanningTrimHandle = false
    
    var isHollow = false
    
    var trimUpdated: (Double, Double, Bool, Bool) -> Void = { _, _, _, _ in }
    var updated: (Transition) -> Void = { _ in }
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        
        let height = scrubberHeight
        let handleImage = generateImage(CGSize(width: handleWidth, height: height), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setFillColor(UIColor.white.cgColor)
            
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width * 2.0, height: size.height)), cornerRadius: 9.0)
            context.addPath(path.cgPath)
            context.fillPath()
            
            context.setBlendMode(.clear)
            let innerPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: handleWidth - 3.0, y: borderHeight), size: CGSize(width: handleWidth, height: size.height - borderHeight * 2.0)), cornerRadius: 2.0)
            context.addPath(innerPath.cgPath)
            context.fillPath()
            
//            if !ghost {
//                context.setBlendMode(.clear)
//                let holeSize = CGSize(width: 2.0, height: 11.0)
//                let holePath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 5.0 - UIScreenPixel, y: (size.height - holeSize.height) / 2.0), size: holeSize), cornerRadius: holeSize.width / 2.0)
//                context.addPath(holePath.cgPath)
//                context.fillPath()
//            }
        })?.withRenderingMode(.alwaysTemplate).resizableImage(withCapInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0))
        
        self.zoneView.image = UIImage()
        self.zoneView.isUserInteractionEnabled = true
        self.zoneView.hitTestSlop = UIEdgeInsets(top: -8.0, left: 0.0, bottom: -8.0, right: 0.0)
        
        self.leftHandleView.image = handleImage
        self.leftHandleView.isUserInteractionEnabled = true
        self.leftHandleView.tintColor = .white
        self.leftHandleView.contentMode = .scaleToFill
        self.leftHandleView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
        
        self.rightHandleView.image = handleImage
        self.rightHandleView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.rightHandleView.isUserInteractionEnabled = true
        self.rightHandleView.tintColor = .white
        self.rightHandleView.contentMode = .scaleToFill
        self.rightHandleView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
        
        self.borderView.image = generateImage(CGSize(width: 1.0, height: height), rotatedContext: { size, context in
            context.clear(CGRect(origin: .zero, size: size))
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: CGSize(width: size.width, height: borderHeight)))
            context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - borderHeight), size: CGSize(width: size.width, height: height)))
        })?.withRenderingMode(.alwaysTemplate).resizableImage(withCapInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0))
        self.borderView.tintColor = .white
        self.borderView.isUserInteractionEnabled = false
        
        self.leftCapsuleView.clipsToBounds = true
        self.leftCapsuleView.layer.cornerRadius = 1.0
        self.leftCapsuleView.backgroundColor = UIColor(rgb: 0x343436)
        
        self.rightCapsuleView.clipsToBounds = true
        self.rightCapsuleView.layer.cornerRadius = 1.0
        self.rightCapsuleView.backgroundColor = UIColor(rgb: 0x343436)
        
        self.addSubview(self.zoneView)
        self.addSubview(self.leftHandleView)
        self.leftHandleView.addSubview(self.leftCapsuleView)
        
        self.addSubview(self.rightHandleView)
        self.rightHandleView.addSubview(self.rightCapsuleView)
        self.addSubview(self.borderView)
        
        self.zoneView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleZoneHandlePan(_:))))
        self.leftHandleView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleLeftHandlePan(_:))))
        self.rightHandleView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleRightHandlePan(_:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleZoneHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let params = self.params else {
            return
        }
        let translation = gestureRecognizer.translation(in: self)
        
        let start = handleWidth / 2.0
        let end = self.frame.width - handleWidth / 2.0
        let length = end - start
        
        let delta = translation.x / length
        
        let duration = params.endPosition - params.startPosition
        let startValue = max(0.0, min(params.duration - duration, params.startPosition + delta * params.duration))
        let endValue = startValue + duration
        
        var transition: Transition = .immediate
        switch gestureRecognizer.state {
        case .began, .changed:
            self.isPanningTrimHandle = true
            self.trimUpdated(startValue, endValue, false, false)
            if case .began = gestureRecognizer.state {
                transition = .easeInOut(duration: 0.25)
            }
        case .ended, .cancelled:
            self.isPanningTrimHandle = false
            self.trimUpdated(startValue, endValue, false, true)
            transition = .easeInOut(duration: 0.25)
        default:
            break
        }
        
        gestureRecognizer.setTranslation(.zero, in: self)
        self.updated(transition)
    }
    
    @objc private func handleLeftHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let params = self.params else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        let start = handleWidth / 2.0
        let end = self.frame.width - handleWidth / 2.0
        let length = end - start
        let fraction = (location.x - start) / length
        
        var startValue = max(0.0, params.duration * fraction)
        if startValue > params.endPosition - params.minDuration {
            startValue = max(0.0, params.endPosition - params.minDuration)
        }
        var endValue = params.endPosition
        if endValue - startValue > params.maxDuration {
            let delta = (endValue - startValue) - params.maxDuration
            endValue -= delta
        }
        
        var transition: Transition = .immediate
        switch gestureRecognizer.state {
        case .began, .changed:
            self.isPanningTrimHandle = true
            self.trimUpdated(startValue, endValue, false, false)
            if case .began = gestureRecognizer.state {
                transition = .easeInOut(duration: 0.25)
            }
        case .ended, .cancelled:
            self.isPanningTrimHandle = false
            self.trimUpdated(startValue, endValue, false, true)
            transition = .easeInOut(duration: 0.25)
        default:
            break
        }
        self.updated(transition)
    }
    
    @objc private func handleRightHandlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        guard let params = self.params else {
            return
        }
        let location = gestureRecognizer.location(in: self)
        let start = handleWidth / 2.0
        let end = self.frame.width - handleWidth / 2.0
        let length = end - start
        let fraction = (location.x - start) / length
       
        var endValue = min(params.duration, params.duration * fraction)
        if endValue < params.startPosition + params.minDuration {
            endValue = min(params.duration, params.startPosition + params.minDuration)
        }
        var startValue = params.startPosition
        if endValue - startValue > params.maxDuration {
            let delta = (endValue - startValue) - params.maxDuration
            startValue += delta
        }
        
        var transition: Transition = .immediate
        switch gestureRecognizer.state {
        case .began, .changed:
            self.isPanningTrimHandle = true
            self.trimUpdated(startValue, endValue, true, false)
            if case .began = gestureRecognizer.state {
                transition = .easeInOut(duration: 0.25)
            }
        case .ended, .cancelled:
            self.isPanningTrimHandle = false
            self.trimUpdated(startValue, endValue, true, true)
            transition = .easeInOut(duration: 0.25)
        default:
            break
        }
        self.updated(transition)
    }
    
    var params: (
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double
    )?
    
    func update(
        totalWidth: CGFloat,
        scrubberSize: CGSize,
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double,
        transition: Transition
    ) -> (leftHandleFrame: CGRect, rightHandleFrame: CGRect)
    {
        self.params = (duration, startPosition, endPosition, position, minDuration, maxDuration)
        
        let trimColor = self.isPanningTrimHandle ? UIColor(rgb: 0xf8d74a) : .white
        transition.setTintColor(view: self.leftHandleView, color: trimColor)
        transition.setTintColor(view: self.rightHandleView, color: trimColor)
        transition.setTintColor(view: self.borderView, color: trimColor)
        
        let leftHandlePositionFraction = duration > 0.0 ? startPosition / duration : 0.0
        let leftHandlePosition = floorToScreenPixels(handleWidth / 2.0 + totalWidth * leftHandlePositionFraction)
        
        let leftHandleFrame = CGRect(origin: CGPoint(x: leftHandlePosition - handleWidth / 2.0, y: 0.0), size: CGSize(width: handleWidth, height: scrubberSize.height))
        transition.setFrame(view: self.leftHandleView, frame: leftHandleFrame)

        let rightHandlePositionFraction = duration > 0.0 ? endPosition / duration : 1.0
        let rightHandlePosition = floorToScreenPixels(handleWidth / 2.0 + totalWidth * rightHandlePositionFraction)
        
        let rightHandleFrame = CGRect(origin: CGPoint(x: max(leftHandleFrame.maxX, rightHandlePosition - handleWidth / 2.0), y: 0.0), size: CGSize(width: handleWidth, height: scrubberSize.height))
        transition.setFrame(view: self.rightHandleView, frame: rightHandleFrame)
        
        let capsuleSize = CGSize(width: 2.0, height: 11.0)
        transition.setFrame(view: self.leftCapsuleView, frame: CGRect(origin: CGPoint(x: 5.0 - UIScreenPixel, y: floorToScreenPixels((leftHandleFrame.height - capsuleSize.height) / 2.0)), size: capsuleSize))
        transition.setFrame(view: self.rightCapsuleView, frame: CGRect(origin: CGPoint(x: 5.0 - UIScreenPixel, y: floorToScreenPixels((leftHandleFrame.height - capsuleSize.height) / 2.0)), size: capsuleSize))
        
        let zoneFrame = CGRect(x: leftHandleFrame.maxX, y: 0.0, width: rightHandleFrame.minX - leftHandleFrame.maxX, height: scrubberSize.height)
        transition.setFrame(view: self.zoneView, frame: zoneFrame)
        
        let borderFrame = CGRect(origin: CGPoint(x: leftHandleFrame.maxX, y: 0.0), size: CGSize(width: rightHandleFrame.minX - leftHandleFrame.maxX, height: scrubberSize.height))
        transition.setFrame(view: self.borderView, frame: borderFrame)
        
        return (leftHandleFrame, rightHandleFrame)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let leftHandleFrame = self.leftHandleView.frame.insetBy(dx: -8.0, dy: -9.0)
        let rightHandleFrame = self.rightHandleView.frame.insetBy(dx: -8.0, dy: -9.0)
        let areaFrame = CGRect(x: leftHandleFrame.minX, y: leftHandleFrame.minY, width: rightHandleFrame.maxX - leftHandleFrame.minX, height: rightHandleFrame.maxY - rightHandleFrame.minY)
        
        if self.isHollow {
            return leftHandleFrame.contains(point) || rightHandleFrame.contains(point)
        } else {
            return areaFrame.contains(point)
        }
    }
}
