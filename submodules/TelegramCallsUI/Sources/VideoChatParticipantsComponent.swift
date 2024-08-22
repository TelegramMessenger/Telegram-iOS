import Foundation
import UIKit
import Display
import ComponentFlow
import Postbox
import TelegramCore
import AccountContext
import PlainButtonComponent
import SwiftSignalKit
import MultilineTextComponent
import MetalEngine
import CallScreen

private final class ParticipantVideoComponent: Component {
    let call: PresentationGroupCall
    let participant: GroupCallParticipantsContext.Participant
    
    init(
        call: PresentationGroupCall,
        participant: GroupCallParticipantsContext.Participant
    ) {
        self.call = call
        self.participant = participant
    }
    
    static func ==(lhs: ParticipantVideoComponent, rhs: ParticipantVideoComponent) -> Bool {
        if lhs.participant != rhs.participant {
            return false
        }
        return true
    }
    
    private struct VideoSpec: Equatable {
        var resolution: CGSize
        var rotationAngle: Float
        
        init(resolution: CGSize, rotationAngle: Float) {
            self.resolution = resolution
            self.rotationAngle = rotationAngle
        }
    }
    
    final class View: UIView {
        private var component: ParticipantVideoComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private let title = ComponentView<Empty>()
        
        private var videoSource: AdaptedCallVideoSource?
        private var videoDisposable: Disposable?
        private var videoLayer: PrivateCallVideoLayer?
        private var videoSpec: VideoSpec?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.clipsToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.videoDisposable?.dispose()
        }
        
