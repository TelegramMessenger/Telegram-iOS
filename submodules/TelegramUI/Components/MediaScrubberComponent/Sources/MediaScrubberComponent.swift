import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import AudioWaveformComponent
import MultilineTextComponent
import MediaEditor
import UIKitRuntimeUtils

private let handleWidth: CGFloat = 14.0
private let trackHeight: CGFloat = 39.0
private let collapsedTrackHeight: CGFloat = 26.0
private let trackSpacing: CGFloat = 4.0
private let collageTrackSpacing: CGFloat = 8.0
private let borderHeight: CGFloat = 1.0 + UIScreenPixel

public final class MediaScrubberComponent: Component {
    public typealias EnvironmentType = Empty
    
    public struct Track: Equatable {
        public enum Content: Equatable {
            case video(frames: [UIImage], framesUpdateTimestamp: Double)
            case audio(artist: String?, title: String?, samples: Data?, peak: Int32, isTimeline: Bool)
            
            public static func ==(lhs: Content, rhs: Content) -> Bool {
                switch lhs {
                case let .video(_, framesUpdateTimestamp):
                    if case .video(_, framesUpdateTimestamp) = rhs {
                        return true
                    } else {
                        return false
                    }
                case let .audio(lhsArtist, lhsTitle, lhsSamples, lhsPeak, lhsIsTimeline):
                    if case let .audio(rhsArtist, rhsTitle, rhsSamples, rhsPeak, rhsIsTimeline) = rhs {
                        return lhsArtist == rhsArtist && lhsTitle == rhsTitle && lhsSamples == rhsSamples && lhsPeak == rhsPeak && lhsIsTimeline == rhsIsTimeline
                    } else {
                        return false
                    }
                }
            }
        }
        
        public let id: Int32
        public let content: Content
        public let duration: Double
        public let trimRange: Range<Double>?
        public let offset: Double?
        public let isMain: Bool
                
        public init(
            id: Int32,
            content: Content,
            duration: Double,
            trimRange: Range<Double>?,
            offset: Double?,
            isMain: Bool
        ) {
            self.id = id
            self.content = content
            self.duration = duration
            self.trimRange = trimRange
            self.offset = offset
            self.isMain = isMain
        }
    }
    
    public enum Style {
        case editor
        case videoMessage
        case voiceMessage
        case cover
    }
    
    let context: AccountContext
    let style: Style
    let theme: PresentationTheme
    
    let generationTimestamp: Double

    let position: Double
    let minDuration: Double
    let maxDuration: Double
    let segmentDuration: Double?
    let isPlaying: Bool
    
    let tracks: [Track]
    let isCollage: Bool
    let isCollageSelected: Bool
    let collageSamples: (samples: Data, peak: Int32)?
    
    let cover: (position: Double, image: UIImage)?
    let getCoverSourceView: () -> UIView?
    
    let portalView: PortalView?
    
    let positionUpdated: (Double, Bool) -> Void
    let coverPositionUpdated: (Double, Bool, @escaping () -> Void) -> Void
    let trackTrimUpdated: (Int32, Double, Double, Bool, Bool) -> Void
    let trackOffsetUpdated: (Int32, Double, Bool) -> Void
    let trackLongPressed: (Int32, UIView) -> Void
    let collageSelectionUpdated: () -> Void
    let trackSelectionUpdated: (Int32) -> Void
    
    public init(
        context: AccountContext,
        style: Style,
        theme: PresentationTheme,
        generationTimestamp: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double,
        segmentDuration: Double? = nil,
        isPlaying: Bool,
        tracks: [Track],
        isCollage: Bool,
        isCollageSelected: Bool = false,
        collageSamples: (samples: Data, peak: Int32)? = nil,
        cover: (position: Double, image: UIImage)? = nil,
        getCoverSourceView: @escaping () -> UIView? = { return nil },
        portalView: PortalView? = nil,
        positionUpdated: @escaping (Double, Bool) -> Void,
        coverPositionUpdated: @escaping (Double, Bool, @escaping () -> Void) -> Void = { _, _, _ in },
        trackTrimUpdated: @escaping (Int32, Double, Double, Bool, Bool) -> Void,
        trackOffsetUpdated: @escaping (Int32, Double, Bool) -> Void,
        trackLongPressed: @escaping (Int32, UIView) -> Void,
        collageSelectionUpdated: @escaping () -> Void = {},
        trackSelectionUpdated: @escaping (Int32) -> Void = { _ in }
    ) {
        self.context = context
        self.style = style
        self.theme = theme
        self.generationTimestamp = generationTimestamp
        self.position = position
        self.minDuration = minDuration
        self.maxDuration = maxDuration
        self.segmentDuration = segmentDuration
        self.isPlaying = isPlaying
        self.tracks = tracks
        self.isCollage = isCollage
        self.isCollageSelected = isCollageSelected
        self.collageSamples = collageSamples
        self.cover = cover
        self.getCoverSourceView = getCoverSourceView
        self.portalView = portalView
        self.positionUpdated = positionUpdated
        self.coverPositionUpdated = coverPositionUpdated
        self.trackTrimUpdated = trackTrimUpdated
        self.trackOffsetUpdated = trackOffsetUpdated
        self.trackLongPressed = trackLongPressed
        self.collageSelectionUpdated = collageSelectionUpdated
        self.trackSelectionUpdated = trackSelectionUpdated
    }
    
    public static func ==(lhs: MediaScrubberComponent, rhs: MediaScrubberComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
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
        if lhs.segmentDuration != rhs.segmentDuration {
            return false
        }
        if lhs.isPlaying != rhs.isPlaying {
            return false
        }
        if lhs.tracks != rhs.tracks {
            return false
        }
        if lhs.isCollage != rhs.isCollage {
            return false
        }
        if lhs.isCollageSelected != rhs.isCollageSelected {
            return false
        }
        if lhs.collageSamples?.samples != rhs.collageSamples?.samples || lhs.collageSamples?.peak != rhs.collageSamples?.peak {
            return false
        }
        if lhs.cover?.position != rhs.cover?.position {
            return false
        }
        return true
    }
    
    public final class View: UIView, UIGestureRecognizerDelegate {
        private let trackContainerView: UIView
        private var collageTrackView: TrackView?
        private var trackViews: [Int32: TrackView] = [:]
        private let trimView: TrimView
        private let ghostTrimView: TrimView
        private let cursorContentView: UIView
        private let cursorView: HandleView
        private let cursorImageView: UIImageView
        
        private let coverDotWrapper: UIView
        private let coverDotView: UIImageView
        private let coverImageView: UIImageView
        
