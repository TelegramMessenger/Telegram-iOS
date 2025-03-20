import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import Postbox
import Display
import UniversalMediaPlayer
import TelegramPresentationData
import RangeSet
import ShimmerEffect
import TelegramUniversalVideoContent

private let textFont = Font.with(size: 13.0, design: .regular, weight: .regular, traits: [.monospacedNumbers])

private let scrubberBackgroundColor = UIColor(white: 1.0, alpha: 0.42)
private let scrubberForegroundColor = UIColor.white
private let scrubberBufferingColor = UIColor(rgb: 0xffffff, alpha: 0.5)

final class ChatVideoGalleryItemScrubberView: UIView {
    private var containerLayout: (CGSize, CGFloat, CGFloat)?
    
    private let leftTimestampNode: MediaPlayerTimeTextNode
    private let rightTimestampNode: MediaPlayerTimeTextNode
    private let infoNode: ASTextNode
    private let scrubberNode: MediaPlayerScrubbingNode
    private let shimmerEffectNode: ShimmerEffectForegroundNode
    
    private let hapticFeedback = HapticFeedback()
    
    private var playbackStatus: MediaPlayerStatus?
    private var chapters: [MediaPlayerScrubbingChapter] = []
    
    private var fetchStatusDisposable = MetaDisposable()
    private var scrubbingDisposable = MetaDisposable()
    private var chapterDisposable = MetaDisposable()
    private var loadingDisposable = MetaDisposable()
    
    private var leftTimestampNodePushed = false
    private var rightTimestampNodePushed = false
    private var infoNodePushed = false
    
    private var currentChapter: MediaPlayerScrubbingChapter?
    
    private var isAnimatedOut: Bool = false
    
    var hideWhenDurationIsUnknown = false {
        didSet {
            if self.hideWhenDurationIsUnknown {
                if let playbackStatus = self.playbackStatus, !playbackStatus.duration.isZero {
                    self.scrubberNode.isHidden = false
                    self.leftTimestampNode.isHidden = false
                    self.rightTimestampNode.isHidden = false
                } else {
                    self.scrubberNode.isHidden = true
                    self.leftTimestampNode.isHidden = true
                    self.rightTimestampNode.isHidden = true
                }
            } else {
                self.scrubberNode.isHidden = false
                self.leftTimestampNode.isHidden = false
                self.rightTimestampNode.isHidden = false
            }
        }
    }
    
    var updateScrubbing: (Double?) -> Void = { _ in }
    var updateScrubbingVisual: (Double?) -> Void = { _ in }
    var updateScrubbingHandlePosition: (CGFloat) -> Void = { _ in }
    var seek: (Double) -> Void = { _ in }
    
