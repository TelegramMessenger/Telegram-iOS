import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AppBundle
import TelegramCore
import AccountContext
import SwiftSignalKit
import MetalEngine
import CallScreen
import AvatarNode

final class VideoChatParticipantThumbnailComponent: Component {
    let call: PresentationGroupCall
    let theme: PresentationTheme
    let participant: GroupCallParticipantsContext.Participant
    let isPresentation: Bool
    let isSelected: Bool
    let action: (() -> Void)?
    
    init(
        call: PresentationGroupCall,
        theme: PresentationTheme,
        participant: GroupCallParticipantsContext.Participant,
        isPresentation: Bool,
        isSelected: Bool,
        action: (() -> Void)?
    ) {
        self.call = call
        self.theme = theme
        self.participant = participant
        self.isPresentation = isPresentation
        self.isSelected = isSelected
        self.action = action
    }
    
    static func ==(lhs: VideoChatParticipantThumbnailComponent, rhs: VideoChatParticipantThumbnailComponent) -> Bool {
        if lhs.call !== rhs.call {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.participant != rhs.participant {
            return false
        }
        if lhs.isPresentation != rhs.isPresentation {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
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
    
    final class View: HighlightTrackingButton {
        private static let selectedBorderImage: UIImage? = {
            return generateStretchableFilledCircleImage(diameter: 20.0, color: nil, strokeColor: UIColor.white, strokeWidth: 2.0)?.withRenderingMode(.alwaysTemplate)
        }()
        
        private var component: VideoChatParticipantThumbnailComponent?
        private weak var componentState: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var avatarNode: AvatarNode?
        private let title = ComponentView<Empty>()
        private let muteStatus = ComponentView<Empty>()
        
        private var selectedBorderView: UIImageView?
        
        private var videoSource: AdaptedCallVideoSource?
        private var videoDisposable: Disposable?
        private var videoBackgroundLayer: SimpleLayer?
        private var videoLayer: PrivateCallVideoLayer?
        private var videoSpec: VideoSpec?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
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
        }
        
        @objc private func pressed() {
            guard let component = self.component, let action = component.action else {
                return
            }
            action()
        }
        
        func update(component: VideoChatParticipantThumbnailComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            if self.component == nil {
                self.backgroundColor = UIColor(rgb: 0x1C1C1E)
            }
            
            self.component = component
            self.componentState = state
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 17.0))
                avatarNode.isUserInteractionEnabled = false
                self.avatarNode = avatarNode
                self.addSubview(avatarNode.view)
            }
            
            let avatarSize = CGSize(width: 50.0, height: 50.0)
            let avatarFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarSize.width) * 0.5), y: 7.0), size: avatarSize)
            transition.setFrame(view: avatarNode.view, frame: avatarFrame)
            avatarNode.updateSize(size: avatarSize)
            if component.participant.peer.smallProfileImage != nil {
                avatarNode.setPeerV2(context: component.call.accountContext, theme: component.theme, peer: EnginePeer(component.participant.peer), displayDimensions: avatarSize)
            } else {
                avatarNode.setPeer(context: component.call.accountContext, theme: component.theme, peer: EnginePeer(component.participant.peer), displayDimensions: avatarSize)
            }
            
            let muteStatusSize = self.muteStatus.update(
                transition: transition,
                component: AnyComponent(VideoChatMuteIconComponent(
                    color: .white,
                    isMuted: component.participant.muteState != nil
                )),
                environment: {},
                containerSize: CGSize(width: 36.0, height: 36.0)
            )
            let muteStatusFrame = CGRect(origin: CGPoint(x: availableSize.width + 5.0 - muteStatusSize.width, y: availableSize.height + 5.0 - muteStatusSize.height), size: muteStatusSize)
            if let muteStatusView = self.muteStatus.view {
                if muteStatusView.superview == nil {
                    self.addSubview(muteStatusView)
                }
                transition.setPosition(view: muteStatusView, position: muteStatusFrame.center)
                transition.setBounds(view: muteStatusView, bounds: CGRect(origin: CGPoint(), size: muteStatusFrame.size))
                transition.setScale(view: muteStatusView, scale: 0.65)
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: EnginePeer(component.participant.peer).compactDisplayTitle, font: Font.semibold(13.0), textColor: .white))
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 6.0 * 2.0 - 8.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: 6.0, y: availableSize.height - 6.0 - titleSize.height), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint()
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setPosition(view: titleView, position: titleFrame.origin)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
            }
            
            if let videoDescription = component.isPresentation ? component.participant.presentationDescription : component.participant.videoDescription {
                let videoBackgroundLayer: SimpleLayer
                if let current = self.videoBackgroundLayer {
                    videoBackgroundLayer = current
                } else {
                    videoBackgroundLayer = SimpleLayer()
                    videoBackgroundLayer.backgroundColor = UIColor(white: 0.1, alpha: 1.0).cgColor
                    self.videoBackgroundLayer = videoBackgroundLayer
                    self.layer.insertSublayer(videoBackgroundLayer, above: avatarNode.layer)
                    videoBackgroundLayer.isHidden = true
                }
                
                let videoLayer: PrivateCallVideoLayer
                if let current = self.videoLayer {
                    videoLayer = current
                } else {
                    videoLayer = PrivateCallVideoLayer()
                    self.videoLayer = videoLayer
                    self.layer.insertSublayer(videoLayer.blurredLayer, above: videoBackgroundLayer)
                    self.layer.insertSublayer(videoLayer, above: videoLayer.blurredLayer)
                    
                    videoLayer.blurredLayer.opacity = 0.25
                    
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
                                        self.componentState?.updated(transition: .immediate, isLocal: true)
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
                
                transition.setFrame(layer: videoBackgroundLayer, frame: CGRect(origin: CGPoint(), size: availableSize))
                
                if let videoSpec = self.videoSpec {
                    videoBackgroundLayer.isHidden = component.isSelected
                    videoLayer.blurredLayer.isHidden = component.isSelected
                    videoLayer.isHidden = component.isSelected
                    
                    let rotatedResolution = videoSpec.resolution
                    let videoSize = rotatedResolution.aspectFilled(availableSize)
                    let videoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - videoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - videoSize.height) * 0.5)), size: videoSize)
                    let blurredVideoSize = rotatedResolution.aspectFilled(availableSize)
                    let blurredVideoFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - blurredVideoSize.width) * 0.5), y: floorToScreenPixels((availableSize.height - blurredVideoSize.height) * 0.5)), size: blurredVideoSize)
                    
                    let videoResolution = rotatedResolution.aspectFitted(CGSize(width: availableSize.width * 3.0, height: availableSize.height * 3.0))
                    let rotatedVideoResolution = videoResolution
                    
                    transition.setPosition(layer: videoLayer, position: videoFrame.center)
                    transition.setBounds(layer: videoLayer, bounds: CGRect(origin: CGPoint(), size: videoFrame.size))
                    videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)), edgeInset: 2)
                    
                    transition.setPosition(layer: videoLayer.blurredLayer, position: blurredVideoFrame.center)
                    transition.setBounds(layer: videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: blurredVideoFrame.size))
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
            
            if component.isSelected {
                let selectedBorderView: UIImageView
                if let current = self.selectedBorderView {
                    selectedBorderView = current
                } else {
                    selectedBorderView = UIImageView()
                    self.selectedBorderView = selectedBorderView
                    self.addSubview(selectedBorderView)
                    selectedBorderView.image = View.selectedBorderImage
                }
                selectedBorderView.tintColor = component.theme.list.itemAccentColor
                selectedBorderView.frame = CGRect(origin: CGPoint(), size: availableSize)
            } else {
                if let selectedBorderView = self.selectedBorderView {
                    self.selectedBorderView = nil
                    selectedBorderView.removeFromSuperview()
                }
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

final class VideoChatExpandedParticipantThumbnailsComponent: Component {
    final class Participant: Equatable {
        struct Key: Hashable {
            var id: EnginePeer.Id
            var isPresentation: Bool

            init(id: EnginePeer.Id, isPresentation: Bool) {
                self.id = id
                self.isPresentation = isPresentation
            }
        }

        let participant: GroupCallParticipantsContext.Participant
        let isPresentation: Bool
        
        var key: Key {
            return Key(id: self.participant.peer.id, isPresentation: self.isPresentation)
        }

        init(
            participant: GroupCallParticipantsContext.Participant,
            isPresentation: Bool
        ) {
            self.participant = participant
            self.isPresentation = isPresentation
        }

        static func ==(lhs: Participant, rhs: Participant) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.participant != rhs.participant {
                return false
            }
            if lhs.isPresentation != rhs.isPresentation {
                return false
            }
            return true
        }
    }

    let call: PresentationGroupCall
    let theme: PresentationTheme
    let participants: [Participant]
    let selectedParticipant: Participant.Key?
    let updateSelectedParticipant: (Participant.Key) -> Void

    init(
        call: PresentationGroupCall,
        theme: PresentationTheme,
        participants: [Participant],
        selectedParticipant: Participant.Key?,
        updateSelectedParticipant: @escaping (Participant.Key) -> Void
    ) {
        self.call = call
        self.theme = theme
        self.participants = participants
        self.selectedParticipant = selectedParticipant
        self.updateSelectedParticipant = updateSelectedParticipant
    }

    static func ==(lhs: VideoChatExpandedParticipantThumbnailsComponent, rhs: VideoChatExpandedParticipantThumbnailsComponent) -> Bool {
        if lhs.call !== rhs.call {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.participants != rhs.participants {
            return false
        }
        if lhs.selectedParticipant != rhs.selectedParticipant {
            return false
        }
        return true
    }
    
    private final class ScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            return true
        }
    }
    
    private struct ItemLayout {
        let containerSize: CGSize
        let containerInsets: UIEdgeInsets
        let itemCount: Int
        let itemSize: CGSize
        let itemSpacing: CGFloat
        
        let contentSize: CGSize
        
        init(containerSize: CGSize, containerInsets: UIEdgeInsets, itemCount: Int) {
            self.containerSize = containerSize
            self.containerInsets = containerInsets
            self.itemCount = itemCount
            self.itemSize = CGSize(width: 84.0, height: 84.0)
            self.itemSpacing = 6.0
            
            let itemsWidth: CGFloat = CGFloat(itemCount) * self.itemSize.width + CGFloat(max(itemCount - 1, 0)) * self.itemSpacing
            self.contentSize = CGSize(width: self.containerInsets.left + self.containerInsets.right + itemsWidth, height: self.containerInsets.top + self.containerInsets.bottom + self.itemSize.height)
        }
        
        func frame(at index: Int) -> CGRect {
            let frame = CGRect(origin: CGPoint(x: self.containerInsets.left + CGFloat(index) * (self.itemSize.width + self.itemSpacing), y: self.containerInsets.top), size: self.itemSize)
            return frame
        }
        
        func visibleItemRange(for rect: CGRect) -> (minIndex: Int, maxIndex: Int) {
            if self.itemCount == 0 {
                return (0, -1)
            }
            let offsetRect = rect.offsetBy(dx: -self.containerInsets.left, dy: 0.0)
            var minVisibleRow = Int(floor((offsetRect.minY) / (self.itemSize.width)))
            minVisibleRow = max(0, minVisibleRow)
            let maxVisibleRow = Int(ceil((offsetRect.maxY) / (self.itemSize.width)))

            let minVisibleIndex = minVisibleRow
            let maxVisibleIndex = min(self.itemCount - 1, (maxVisibleRow + 1) - 1)

            return (minVisibleIndex, maxVisibleIndex)
        }
    }
    
    private final class VisibleItem {
        let view = ComponentView<Empty>()
        
        init() {
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        private let scrollView: ScrollView
        
        private var component: VideoChatExpandedParticipantThumbnailsComponent?
        private var isUpdating: Bool = false
        
        private var ignoreScrolling: Bool = false
        
        private var itemLayout: ItemLayout?
        private var visibleItems: [Participant.Key: VisibleItem] = [:]
        
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
            self.scrollView.alwaysBounceVertical = false
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
            
            var validListItemIds: [Participant.Key] = []
            let visibleListItemRange = itemLayout.visibleItemRange(for: self.scrollView.bounds)
            if visibleListItemRange.maxIndex >= visibleListItemRange.minIndex {
                for i in visibleListItemRange.minIndex ... visibleListItemRange.maxIndex {
                    let participant = component.participants[i]
                    validListItemIds.append(participant.key)
                    
                    var itemTransition = transition
                    let itemView: VisibleItem
                    if let current = self.visibleItems[participant.key] {
                        itemView = current
                    } else {
                        itemTransition = itemTransition.withAnimation(.none)
                        itemView = VisibleItem()
                        self.visibleItems[participant.key] = itemView
                    }
                    
                    let itemFrame = itemLayout.frame(at: i)
                    
                    let participantKey = participant.key
                    let _ = itemView.view.update(
                        transition: itemTransition,
                        component: AnyComponent(VideoChatParticipantThumbnailComponent(
                            call: component.call,
                            theme: component.theme,
                            participant: participant.participant,
                            isPresentation: participant.isPresentation,
                            isSelected: component.selectedParticipant == participant.key,
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.updateSelectedParticipant(participantKey)
                            }
                        )),
                        environment: {},
                        containerSize: itemFrame.size
                    )
                    if let itemComponentView = itemView.view.view {
                        if itemComponentView.superview == nil {
                            itemComponentView.clipsToBounds = true
                            
                            self.scrollView.addSubview(itemComponentView)
                            
                            if !transition.animation.isImmediate {
                                itemComponentView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                                transition.animateScale(view: itemComponentView, from: 0.001, to: 1.0)
                            }
                        }
                        transition.setFrame(view: itemComponentView, frame: itemFrame)
                    }
                }
            }
            
            var removedListItemIds: [Participant.Key] = []
            for (itemId, itemView) in self.visibleItems {
                if !validListItemIds.contains(itemId) {
                    removedListItemIds.append(itemId)
                    
                    if let itemComponentView = itemView.view.view {
                        if !transition.animation.isImmediate {
                            transition.setScale(view: itemComponentView, scale: 0.001)
                            itemComponentView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak itemComponentView] _ in
                                itemComponentView?.removeFromSuperview()
                            })
                        } else {
                            itemComponentView.removeFromSuperview()
                        }
                    }
                }
            }
            for itemId in removedListItemIds {
                self.visibleItems.removeValue(forKey: itemId)
            }
        }
        
        func update(component: VideoChatExpandedParticipantThumbnailsComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            
            let itemLayout = ItemLayout(
                containerSize: availableSize,
                containerInsets: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0),
                itemCount: component.participants.count
            )
            self.itemLayout = itemLayout
            
            let size = CGSize(width: availableSize.width, height: itemLayout.contentSize.height)
            
            self.ignoreScrolling = true
            if self.scrollView.bounds.size != size {
                transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
            }
            let contentSize = CGSize(width: itemLayout.contentSize.width, height: size.height)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.ignoreScrolling = false
            
            self.updateScrolling(transition: transition)
            
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