        private var cursorDisplayLink: SharedDisplayLinkDriver.Link?
        private var cursorPositionAnimation: (start: Double, from: Double, to: Double, ended: Bool)?
    
        private var selectedTrackId: Int32 = 0
        private var isPanningCursor = false
        private var ignoreCursorPositionUpdate = false
        
        private var scrubberSize: CGSize?
        
        private var component: MediaScrubberComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            self.trackContainerView = UIView()
            self.trimView = TrimView(frame: .zero)
            self.ghostTrimView = TrimView(frame: .zero)
            self.ghostTrimView.isHollow = true
            self.cursorContentView = UIView()
            self.cursorView = HandleView()
            self.cursorImageView = UIImageView()
            
            self.coverDotWrapper = UIView()
            self.coverDotWrapper.isUserInteractionEnabled = false
            self.coverDotWrapper.isHidden = true
            
            self.coverDotView = UIImageView(image: generateFilledCircleImage(diameter: 7.0, color: UIColor(rgb: 0x007aff)))
            
            self.coverImageView = UIImageView()
            self.coverImageView.clipsToBounds = true
            self.coverImageView.contentMode = .scaleAspectFill
            
            super.init(frame: frame)
                                                 
            self.clipsToBounds = false
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveKeyboardGestureRecognizer = true
            
            self.cursorContentView.isUserInteractionEnabled = false
            self.cursorContentView.clipsToBounds = true
            self.cursorContentView.layer.cornerRadius = 10.0
            