    init(chapters: [MediaPlayerScrubbingChapter]) {
        self.chapters = chapters
        self.scrubberNode = MediaPlayerScrubbingNode(content: .standard(lineHeight: 5.0, lineCap: .round, scrubberHandle: .circle, backgroundColor: scrubberBackgroundColor, foregroundColor: scrubberForegroundColor, bufferingColor: scrubberBufferingColor, chapters: chapters))
        self.shimmerEffectNode = ShimmerEffectForegroundNode()
        
        self.leftTimestampNode = MediaPlayerTimeTextNode(textColor: .white)
        self.rightTimestampNode = MediaPlayerTimeTextNode(textColor: .white)
        self.rightTimestampNode.alignment = .right
        self.rightTimestampNode.mode = .reversed
        
        self.infoNode = ASTextNode()
        self.infoNode.maximumNumberOfLines = 1
        self.infoNode.isUserInteractionEnabled = false
        self.infoNode.displaysAsynchronously = false
        
        super.init(frame: CGRect())
        
        self.scrubberNode.seek = { [weak self] timestamp in
            self?.seek(timestamp)
        }
        
        self.scrubberNode.update = { [weak self] timestamp, position in
            self?.updateScrubbing(timestamp)
            self?.updateScrubbingVisual(timestamp)
            self?.updateScrubbingHandlePosition(position)
        }
        
        self.scrubberNode.playerStatusUpdated = { [weak self] status in
            if let strongSelf = self {
                strongSelf.playbackStatus = status
                if strongSelf.hideWhenDurationIsUnknown {
                    if let playbackStatus = status, !playbackStatus.duration.isZero {
                        strongSelf.scrubberNode.isHidden = false
                        strongSelf.leftTimestampNode.isHidden = false
                        strongSelf.rightTimestampNode.isHidden = false
                    } else {
                        strongSelf.scrubberNode.isHidden = true
                        strongSelf.leftTimestampNode.isHidden = true
                        strongSelf.rightTimestampNode.isHidden = true
                    }
                } else {
                    strongSelf.scrubberNode.isHidden = false
                    strongSelf.leftTimestampNode.isHidden = false
                    strongSelf.rightTimestampNode.isHidden = false
                }
            }
        }
                
        self.addSubnode(self.scrubberNode)
        self.addSubnode(self.leftTimestampNode)
        self.addSubnode(self.rightTimestampNode)
        self.addSubnode(self.infoNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.scrubbingDisposable.dispose()
        self.fetchStatusDisposable.dispose()
        self.chapterDisposable.dispose()
        self.loadingDisposable.dispose()
    }
    
    var isLoading = false
    var isCollapsed: Bool?
    func setCollapsed(_ collapsed: Bool, animated: Bool) {
        guard self.isCollapsed != collapsed else {
            return
        }
        
        self.isCollapsed = collapsed
        
        self.updateTimestampsVisibility(animated: animated)
        self.updateScrubberVisibility(animated: animated)
        
        if let (size, _, _) = self.containerLayout {
            self.infoNode.alpha = size.width < size.height && !collapsed ? 1.0 : 0.0
        }
    }
    
    func updateTimestampsVisibility(animated: Bool) {
        if self.isAnimatedOut {
            return
        }
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate
        let alpha: CGFloat = self.isCollapsed == true || self.isLoading ? 0.0 : 1.0
        transition.updateAlpha(node: self.leftTimestampNode, alpha: alpha)
        transition.updateAlpha(node: self.rightTimestampNode, alpha: alpha)
    }
    
    private func updateScrubberVisibility(animated: Bool) {
        var collapsed = self.isCollapsed
        var alpha: CGFloat = 1.0
        if let playbackStatus = self.playbackStatus, playbackStatus.duration <= 30.0 {
        } else {
            alpha = self.isCollapsed == true ? 0.0 : 1.0
            collapsed = false
        }
        self.scrubberNode.setCollapsed(collapsed == true, animated: animated)
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.3, curve: .linear) : .immediate
        transition.updateAlpha(node: self.scrubberNode, alpha: alpha)
    }
    
    func animateTo(_ timestamp: Double) {
        self.scrubberNode.animateTo(timestamp)
    }
    
