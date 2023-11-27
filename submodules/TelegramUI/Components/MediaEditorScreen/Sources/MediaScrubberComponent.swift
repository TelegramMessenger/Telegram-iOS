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
import MediaEditor

private let handleWidth: CGFloat = 14.0
private let trackHeight: CGFloat = 39.0
private let collapsedTrackHeight: CGFloat = 26.0
private let trackSpacing: CGFloat = 4.0
private let borderHeight: CGFloat = 1.0 + UIScreenPixel
private let frameWidth: CGFloat = 24.0

final class MediaScrubberComponent: Component {
    typealias EnvironmentType = Empty
    
    struct Track: Equatable {
        enum Content: Equatable {
            case video(frames: [UIImage], framesUpdateTimestamp: Double)
            case audio(artist: String?, title: String?, samples: Data?, peak: Int32)
            
            static func ==(lhs: Content, rhs: Content) -> Bool {
                switch lhs {
                case let .video(_, framesUpdateTimestamp):
                    if case .video(_, framesUpdateTimestamp) = rhs {
                        return true
                    } else {
                        return false
                    }
                case let .audio(lhsArtist, lhsTitle, lhsSamples, lhsPeak):
                    if case let .audio(rhsArtist, rhsTitle, rhsSamples, rhsPeak) = rhs {
                        return lhsArtist == rhsArtist && lhsTitle == rhsTitle && lhsSamples == rhsSamples && lhsPeak == rhsPeak
                    } else {
                        return false
                    }
                }
            }
        }
        
        let id: Int32
        let content: Content
        let duration: Double
        let trimRange: Range<Double>?
        let offset: Double?
        let isMain: Bool
        
        init(_ track: MediaEditorPlayerState.Track) {
            self.id = track.id
            switch track.content {
            case let .video(frames, framesUpdateTimestamp):
                self.content = .video(frames: frames, framesUpdateTimestamp: framesUpdateTimestamp)
            case let .audio(artist, title, samples, peak):
                self.content = .audio(artist: artist, title: title, samples: samples, peak: peak)
            }
            self.duration = track.duration
            self.trimRange = track.trimRange
            self.offset = track.offset
            self.isMain = track.isMain
        }
    }
    
    let context: AccountContext
    let generationTimestamp: Double

    let position: Double
    let minDuration: Double
    let maxDuration: Double
    let isPlaying: Bool
    
    let tracks: [Track]
    
    let positionUpdated: (Double, Bool) -> Void    
    let trackTrimUpdated: (Int32, Double, Double, Bool, Bool) -> Void
    let trackOffsetUpdated: (Int32, Double, Bool) -> Void
    let trackLongPressed: (Int32, UIView) -> Void
    
    init(
        context: AccountContext,
        generationTimestamp: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double,
        isPlaying: Bool,
        tracks: [Track],
        positionUpdated: @escaping (Double, Bool) -> Void,
        trackTrimUpdated: @escaping (Int32, Double, Double, Bool, Bool) -> Void,
        trackOffsetUpdated: @escaping (Int32, Double, Bool) -> Void,
        trackLongPressed: @escaping (Int32, UIView) -> Void
    ) {
        self.context = context
        self.generationTimestamp = generationTimestamp
        self.position = position
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.isPlaying = isPlaying
        self.tracks = tracks
        self.positionUpdated = positionUpdated
        self.trackTrimUpdated = trackTrimUpdated
        self.trackOffsetUpdated = trackOffsetUpdated
        self.trackLongPressed = trackLongPressed
    }
    