            let positionImage = generateImage(CGSize(width: handleWidth, height: 50.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.setShadow(offset: .zero, blur: 2.0, color: UIColor(rgb: 0x000000, alpha: 0.55).cgColor)
                
                let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 6.0, y: 4.0), size: CGSize(width: 2.0, height: 42.0)), cornerRadius: 1.0)
                context.addPath(path.cgPath)
                context.fillPath()
            })?.stretchableImage(withLeftCapWidth: Int(handleWidth / 2.0), topCapHeight: 25)
            self.cursorView.image = nil
            self.cursorView.isUserInteractionEnabled = true
            self.cursorView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
            
            self.cursorImageView.image = positionImage
            
            self.addSubview(self.trackContainerView)
            self.trackContainerView.addSubview(self.ghostTrimView)
            self.trackContainerView.addSubview(self.trimView)
            self.addSubview(self.cursorContentView)
            self.addSubview(self.cursorView)
            self.cursorView.addSubview(self.cursorImageView)
            
            self.addSubview(self.coverDotWrapper)
            self.coverDotWrapper.addSubview(self.coverDotView)
            self.coverDotWrapper.addSubview(self.coverImageView)
            
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
            return firstTrack.trimRange?.upperBound ?? min(firstTrack.duration, component.maxDuration)
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
            
            guard !component.isCollage || component.isCollageSelected else {
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
            let transition: ComponentTransition = .immediate
            switch gestureRecognizer.state {
            case .began, .changed:
                self.isPanningCursor = true
                if case .cover = component.style {
                    component.coverPositionUpdated(position, false, {})
                } else {
                    component.positionUpdated(position, false)
                }
            case .ended, .cancelled:
                self.isPanningCursor = false
                if case .cover = component.style {
                    component.coverPositionUpdated(position, false, {})
                } else {
                    component.positionUpdated(position, true)
                }
            default:
                break
            }
            self.state?.updated(transition: transition)
        }
        
        private func cursorFrame(size: CGSize, height: CGFloat, position: Double, duration : Double) -> CGRect {
            var cursorWidth = handleWidth
            var cursorMargin = handleWidth
            var height = height
            var isCover = false
            var y: CGFloat = -5.0 - UIScreenPixel
            if let component = self.component, case .cover = component.style {
                cursorWidth = 30.0 + 12.0
                cursorMargin = handleWidth
                height = 50.0
                isCover = true
                y += 1.0
            }
            
            let cursorPadding: CGFloat = 8.0
            let cursorPositionFraction = duration > 0.0 ? position / duration : 0.0
            let cursorPosition = floorToScreenPixels(cursorMargin - 1.0 + (size.width - handleWidth * 2.0 + 2.0) * cursorPositionFraction)
            var cursorFrame = CGRect(origin: CGPoint(x: cursorPosition - cursorWidth / 2.0, y: y), size: CGSize(width: cursorWidth, height: height))
            
            var leftEdge = self.ghostTrimView.leftHandleView.frame.maxX
            var rightEdge = self.ghostTrimView.rightHandleView.frame.minX
            if self.isAudioOnly {
                leftEdge = self.trimView.leftHandleView.frame.maxX
                rightEdge = self.trimView.rightHandleView.frame.minX
            }
            if isCover {
                leftEdge = 0.0
                rightEdge = size.width
            }
            
            cursorFrame.origin.x = max(leftEdge - cursorPadding, cursorFrame.origin.x)
            cursorFrame.origin.x = min(rightEdge - cursorWidth + cursorPadding, cursorFrame.origin.x)
            return cursorFrame
        }
        
        private var effectiveCursorHeight: CGFloat {
            var height: CGFloat = 50.0
            if let component = self.component {
                if !component.isCollage || component.isCollageSelected {
                    let trackHeight = component.isCollage ? 34.0 : 30.0
                    let additionalTracksCount = max(0, (component.tracks.count) - 1)
                    height += CGFloat(additionalTracksCount) * trackHeight
                }
                if component.isCollage && !component.isCollageSelected {
                    height = 37.0
                }
            }
            return height
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
            self.cursorContentView.frame = self.cursorView.frame.insetBy(dx: 6.0, dy: 2.0).offsetBy(dx: -1.0 - UIScreenPixel, dy: 0.0)
        }
                
        public func update(component: MediaScrubberComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            let previousComponent = self.component
            self.component = component
            self.state = state
            
            if let portalView = component.portalView, portalView.view.superview == nil {
                portalView.view.frame = CGRect(x: 0.0, y: 0.0, width: 30.0, height: 48.0)
                portalView.view.clipsToBounds = true
                self.cursorContentView.addSubview(portalView.view)
            }
            
            switch component.style {
            case .editor:
                self.cursorView.isHidden = false
            case .videoMessage, .voiceMessage:
                self.cursorView.isHidden = true
            case .cover:
                self.cursorView.isHidden = false
                self.trimView.isHidden = true
                self.ghostTrimView.isHidden = true
                
                if isFirstTime {
                    let positionImage = generateImage(CGSize(width: 30.0 + 12.0, height: 50.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: .zero, size: size))
                        context.setStrokeColor(UIColor.white.cgColor)
                        let lineWidth = 2.0 - UIScreenPixel
                        context.setLineWidth(lineWidth)
                        context.setShadow(offset: .zero, blur: 2.0, color: UIColor(rgb: 0x000000, alpha: 0.55).cgColor)
                        
                        let path = UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 6.0 - lineWidth / 2.0, y: 2.0 - lineWidth / 2.0), size: CGSize(width: 30.0 - lineWidth, height: 48.0 - lineWidth)), cornerRadius: 9.0)
                        context.addPath(path.cgPath)
                        context.strokePath()
                    })
                    self.cursorImageView.image = positionImage
                }
            }
            
            var totalHeight: CGFloat = 0.0
            var trackLayout: [Int32: (CGRect, ComponentTransition, Bool)] = [:]
            
            if !component.tracks.contains(where: { $0.id == self.selectedTrackId }) {
                self.selectedTrackId = component.tracks.first(where: { $0.isMain })?.id ?? 0
            }
            
            var lowestVideoId: Int32?
            
            let effectiveTrackSpacing = component.isCollage ? collageTrackSpacing : trackSpacing
                
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
                    trackView.onTap = { [weak self] fraction in
                        guard let self, let component = self.component else {
                            return
                        }
                        var position = max(self.startPosition, min(self.endPosition, self.trimDuration * fraction))
                        if let offset = self.mainAudioTrackOffset {
                            position += offset
                        }
                        self.ignoreCursorPositionUpdate = true
                        component.coverPositionUpdated(position, true, { [weak self] in
                            guard let self else {
                                return
                            }
                            self.ignoreCursorPositionUpdate = false
                            self.state?.updated(transition: .immediate)
                        })
                    }
                    trackView.onSelection = { [weak self] id in
                        guard let self else {
                            return
                        }
                        self.selectedTrackId = id
                        self.component?.trackSelectionUpdated(id)
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
                    
                    self.trackContainerView.insertSubview(trackView, at: 0)
                    
                    if !isFirstTime {
                        animateTrackIn = true
                    }
                }
                
                var isSelected = id == self.selectedTrackId
                if component.isCollage && !component.isCollageSelected {
                    isSelected = false
                }
                
                let trackSize = trackView.update(
                    context: component.context,
                    style: component.style,
                    track: track,
                    isSelected: isSelected,
                    availableSize: availableSize,
                    duration: self.duration,
                    segmentDuration: lowestVideoId == track.id ? component.segmentDuration : nil,
                    transition: trackTransition
                )
                trackLayout[id] = (CGRect(origin: CGPoint(x: 0.0, y: totalHeight), size: trackSize), trackTransition, animateTrackIn)
                
                if component.isCollage && !component.isCollageSelected {
                    
                } else {
                    totalHeight += trackSize.height
                    totalHeight += effectiveTrackSpacing
                }
            }
            totalHeight -= effectiveTrackSpacing
            
            if component.isCollage {
                if !component.isCollageSelected {
                    totalHeight = collapsedTrackHeight
                }
                
                var trackTransition = transition
                
                let trackView: TrackView
                if let current = self.collageTrackView {
                    trackView = current
                } else {
                    trackTransition = .immediate
                    trackView = TrackView()
                    trackView.onSelection = { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.component?.collageSelectionUpdated()
                    }
                    self.insertSubview(trackView, belowSubview: self.cursorView)
                    self.collageTrackView = trackView
                }
                
                let strings = component.context.sharedContext.currentPresentationData.with { $0 }.strings
                let trackSize = trackView.update(
                    context: component.context,
                    style: component.style,
                    track: MediaScrubberComponent.Track(
                        id: 1024,
                        content: .audio(artist: nil, title: strings.MediaEditor_Timeline, samples: component.collageSamples?.samples, peak: component.collageSamples?.peak ?? 0, isTimeline: true),
                        duration: component.maxDuration,
                        trimRange: nil,
                        offset: nil,
                        isMain: false
                    ),
                    isSelected: false,
                    availableSize: availableSize,
                    duration: self.duration,
                    segmentDuration: nil,
                    transition: trackTransition
                )
                trackTransition.setFrame(view: trackView, frame: CGRect(origin: .zero, size: trackSize))
                trackTransition.setAlpha(view: trackView, alpha: component.isCollageSelected ? 0.0 : 1.0)
            }
            
            for track in component.tracks {
                guard let trackView = self.trackViews[track.id], let (trackFrame, trackTransition, animateTrackIn) = trackLayout[track.id] else {
                    continue
                }
                trackTransition.setFrame(view: trackView, frame: CGRect(origin: CGPoint(x: 0.0, y: totalHeight - trackFrame.maxY), size: trackFrame.size))
                if animateTrackIn {
                    trackView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    trackView.layer.animatePosition(from: CGPoint(x: 0.0, y: trackFrame.height + effectiveTrackSpacing), to: .zero, duration: 0.35, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
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
                    
                    if (lowestVideoId == 0 && track.id == 1) || component.isCollage {
                        trimViewVisualInsets = .zero
                        trackViewWidth = trackView.containerView.frame.width
                        mainTrimDuration = track.duration
                    }
                }
            }

            let fullTrackHeight: CGFloat
            switch component.style {
            case .editor, .cover:
                fullTrackHeight = trackHeight
            case .videoMessage, .voiceMessage:
                fullTrackHeight = 33.0
            }
            let scrubberSize = CGSize(width: availableSize.width, height: fullTrackHeight)
            
            self.trimView.isHollow = self.selectedTrackId != lowestVideoId || self.isAudioOnly
            let (leftHandleFrame, rightHandleFrame) = self.trimView.update(
                style: component.style,
                theme: component.theme,
                visualInsets: trimViewVisualInsets,
                scrubberSize: CGSize(width: trackViewWidth, height: fullTrackHeight),
                duration: mainTrimDuration,
                startPosition: startPosition,
                endPosition: endPosition,
                position: component.position,
                minDuration: component.minDuration,
                maxDuration: component.maxDuration,
                transition: transition
            )
            
            let (ghostLeftHandleFrame, ghostRightHandleFrame) = self.ghostTrimView.update(
                style: component.style,
                theme: component.theme,
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

            var trimViewFrame = CGRect(origin: CGPoint(x: trimViewOffset, y: selectedTrackFrame.minY), size: scrubberSize)
            
            var trimVisible = true
            if component.isCollage && !component.isCollageSelected {
                trimVisible = false
                trimViewFrame = trimViewFrame.offsetBy(dx: 0.0, dy: collapsedTrackHeight - trackHeight)
            }
            
            transition.setFrame(view: self.trimView, frame: trimViewFrame)
            transition.setAlpha(view: self.trimView, alpha: trimVisible ? 1.0 : 0.0)
            
            var ghostTrimVisible = false
            if let lowestVideoId, self.selectedTrackId != lowestVideoId {
                ghostTrimVisible = true
            }
            
            let ghostTrimViewFrame = CGRect(origin: CGPoint(x: 0.0, y: totalHeight - collapsedTrackHeight), size: CGSize(width: availableSize.width, height: collapsedTrackHeight))
            transition.setFrame(view: self.ghostTrimView, frame: ghostTrimViewFrame)
            transition.setAlpha(view: self.ghostTrimView, alpha: ghostTrimVisible ? 0.75 : 0.0)
            
            if [.videoMessage, .cover].contains(component.style) {
                for (_ , trackView) in self.trackViews {
                    trackView.updateOpaqueEdges(
                        left: leftHandleFrame.minX,
                        right: rightHandleFrame.maxX,
                        transition: transition
                    )
                }
            } else {
                for (_ , trackView) in self.trackViews {
                    trackView.updateTrimEdges(
                        left: leftHandleFrame.minX,
                        right: rightHandleFrame.maxX,
                        transition: transition
                    )
                }
            }
            
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
                
                if !self.ignoreCursorPositionUpdate {
                    var cursorPosition = component.position
                    if let offset = self.mainAudioTrackOffset {
                        cursorPosition -= offset
                    }
                    let cursorFrame = cursorFrame(size: scrubberSize, height: self.effectiveCursorHeight, position: cursorPosition, duration: self.trimDuration)
                    transition.setFrame(view: self.cursorView, frame: cursorFrame)
                    transition.setFrame(view: self.cursorContentView, frame: cursorFrame.insetBy(dx: 6.0, dy: 2.0).offsetBy(dx: -1.0  - UIScreenPixel, dy: 0.0))
                }
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
            
            transition.setFrame(view: self.cursorImageView, frame: CGRect(origin: .zero, size: self.cursorView.frame.size))
            
            if let (coverPosition, coverImage) = component.cover {
                let imageSize = CGSize(width: 36.0, height: 36.0)
                var animateFrame = false
                if previousComponent?.cover?.position != coverPosition {
                    self.coverDotWrapper.isHidden = false
                    if let _ = previousComponent?.cover {
                        if let snapshotView = self.coverDotWrapper.layer.snapshotContentTreeAsView() {
                            snapshotView.frame = self.coverDotWrapper.frame
                            self.addSubview(snapshotView)
                            snapshotView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                                snapshotView.removeFromSuperview()
                            })
                        }
                    }
                    self.coverDotView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                    self.coverImageView.image = coverImage
                    self.coverImageView.layer.cornerRadius = imageSize.width / 2.0
                    
                    animateFrame = true
                }
                
                let dotSize = self.coverDotView.bounds.size
                let dotFrame = cursorFrame(size: scrubberSize, height: dotSize.height, position: coverPosition, duration: self.trimDuration)
                self.coverDotWrapper.frame = CGRect(origin: CGPoint(x: floor(dotFrame.center.x - dotSize.width / 2.0), y: -18.0), size: dotSize)
                self.coverDotView.frame = CGRect(origin: .zero, size: dotSize)
                self.coverImageView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((dotSize.width - imageSize.width) / 2.0), y: -42.0), size: imageSize)
                
                if animateFrame, let sourceView = component.getCoverSourceView() {
                    let sourceFrame = sourceView.convert(sourceView.bounds, to: self.coverDotWrapper)
                    self.coverImageView.layer.animate(from: sourceFrame.width as NSNumber, to: self.coverImageView.layer.cornerRadius as NSNumber, keyPath: "cornerRadius", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4)
                    self.coverImageView.layer.animateFrame(from: sourceFrame, to: self.coverImageView.frame, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
            
            if component.isCollage {
                transition.setAlpha(view: self.trackContainerView, alpha: component.isCollageSelected ? 1.0 : 0.0)
            }
            
            if let previousComponent, component.isCollage, previousComponent.isCollageSelected != component.isCollageSelected {
                if let blurFilter = makeBlurFilter() {
                    if component.isCollageSelected {
                        blurFilter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                        self.trackContainerView.layer.filters = [blurFilter]
                        self.trackContainerView.layer.animate(from: 20.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.3, completion: { [weak self] completed in
                            guard let self, completed else {
                                return
                            }
                            self.trackContainerView.layer.filters = []
                        })
                    } else {
                        blurFilter.setValue(0.0 as NSNumber, forKey: "inputRadius")
                        self.trackContainerView.layer.filters = [blurFilter]
                        self.trackContainerView.layer.animate(from: 0.0 as NSNumber, to: 20.0 as NSNumber, keyPath: "filters.gaussianBlur.inputRadius", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 0.4, completion: { [weak self] completed in
                            guard let self, completed else {
                                return
                            }
                            self.trackContainerView.layer.filters = []
                        })
                    }
                }
            }
            
            let size = CGSize(width: availableSize.width, height: totalHeight)
            transition.setFrame(view: self.trackContainerView, frame: CGRect(origin: .zero, size: size))
            
            return size
        }
        
        public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
            return self.bounds.inset(by: hitTestSlop).contains(point)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
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
    
    fileprivate let segmentsContainerView = UIView()
    fileprivate var segmentTitles: [Int32: ComponentView<Empty>] = [:]
    fileprivate var segmentLayers: [Int32: SimpleLayer] = [:]

    fileprivate let videoTransparentFramesContainer = UIView()
    fileprivate var videoTransparentFrameLayers: [VideoFrameLayer] = []
    fileprivate let videoOpaqueFramesContainer = UIView()
    fileprivate var videoOpaqueFrameLayers: [VideoFrameLayer] = []
    
    var onSelection: (Int32) -> Void = { _ in }
    var onTap: (CGFloat) -> Void = { _ in }
    var offsetUpdated: (Double, Bool) -> Void = { _, _ in }
    var updated: (ComponentTransition) -> Void = { _ in }
    
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
        
        self.videoTransparentFramesContainer.clipsToBounds = true
        self.videoTransparentFramesContainer.isUserInteractionEnabled = false
        
        self.videoOpaqueFramesContainer.clipsToBounds = true
        self.videoOpaqueFramesContainer.isUserInteractionEnabled = false
        
        self.addSubview(self.clippingView)
        self.clippingView.addSubview(self.scrollView)
        self.scrollView.addSubview(self.containerView)
        self.backgroundView.addSubview(self.vibrancyView)
        
        self.segmentsContainerView.clipsToBounds = true
        self.segmentsContainerView.isUserInteractionEnabled = false
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
        self.addGestureRecognizer(tapGesture)
        
        self.audioContentMaskView.image = audioContentMaskImage
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let params = self.params else {
            return
        }
        if case .cover = params.style {
            let location = gestureRecognizer.location(in: self)
            self.onTap(location.x / self.frame.width)
        } else {
            self.onSelection(params.track.id)
        }
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
        style: MediaScrubberComponent.Style,
        track: MediaScrubberComponent.Track,
        isSelected: Bool,
        availableSize: CGSize,
        duration: Double
    )?
    
    private var leftOpaqueEdge: CGFloat?
    private var rightOpaqueEdge: CGFloat?
    func updateOpaqueEdges(
        left: CGFloat,
        right: CGFloat,
        transition: ComponentTransition
    ) {
        self.leftOpaqueEdge = left
        self.rightOpaqueEdge = right
        
        if let params = self.params {
            let fullTrackHeight: CGFloat
            if case .cover = params.style {
                fullTrackHeight = trackHeight
            } else {
                fullTrackHeight = 33.0
            }
            self.updateThumbnailContainers(
                scrubberSize: CGSize(width: params.availableSize.width, height: fullTrackHeight),
                availableSize: params.availableSize,
                transition: transition
            )
        }
    }
    
    private var leftTrimEdge: CGFloat?
    private var rightTrimEdge: CGFloat?
    func updateTrimEdges(
        left: CGFloat,
        right: CGFloat,
        transition: ComponentTransition
    ) {
        self.leftTrimEdge = left
        self.rightTrimEdge = right
        
        if let params = self.params {
            self.updateSegmentContainer(
                scrubberSize: CGSize(width: params.availableSize.width, height: trackHeight),
                availableSize: params.availableSize,
                transition: transition
            )
        }
    }
    
    private func updateThumbnailContainers(
        scrubberSize: CGSize,
        availableSize: CGSize,
        transition: ComponentTransition
    ) {
        let containerLeftEdge: CGFloat = self.leftOpaqueEdge ?? 0.0
        let containerRightEdge: CGFloat = self.rightOpaqueEdge ?? availableSize.width
        
        transition.setFrame(view: self.videoTransparentFramesContainer, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: scrubberSize.width, height: scrubberSize.height)))
        transition.setFrame(view: self.videoOpaqueFramesContainer, frame: CGRect(origin: CGPoint(x: containerLeftEdge, y: 0.0), size: CGSize(width: containerRightEdge - containerLeftEdge, height: scrubberSize.height)))
        transition.setBounds(view: self.videoOpaqueFramesContainer, bounds: CGRect(origin: CGPoint(x: containerLeftEdge, y: 0.0), size: CGSize(width: containerRightEdge - containerLeftEdge, height: scrubberSize.height)))
    }
    
    private func updateSegmentContainer(
        scrubberSize: CGSize,
        availableSize: CGSize,
        transition: ComponentTransition
    ) {
        let containerLeftEdge: CGFloat = self.leftTrimEdge ?? 0.0
        let containerRightEdge: CGFloat = self.rightTrimEdge ?? availableSize.width
        
        transition.setFrame(view: self.segmentsContainerView, frame: CGRect(origin: CGPoint(x: containerLeftEdge, y: 0.0), size: CGSize(width: containerRightEdge - containerLeftEdge - 2.0, height: scrubberSize.height)))
    }
    
    func update(
        context: AccountContext,
        style: MediaScrubberComponent.Style,
        track: MediaScrubberComponent.Track,
        isSelected: Bool,
        availableSize: CGSize,
        duration: Double,
        segmentDuration: Double?,
        transition: ComponentTransition
    ) -> CGSize {
        let previousParams = self.params
        self.params = (style, track, isSelected, availableSize, duration)
        
        let fullTrackHeight: CGFloat
        let framesCornerRadius: CGFloat
        switch style {
        case .editor, .cover:
            fullTrackHeight = trackHeight
            framesCornerRadius = 9.0
            self.videoTransparentFramesContainer.alpha = 0.35
        case .videoMessage, .voiceMessage:
            fullTrackHeight = 33.0
            framesCornerRadius = fullTrackHeight / 2.0
            self.videoTransparentFramesContainer.alpha = 0.5
        }
        self.videoTransparentFramesContainer.layer.cornerRadius = framesCornerRadius
        self.videoOpaqueFramesContainer.layer.cornerRadius = framesCornerRadius
        
        let scrubberSize = CGSize(width: availableSize.width, height: isSelected ? fullTrackHeight : collapsedTrackHeight)
        
        var screenSpanDuration = duration
        if track.isAudio && track.isMain && !track.isTimeline {
            screenSpanDuration = min(30.0, track.duration)
        }
        
        let minimalAudioWidth = handleWidth * 2.0
        var containerTotalWidth = scrubberSize.width
        
        if !track.isTimeline, track.isAudio || !track.isMain, screenSpanDuration > 0.0 {
            let trackFraction = track.duration / screenSpanDuration
            if trackFraction < 1.0 - .ulpOfOne || trackFraction > 1.0 + .ulpOfOne {
                containerTotalWidth = max(minimalAudioWidth, ceil(availableSize.width * trackFraction))
            }
        }
        
        var clipOrigin: CGFloat = -9.0
        var clipWidth = availableSize.width + 18.0
        
        var deselectedClipWidth: CGFloat = 0.0
        var deselectedClipOrigin: CGFloat = 0.0
        
        if track.isTimeline {
            deselectedClipWidth = clipWidth
            deselectedClipOrigin = clipOrigin
        } else if !track.isMain, duration > 0.0 {
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
                            
        let contentContainerFrame = CGRect(origin: .zero, size: CGSize(width: clipWidth, height: containerFrame.height))
        let contentContainerOrigin = deselectedClipOrigin + self.scrollView.contentOffset.x
        transition.setFrame(view: self.audioContentContainerView, frame: contentContainerFrame.offsetBy(dx: contentContainerOrigin, dy: 0.0))
        transition.setFrame(view: self.audioContentMaskView, frame: CGRect(origin: .zero, size: contentContainerFrame.size))
        
        switch track.content {
        case let .video(frames, framesUpdateTimestamp):
            if self.videoTransparentFramesContainer.superview == nil {
                self.containerView.addSubview(self.videoTransparentFramesContainer)
                self.containerView.addSubview(self.videoOpaqueFramesContainer)
                self.containerView.addSubview(self.segmentsContainerView)
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
                        if case .videoMessage = style {
                            transparentFrameLayer.contentsRect = CGRect(origin: .zero, size: CGSize(width: 1.0, height: 1.0)).insetBy(dx: 0.15, dy: 0.15)
                        }
                        self.videoTransparentFramesContainer.layer.addSublayer(transparentFrameLayer)
                        self.videoTransparentFrameLayers.append(transparentFrameLayer)
                        
                        opaqueFrameLayer = VideoFrameLayer()
                        opaqueFrameLayer.masksToBounds = true
                        opaqueFrameLayer.contentsGravity = .resizeAspectFill
                        if case .videoMessage = style {
                            opaqueFrameLayer.contentsRect = CGRect(origin: .zero, size: CGSize(width: 1.0, height: 1.0)).insetBy(dx: 0.15, dy: 0.15)
                        }
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
                        
            self.updateThumbnailContainers(
                scrubberSize: scrubberSize,
                availableSize: availableSize,
                transition: transition
            )
            
            self.updateSegmentContainer(
                scrubberSize: scrubberSize,
                availableSize: availableSize,
                transition: transition
            )
            
            var frameAspectRatio = 0.66
            if let image = frames.first, image.size.height > 0.0 {
                frameAspectRatio = max(0.66, image.size.width / image.size.height)
            }
            let frameSize = CGSize(width: fullTrackHeight * frameAspectRatio, height: fullTrackHeight)
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
        case let .audio(artist, title, samples, peak, isTimeline):
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
            var iconSize = CGSize(width: 14.0, height: 14.0)
            var trackTitleAlpha: CGFloat = 1.0
            if isTimeline {
                if previousParams == nil {
                    self.audioIconView.image = UIImage(bundleImageName: "Media Editor/Timeline")
                }
                iconSize = CGSize(width: 24.0, height: 24.0)
                trackTitleAlpha = 0.7
            }
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
                transition.setAlpha(view: view, alpha: trackTitleIsVisible ? trackTitleAlpha : 0.0)
                
                let audioTitleFrame = CGRect(origin: CGPoint(x: audioIconFrame.maxX + spacing, y: floorToScreenPixels((scrubberSize.height - audioTitleSize.height) / 2.0)), size: audioTitleSize)
                view.bounds = CGRect(origin: .zero, size: audioTitleFrame.size)
                audioContentTransition.setPosition(view: view, position: audioTitleFrame.center)
            }
            transition.setAlpha(view: self.audioIconView, alpha: trackTitleIsVisible ? trackTitleAlpha : 0.0)
            
            var previousSamples: Data?
            if let previousParams, case let .audio(_ , _, previousSamplesValue, _, _) = previousParams.track.content {
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
                        isViewOnceMessage: false,
                        seek: nil,
                        updateIsSeeking: nil
                    )
                ),
                environment: {},
                containerSize: CGSize(width: containerFrame.width, height: fullTrackHeight)
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
                
        transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: containerFrame.size))
        self.backgroundView.update(size: containerFrame.size, transition: transition.containedViewLayoutTransition)
        transition.setFrame(view: self.vibrancyView, frame: CGRect(origin: .zero, size: containerFrame.size))
        transition.setFrame(view: self.vibrancyContainer, frame: CGRect(origin: .zero, size: containerFrame.size))
                
        var segmentCount = 0
        var segmentWidth: CGFloat = 0.0
        if let segmentDuration {
            if duration > segmentDuration {
                let fraction = segmentDuration / duration
                segmentCount = Int(ceil(duration / segmentDuration)) - 1
                segmentWidth = floorToScreenPixels(containerFrame.width * fraction)
            }
            if let trimRange = track.trimRange {
                let actualSegmentCount = Int(ceil((trimRange.upperBound - trimRange.lowerBound) / segmentDuration)) - 1
                segmentCount = min(actualSegmentCount, segmentCount)
            }
        }
        
        let displaySegmentLabels = segmentWidth >= 30.0

        var validIds = Set<Int32>()
        var segmentFrame = CGRect(x: segmentWidth, y: 0.0, width: 1.0, height: containerFrame.size.height)
        for i in 0 ..< min(segmentCount, 2) {
            let id = Int32(i)
            validIds.insert(id)
            
            let segmentLayer: SimpleLayer
            let segmentTitle: ComponentView<Empty>
            
            var segmentTransition = transition
            if let currentLayer = self.segmentLayers[id], let currentTitle = self.segmentTitles[id] {
                segmentLayer = currentLayer
                segmentTitle = currentTitle
            } else {
                segmentTransition = .immediate
                segmentLayer = SimpleLayer()
                segmentLayer.backgroundColor = UIColor.white.cgColor
                segmentTitle = ComponentView<Empty>()
                
                self.segmentLayers[id] = segmentLayer
                self.segmentTitles[id] = segmentTitle
                
                self.segmentsContainerView.layer.addSublayer(segmentLayer)
            }
            
            transition.setFrame(layer: segmentLayer, frame: segmentFrame)
            
            let segmentTitleSize = segmentTitle.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: "#\(i + 2)", font: Font.semibold(11.0), textColor: .white)),
                    textShadowColor: UIColor(rgb: 0x000000, alpha: 0.4),
                    textShadowBlur: 1.0
                )),
                environment: {},
                containerSize: containerFrame.size
            )
            if let view = segmentTitle.view {
                view.alpha = displaySegmentLabels ? 1.0 : 0.0
                if view.superview == nil {
                    self.segmentsContainerView.addSubview(view)
                }
                segmentTransition.setFrame(view: view, frame: CGRect(origin: CGPoint(x: segmentFrame.maxX + 2.0, y: 2.0), size: segmentTitleSize))
            }
            segmentFrame.origin.x += segmentWidth
        }

        var removeIds: [Int32] = []
        for (id, segmentLayer) in self.segmentLayers {
            if !validIds.contains(id) {
                removeIds.append(id)
                segmentLayer.removeFromSuperlayer()
                if let segmentTitle = self.segmentTitles[id] {
                    segmentTitle.view?.removeFromSuperview()
                }
            }
        }
        for id in removeIds {
            self.segmentLayers.removeValue(forKey: id)
            self.segmentTitles.removeValue(forKey: id)
        }
        
        return scrubberSize
    }
}