        func update(component: ParticipantVideoComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let nameColor = component.participant.peer.nameColor ?? .blue
            let nameColors = component.call.accountContext.peerNameColors.get(nameColor, dark: true)
            self.backgroundColor = nameColors.main
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.participant.peer.debugDisplayTitle, font: Font.regular(14.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 8.0 * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 8.0, y: availableSize.height - 8.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            if let videoDescription = component.participant.videoDescription {
                let _ = videoDescription
                
                let videoLayer: PrivateCallVideoLayer
                if let current = self.videoLayer {
                    videoLayer = current
                } else {
                    videoLayer = PrivateCallVideoLayer()
                    self.videoLayer = videoLayer
                    self.layer.insertSublayer(videoLayer, at: 0)
                    
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
                                let videoSpec = VideoSpec(resolution: videoOutput.resolution, rotationAngle: videoOutput.rotationAngle)
                                if self.videoSpec != videoSpec {
                                    self.videoSpec = videoSpec
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .immediate, isLocal: true)
                                    }
                                }
                            } else {
                                if self.videoSpec != nil {
                                    self.videoSpec = nil
                                    if !self.isUpdating {
                                        self.state?.updated(transition: .immediate, isLocal: true)
                                    }
                                }
                            }
                            
                            /*var notifyOrientationUpdated = false
                            var notifyIsMirroredUpdated = false
                            
                            if !self.didReportFirstFrame {
                                notifyOrientationUpdated = true
                                notifyIsMirroredUpdated = true
                            }
                            
                            if let currentOutput = videoOutput {
                                let currentAspect: CGFloat
                                if currentOutput.resolution.height > 0.0 {
                                    currentAspect = currentOutput.resolution.width / currentOutput.resolution.height
                                } else {
                                    currentAspect = 1.0
                                }
                                if self.currentAspect != currentAspect {
                                    self.currentAspect = currentAspect
                                    notifyOrientationUpdated = true
                                }
                                
                                let currentOrientation: PresentationCallVideoView.Orientation
                                if currentOutput.followsDeviceOrientation {
                                    currentOrientation = .rotation0
                                } else {
                                    if abs(currentOutput.rotationAngle - 0.0) < .ulpOfOne {
                                        currentOrientation = .rotation0
                                    } else if abs(currentOutput.rotationAngle - Float.pi * 0.5) < .ulpOfOne {
                                        currentOrientation = .rotation90
                                    } else if abs(currentOutput.rotationAngle - Float.pi) < .ulpOfOne {
                                        currentOrientation = .rotation180
                                    } else if abs(currentOutput.rotationAngle - Float.pi * 3.0 / 2.0) < .ulpOfOne {
                                        currentOrientation = .rotation270
                                    } else {
                                        currentOrientation = .rotation0
                                    }
                                }
                                if self.currentOrientation != currentOrientation {
                                    self.currentOrientation = currentOrientation
                                    notifyOrientationUpdated = true
                                }
                                
                                let currentIsMirrored = !currentOutput.mirrorDirection.isEmpty
                                if self.currentIsMirrored != currentIsMirrored {
                                    self.currentIsMirrored = currentIsMirrored
                                    notifyIsMirroredUpdated = true
                                }
                            }
                            
                            if !self.didReportFirstFrame {
                                self.didReportFirstFrame = true
                                self.onFirstFrameReceived?(Float(self.currentAspect))
                            }
                            
                            if notifyOrientationUpdated {
                                self.onOrientationUpdated?(self.currentOrientation, self.currentAspect)
                            }
                            
                            if notifyIsMirroredUpdated {
                                self.onIsMirroredUpdated?(self.currentIsMirrored)
                            }*/
                            
                            
                        }
                    }
                }
                
                transition.setFrame(layer: videoLayer, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if let videoSpec = self.videoSpec {
                    let rotatedResolution = videoSpec.resolution
                    let videoSize = rotatedResolution.aspectFilled(availableSize)
                    let videoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - videoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                    
                    let videoResolution = rotatedResolution.aspectFittedOrSmaller(CGSize(width: availableSize.width, height: availableSize.height)).aspectFittedOrSmaller(CGSize(width: videoSize.width * 3.0, height: videoSize.height * 3.0))
                    let rotatedVideoResolution = videoResolution
                    
                    transition.setPosition(layer: videoLayer, position: videoFrame.center)
                    transition.setBounds(layer: videoLayer, bounds: CGRect(origin: CGPoint(), size: videoFrame.size))
                    videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)), edgeInset: 2)
                }
            } else {
                if let videoLayer = self.videoLayer {
                    self.videoLayer = nil
                    videoLayer.removeFromSuperlayer()
                }
                self.videoDisposable?.dispose()
                self.videoDisposable = nil
                self.videoSource = nil
                self.videoSpec = nil
            }
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class VideoChatParticipantsComponent: Component {
    let call: PresentationGroupCall
    let members: PresentationGroupCallMembers?

    init(
        call: PresentationGroupCall,
        members: PresentationGroupCallMembers?
    ) {
        self.call = call
        self.members = members
    }

    static func ==(lhs: VideoChatParticipantsComponent, rhs: VideoChatParticipantsComponent) -> Bool {
        if lhs.members != rhs.members {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private final class ItemLayout {
        let containerSize: CGSize
        let itemCount: Int
        let itemSize: CGSize
        let itemSpacing: CGFloat
        let lastItemSize: CGFloat
        let itemsPerRow: Int

        init(containerSize: CGSize, itemCount: Int) {
            self.containerSize = containerSize
            self.itemCount = itemCount
            
            let width: CGFloat = containerSize.width
            
            self.itemSpacing = 1.0

            let itemsPerRow: CGFloat = CGFloat(3)
            self.itemsPerRow = Int(itemsPerRow)
            
            let itemSize = floorToScreenPixels((width - (self.itemSpacing * CGFloat(self.itemsPerRow - 1))) / itemsPerRow)
            self.itemSize = CGSize(width: itemSize, height: itemSize)

            self.lastItemSize = width - (self.itemSize.width + self.itemSpacing) * CGFloat(self.itemsPerRow - 1)
        }

        func frame(at index: Int) -> CGRect {
            let row = index / self.itemsPerRow
            let column = index % self.itemsPerRow
            
            let frame = CGRect(origin: CGPoint(x: CGFloat(column) * (self.itemSize.width + self.itemSpacing), y: CGFloat(row) * (self.itemSize.height + self.itemSpacing)), size: CGSize(width: column == (self.itemsPerRow - 1) ? self.lastItemSize : itemSize.width, height: itemSize.height))
            return frame
        }

        func contentHeight() -> CGFloat {
            return self.frame(at: self.itemCount - 1).maxY
        }

        func visibleItemRange(for rect: CGRect, count: Int) -> (minIndex: Int, maxIndex: Int) {
            let offsetRect = rect.offsetBy(dx: 0.0, dy: 0.0)
            var minVisibleRow = Int(floor((offsetRect.minY - self.itemSpacing) / (self.itemSize.height + self.itemSpacing)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY - self.itemSpacing) / (self.itemSize.height + itemSpacing)))

            let minVisibleIndex = minVisibleRow * self.itemsPerRow
            let maxVisibleIndex = min(count - 1, (maxVisibleRow + 1) * self.itemsPerRow - 1)

            return (minVisibleIndex, maxVisibleIndex)
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private var component: VideoChatParticipantsComponent?
        private var isUpdating: Bool = false
        
        private var ignoreScrolling: Bool = false
        
        private var itemViews: [EnginePeer.Id: ComponentView<Empty>] = [:]
        private var itemLayout: ItemLayout?
        
        override init(frame: CGRect) {
            self.scrollView = ScrollView()
            
            super.init(frame: frame)
            
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.clipsToBounds = false
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.alwaysBounceVertical = true
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            
            self.addSubview(self.scrollView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }
        
        private func updateScrolling(transition: ComponentTransition) {
            guard let component = self.component, let itemLayout = self.itemLayout else {
                return
            }
            
            var validItemIds: [EnginePeer.Id] = []
            if let members = component.members {
                let visibleItemRange = itemLayout.visibleItemRange(for: self.scrollView.bounds, count: itemLayout.itemCount)
                if visibleItemRange.maxIndex >= visibleItemRange.minIndex {
                    for i in visibleItemRange.minIndex ... visibleItemRange.maxIndex {
                        let participant = members.participants[i]
                        validItemIds.append(participant.peer.id)
                        
                        var itemTransition = transition
                        let itemView: ComponentView<Empty>
                        if let current = self.itemViews[participant.peer.id] {
                            itemView = current
                        } else {
                            itemTransition = itemTransition.withAnimation(.none)
                            itemView = ComponentView()
                            self.itemViews[participant.peer.id] = itemView
                        }
                        
                        let itemFrame = itemLayout.frame(at: i)
                        
                        let _ = itemView.update(
                            transition: itemTransition,
                            component: AnyComponent(ParticipantVideoComponent(
                                call: component.call,
                                participant: participant
                            )),
                            environment: {},
                            containerSize: itemFrame.size
                        )
                        if let itemComponentView = itemView.view {
                            if itemComponentView.superview == nil {
                                self.scrollView.addSubview(itemComponentView)
                            }
                            itemTransition.setFrame(view: itemComponentView, frame: itemFrame)
                        }
                    }
                }
            }
            
            var removedItemIds: [EnginePeer.Id] = []
            for (itemId, itemView) in self.itemViews {
                if !validItemIds.contains(itemId) {
                    removedItemIds.append(itemId)
                    
                    if let itemComponentView = itemView.view {
                        itemComponentView.removeFromSuperview()
                    }
                }
            }
            for itemId in removedItemIds {
                self.itemViews.removeValue(forKey: itemId)
            }
        }
        
        func update(component: VideoChatParticipantsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let itemLayout = ItemLayout(containerSize: availableSize, itemCount: component.members?.totalCount ?? 0)
            self.itemLayout = itemLayout
            
            var requestedVideo: [PresentationGroupCallRequestedVideo] = []
            if let members = component.members {
                for participant in members.participants {
                    if let videoChannel = participant.requestedVideoChannel(minQuality: .thumbnail, maxQuality: .medium) {
                        requestedVideo.append(videoChannel)
                    }
                }
            }
            (component.call as! PresentationGroupCallImpl).setRequestedVideoList(items: requestedVideo)
            
            self.ignoreScrolling = true
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
            let contentSize = CGSize(width: availableSize.width, height: itemLayout.contentHeight())
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