    static func ==(lhs: MediaScrubberComponent, rhs: MediaScrubberComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.generationTimestamp != rhs.generationTimestamp {
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
        if lhs.tracks != rhs.tracks {
            return false
        }
        return true
    }
    
    final class View: UIView, UIGestureRecognizerDelegate {
        private var trackViews: [Int32: TrackView] = [:]
        private let trimView: TrimView
        private let ghostTrimView: TrimView
        private let cursorView: HandleView
        
        private var cursorDisplayLink: SharedDisplayLinkDriver.Link?
        private var cursorPositionAnimation: (start: Double, from: Double, to: Double, ended: Bool)?
    
        private var selectedTrackId: Int32 = 0
        private var isPanningCursor = false
        
        private var scrubberSize: CGSize?
        
        private var component: MediaScrubberComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.trimView = TrimView(frame: .zero)
            self.ghostTrimView = TrimView(frame: .zero)
            self.ghostTrimView.isHollow = true
            self.cursorView = HandleView()
            
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
                
            self.addSubview(self.ghostTrimView)
            self.addSubview(self.trimView)
            self.addSubview(self.cursorView)
            
            self.cursorView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.handleCursorPan(_:))))
            
            self.cursorDisplayLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                self?.updateCursorPosition()
            }
            self.cursorDisplayLink?.isPaused = true
            
            self.trimView.updated = { [weak self] transition in
                self?.state?.updated(transition: transition)
            }
            self.trimView.trimUpdated = { [weak self] startValue, endValue, updatedEnd, done in
                if let self, let component = self.component {
                    component.trackTrimUpdated(self.selectedTrackId, startValue, endValue, updatedEnd, done)
                }
            }
            self.ghostTrimView.trimUpdated = { [weak self] startValue, endValue, updatedEnd, done in
                if let self, let component = self.component {
                    component.trackTrimUpdated(0, startValue, endValue, updatedEnd, done)
                }
            }
            
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
            longPressGesture.delegate = self
            self.addGestureRecognizer(longPressGesture)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.cursorDisplayLink?.invalidate()
        }
        
        private var isAudioOnly: Bool {
            guard let component = self.component else {
                return false
            }
            var hasVideoTracks = false
            var hasAudioTracks = false
            for track in component.tracks {
                switch track.content {
                case .video:
                    hasVideoTracks = true
                case .audio:
                    hasAudioTracks = true
                }
            }
            return !hasVideoTracks && hasAudioTracks
        }
        
        private var trimDuration: Double {
            guard let component = self.component, var duration = component.tracks.first?.duration else {
                return 0.0
            }
            if self.isAudioOnly {
                duration = min(30.0, duration)
            }
            return duration
        }
        
        private var duration: Double {
            guard let component = self.component, let firstTrack = component.tracks.first else {
                return 0.0
            }
            return max(0.0, firstTrack.duration)
        }
        
        private var startPosition: Double {
            guard let component = self.component, let firstTrack = component.tracks.first else {
                return 0.0
            }
            return max(0.0, firstTrack.trimRange?.lowerBound ?? 0.0)
        }
        
        private var endPosition: Double {
            guard let component = self.component, let firstTrack = component.tracks.first else {
                return 0.0
            }
            return firstTrack.trimRange?.upperBound ?? min(firstTrack.duration, storyMaxVideoDuration)
        }
        
        private var mainAudioTrackOffset: Double? {
            guard self.isAudioOnly, let component = self.component, let firstTrack = component.tracks.first else {
                return nil
            }
            return firstTrack.offset
        }
        
        @objc private func longPressed(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard let component = self.component, case .began = gestureRecognizer.state else {
                return
            }
            let point = gestureRecognizer.location(in: self)
            for (id, trackView) in self.trackViews {
                if trackView.frame.contains(point) {
                    component.trackLongPressed(id, trackView.clippingView)
                    return
                }
            }
        }
                
        @objc private func handleCursorPan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }

            let location = gestureRecognizer.location(in: self)
            let start = handleWidth
            let end = self.frame.width - handleWidth
            let length = end - start
            let fraction = (location.x - start) / length
            
            var position = max(self.startPosition, min(self.endPosition, self.trimDuration * fraction))
            if let offset = self.mainAudioTrackOffset {
                position += offset
            }
            let transition: Transition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningCursor = true
                component.positionUpdated(position, false)
            case .ended, .cancelled:
                self.isPanningCursor = false
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
            
            var leftEdge = self.ghostTrimView.leftHandleView.frame.maxX
            var rightEdge = self.ghostTrimView.rightHandleView.frame.minX
            if self.isAudioOnly {
                leftEdge = self.trimView.leftHandleView.frame.maxX
                rightEdge = self.trimView.rightHandleView.frame.minX
            }
            
            cursorFrame.origin.x = max(leftEdge - cursorPadding, cursorFrame.origin.x)
            cursorFrame.origin.x = min(rightEdge - handleWidth + cursorPadding, cursorFrame.origin.x)
            return cursorFrame
        }
        
        private var effectiveCursorHeight: CGFloat {
            let additionalTracksCount = max(0, (self.component?.tracks.count ?? 1) - 1)
            return 50.0 + CGFloat(additionalTracksCount) * 30.0
        }
        
        private func updateCursorPosition() {
            guard let component = self.component, let scrubberSize = self.scrubberSize else {
                return
            }
            let timestamp = CACurrentMediaTime()
            
            let updatedPosition: Double
            if let (start, from, to, _) = self.cursorPositionAnimation {
                var from = from
                if let offset = self.mainAudioTrackOffset {
                    from -= offset
                }
                let duration = to - from
                let fraction = duration > 0.0 ? (timestamp - start) / duration : 0.0
                updatedPosition = max(self.startPosition, min(self.endPosition, from + (to - from) * fraction))
                if fraction >= 1.0 {
                    self.cursorPositionAnimation = (start, from, to, true)
                }
            } else {
                var position = component.position
                if let offset = self.mainAudioTrackOffset {
                    position -= offset
                }
                let advance = component.isPlaying ? timestamp - component.generationTimestamp : 0.0
                updatedPosition = max(self.startPosition, min(self.endPosition, position + advance))
            }
            self.cursorView.frame = cursorFrame(size: scrubberSize, height: self.effectiveCursorHeight, position: updatedPosition, duration: self.trimDuration)
        }
                
        func update(component: MediaScrubberComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            let isFirstTime = self.component == nil
            self.component = component
            self.state = state
            
            var totalHeight: CGFloat = 0.0
            var trackLayout: [Int32: (CGRect, Transition, Bool)] = [:]
            
            if !component.tracks.contains(where: { $0.id == self.selectedTrackId }) {
                self.selectedTrackId = component.tracks.first(where: { $0.isMain })?.id ?? 0
            }
            
            var lowestVideoId: Int32?
            
            var validIds = Set<Int32>()
            for track in component.tracks {
                let id = track.id
                validIds.insert(id)
                
                if case .video = track.content {
                    if lowestVideoId == nil {
                        lowestVideoId = track.id
                    }
                }
                
                var trackTransition = transition
                let trackView: TrackView
                var animateTrackIn = false
                if let current = self.trackViews[id] {
                    trackView = current
                } else {
                    trackTransition = .immediate
                    trackView = TrackView()
                    trackView.onSelection = { [weak self] id in
                        guard let self else {
                            return
                        }
                        self.selectedTrackId = id
                        self.state?.updated(transition: .easeInOut(duration: 0.2))
                    }
                    trackView.offsetUpdated = { [weak self] offset, apply in
                        guard let self, let component = self.component else {
                            return
                        }
                        component.trackOffsetUpdated(id, offset, apply)
                    }
                    trackView.updated = { [weak self] transition in
                        guard let self else {
                            return
                        }
                        self.state?.updated(transition: transition)
                    }
                    self.trackViews[id] = trackView
                    
                    self.insertSubview(trackView, at: 0)
                    
                    if !isFirstTime {
                        animateTrackIn = true
                    }
                }
                
                let trackSize = trackView.update(
                    context: component.context,
                    track: track,
                    isSelected: id == self.selectedTrackId,
                    availableSize: availableSize,
                    duration: self.duration,
                    transition: trackTransition
                )
                trackLayout[id] = (CGRect(origin: CGPoint(x: 0.0, y: totalHeight), size: trackSize), trackTransition, animateTrackIn)
                
                totalHeight += trackSize.height
                totalHeight += trackSpacing
            }
            totalHeight -= trackSpacing
            
            for track in component.tracks {
                guard let trackView = self.trackViews[track.id], let (trackFrame, trackTransition, animateTrackIn) = trackLayout[track.id] else {
                    continue
                }
                trackTransition.setFrame(view: trackView, frame: CGRect(origin: CGPoint(x: 0.0, y: totalHeight - trackFrame.maxY), size: trackFrame.size))
                if animateTrackIn {
                    trackView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    trackView.layer.animatePosition(from: CGPoint(x: 0.0, y: trackFrame.height + trackSpacing), to: .zero, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                }
            }
            
            var removeIds: [Int32] = []
            for (id, trackView) in self.trackViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    trackView.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: trackView.frame.height), duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
                    transition.setAlpha(view: trackView, alpha: 0.0, completion: { [weak trackView] _ in
                        trackView?.removeFromSuperview()
                    })
                }
            }
            for id in removeIds {
                self.trackViews.removeValue(forKey: id)
            }
            
            var startPosition = self.startPosition
            var endPosition = self.endPosition
            var trimViewOffset: CGFloat = 0.0
            var trimViewVisualInsets: UIEdgeInsets = .zero
            var trackViewWidth: CGFloat = availableSize.width
            var mainTrimDuration = self.trimDuration
            
            if let track = component.tracks.first(where: { $0.id == self.selectedTrackId }), track.id != 0 {
                if let trimRange = track.trimRange {
                    startPosition = trimRange.lowerBound
                    endPosition = trimRange.upperBound
                }
                if let trackView = self.trackViews[track.id] {
                    if trackView.scrollView.contentOffset.x < 0.0 {
                        trimViewOffset = -trackView.scrollView.contentOffset.x
                        trimViewVisualInsets.right = trimViewOffset
                    } else if trackView.scrollView.contentSize.width > trackView.scrollView.frame.width, trackView.scrollView.contentOffset.x > trackView.scrollView.contentSize.width - trackView.scrollView.frame.width {
                        let delta = trackView.scrollView.contentOffset.x - (trackView.scrollView.contentSize.width - trackView.scrollView.frame.width)
                        trimViewOffset = -delta
                        trimViewVisualInsets.left = delta
                    }
                    
                    if lowestVideoId == 0 && track.id == 1 {
                        trimViewVisualInsets = .zero
                        trackViewWidth = trackView.containerView.frame.width
                        mainTrimDuration = track.duration
                    }
                }
            }

            let scrubberSize = CGSize(width: availableSize.width, height: trackHeight)
            
            self.trimView.isHollow = self.selectedTrackId != lowestVideoId || self.isAudioOnly
            let (leftHandleFrame, rightHandleFrame) = self.trimView.update(
                visualInsets: trimViewVisualInsets,
                scrubberSize: CGSize(width: trackViewWidth, height: trackHeight),
                duration: mainTrimDuration,
                startPosition: startPosition,
                endPosition: endPosition,
                position: component.position,
                minDuration: component.minDuration,
                maxDuration: component.maxDuration,
                transition: transition
            )
            
            let (ghostLeftHandleFrame, ghostRightHandleFrame) = self.ghostTrimView.update(
                visualInsets: .zero,
                scrubberSize: CGSize(width: scrubberSize.width, height: collapsedTrackHeight),
                duration: self.duration,
                startPosition: self.startPosition,
                endPosition: self.endPosition,
                position: component.position,
                minDuration: component.minDuration,
                maxDuration: component.maxDuration,
                transition: transition
            )
            
            let _ = leftHandleFrame
            let _ = rightHandleFrame
            let _ = ghostLeftHandleFrame
            let _ = ghostRightHandleFrame
            
            let scrubberBounds = CGRect(origin: .zero, size: scrubberSize)
            var selectedTrackFrame = scrubberBounds
            var mainTrackFrame = scrubberBounds
            if let (trackFrame, _, _) = trackLayout[0] {
                mainTrackFrame = CGRect(origin: CGPoint(x: trackFrame.minX, y: totalHeight - trackFrame.maxY), size: trackFrame.size)
            }
            if let (trackFrame, _, _) = trackLayout[self.selectedTrackId] {
                selectedTrackFrame = CGRect(origin: CGPoint(x: trackFrame.minX, y: totalHeight - trackFrame.maxY), size: trackFrame.size)
            } else {
                selectedTrackFrame = mainTrackFrame
            }

            let trimViewFrame = CGRect(origin: CGPoint(x: trimViewOffset, y: selectedTrackFrame.minY), size: scrubberSize)
            transition.setFrame(view: self.trimView, frame: trimViewFrame)
            
            var ghostTrimVisible = false
            if let lowestVideoId, self.selectedTrackId != lowestVideoId {
                ghostTrimVisible = true
            }
            
            let ghostTrimViewFrame = CGRect(origin: CGPoint(x: 0.0, y: totalHeight - collapsedTrackHeight), size: CGSize(width: availableSize.width, height: collapsedTrackHeight))
            transition.setFrame(view: self.ghostTrimView, frame: ghostTrimViewFrame)
            transition.setAlpha(view: self.ghostTrimView, alpha: ghostTrimVisible ? 0.75 : 0.0)
            