public class TrimView: UIView {
    fileprivate let leftHandleView = HandleView()
    fileprivate let rightHandleView = HandleView()
    private let borderView = UIImageView()
    private let zoneView = HandleView()
    
    private let leftCapsuleView = UIView()
    private let rightCapsuleView = UIView()
    
    fileprivate var isPanningTrimHandle = false
    
    public var isHollow = false
    
    public var trimUpdated: (Double, Double, Bool, Bool) -> Void = { _, _, _, _ in }
    var updated: (ComponentTransition) -> Void = { _ in }
    
    public override init(frame: CGRect) {
        super.init(frame: .zero)
        
        self.zoneView.image = UIImage()
        self.zoneView.isUserInteractionEnabled = true
        self.zoneView.hitTestSlop = UIEdgeInsets(top: -8.0, left: 0.0, bottom: -8.0, right: 0.0)
        
        self.leftHandleView.isUserInteractionEnabled = true
        self.leftHandleView.tintColor = .white
        self.leftHandleView.contentMode = .scaleToFill
        self.leftHandleView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
        
        self.rightHandleView.transform = CGAffineTransform(scaleX: -1.0, y: 1.0)
        self.rightHandleView.isUserInteractionEnabled = true
        self.rightHandleView.tintColor = .white
        self.rightHandleView.contentMode = .scaleToFill
        self.rightHandleView.hitTestSlop = UIEdgeInsets(top: -8.0, left: -9.0, bottom: -8.0, right: -9.0)
        
        self.borderView.tintColor = .white
        self.borderView.isUserInteractionEnabled = false
        
        self.leftCapsuleView.clipsToBounds = true
        self.leftCapsuleView.layer.cornerRadius = 1.0
        
        self.rightCapsuleView.clipsToBounds = true
        self.rightCapsuleView.layer.cornerRadius = 1.0
        
        self.addSubview(self.zoneView)
        self.addSubview(self.leftHandleView)
        self.leftHandleView.addSubview(self.leftCapsuleView)
        
        self.addSubview(self.rightHandleView)
        self.rightHandleView.addSubview(self.rightCapsuleView)
        self.addSubview(self.borderView)
        
        let zoneHandlePanGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleZoneHandlePan(_:)))
        zoneHandlePanGesture.minimumPressDuration = 0.0
        zoneHandlePanGesture.allowableMovement = .infinity
        
        let leftHandlePanGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleLeftHandlePan(_:)))
        leftHandlePanGesture.minimumPressDuration = 0.0
        leftHandlePanGesture.allowableMovement = .infinity
        
        let rightHandlePanGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.handleRightHandlePan(_:)))
        rightHandlePanGesture.minimumPressDuration = 0.0
        rightHandlePanGesture.allowableMovement = .infinity
        
        self.zoneView.addGestureRecognizer(zoneHandlePanGesture)
        self.leftHandleView.addGestureRecognizer(leftHandlePanGesture)
        self.rightHandleView.addGestureRecognizer(rightHandlePanGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var panStartLocation: CGPoint?
    
    @objc private func handleZoneHandlePan(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let params = self.params else {
            return
        }
        
        let location = gestureRecognizer.location(in: self)
        if case .began = gestureRecognizer.state {
            self.panStartLocation = location
        }
        
        let translation = CGPoint(
            x: location.x - (self.panStartLocation?.x ?? 0.0),
            y: location.y - (self.panStartLocation?.y ?? 0.0)
        )
        
        let start = handleWidth / 2.0
        let end = self.frame.width - handleWidth / 2.0
        let length = end - start
        
        let delta = translation.x / length
        
        let duration = params.endPosition - params.startPosition
        let startValue = max(0.0, min(params.duration - duration, params.startPosition + delta * params.duration))
        let endValue = startValue + duration
        
        var transition: ComponentTransition = .immediate
        switch gestureRecognizer.state {
        case .began, .changed:
            self.isPanningTrimHandle = true
            self.trimUpdated(startValue, endValue, false, false)
            if case .began = gestureRecognizer.state {
                transition = .easeInOut(duration: 0.25)
            }
        case .ended, .cancelled:
            self.panStartLocation = nil
            self.isPanningTrimHandle = false
            self.trimUpdated(startValue, endValue, false, true)
            transition = .easeInOut(duration: 0.25)
        default:
            break
        }
        
        self.updated(transition)
    }
    
    @objc private func handleLeftHandlePan(_ gestureRecognizer: UILongPressGestureRecognizer) {
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
        
        var transition: ComponentTransition = .immediate
        switch gestureRecognizer.state {
        case .began, .changed:
            self.isPanningTrimHandle = true
            self.trimUpdated(startValue, endValue, false, false)
            if case .began = gestureRecognizer.state {
                transition = .easeInOut(duration: 0.25)
            }
        case .ended, .cancelled:
            self.panStartLocation = nil
            self.isPanningTrimHandle = false
            self.trimUpdated(startValue, endValue, false, true)
            transition = .easeInOut(duration: 0.25)
        default:
            break
        }
        self.updated(transition)
    }
    
    @objc private func handleRightHandlePan(_ gestureRecognizer: UILongPressGestureRecognizer) {
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
        
        var transition: ComponentTransition = .immediate
        switch gestureRecognizer.state {
        case .began, .changed:
            self.isPanningTrimHandle = true
            self.trimUpdated(startValue, endValue, true, false)
            if case .began = gestureRecognizer.state {
                transition = .easeInOut(duration: 0.25)
            }
        case .ended, .cancelled:
            self.panStartLocation = nil
            self.isPanningTrimHandle = false
            self.trimUpdated(startValue, endValue, true, true)
            transition = .easeInOut(duration: 0.25)
        default:
            break
        }
        self.updated(transition)
    }
    
    private var params: (
        scrubberSize: CGSize,
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double
    )?
    
    public func update(
        style: MediaScrubberComponent.Style,
        theme: PresentationTheme,
        visualInsets: UIEdgeInsets,
        scrubberSize: CGSize,
        duration: Double,
        startPosition: Double,
        endPosition: Double,
        position: Double,
        minDuration: Double,
        maxDuration: Double,
        transition: ComponentTransition
    ) -> (leftHandleFrame: CGRect, rightHandleFrame: CGRect) {
        let isFirstTime = self.params == nil
        self.params = (scrubberSize, duration, startPosition, endPosition, position, minDuration, maxDuration)
        
        let effectiveHandleWidth: CGFloat
        let fullTrackHeight: CGFloat
        let capsuleOffset: CGFloat
        let color: UIColor
        let highlightColor: UIColor
        var borderColor: UIColor
        
        switch style {
        case .editor, .cover:
            effectiveHandleWidth = handleWidth
            fullTrackHeight = trackHeight
            capsuleOffset = 5.0 - UIScreenPixel
            color = .white
            highlightColor = UIColor(rgb: 0xf8d74a)
            
            if isFirstTime {
                self.borderView.image = generateImage(CGSize(width: 1.0, height: fullTrackHeight), rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: .zero, size: CGSize(width: size.width, height: borderHeight)))
                    context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.height - borderHeight), size: CGSize(width: size.width, height: fullTrackHeight)))
                })?.withRenderingMode(.alwaysTemplate).resizableImage(withCapInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0))
                
                let handleImage = generateImage(CGSize(width: handleWidth, height: fullTrackHeight), rotatedContext: { size, context in
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
                
                self.leftHandleView.image = handleImage
                self.rightHandleView.image = handleImage
                
                self.leftCapsuleView.backgroundColor = UIColor(rgb: 0x343436)
                self.rightCapsuleView.backgroundColor = UIColor(rgb: 0x343436)
            }
        case .videoMessage:
            effectiveHandleWidth = 16.0
            fullTrackHeight = 33.0
            capsuleOffset = 8.0
            color = theme.chat.inputPanel.panelControlAccentColor
            highlightColor = theme.chat.inputPanel.panelControlAccentColor
            
            if isFirstTime {
                let handleImage = generateImage(CGSize(width: effectiveHandleWidth, height: fullTrackHeight), rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    context.setFillColor(UIColor.white.cgColor)
                    
                    let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width * 2.0, height: size.height)), cornerRadius: 16.5)
                    context.addPath(path.cgPath)
                    context.fillPath()
                })?.withRenderingMode(.alwaysTemplate)
                
                self.leftHandleView.image = handleImage
                self.rightHandleView.image = handleImage
                
                self.leftCapsuleView.backgroundColor = .white
                self.rightCapsuleView.backgroundColor = .white
            }
            
        case .voiceMessage:
            effectiveHandleWidth = 16.0
            fullTrackHeight = 33.0
            capsuleOffset = 8.0
            color = theme.chat.inputPanel.panelControlAccentColor
            highlightColor = theme.chat.inputPanel.panelControlAccentColor
        
            self.zoneView.backgroundColor = UIColor(white: 1.0, alpha: 0.4)
            
            if isFirstTime {
                self.borderView.image = generateImage(CGSize(width: 3.0, height: fullTrackHeight), rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(CGRect(origin: .zero, size: CGSize(width: 1.0, height: size.height)))
                    context.fill(CGRect(origin: CGPoint(x: size.width - 1.0, y: 0.0), size: CGSize(width: 1.0, height: size.height)))
                })?.withRenderingMode(.alwaysTemplate).resizableImage(withCapInsets: UIEdgeInsets(top: 0.0, left: 1.0, bottom: 0.0, right: 1.0))
                              
                let handleImage = generateImage(CGSize(width: effectiveHandleWidth, height: fullTrackHeight), rotatedContext: { size, context in
                    context.clear(CGRect(origin: .zero, size: size))
                    context.setFillColor(UIColor.white.cgColor)
                    
                    let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width * 2.0, height: size.height)), cornerRadius: 16.5)
                    context.addPath(path.cgPath)
                    context.fillPath()
                })?.withRenderingMode(.alwaysTemplate)
                
                self.leftHandleView.image = handleImage
                self.rightHandleView.image = handleImage
                
                self.leftCapsuleView.backgroundColor = .white
                self.rightCapsuleView.backgroundColor = .white
            }
        }
        
        let trimColor = self.isPanningTrimHandle ? highlightColor : color
        borderColor = trimColor
        if case .voiceMessage = style {
            borderColor = theme.chat.inputPanel.panelBackgroundColor
        }
        
        transition.setTintColor(view: self.leftHandleView, color: trimColor)
        transition.setTintColor(view: self.rightHandleView, color: trimColor)
        transition.setTintColor(view: self.borderView, color: borderColor)
        
        let totalWidth = scrubberSize.width
        let totalRange = totalWidth - effectiveHandleWidth
        let leftHandlePositionFraction = duration > 0.0 ? startPosition / duration : 0.0
        let leftHandlePosition = floorToScreenPixels(effectiveHandleWidth / 2.0 + totalRange * leftHandlePositionFraction)
        
        var leftHandleFrame = CGRect(origin: CGPoint(x: leftHandlePosition - effectiveHandleWidth / 2.0, y: 0.0), size: CGSize(width: effectiveHandleWidth, height: scrubberSize.height))
        leftHandleFrame.origin.x = max(leftHandleFrame.origin.x, visualInsets.left)
        transition.setFrame(view: self.leftHandleView, frame: leftHandleFrame)

        let rightHandlePositionFraction = duration > 0.0 ? endPosition / duration : 1.0
        let rightHandlePosition = floorToScreenPixels(effectiveHandleWidth / 2.0 + totalRange * rightHandlePositionFraction)
        
        var rightHandleFrame = CGRect(origin: CGPoint(x: max(leftHandleFrame.maxX, rightHandlePosition - effectiveHandleWidth / 2.0), y: 0.0), size: CGSize(width: effectiveHandleWidth, height: scrubberSize.height))
        rightHandleFrame.origin.x = min(rightHandleFrame.origin.x, totalWidth - visualInsets.right - effectiveHandleWidth)
        transition.setFrame(view: self.rightHandleView, frame: rightHandleFrame)
        
        let capsuleSize = CGSize(width: 2.0, height: 11.0)
        transition.setFrame(view: self.leftCapsuleView, frame: CGRect(origin: CGPoint(x: capsuleOffset, y: floorToScreenPixels((leftHandleFrame.height - capsuleSize.height) / 2.0)), size: capsuleSize))
        transition.setFrame(view: self.rightCapsuleView, frame: CGRect(origin: CGPoint(x: capsuleOffset, y: floorToScreenPixels((leftHandleFrame.height - capsuleSize.height) / 2.0)), size: capsuleSize))
        
        let zoneFrame = CGRect(x: leftHandleFrame.maxX, y: 0.0, width: rightHandleFrame.minX - leftHandleFrame.maxX, height: scrubberSize.height)
        transition.setFrame(view: self.zoneView, frame: zoneFrame)
        
        let borderFrame = CGRect(origin: CGPoint(x: leftHandleFrame.maxX, y: 0.0), size: CGSize(width: rightHandleFrame.minX - leftHandleFrame.maxX, height: scrubberSize.height))
        transition.setFrame(view: self.borderView, frame: borderFrame)
        
        return (leftHandleFrame, rightHandleFrame)
    }
    
    public override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
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
    
    var isTimeline: Bool {
        if case let .audio(_, _, _, _, isTimeline) = self.content {
            return isTimeline
        } else {
            return false
        }
    }
}