    func setStatusSignal(_ status: Signal<MediaPlayerStatus, NoError>?) {
        let mappedStatus: Signal<MediaPlayerStatus, NoError>?
        if let status = status {
            mappedStatus = combineLatest(status, self.scrubberNode.scrubbingTimestamp) |> map { status, scrubbingTimestamp -> MediaPlayerStatus in
                return MediaPlayerStatus(generationTimestamp: scrubbingTimestamp != nil ? 0 : status.generationTimestamp, duration: status.duration, dimensions: status.dimensions, timestamp: scrubbingTimestamp ?? status.timestamp, baseRate: status.baseRate, seekId: status.seekId, status: status.status, soundEnabled: status.soundEnabled)
            }
        } else {
            mappedStatus = nil
        }
        self.scrubberNode.status = mappedStatus
        self.leftTimestampNode.status = mappedStatus
        self.rightTimestampNode.status = mappedStatus
        
        if let mappedStatus = mappedStatus {
            self.loadingDisposable.set((mappedStatus
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    if status.duration < 1.0 {
                        strongSelf.isLoading = true
                        strongSelf.updateTimestampsVisibility(animated: true)
                        
                        if strongSelf.shimmerEffectNode.supernode == nil {
                            strongSelf.scrubberNode.containerNode.addSubnode(strongSelf.shimmerEffectNode)
                        }
                    } else {
                        strongSelf.isLoading = false
                        strongSelf.updateTimestampsVisibility(animated: true)
                        if strongSelf.shimmerEffectNode.supernode != nil {
                            strongSelf.shimmerEffectNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.shimmerEffectNode.removeFromSupernode()
                                }
                            })
                        }
                    }
                }
            }))
            
            self.chapterDisposable.set((mappedStatus
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self, status.duration > 1.0, strongSelf.chapters.count > 0 {
                    let previousChapter = strongSelf.currentChapter
                    var currentChapter: MediaPlayerScrubbingChapter?
                    for chapter in strongSelf.chapters {
                        if chapter.start > status.timestamp {
                            break
                        } else {
                            currentChapter = chapter
                        }
                    }
                    
                    if let chapter = currentChapter, chapter != previousChapter {
                        strongSelf.currentChapter = chapter

                        if strongSelf.scrubberNode.isScrubbing {
                            strongSelf.hapticFeedback.impact(.light)
                        }
                        
                        if let previousChapter = previousChapter, !strongSelf.infoNode.alpha.isZero {
                            if let snapshotView = strongSelf.infoNode.view.snapshotView(afterScreenUpdates: false) {
                                snapshotView.frame = strongSelf.infoNode.frame
                                strongSelf.infoNode.view.superview?.addSubview(snapshotView)
                                
                                let offset: CGFloat = 30.0
                                let snapshotTargetPosition: CGPoint
                                let nodeStartPosition: CGPoint
                                if previousChapter.start < chapter.start {
                                    snapshotTargetPosition = CGPoint(x: -offset, y: 0.0)
                                    nodeStartPosition = CGPoint(x: offset, y: 0.0)
                                } else {
                                    snapshotTargetPosition = CGPoint(x: offset, y: 0.0)
                                    nodeStartPosition = CGPoint(x: -offset, y: 0.0)
                                }
                                snapshotView.layer.animatePosition(from: CGPoint(), to: snapshotTargetPosition, duration: 0.2, removeOnCompletion: false, additive: true)
                                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                    snapshotView?.removeFromSuperview()
                                })
                                strongSelf.infoNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                strongSelf.infoNode.layer.animatePosition(from: nodeStartPosition, to: CGPoint(), duration: 0.2, additive: true)
                            }
                        }
                        strongSelf.infoNode.attributedText = NSAttributedString(string: chapter.title, font: textFont, textColor: .white)
                        
                        if let (size, leftInset, rightInset) = strongSelf.containerLayout {
                            strongSelf.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                        }
                    }
                }
            }))
        }
        
        self.scrubbingDisposable.set((self.scrubberNode.scrubbingPosition
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            let leftTimestampNodePushed: Bool
            let rightTimestampNodePushed: Bool
            let infoNodePushed: Bool
            if let value = value {
                leftTimestampNodePushed = value < 0.16
                rightTimestampNodePushed = value > 0.84
                infoNodePushed = value >= 0.16 && value <= 0.84
            } else {
                leftTimestampNodePushed = false
                rightTimestampNodePushed = false
                infoNodePushed = false
            }
            if leftTimestampNodePushed != strongSelf.leftTimestampNodePushed || rightTimestampNodePushed != strongSelf.rightTimestampNodePushed || infoNodePushed != strongSelf.infoNodePushed {
                strongSelf.leftTimestampNodePushed = leftTimestampNodePushed
                strongSelf.rightTimestampNodePushed = rightTimestampNodePushed
                strongSelf.infoNodePushed = infoNodePushed
                
                if let layout = strongSelf.containerLayout {
                    strongSelf.updateLayout(size: layout.0, leftInset: layout.1, rightInset: layout.2, transition: .animated(duration: 0.35, curve: .spring))
                }
            }
        }))
    }
    
    func setBufferingStatusSignal(_ status: Signal<(RangeSet<Int64>, Int64)?, NoError>?) {
        self.scrubberNode.bufferingStatus = status
    }
    
    func setFetchStatusSignal(_ fetchStatus: Signal<MediaResourceStatus, NoError>?, strings: PresentationStrings, decimalSeparator: String, fileSize: Int64?) {
        let formatting = DataSizeStringFormatting(strings: strings, decimalSeparator: decimalSeparator)
        if let fileSize = fileSize {
            if let fetchStatus = fetchStatus {
                self.fetchStatusDisposable.set((fetchStatus
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self, strongSelf.chapters.isEmpty {
                        var text: String
                        switch status {
                            case .Remote:
                                text = dataSizeString(fileSize, forceDecimal: true, formatting: formatting)
                            case let .Fetching(_, progress):
                                text = strings.DownloadingStatus(dataSizeString(Int64(Float(fileSize) * progress), forceDecimal: true, formatting: formatting), dataSizeString(fileSize, forceDecimal: true, formatting: formatting)).string
                            default:
                                text = ""
                        }
                        strongSelf.infoNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: .white)
                        
                        if let (size, leftInset, rightInset) = strongSelf.containerLayout {
                            strongSelf.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                        }
                    }
                }))
            } else if self.chapters.isEmpty {
                self.infoNode.attributedText = NSAttributedString(string: dataSizeString(fileSize, forceDecimal: true, formatting: formatting), font: textFont, textColor: .white)
            }
        } else if self.chapters.isEmpty {
            self.infoNode.attributedText = nil
        }
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (size, leftInset, rightInset)
        
        let scrubberHeight: CGFloat = 14.0
        var scrubberInset: CGFloat
        let leftTimestampOffset: CGFloat
        let rightTimestampOffset: CGFloat
        let infoOffset: CGFloat
        if size.width > size.height {
            scrubberInset = 58.0
            leftTimestampOffset = 4.0
            rightTimestampOffset = 4.0
            infoOffset = 0.0
        } else {
            scrubberInset = 13.0
            leftTimestampOffset = 22.0 + (self.leftTimestampNodePushed ? 8.0 : 0.0)
            rightTimestampOffset = 22.0 + (self.rightTimestampNodePushed ? 8.0 : 0.0)
            infoOffset = 22.0 + (self.infoNodePushed ? 8.0 : 0.0)
        }
        
        transition.updateFrame(node: self.leftTimestampNode, frame: CGRect(origin: CGPoint(x: 12.0, y: leftTimestampOffset), size: CGSize(width: 60.0, height: 20.0)))
        transition.updateFrame(node: self.rightTimestampNode, frame: CGRect(origin: CGPoint(x: size.width - leftInset - rightInset - 60.0 - 12.0, y: rightTimestampOffset), size: CGSize(width: 60.0, height: 20.0)))
        
        var infoConstrainedSize = size
        infoConstrainedSize.width = size.width - scrubberInset * 2.0 - 100.0
        
        let infoSize = self.infoNode.measure(infoConstrainedSize)
        self.infoNode.bounds = CGRect(origin: CGPoint(), size: infoSize)
        transition.updatePosition(node: self.infoNode, position: CGPoint(x: size.width / 2.0, y: infoOffset + infoSize.height / 2.0))
        self.infoNode.alpha = size.width < size.height && self.isCollapsed == false ? 1.0 : 0.0
        
        let scrubberFrame = CGRect(origin: CGPoint(x: scrubberInset, y: 6.0), size: CGSize(width: size.width - leftInset - rightInset - scrubberInset * 2.0, height: scrubberHeight))
        self.scrubberNode.frame = scrubberFrame
        self.shimmerEffectNode.updateAbsoluteRect(CGRect(origin: .zero, size: scrubberFrame.size), within: scrubberFrame.size)
        self.shimmerEffectNode.update(backgroundColor: .clear, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.75), horizontal: true, effectSize: nil, globalTimeOffset: false, duration: nil)
        self.shimmerEffectNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 4.0), size: CGSize(width: scrubberFrame.size.width, height: 5.0))
        self.shimmerEffectNode.cornerRadius = 2.5
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        var hitTestRect = self.bounds
        let minHeightDiff = 44.0 - hitTestRect.height
        if (minHeightDiff > 0) {
            hitTestRect = bounds.insetBy(dx: 0, dy: -minHeightDiff / 2.0)
        }
        return hitTestRect.contains(point)
    }
    
    func animateIn(from scrubberTransition: GalleryItemScrubberTransition?, transition: ContainedViewLayoutTransition) {
        if let scrubberTransition = scrubberTransition?.scrubber {
            let fromRect = scrubberTransition.view.convert(scrubberTransition.view.bounds, to: self)
            
            let targetCloneView = scrubberTransition.makeView()
            self.addSubview(targetCloneView)
            targetCloneView.frame = fromRect
            scrubberTransition.updateView(targetCloneView, GalleryItemScrubberTransition.Scrubber.TransitionState(sourceSize: fromRect.size, destinationSize: CGSize(width: self.scrubberNode.bounds.width, height: fromRect.height), progress: 0.0, direction: .in), .immediate)
            targetCloneView.alpha = 1.0
            
            transition.updateFrame(view: targetCloneView, frame: CGRect(origin: CGPoint(x: self.scrubberNode.frame.minX, y: self.scrubberNode.frame.maxY - fromRect.height - 3.0), size: CGSize(width: self.scrubberNode.bounds.width, height: fromRect.height)))
            scrubberTransition.updateView(targetCloneView, GalleryItemScrubberTransition.Scrubber.TransitionState(sourceSize: fromRect.size, destinationSize: CGSize(width: self.scrubberNode.bounds.width, height: fromRect.height), progress: 1.0, direction: .in), transition)
            let scrubberTransitionView = scrubberTransition.view
            scrubberTransitionView.isHidden = true
            ContainedViewLayoutTransition.animated(duration: 0.08, curve: .easeInOut).updateAlpha(layer: targetCloneView.layer, alpha: 0.0, completion: { [weak targetCloneView] _ in
                targetCloneView?.removeFromSuperview()
            })
            
            let scrubberSourceRect = CGRect(origin: CGPoint(x: fromRect.minX, y: fromRect.maxY - 3.0), size: CGSize(width: fromRect.width, height: 3.0))
            
            let leftTimestampOffset = CGPoint(x: self.leftTimestampNode.position.x - self.scrubberNode.frame.minX, y: self.leftTimestampNode.position.y - self.scrubberNode.frame.maxY)
            let rightTimestampOffset = CGPoint(x: self.rightTimestampNode.position.x - self.scrubberNode.frame.maxX, y: self.rightTimestampNode.position.y - self.scrubberNode.frame.maxY)
            
            transition.animatePosition(node: self.scrubberNode, from: scrubberSourceRect.center)
            self.scrubberNode.animateWidth(from: scrubberSourceRect.width, transition: transition)
            
            transition.animatePosition(node: self.leftTimestampNode, from: CGPoint(x: leftTimestampOffset.x + scrubberSourceRect.minX, y: leftTimestampOffset.y + scrubberSourceRect.maxY))
            transition.animatePosition(node: self.rightTimestampNode, from: CGPoint(x: rightTimestampOffset.x + scrubberSourceRect.maxX, y: rightTimestampOffset.y + scrubberSourceRect.maxY))
        }
        
        self.scrubberNode.layer.animateAlpha(from: 0.0, to: self.leftTimestampNode.alpha, duration: 0.25)
        self.leftTimestampNode.layer.animateAlpha(from: 0.0, to: self.leftTimestampNode.alpha, duration: 0.25)
        self.rightTimestampNode.layer.animateAlpha(from: 0.0, to: self.leftTimestampNode.alpha, duration: 0.25)
        self.infoNode.layer.animateAlpha(from: 0.0, to: self.leftTimestampNode.alpha, duration: 0.25)
    }
    
    func animateOut(to scrubberTransition: GalleryItemScrubberTransition?, transition: ContainedViewLayoutTransition) {
        self.isAnimatedOut = true
        
        if let scrubberTransition = scrubberTransition?.scrubber {
            let toRect = scrubberTransition.view.convert(scrubberTransition.view.bounds, to: self)
            let scrubberDestinationRect = CGRect(origin: CGPoint(x: toRect.minX, y: toRect.maxY - 3.0), size: CGSize(width: toRect.width, height: 3.0))

            let targetCloneView = scrubberTransition.makeView()
            self.addSubview(targetCloneView)
            targetCloneView.frame = CGRect(origin: CGPoint(x: self.scrubberNode.frame.minX, y: self.scrubberNode.frame.maxY - toRect.height), size: CGSize(width: self.scrubberNode.bounds.width, height: toRect.height))
            scrubberTransition.updateView(targetCloneView, GalleryItemScrubberTransition.Scrubber.TransitionState(sourceSize: CGSize(width: self.scrubberNode.bounds.width, height: toRect.height), destinationSize: toRect.size, progress: 0.0, direction: .out), .immediate)
            targetCloneView.alpha = 0.0
            
            transition.updateFrame(view: targetCloneView, frame: toRect)
            scrubberTransition.updateView(targetCloneView, GalleryItemScrubberTransition.Scrubber.TransitionState(sourceSize: CGSize(width: self.scrubberNode.bounds.width, height: toRect.height), destinationSize: toRect.size, progress: 1.0, direction: .out), transition)
            let scrubberTransitionView = scrubberTransition.view
            scrubberTransitionView.isHidden = true
            transition.updateAlpha(layer: targetCloneView.layer, alpha: 1.0, completion: { [weak scrubberTransitionView] _ in
                scrubberTransitionView?.isHidden = false
            })
            
            let leftTimestampOffset = CGPoint(x: self.leftTimestampNode.position.x - self.scrubberNode.frame.minX, y: self.leftTimestampNode.position.y - self.scrubberNode.frame.maxY)
            let rightTimestampOffset = CGPoint(x: self.rightTimestampNode.position.x - self.scrubberNode.frame.maxX, y: self.rightTimestampNode.position.y - self.scrubberNode.frame.maxY)
            
            transition.animatePositionAdditive(layer: self.scrubberNode.layer, offset: CGPoint(), to: CGPoint(x: scrubberDestinationRect.midX - self.scrubberNode.position.x, y: scrubberDestinationRect.midY - self.scrubberNode.position.y), removeOnCompletion: false)
            
            self.scrubberNode.animateWidth(to: scrubberDestinationRect.width, transition: transition)
            
            transition.animatePositionAdditive(layer: self.leftTimestampNode.layer, offset: CGPoint(), to: CGPoint(x: -self.leftTimestampNode.position.x + (leftTimestampOffset.x + scrubberDestinationRect.minX), y: -self.leftTimestampNode.position.y + (leftTimestampOffset.y + scrubberDestinationRect.maxY)), removeOnCompletion: false)
            
            transition.animatePositionAdditive(layer: self.rightTimestampNode.layer, offset: CGPoint(), to: CGPoint(x: -self.rightTimestampNode.position.x + (rightTimestampOffset.x + scrubberDestinationRect.maxX), y: -self.rightTimestampNode.position.y + (rightTimestampOffset.y + scrubberDestinationRect.maxY)), removeOnCompletion: false)
        }
        
        transition.updateAlpha(layer: self.scrubberNode.layer, alpha: 0.0)
        transition.updateAlpha(layer: self.leftTimestampNode.layer, alpha: 0.0)
        transition.updateAlpha(layer: self.rightTimestampNode.layer, alpha: 0.0)
        transition.updateAlpha(layer: self.infoNode.layer, alpha: 0.0)
    }
}