//            var containerLeftEdge = leftHandleFrame.maxX
//            var containerRightEdge = rightHandleFrame.minX
//            if self.isAudioSelected && component.duration > 0.0 {
//                containerLeftEdge = ghostLeftHandleFrame.maxX
//                containerRightEdge = ghostRightHandleFrame.minX
//            }
            
            let isDraggingTracks = self.trackViews.values.contains(where: { $0.isDragging })
            let isCursorHidden = isDraggingTracks || self.trimView.isPanningTrimHandle || self.ghostTrimView.isPanningTrimHandle
            var cursorTransition = transition
            if isCursorHidden {
                cursorTransition = .immediate
            }
            cursorTransition.setAlpha(view: self.cursorView, alpha: isCursorHidden ? 0.0 : 1.0, delay: self.cursorView.alpha.isZero && !isCursorHidden ? 0.25 : 0.0)
            
            self.scrubberSize = scrubberSize
            if self.isPanningCursor || !component.isPlaying {
                self.cursorPositionAnimation = nil
                self.cursorDisplayLink?.isPaused = true
                
                var cursorPosition = component.position
                if let offset = self.mainAudioTrackOffset {
                    cursorPosition -= offset
                }
                transition.setFrame(view: self.cursorView, frame: cursorFrame(size: scrubberSize, height: self.effectiveCursorHeight, position: cursorPosition, duration: trimDuration))
            } else {
                if let (_, _, end, ended) = self.cursorPositionAnimation {
                    if ended, component.position >= self.startPosition && component.position < end - 1.0 {
                        self.cursorPositionAnimation = (CACurrentMediaTime(), component.position, self.endPosition, false)
                    }
                } else {
                    self.cursorPositionAnimation = (CACurrentMediaTime(), component.position, self.endPosition, false)
                }
                self.cursorDisplayLink?.isPaused = false
                self.updateCursorPosition()
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


private class TrackView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    fileprivate let clippingView: UIView
    fileprivate let scrollView: UIScrollView
    fileprivate let containerView: UIView
    fileprivate let backgroundView: BlurredBackgroundView
    fileprivate let vibrancyView: UIVisualEffectView
    fileprivate let vibrancyContainer: UIView
    
    fileprivate let audioContentContainerView: UIView
    fileprivate let audioWaveform = ComponentView<Empty>()
    fileprivate let waveformCloneLayer = AudioWaveformComponent.View.CloneLayer()
    fileprivate let audioContentMaskView: UIImageView
    fileprivate let audioIconView: UIImageView
    fileprivate let audioTitle = ComponentView<Empty>()

    fileprivate let videoTransparentFramesContainer = UIView()
    fileprivate var videoTransparentFrameLayers: [VideoFrameLayer] = []
    fileprivate let videoOpaqueFramesContainer = UIView()
    fileprivate var videoOpaqueFrameLayers: [VideoFrameLayer] = []
    
    var onSelection: (Int32) -> Void = { _ in }
    var offsetUpdated: (Double, Bool) -> Void = { _, _ in }
    var updated: (Transition) -> Void = { _ in }
    
    private(set) var isDragging = false
    private var ignoreScrollUpdates = false
    
    override init(frame: CGRect) {
        self.scrollView = UIScrollView()
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        }
        if #available(iOS 13.0, *) {
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        self.scrollView.bounces = false
        self.scrollView.decelerationRate = .fast
        self.scrollView.clipsToBounds = false
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        
        self.clippingView = UIView()
        self.clippingView.clipsToBounds = true
        
        self.containerView = UIView()
        self.containerView.clipsToBounds = true
        self.containerView.layer.cornerRadius = 9.0
        self.containerView.isUserInteractionEnabled = false
        
        self.backgroundView = BlurredBackgroundView(color: UIColor(white: 0.0, alpha: 0.5), enableBlur: true)
        
        let style: UIBlurEffect.Style = .dark
        let blurEffect = UIBlurEffect(style: style)
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyEffectView = UIVisualEffectView(effect: vibrancyEffect)
        self.vibrancyView = vibrancyEffectView
        
        self.vibrancyContainer = UIView()
        self.vibrancyView.contentView.addSubview(self.vibrancyContainer)
        
        self.audioContentContainerView = UIView()
        self.audioContentContainerView.clipsToBounds = true

        self.audioContentMaskView = UIImageView()
        self.audioContentContainerView.mask = self.audioContentMaskView
        
        self.audioIconView = UIImageView(image: UIImage(bundleImageName: "Media Editor/SmallAudio"))
        
        self.waveformCloneLayer.opacity = 0.3
        
        super.init(frame: .zero)
        
        self.scrollView.delegate = self
        
        self.videoTransparentFramesContainer.alpha = 0.5
        self.videoTransparentFramesContainer.clipsToBounds = true
        self.videoTransparentFramesContainer.layer.cornerRadius = 9.0
        self.videoTransparentFramesContainer.isUserInteractionEnabled = false
        
        self.videoOpaqueFramesContainer.clipsToBounds = true
        self.videoOpaqueFramesContainer.layer.cornerRadius = 9.0
        self.videoOpaqueFramesContainer.isUserInteractionEnabled = false
        
        self.addSubview(self.clippingView)
        self.clippingView.addSubview(self.scrollView)
        self.scrollView.addSubview(self.containerView)
        self.backgroundView.addSubview(self.vibrancyView)
                                
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tapGesture)
        
        self.audioContentMaskView.image = audioContentMaskImage
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let (track, _, _) = self.params else {
            return
        }
        self.onSelection(track.id)
    }
    
    private func updateTrackOffset(done: Bool) {
        guard self.scrollView.contentSize.width > 0.0, let duration = self.params?.track.duration else {
            return
        }
        let totalWidth = self.scrollView.contentSize.width
        let offset = self.scrollView.contentOffset.x * duration / totalWidth
        self.offsetUpdated(offset, done)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.isDragging = true
        self.updated(.easeInOut(duration: 0.25))
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.ignoreScrollUpdates else {
            return
        }
        self.updateTrackOffset(done: false)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.updateTrackOffset(done: true)
            self.isDragging = false
            self.updated(.easeInOut(duration: 0.25))
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.updateTrackOffset(done: true)
        self.isDragging = false
        self.updated(.easeInOut(duration: 0.25))
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: self.containerView)
        return self.containerView.bounds.contains(location)
    }
    
    private var params: (
        track: MediaScrubberComponent.Track,
        isSelected: Bool,
        duration: Double
    )?
    
    func update(
        context: AccountContext,
        track: MediaScrubberComponent.Track,
        isSelected: Bool,
        availableSize: CGSize,
        duration: Double,
        transition: Transition
    ) -> CGSize {
        let previousParams = self.params
        self.params = (track, isSelected, duration)
        
        let scrubberSize = CGSize(width: availableSize.width, height: isSelected ? trackHeight : collapsedTrackHeight)
        
        var screenSpanDuration = duration
        if track.isAudio && track.isMain {
            screenSpanDuration = min(30.0, track.duration)
        }
        
        let minimalAudioWidth = handleWidth * 2.0
        var containerTotalWidth = scrubberSize.width
        if track.isAudio || !track.isMain, screenSpanDuration > 0.0 {
            let trackFraction = track.duration / screenSpanDuration
            if trackFraction < 1.0 - .ulpOfOne || trackFraction > 1.0 + .ulpOfOne {
                containerTotalWidth = max(minimalAudioWidth, ceil(availableSize.width * trackFraction))
            }
        }
        
        var clipOrigin: CGFloat = -9.0
        var clipWidth = availableSize.width + 18.0
        
        var deselectedClipWidth: CGFloat = 0.0
        var deselectedClipOrigin: CGFloat = 0.0
        
        if !track.isMain, duration > 0.0 {
            let trackDuration: Double
            if let trimRange = track.trimRange {
                trackDuration = trimRange.upperBound - trimRange.lowerBound
            } else {
                trackDuration = duration
            }
            
            let fraction = trackDuration / duration
            deselectedClipWidth = max(minimalAudioWidth, availableSize.width * fraction)
            deselectedClipOrigin = (track.trimRange?.lowerBound ?? 0.0) / duration * availableSize.width
            
            if self.scrollView.contentOffset.x < 0.0 {
                deselectedClipOrigin -= self.scrollView.contentOffset.x
                if self.scrollView.contentSize.width > self.scrollView.frame.width {
                    deselectedClipWidth += self.scrollView.contentOffset.x
                }
            } else if self.scrollView.contentSize.width > self.scrollView.frame.width, self.scrollView.contentOffset.x > self.scrollView.contentSize.width - self.scrollView.frame.width {
                let delta = self.scrollView.contentOffset.x - (self.scrollView.contentSize.width - self.scrollView.frame.width)
                deselectedClipWidth -= delta
            }
        }
        
        if !isSelected && (track.isAudio || !track.isMain) {
            clipOrigin = deselectedClipOrigin
            clipWidth = deselectedClipWidth
        }
        
        let clippingFrame = CGRect(origin: CGPoint(x: clipOrigin, y: 0.0), size: CGSize(width: clipWidth, height: scrubberSize.height))
        let clippingBounds = CGRect(origin: CGPoint(x: clipOrigin, y: 0.0), size: CGSize(width: clipWidth, height: scrubberSize.height))
        transition.setFrame(view: self.clippingView, frame: clippingFrame)
        transition.setBounds(view: self.clippingView, bounds: clippingBounds)
    
        self.scrollView.isUserInteractionEnabled = isSelected && (track.isAudio || !track.isMain)
        
        self.ignoreScrollUpdates = true
        
        let scrollFrame = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: scrubberSize.height))
        transition.setFrame(view: self.scrollView, frame: scrollFrame)
        
        let audioChanged = !"".isEmpty
        
        let contentSize = CGSize(width: containerTotalWidth, height: collapsedTrackHeight)
        if self.scrollView.contentSize != contentSize || audioChanged {
            self.scrollView.contentSize = contentSize
            if !track.isMain {
                let leftInset = scrubberSize.width - handleWidth * 2.5
                let rightInset: CGFloat
                if self.scrollView.contentSize.width > self.scrollView.frame.width {
                    rightInset = scrubberSize.width - handleWidth * 2.5
                } else {
                    rightInset = self.scrollView.frame.width - self.scrollView.contentSize.width
                }
                self.scrollView.contentInset = UIEdgeInsets(top: 0.0, left: leftInset, bottom: 0.0, right: rightInset)
            }
            
            if let offset = track.offset, track.duration > 0.0 {
                let contentOffset = offset * containerTotalWidth / track.duration
                self.scrollView.contentOffset = CGPoint(x: contentOffset, y: 0.0)
            } else {
                self.scrollView.contentOffset = .zero
            }
        }
        
        self.ignoreScrollUpdates = false
        
        transition.setCornerRadius(layer: self.clippingView.layer, cornerRadius: isSelected ? 0.0 : 9.0)
        
        let containerFrame = CGRect(origin: .zero, size: CGSize(width: containerTotalWidth, height: scrubberSize.height))
        transition.setFrame(view: self.containerView, frame: containerFrame)
        
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: containerFrame.size))
        self.backgroundView.update(size: containerFrame.size, transition: transition.containedViewLayoutTransition)
        transition.setFrame(view: self.vibrancyView, frame: CGRect(origin: .zero, size: containerFrame.size))
        transition.setFrame(view: self.vibrancyContainer, frame: CGRect(origin: .zero, size: containerFrame.size))
                    
        let contentContainerFrame = CGRect(origin: .zero, size: CGSize(width: clipWidth, height: containerFrame.height))
        let contentContainerOrigin = deselectedClipOrigin + self.scrollView.contentOffset.x
        transition.setFrame(view: self.audioContentContainerView, frame: contentContainerFrame.offsetBy(dx: contentContainerOrigin, dy: 0.0))
        transition.setFrame(view: self.audioContentMaskView, frame: CGRect(origin: .zero, size: contentContainerFrame.size))
        
        switch track.content {
        case let .video(frames, framesUpdateTimestamp):
            if self.videoTransparentFramesContainer.superview == nil {
                self.containerView.addSubview(self.videoTransparentFramesContainer)
                self.containerView.addSubview(self.videoOpaqueFramesContainer)
            }
            var previousFramesUpdateTimestamp: Double?
            if let previousParams, case let .video(_, previousFramesUpdateTimestampValue) = previousParams.track.content {
                previousFramesUpdateTimestamp = previousFramesUpdateTimestampValue
            }
            
            if framesUpdateTimestamp != previousFramesUpdateTimestamp {
                for i in 0 ..< frames.count {
                    let transparentFrameLayer: VideoFrameLayer
                    let opaqueFrameLayer: VideoFrameLayer
                    if i >= self.videoTransparentFrameLayers.count {
                        transparentFrameLayer = VideoFrameLayer()
                        transparentFrameLayer.masksToBounds = true
                        transparentFrameLayer.contentsGravity = .resizeAspectFill
                        self.videoTransparentFramesContainer.layer.addSublayer(transparentFrameLayer)
                        self.videoTransparentFrameLayers.append(transparentFrameLayer)
                        opaqueFrameLayer = VideoFrameLayer()
                        opaqueFrameLayer.masksToBounds = true
                        opaqueFrameLayer.contentsGravity = .resizeAspectFill
                        self.videoOpaqueFramesContainer.layer.addSublayer(opaqueFrameLayer)
                        self.videoOpaqueFrameLayers.append(opaqueFrameLayer)
                    } else {
                        transparentFrameLayer = self.videoTransparentFrameLayers[i]
                        opaqueFrameLayer = self.videoOpaqueFrameLayers[i]
                    }
                    transparentFrameLayer.contents = frames[i].cgImage
                    if let contents = opaqueFrameLayer.contents, (contents as! CGImage) !== frames[i].cgImage, opaqueFrameLayer.animation(forKey: "contents") == nil {
                        opaqueFrameLayer.contents = frames[i].cgImage
                        opaqueFrameLayer.animate(from: contents as AnyObject, to: frames[i].cgImage! as AnyObject, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.2)
                    } else {
                        opaqueFrameLayer.contents = frames[i].cgImage
                    }
                    if frames[i].imageOrientation == .upMirrored {
                        transparentFrameLayer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                        opaqueFrameLayer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                    }
                }
            }
            
            let containerLeftEdge: CGFloat = 0.0
            let containerRightEdge: CGFloat = availableSize.width
            
            transition.setFrame(view: self.videoTransparentFramesContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: scrubberSize.width, height: scrubberSize.height)))
            transition.setFrame(view: self.videoOpaqueFramesContainer, frame: CGRect(origin: CGPoint(x: containerLeftEdge, y: 0.0), size: CGSize(width: containerRightEdge - containerLeftEdge, height: scrubberSize.height)))
            transition.setBounds(view: self.videoOpaqueFramesContainer, bounds: CGRect(origin: CGPoint(x: containerLeftEdge, y: 0.0), size: CGSize(width: containerRightEdge - containerLeftEdge, height: scrubberSize.height)))
            
            var frameAspectRatio = 0.66
            if let image = frames.first, image.size.height > 0.0 {
                frameAspectRatio = max(0.66, image.size.width / image.size.height)
            }
            let frameSize = CGSize(width: trackHeight * frameAspectRatio, height: trackHeight)
            var frameOffset: CGFloat = 0.0
            for i in 0 ..< frames.count {
                if i < self.videoTransparentFrameLayers.count {
                    let transparentFrameLayer = self.videoTransparentFrameLayers[i]
                    let opaqueFrameLayer = self.videoOpaqueFrameLayers[i]
                    let frame = CGRect(origin: CGPoint(x: frameOffset, y: floorToScreenPixels((scrubberSize.height - frameSize.height) / 2.0)), size: frameSize)
                    
                    transparentFrameLayer.bounds = CGRect(origin: .zero, size: frame.size)
                    opaqueFrameLayer.bounds = CGRect(origin: .zero, size: frame.size)
                    
                    transition.setPosition(layer: transparentFrameLayer, position: frame.center)
                    transition.setPosition(layer: opaqueFrameLayer, position: frame.center)
                }
                frameOffset += frameSize.width
            }
        case let .audio(artist, title, samples, peak):
            var components: [String] = []
            var trackTitle = ""
            if let artist {
                components.append(artist)
            }
            if let title {
                components.append(title)
            }
            if components.isEmpty {
                let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
                components.append(strings.MediaEditor_Audio)
            }
            trackTitle = components.joined(separator: " • ")
            
            let audioTitle = NSAttributedString(string: trackTitle, font: Font.semibold(13.0), textColor: .white)
            let audioTitleSize: CGSize
            if !trackTitle.isEmpty {
                audioTitleSize = self.audioTitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(audioTitle)
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
            } else {
                if let audioTitleView = self.audioTitle.view {
                    audioTitleSize = audioTitleView.bounds.size
                } else {
                    audioTitleSize = .zero
                }
            }
            
            let spacing: CGFloat = 4.0
            let iconSize = CGSize(width: 14.0, height: 14.0)
            let contentTotalWidth = iconSize.width + audioTitleSize.width + spacing
            
            let audioContentTransition = transition
            transition.setAlpha(view: self.audioIconView, alpha: isSelected ? 0.0 : 1.0)
                      
            let audioIconFrame = CGRect(origin: CGPoint(x: max(8.0, floorToScreenPixels((deselectedClipWidth - contentTotalWidth) / 2.0)), y: floorToScreenPixels((scrubberSize.height - iconSize.height) / 2.0)), size: iconSize)
            audioContentTransition.setBounds(view: self.audioIconView, bounds: CGRect(origin: .zero, size: audioIconFrame.size))
            audioContentTransition.setPosition(view: self.audioIconView, position: audioIconFrame.center)
            
            let trackTitleIsVisible = !isSelected && !track.isMain && !trackTitle.isEmpty
            if let view = self.audioTitle.view {
                if view.superview == nil {
                    view.alpha = 0.0
                    view.isUserInteractionEnabled = false
                    self.containerView.addSubview(self.backgroundView)
                    self.containerView.addSubview(self.audioContentContainerView)
                    self.audioContentContainerView.addSubview(self.audioIconView)
                    self.audioContentContainerView.addSubview(view)
                }
                transition.setAlpha(view: view, alpha: trackTitleIsVisible ? 1.0 : 0.0)
                
                let audioTitleFrame = CGRect(origin: CGPoint(x: audioIconFrame.maxX + spacing, y: floorToScreenPixels((scrubberSize.height - audioTitleSize.height) / 2.0)), size: audioTitleSize)
                view.bounds = CGRect(origin: .zero, size: audioTitleFrame.size)
                audioContentTransition.setPosition(view: view, position: audioTitleFrame.center)
            }
            transition.setAlpha(view: self.audioIconView, alpha: trackTitleIsVisible ? 1.0 : 0.0)
            
            var previousSamples: Data?
            if let previousParams, case let .audio(_ , _, previousSamplesValue, _) = previousParams.track.content {
                previousSamples = previousSamplesValue
            }
            
            let samples = samples ?? Data()
            if let view = self.audioWaveform.view, previousSamples == nil && !samples.isEmpty, let vibrancySnapshotView = view.snapshotContentTree(), let snapshotView = self.waveformCloneLayer.snapshotContentTreeAsView() {
                vibrancySnapshotView.frame = view.frame
                snapshotView.alpha = 0.3
                snapshotView.frame = view.frame
                self.vibrancyContainer.addSubview(vibrancySnapshotView)
                self.containerView.addSubview(snapshotView)
                
                vibrancySnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    vibrancySnapshotView.removeFromSuperview()
                })
                
                snapshotView.layer.animateAlpha(from: 0.3, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    vibrancySnapshotView.removeFromSuperview()
                })
                
                view.layer.animateScaleY(from: 0.01, to: 1.0, duration: 0.2)
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                
                self.waveformCloneLayer.animateScaleY(from: 0.01, to: 1.0, duration: 0.2)
                self.waveformCloneLayer.animateAlpha(from: 0.0, to: 0.3, duration: 0.2)
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
                        peak: peak,
                        status: .complete(),
                        seek: nil,
                        updateIsSeeking: nil
                    )
                ),
                environment: {},
                containerSize: CGSize(width: containerFrame.width, height: trackHeight)
            )
            if let view = self.audioWaveform.view as? AudioWaveformComponent.View {
                if view.superview == nil {
                    view.cloneLayer = self.waveformCloneLayer
                    self.vibrancyContainer.addSubview(view)
                    self.containerView.layer.addSublayer(self.waveformCloneLayer)
                }
                let audioWaveformFrame = CGRect(origin: CGPoint(x: 0.0, y: isSelected || track.isMain ? 0.0 : 6.0), size: audioWaveformSize)
                transition.setFrame(view: view, frame: audioWaveformFrame)
                transition.setFrame(layer: self.waveformCloneLayer, frame: audioWaveformFrame)
            }
        }
        
        return scrubberSize
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
        
        let height = trackHeight
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
        let end = params.scrubberSize.width - handleWidth / 2.0
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
        let end = params.scrubberSize.width - handleWidth / 2.0
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
        scrubberSize: CGSize,
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double
    )?
    
    func update(
        visualInsets: UIEdgeInsets,
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
        self.params = (scrubberSize, duration, startPosition, endPosition, position, minDuration, maxDuration)
        
        let trimColor = self.isPanningTrimHandle ? UIColor(rgb: 0xf8d74a) : .white
        transition.setTintColor(view: self.leftHandleView, color: trimColor)
        transition.setTintColor(view: self.rightHandleView, color: trimColor)
        transition.setTintColor(view: self.borderView, color: trimColor)
        
        let totalWidth = scrubberSize.width
        let totalRange = totalWidth - handleWidth
        let leftHandlePositionFraction = duration > 0.0 ? startPosition / duration : 0.0
        let leftHandlePosition = floorToScreenPixels(handleWidth / 2.0 + totalRange * leftHandlePositionFraction)
        
        var leftHandleFrame = CGRect(origin: CGPoint(x: leftHandlePosition - handleWidth / 2.0, y: 0.0), size: CGSize(width: handleWidth, height: scrubberSize.height))
        leftHandleFrame.origin.x = max(leftHandleFrame.origin.x, visualInsets.left)
        transition.setFrame(view: self.leftHandleView, frame: leftHandleFrame)

        let rightHandlePositionFraction = duration > 0.0 ? endPosition / duration : 1.0
        let rightHandlePosition = floorToScreenPixels(handleWidth / 2.0 + totalRange * rightHandlePositionFraction)
        
        var rightHandleFrame = CGRect(origin: CGPoint(x: max(leftHandleFrame.maxX, rightHandlePosition - handleWidth / 2.0), y: 0.0), size: CGSize(width: handleWidth, height: scrubberSize.height))
        rightHandleFrame.origin.x = min(rightHandleFrame.origin.x, totalWidth - visualInsets.right - handleWidth)
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


private let audioContentMaskImage = generateImage(CGSize(width: 100.0, height: 50.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: .zero, size: size))
    
    var locations: [CGFloat] = [0.0, 0.75, 0.95, 1.0]
    let colors: [CGColor] = [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
    
    context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
})?.stretchableImage(withLeftCapWidth: 40, topCapHeight: 0)


private extension MediaScrubberComponent.Track {
    var isAudio: Bool {
        if case .audio = self.content {
            return true
        } else {
            return false
        }
    }
}
