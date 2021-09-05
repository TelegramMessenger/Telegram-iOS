import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AvatarNode
import TelegramStringFormatting
import PeerPresenceStatusManager
import ContextUI
import AccountContext
import LegacyComponents
import AudioBlob
import PeerInfoAvatarListNode

private let avatarFont = avatarPlaceholderFont(size: floor(50.0 * 16.0 / 37.0))
private let tileSize = CGSize(width: 84.0, height: 84.0)
private let backgroundCornerRadius: CGFloat = 11.0
private let videoCornerRadius: CGFloat = 23.0
private let avatarSize: CGFloat = 50.0
private let videoSize = CGSize(width: 180.0, height: 180.0)

private let accentColor: UIColor = UIColor(rgb: 0x007aff)
private let constructiveColor: UIColor = UIColor(rgb: 0x34c759)
private let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)

private let borderLineWidth: CGFloat = 2.0

private let fadeColor = UIColor(rgb: 0x000000, alpha: 0.5)
let fadeHeight: CGFloat = 50.0

private var fadeImage: UIImage? = {
    return generateImage(CGSize(width: fadeHeight, height: fadeHeight), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)

        let stepCount = 10
        var colors: [CGColor] = []
        var locations: [CGFloat] = []

        for i in 0 ... stepCount {
            let t = CGFloat(i) / CGFloat(stepCount)
            colors.append(fadeColor.withAlphaComponent((1.0 - t * t) * 0.7).cgColor)
            locations.append(t)
        }

        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    })
}()

final class VoiceChatFullscreenParticipantItem: ListViewItem {
    enum Icon {
        case none
        case microphone(Bool, UIColor)
        case invite(Bool)
        case wantsToSpeak
    }
    
    enum Color {
        case generic
        case accent
        case constructive
        case destructive
    }
    
    let presentationData: ItemListPresentationData
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peer: Peer
    let videoEndpointId: String?
    let isPaused: Bool
    let icon: Icon
    let text: VoiceChatParticipantItem.ParticipantText
    let textColor: Color
    let color: Color
    let isLandscape: Bool
    let active: Bool
    let showVideoWhenActive: Bool
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    let getVideo: () -> GroupVideoNode?
    let action: ((ASDisplayNode?) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let getUpdatingAvatar: () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>
    
    public let selectable: Bool = true
    
    public init(presentationData: ItemListPresentationData, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, peer: Peer, videoEndpointId: String?, isPaused: Bool, icon: Icon, text: VoiceChatParticipantItem.ParticipantText, textColor: Color, color: Color, isLandscape: Bool, active: Bool, showVideoWhenActive: Bool, getAudioLevel: (() -> Signal<Float, NoError>)?, getVideo: @escaping () -> GroupVideoNode?, action: ((ASDisplayNode?) -> Void)?, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil, getUpdatingAvatar: @escaping () -> Signal<(TelegramMediaImageRepresentation, Float)?, NoError>) {
        self.presentationData = presentationData
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.peer = peer
        self.videoEndpointId = videoEndpointId
        self.isPaused = isPaused
        self.icon = icon
        self.text = text
        self.textColor = textColor
        self.color = color
        self.isLandscape = isLandscape
        self.active = active
        self.showVideoWhenActive = showVideoWhenActive
        self.getAudioLevel = getAudioLevel
        self.getVideo = getVideo
        self.action = action
        self.contextAction = contextAction
        self.getUpdatingAvatar = getUpdatingAvatar
    }
        
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VoiceChatFullscreenParticipantItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, previousItem == nil, nextItem == nil)
            
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            
            Queue.mainQueue().async {
                completion(node, {
                    return (node.avatarNode.ready, { _ in apply(synchronousLoads, false) })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? VoiceChatFullscreenParticipantItemNode {
                let makeLayout = nodeValue.asyncLayout()
                
                var animated = true
                if case .None = animation {
                    animated = false
                }
                
                async {
                    let (layout, apply) = makeLayout(self, params, previousItem == nil, nextItem == nil)
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(false, animated)
                        })
                    }
                }
            }
        }
    }
    
    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
    }
}

class VoiceChatFullscreenParticipantItemNode: ItemListRevealOptionsItemNode {
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    let backgroundImageNode: ASImageNode
    private let extractedBackgroundImageNode: ASImageNode
    let offsetContainerNode: ASDisplayNode
    let highlightNode: VoiceChatTileHighlightNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    private var extractedVerticalOffset: CGFloat?
        
    let avatarNode: AvatarNode
    let contentWrapperNode: ASDisplayNode
    private let titleNode: TextNode
    private let statusNode: VoiceChatParticipantStatusNode
    private var credibilityIconNode: ASImageNode?
        
    private let actionContainerNode: ASDisplayNode
    private var animationNode: VoiceChatMicrophoneNode?
    private var iconNode: ASImageNode?
    private var raiseHandNode: VoiceChatRaiseHandNode?
    private var actionButtonNode: HighlightableButtonNode
    
    var audioLevelView: VoiceBlobView?
    private let audioLevelDisposable = MetaDisposable()
    private var didSetupAudioLevel = false
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var layoutParams: (VoiceChatFullscreenParticipantItem, ListViewItemLayoutParams, Bool, Bool)?
    private var isExtracted = false
    private var animatingExtraction = false
    private var animatingSelection = false
    private var wavesColor: UIColor?
    
    let videoContainerNode: ASDisplayNode
    let videoFadeNode: ASDisplayNode
    var videoNode: GroupVideoNode?
    
    private var profileNode: VoiceChatPeerProfileNode?
    
    private var raiseHandTimer: SwiftSignalKit.Timer?
    private var silenceTimer: SwiftSignalKit.Timer?
    
    var item: VoiceChatFullscreenParticipantItem? {
        return self.layoutParams?.0
    }

    private var isCurrentlyInHierarchy = false {
        didSet {
            if self.isCurrentlyInHierarchy != oldValue {
                self.highlightNode.isCurrentlyInHierarchy = self.isCurrentlyInHierarchy
                self.audioLevelView?.isManuallyInHierarchy = self.isCurrentlyInHierarchy
            }
        }
    }
    private var isCurrentlyInHierarchyDisposable: Disposable?
    
    init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.backgroundImageNode = ASImageNode()
        self.backgroundImageNode.clipsToBounds = true
        self.backgroundImageNode.displaysAsynchronously = false
        self.backgroundImageNode.alpha = 0.0
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.clipsToBounds = true
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.highlightNode = VoiceChatTileHighlightNode()
        self.highlightNode.isHidden = true
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: avatarSize, height: avatarSize))
        
        self.contentWrapperNode = ASDisplayNode()
        
        self.videoContainerNode = ASDisplayNode()
        self.videoContainerNode.clipsToBounds = true
        
        self.videoFadeNode = ASDisplayNode()
        self.videoFadeNode.displaysAsynchronously = false
        if let image = fadeImage {
            self.videoFadeNode.backgroundColor = UIColor(patternImage: image)
        }
        self.videoContainerNode.addSubnode(self.videoFadeNode)
        
        self.titleNode = TextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = VoiceChatParticipantStatusNode()
    
        self.actionContainerNode = ASDisplayNode()
        self.actionButtonNode = HighlightableButtonNode()

        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.backgroundImageNode)
        self.backgroundImageNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.videoContainerNode)
        self.offsetContainerNode.addSubnode(self.contentWrapperNode)
        self.contentWrapperNode.addSubnode(self.titleNode)
        self.contentWrapperNode.addSubnode(self.actionContainerNode)
        self.actionContainerNode.addSubnode(self.actionButtonNode)
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.contextSourceNode.contentNode.addSubnode(self.highlightNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
                
        self.containerNode.shouldBegin = { [weak self] location in
            guard let _ = self else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0, let contextAction = item.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextSourceNode, gesture)
        }
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let _ = strongSelf.item else {
                return
            }
            strongSelf.updateIsExtracted(isExtracted, transition: transition)
        }
    }
    
    deinit {
        self.audioLevelDisposable.dispose()
        self.raiseHandTimer?.invalidate()
        self.silenceTimer?.invalidate()
        self.isCurrentlyInHierarchyDisposable?.dispose()
    }
    
    override func selected() {
        super.selected()
        if self.animatingSelection {
            return
        }
        self.layoutParams?.0.action?(self.contextSourceNode)
    }
    
    func transitionIn(from sourceNode: ASDisplayNode?) {
        guard let item = self.item else {
            return
        }
        let active = item.active && !item.showVideoWhenActive
        
        var videoNode: GroupVideoNode?
        if let sourceNode = sourceNode as? VoiceChatTileItemNode {
            if let sourceVideoNode = sourceNode.videoNode {
                sourceNode.videoNode = nil
                videoNode = sourceVideoNode
            }
        }
        
        if videoNode == nil {
            videoNode = item.getVideo()
        }
        
        if videoNode?.isMainstageExclusive == true && active {
            videoNode = nil
        }
        
        if let videoNode = videoNode {
            if active {
                self.avatarNode.alpha = 1.0
                videoNode.alpha = 0.0
            } else {
                self.avatarNode.alpha = 0.0
                videoNode.alpha = 1.0
            }
            self.videoNode = videoNode
            self.videoContainerNode.insertSubnode(videoNode, at: 0)
            
            videoNode.updateLayout(size: videoSize, layoutMode: .fillOrFitToSquare, transition: .immediate)
            videoNode.frame = CGRect(origin: CGPoint(), size: videoSize)
        }
    }
    
    var gridVisibility = true {
        didSet {
            self.updateIsEnabled()
        }
    }
    
    func updateIsEnabled() {
        guard let (rect, containerSize) = self.absoluteLocation else {
            return
        }
        let isVisibleInContainer = rect.maxY >= 0.0 && rect.minY <= containerSize.height
        if let videoNode = self.videoNode, videoNode.supernode === self.videoContainerNode {
            videoNode.updateIsEnabled(self.gridVisibility && isVisibleInContainer)
        }
    }
    
    private func updateIsExtracted(_ isExtracted: Bool, transition: ContainedViewLayoutTransition) {
        guard self.isExtracted != isExtracted,  let extractedRect = self.extractedRect, let nonExtractedRect = self.nonExtractedRect, let item = self.item else {
            return
        }
        self.isExtracted = isExtracted
        
        if item.peer.smallProfileImage != nil {
            let springDuration: Double = 0.42
            let springDamping: CGFloat = 124.0
            
            if isExtracted {
                var hasVideo = false
                if let videoNode = self.videoNode, videoNode.supernode == self.videoContainerNode, !videoNode.alpha.isZero {
                    hasVideo = true
                }
                let profileNode = VoiceChatPeerProfileNode(context: item.context, size: extractedRect.size, sourceSize: nonExtractedRect.size, peer: item.peer, text: item.text, customNode: hasVideo ? self.videoContainerNode : nil, additionalEntry: .single(nil), requestDismiss: { [weak self] in
                    self?.contextSourceNode.requestDismiss?()
                })
                profileNode.frame = CGRect(origin: CGPoint(), size: extractedRect.size)
                self.profileNode = profileNode
                self.contextSourceNode.contentNode.addSubnode(profileNode)
                
                profileNode.animateIn(from: self, targetRect: extractedRect, transition: transition)
                var appearenceTransition = transition
                if transition.isAnimated {
                    appearenceTransition = .animated(duration: springDuration, curve: .customSpring(damping: springDamping, initialVelocity: 0.0))
                }
                appearenceTransition.updateFrame(node: profileNode, frame: extractedRect)
                
                self.contextSourceNode.contentNode.customHitTest = { [weak self] point in
                    if let strongSelf = self, let profileNode = strongSelf.profileNode {
                        if profileNode.avatarListWrapperNode.frame.contains(point) {
                            return profileNode.avatarListNode.view
                        }
                    }
                    return nil
                }
                self.highlightNode.isHidden = true
                self.backgroundImageNode.isHidden = true
            } else if let profileNode = self.profileNode {
                self.profileNode = nil
                profileNode.animateOut(to: self, targetRect: nonExtractedRect, transition: transition, completion: { [weak self] in
                    self?.backgroundImageNode.isHidden = false
                })
                
                var appearenceTransition = transition
                if transition.isAnimated {
                    appearenceTransition = .animated(duration: 0.2, curve: .easeInOut)
                }
                appearenceTransition.updateFrame(node: profileNode, frame: nonExtractedRect)
                
                self.contextSourceNode.contentNode.customHitTest = nil
                self.highlightNode.isHidden = !item.active
            }
        }
    }
    
    func asyncLayout() -> (_ item: VoiceChatFullscreenParticipantItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = self.statusNode.asyncLayout()
        
        let currentItem = self.layoutParams?.0
        var hasVideo = self.videoNode != nil
        
        return { item, params, first, last in
            let titleFont = Font.semibold(13.0)
            var titleAttributedString: NSAttributedString?
            
            if !hasVideo && item.videoEndpointId != nil {
                hasVideo = true
            }
            let active = item.active && !item.showVideoWhenActive
            
            var titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            if !hasVideo || active {
                switch item.textColor {
                    case .generic:
                        titleColor = item.presentationData.theme.list.itemPrimaryTextColor
                    case .accent:
                        titleColor = item.presentationData.theme.list.itemAccentColor
                    case .constructive:
                        titleColor = constructiveColor
                    case .destructive:
                        titleColor = destructiveColor
                }
            }
            let currentBoldFont: UIFont = titleFont
            
            if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: titleFont, textColor: titleColor)
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: currentBoldFont, textColor: titleColor)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.presentationData.strings.User_DeletedAccount, font: currentBoldFont, textColor: titleColor)
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: currentBoldFont, textColor: titleColor)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: currentBoldFont, textColor: titleColor)
            }
        
            var wavesColor = UIColor(rgb: 0x34c759)
            var gradient: VoiceChatTileHighlightNode.Gradient = .active
            switch item.color {
                case .accent:
                    wavesColor = accentColor
                    if case .wantsToSpeak = item.icon {
                        gradient = .muted
                    }
                case .constructive:
                    gradient = .speaking
                case .destructive:
                    gradient = .mutedForYou
                    wavesColor = destructiveColor
                default:
                    break
            }
            var titleUpdated = false
            if let currentColor = currentItem?.textColor, currentColor != item.textColor {
                titleUpdated = true
            }

            let leftInset: CGFloat = 58.0 + params.leftInset
            
            var titleIconsWidth: CGFloat = 0.0
            var currentCredibilityIconImage: UIImage?
            var credibilityIconOffset: CGFloat = 0.0
            if item.peer.isScam {
                currentCredibilityIconImage = PresentationResourcesChatList.scamIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                credibilityIconOffset = 2.0
            } else if item.peer.isFake {
                currentCredibilityIconImage = PresentationResourcesChatList.fakeIcon(item.presentationData.theme, strings: item.presentationData.strings, type: .regular)
                credibilityIconOffset = 2.0
            } else if item.peer.isVerified {
                currentCredibilityIconImage = PresentationResourcesChatList.verifiedIcon(item.presentationData.theme)
                credibilityIconOffset = 3.0
            }
            
            if let currentCredibilityIconImage = currentCredibilityIconImage {
                titleIconsWidth += 4.0 + currentCredibilityIconImage.size.width
            }
                      
            let constrainedWidth = params.width - 24.0 - 10.0
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                        
            let availableWidth = params.availableHeight
            let (statusLayout, _) = makeStatusLayout(CGSize(width: availableWidth - 30.0, height: CGFloat.greatestFiniteMagnitude), item.text, true)
            
            let contentSize = tileSize
            let insets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: !last ? 6.0 : 0.0, right: 0.0)
                            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
                        
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    let hadItem = strongSelf.layoutParams?.0 != nil
                    strongSelf.layoutParams = (item, params, first, last)
                    strongSelf.wavesColor = wavesColor
                    
                    let videoContainerScale = tileSize.width / videoSize.width
                    
                    let appearanceDuration: Double = 0.25
                    let apperanceTransition = ContainedViewLayoutTransition.animated(duration: appearanceDuration, curve: .easeInOut)
                    let videoNode = item.getVideo()
                    if let currentVideoNode = strongSelf.videoNode, currentVideoNode !== videoNode {
                        if videoNode == nil {
                            let snapshotView = currentVideoNode.snapshotView
                            if strongSelf.avatarNode.alpha.isZero {
                                strongSelf.animatingSelection = true
                                strongSelf.videoContainerNode.layer.animateScale(from: videoContainerScale, to: 0.001, duration: appearanceDuration, completion: { _ in
                                    snapshotView?.removeFromSuperview()
                                })
                                strongSelf.avatarNode.layer.animateScale(from: 0.0, to: 1.0, duration: appearanceDuration, completion: { [weak self] _ in
                                    self?.animatingSelection = false
                                })
                                strongSelf.videoContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -9.0), duration: appearanceDuration, additive: true)
                                strongSelf.audioLevelView?.layer.animateScale(from: 0.0, to: 1.0, duration: appearanceDuration)
                            }
                            if currentVideoNode.supernode === strongSelf.videoContainerNode {
                                apperanceTransition.updateAlpha(node: currentVideoNode, alpha: 0.0)
                            } else if let snapshotView = snapshotView {
                                strongSelf.videoContainerNode.view.insertSubview(snapshotView, at: 0)
                                apperanceTransition.updateAlpha(layer: snapshotView.layer, alpha: 0.0)
                            }
                            apperanceTransition.updateAlpha(node: strongSelf.videoFadeNode, alpha: 0.0)
                            apperanceTransition.updateAlpha(node: strongSelf.avatarNode, alpha: 1.0)
                            if let audioLevelView = strongSelf.audioLevelView {
                                apperanceTransition.updateAlpha(layer: audioLevelView.layer, alpha: 1.0)
                            }
                        } else {
                            if currentItem?.peer.id == item.peer.id {
                                currentVideoNode.layer.animateScale(from: 1.0, to: 0.0, duration: appearanceDuration, removeOnCompletion: false, completion: { [weak self, weak currentVideoNode] _ in
                                    currentVideoNode?.layer.removeAllAnimations()
                                    if currentVideoNode !== self?.videoNode {
                                        currentVideoNode?.removeFromSupernode()
                                    }
                                })
                            } else {
                                currentVideoNode.removeFromSupernode()
                            }
                        }
                    }
                    
                    let videoNodeUpdated = strongSelf.videoNode !== videoNode
                    strongSelf.videoNode = videoNode
                    
                    videoNode?.updateIsBlurred(isBlurred: item.isPaused, light: true)
                    
                    let nonExtractedRect: CGRect
                    let avatarFrame: CGRect
                    let titleFrame: CGRect
                    let animationSize: CGSize
                    let animationFrame: CGRect
                    let animationScale: CGFloat
                    
                    nonExtractedRect = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.transform = CATransform3DMakeRotation(item.isLandscape ? 0.0 : CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
                    avatarFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - avatarSize) / 2.0), y: 7.0), size: CGSize(width: avatarSize, height: avatarSize))
                    
                    animationSize = CGSize(width: 36.0, height: 36.0)
                    animationScale = 0.66667
                    animationFrame = CGRect(x: layout.size.width - 29.0, y: 55.0, width: 24.0, height: 24.0)
                    titleFrame = CGRect(origin: CGPoint(x: 8.0, y: 63.0), size: titleLayout.size)
                                    
                    let extractedWidth = availableWidth
                    var extractedRect = CGRect(x: 0.0, y: 0.0, width: extractedWidth, height: extractedWidth + statusLayout.height + 39.0)
                    if item.peer.smallProfileImage == nil {
                        extractedRect = nonExtractedRect
                    }
                    strongSelf.extractedRect = extractedRect
                    strongSelf.nonExtractedRect = nonExtractedRect
                    
                    strongSelf.backgroundImageNode.frame = nonExtractedRect
                
                    if strongSelf.backgroundImageNode.image == nil {
                        strongSelf.backgroundImageNode.image = generateStretchableFilledCircleImage(diameter: backgroundCornerRadius * 2.0, color: UIColor(rgb: 0x1c1c1e))
                        strongSelf.backgroundImageNode.alpha = 1.0
                    }
                    strongSelf.extractedBackgroundImageNode.frame = strongSelf.backgroundImageNode.bounds
                    strongSelf.contextSourceNode.contentRect = extractedRect
                    
                    let contentBounds = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.frame = contentBounds
                    strongSelf.contextSourceNode.frame = contentBounds
                    strongSelf.contentWrapperNode.frame = contentBounds
                    strongSelf.offsetContainerNode.frame = contentBounds
                    strongSelf.contextSourceNode.contentNode.frame = contentBounds
                    strongSelf.actionContainerNode.frame = contentBounds
                    strongSelf.highlightNode.frame = contentBounds
                    strongSelf.highlightNode.updateLayout(size: contentBounds.size, transition: .immediate)
                    
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                        
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    let combinedValueString = ""
//                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
//                        combinedValueString.append(statusString)
//                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                                        
                    let transition: ContainedViewLayoutTransition
                    if animated && hadItem {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.3, curve: .easeInOut)
                    } else {
                        transition = .immediate
                    }
                                                            
                    if titleUpdated, let snapshotView = strongSelf.titleNode.view.snapshotContentTree() {
                        strongSelf.titleNode.view.superview?.addSubview(snapshotView)
                        snapshotView.frame = strongSelf.titleNode.view.frame
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                    
                    let _ = titleApply()               
                    transition.updateFrame(node: strongSelf.titleNode, frame: titleFrame)
                
                    if let currentCredibilityIconImage = currentCredibilityIconImage {
                        let iconNode: ASImageNode
                        if let current = strongSelf.credibilityIconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.isLayerBacked = true
                            iconNode.displaysAsynchronously = false
                            iconNode.displayWithoutProcessing = true
                            strongSelf.offsetContainerNode.addSubnode(iconNode)
                            strongSelf.credibilityIconNode = iconNode
                        }
                        iconNode.image = currentCredibilityIconImage
                        transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: leftInset + titleLayout.size.width + 3.0, y: credibilityIconOffset), size: currentCredibilityIconImage.size))
                    } else if let credibilityIconNode = strongSelf.credibilityIconNode {
                        strongSelf.credibilityIconNode = nil
                        credibilityIconNode.removeFromSupernode()
                    }
                    
                    transition.updateFrameAsPositionAndBounds(node: strongSelf.avatarNode, frame: avatarFrame)
                    
                    strongSelf.highlightNode.updateGlowAndGradientAnimations(type: gradient, animated: true)
                    
                    let blobFrame = avatarFrame.insetBy(dx: -18.0, dy: -18.0)
                    if let getAudioLevel = item.getAudioLevel {
                        if !strongSelf.didSetupAudioLevel || currentItem?.peer.id != item.peer.id {
                            strongSelf.audioLevelView?.frame = blobFrame
                            strongSelf.didSetupAudioLevel = true
                            strongSelf.audioLevelDisposable.set((getAudioLevel()
                            |> deliverOnMainQueue).start(next: { value in
                                guard let strongSelf = self else {
                                    return
                                }
                                
                                strongSelf.highlightNode.updateLevel(CGFloat(value))
                                
                                if strongSelf.audioLevelView == nil, value > 0.0 {
                                    let audioLevelView = VoiceBlobView(
                                        frame: blobFrame,
                                        maxLevel: 1.5,
                                        smallBlobRange: (0, 0),
                                        mediumBlobRange: (0.69, 0.87),
                                        bigBlobRange: (0.71, 1.0)
                                    )
                                    
                                    let maskRect = CGRect(origin: .zero, size: blobFrame.size)
                                    let playbackMaskLayer = CAShapeLayer()
                                    playbackMaskLayer.frame = maskRect
                                    playbackMaskLayer.fillRule = .evenOdd
                                    let maskPath = UIBezierPath()
                                    maskPath.append(UIBezierPath(roundedRect: maskRect.insetBy(dx: 18, dy: 18), cornerRadius: 22))
                                    maskPath.append(UIBezierPath(rect: maskRect))
                                    playbackMaskLayer.path = maskPath.cgPath
                                    audioLevelView.layer.mask = playbackMaskLayer
                                    
                                    audioLevelView.setColor(wavesColor)
                                    
                                    strongSelf.audioLevelView = audioLevelView
                                    strongSelf.offsetContainerNode.view.insertSubview(audioLevelView, at: 0)
                                }
                                
                                let level = min(1.0, max(0.0, CGFloat(value)))
                                if let audioLevelView = strongSelf.audioLevelView {
                                    audioLevelView.updateLevel(CGFloat(value))
                                    
                                    var hasVideo = false
                                    if let videoNode = strongSelf.videoNode, videoNode.supernode == strongSelf.videoContainerNode, !videoNode.alpha.isZero {
                                        hasVideo = true
                                    }
                                    
                                    var audioLevelAlpha: CGFloat = 1.0
                                    if strongSelf.isExtracted {
                                        audioLevelAlpha = 0.0
                                    } else {
                                        audioLevelAlpha = hasVideo ? 0.0 : 1.0
                                    }
                                    audioLevelView.alpha = audioLevelAlpha
                                    
                                    let avatarScale: CGFloat
                                    if value > 0.02 {
                                        audioLevelView.startAnimating()
                                        avatarScale = 1.03 + level * 0.13

                                        if let silenceTimer = strongSelf.silenceTimer {
                                            silenceTimer.invalidate()
                                            strongSelf.silenceTimer = nil
                                        }
                                    } else {
                                        avatarScale = 1.0
                                        if strongSelf.silenceTimer == nil {
                                            let silenceTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
                                                self?.audioLevelView?.stopAnimating(duration: 0.75)
                                                self?.silenceTimer = nil
                                            }, queue: Queue.mainQueue())
                                            strongSelf.silenceTimer = silenceTimer
                                            silenceTimer.start()
                                        }
                                    }
                                    
                                    if let wavesColor = strongSelf.wavesColor {
                                        audioLevelView.setColor(wavesColor, animated: true)
                                    }
                                    
                                    if !strongSelf.animatingSelection {
                                        let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
                                        transition.updateTransformScale(node: strongSelf.avatarNode, scale: strongSelf.isExtracted ? 1.0 : avatarScale, beginWithCurrentState: true)
                                    }
                                }
                            }))
                        }
                    } else if let audioLevelView = strongSelf.audioLevelView {
                        strongSelf.audioLevelView = nil
                        audioLevelView.removeFromSuperview()
                        
                        strongSelf.audioLevelDisposable.set(nil)
                    }
                    
                    var overrideImage: AvatarNodeImageOverride?
                    if item.peer.isDeleted {
                        overrideImage = .deletedIcon
                    }
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: EnginePeer(item.peer), overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad, storeUnrounded: true)
                
                    var hadMicrophoneNode = false
                    var hadRaiseHandNode = false
                    var hadIconNode = false
                    var nodeToAnimateIn: ASDisplayNode?
                    
                    if case let .microphone(muted, color) = item.icon {
                        let animationNode: VoiceChatMicrophoneNode
                        if let current = strongSelf.animationNode {
                            animationNode = current
                        } else {
                            animationNode = VoiceChatMicrophoneNode()
                            strongSelf.animationNode = animationNode
                            strongSelf.actionButtonNode.addSubnode(animationNode)
                            
                            nodeToAnimateIn = animationNode
                        }
                        var color = color
                        if (hasVideo && !active) || color.rgb == 0x979797 {
                            color = UIColor(rgb: 0xffffff)
                        }
                        animationNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: true, color: color), animated: true)
                        strongSelf.actionButtonNode.isUserInteractionEnabled = false
                    } else if let animationNode = strongSelf.animationNode {
                        hadMicrophoneNode = true
                        strongSelf.animationNode = nil
                        animationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        animationNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak animationNode] _ in
                            animationNode?.removeFromSupernode()
                        })
                    }
                    
                    if case .wantsToSpeak = item.icon {
                        let raiseHandNode: VoiceChatRaiseHandNode
                        if let current = strongSelf.raiseHandNode {
                            raiseHandNode = current
                        } else {
                            raiseHandNode = VoiceChatRaiseHandNode(color: item.presentationData.theme.list.itemAccentColor)
                            raiseHandNode.contentMode = .center
                            strongSelf.raiseHandNode = raiseHandNode
                            strongSelf.actionButtonNode.addSubnode(raiseHandNode)
                            
                            nodeToAnimateIn = raiseHandNode
                            raiseHandNode.playRandomAnimation()
                            
                            strongSelf.raiseHandTimer = SwiftSignalKit.Timer(timeout: Double.random(in: 8.0 ... 10.5), repeat: true, completion: {
                                self?.raiseHandNode?.playRandomAnimation()
                            }, queue: Queue.mainQueue())
                            strongSelf.raiseHandTimer?.start()
                        }
                        strongSelf.actionButtonNode.isUserInteractionEnabled = false
                    } else if let raiseHandNode = strongSelf.raiseHandNode {
                        hadRaiseHandNode = true
                        strongSelf.raiseHandNode = nil
                        if let raiseHandTimer = strongSelf.raiseHandTimer {
                            strongSelf.raiseHandTimer = nil
                            raiseHandTimer.invalidate()
                        }
                        raiseHandNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        raiseHandNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak raiseHandNode] _ in
                            raiseHandNode?.removeFromSupernode()
                        })
                    }
                    
                    if case let .invite(invited) = item.icon {
                        let iconNode: ASImageNode
                        if let current = strongSelf.iconNode {
                            iconNode = current
                        } else {
                            iconNode = ASImageNode()
                            iconNode.contentMode = .center
                            strongSelf.iconNode = iconNode
                            strongSelf.actionButtonNode.addSubnode(iconNode)
                            
                            nodeToAnimateIn = iconNode
                        }
                        
                        if invited {
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Invited"), color: UIColor(rgb: 0x979797))
                        } else {
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: item.presentationData.theme.list.itemAccentColor)
                        }
                        strongSelf.actionButtonNode.isUserInteractionEnabled = false
                    } else if let iconNode = strongSelf.iconNode {
                        hadIconNode = true
                        strongSelf.iconNode = nil
                        iconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        iconNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak iconNode] _ in
                            iconNode?.removeFromSupernode()
                        })
                    }
                    
                    if let node = nodeToAnimateIn, hadMicrophoneNode || hadRaiseHandNode || hadIconNode {
                        node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        node.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                    }
                    
                    if !strongSelf.isExtracted && !strongSelf.animatingExtraction && strongSelf.videoContainerNode.supernode == strongSelf.offsetContainerNode {
                        strongSelf.videoFadeNode.frame = CGRect(x: 0.0, y: videoSize.height - fadeHeight, width: videoSize.width, height: fadeHeight)
                        strongSelf.videoContainerNode.bounds = CGRect(origin: CGPoint(), size: videoSize)

                        if let videoNode = strongSelf.videoNode {
                            strongSelf.videoFadeNode.alpha = videoNode.alpha
                        } else {
                            strongSelf.videoFadeNode.alpha = 0.0
                        }
                        strongSelf.videoContainerNode.position = CGPoint(x: tileSize.width / 2.0, y: tileSize.height / 2.0)
                        strongSelf.videoContainerNode.cornerRadius = videoCornerRadius
                        strongSelf.videoContainerNode.transform = CATransform3DMakeScale(videoContainerScale, videoContainerScale, 1.0)
                    
                        strongSelf.highlightNode.isHidden = !item.active
                    }
                    
                    let canUpdateAvatarVisibility = !strongSelf.isExtracted && !strongSelf.animatingExtraction
                    
                    if let videoNode = videoNode {
                        if !strongSelf.isExtracted && !strongSelf.animatingExtraction {
                            if currentItem != nil {
                                if active {
                                    if strongSelf.avatarNode.alpha.isZero {
                                        strongSelf.animatingSelection = true
                                        strongSelf.videoContainerNode.layer.animateScale(from: videoContainerScale, to: 0.001, duration: appearanceDuration)
                                        strongSelf.avatarNode.layer.animateScale(from: 0.0, to: 1.0, duration: appearanceDuration, completion: { [weak self] _ in
                                            self?.animatingSelection = false
                                        })
                                        strongSelf.videoContainerNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -9.0), duration: appearanceDuration, additive: true)
                                        strongSelf.audioLevelView?.layer.animateScale(from: 0.0, to: 1.0, duration: appearanceDuration)
                                    }
                                    if videoNodeUpdated {
                                        videoNode.alpha = 0.0
                                        strongSelf.videoFadeNode.alpha = 0.0
                                    } else {
                                        apperanceTransition.updateAlpha(node: videoNode, alpha: 0.0)
                                        apperanceTransition.updateAlpha(node: strongSelf.videoFadeNode, alpha: 0.0)
                                    }
                                    apperanceTransition.updateAlpha(node: strongSelf.avatarNode, alpha: 1.0)
                                    if let audioLevelView = strongSelf.audioLevelView {
                                        apperanceTransition.updateAlpha(layer: audioLevelView.layer, alpha: 1.0)
                                    }
                                } else {
                                    if !strongSelf.avatarNode.alpha.isZero {
                                        strongSelf.videoContainerNode.layer.animateScale(from: 0.001, to: videoContainerScale, duration: appearanceDuration)
                                        strongSelf.avatarNode.layer.animateScale(from: 1.0, to: 0.001, duration: appearanceDuration)
                                        strongSelf.audioLevelView?.layer.animateScale(from: 1.0, to: 0.001, duration: appearanceDuration)
                                        strongSelf.videoContainerNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -9.0), to: CGPoint(), duration: appearanceDuration, additive: true)
                                    }
                                    if videoNode.supernode === strongSelf.videoContainerNode {
                                        apperanceTransition.updateAlpha(node: videoNode, alpha: 1.0)
                                    }
                                    apperanceTransition.updateAlpha(node: strongSelf.videoFadeNode, alpha: 1.0)
                                    apperanceTransition.updateAlpha(node: strongSelf.avatarNode, alpha: 0.0)
                                    if let audioLevelView = strongSelf.audioLevelView {
                                        apperanceTransition.updateAlpha(layer: audioLevelView.layer, alpha: 0.0)
                                    }
                                }
                            } else {
                                if active {
                                    videoNode.alpha = 0.0
                                    if canUpdateAvatarVisibility {
                                        strongSelf.avatarNode.alpha = 1.0
                                    }
                                } else {
                                    videoNode.alpha = 1.0
                                    strongSelf.avatarNode.alpha = 0.0
                                }
                            }
                        }
                        
                        videoNode.updateLayout(size: videoSize, layoutMode: .fillOrFitToSquare, transition: .immediate)
                        if !strongSelf.isExtracted && !strongSelf.animatingExtraction {
                            if videoNode.supernode !== strongSelf.videoContainerNode {
                                videoNode.clipsToBounds = true
                                strongSelf.videoContainerNode.insertSubnode(videoNode, at: 0)
                            }
                            
                            videoNode.position = CGPoint(x: videoSize.width / 2.0, y: videoSize.height / 2.0)
                            videoNode.bounds = CGRect(origin: CGPoint(), size: videoSize)
                        }
                        
                        if let _ = currentItem, videoNodeUpdated {
                            if active {
                                if canUpdateAvatarVisibility {
                                    strongSelf.avatarNode.alpha = 1.0
                                }
                                videoNode.alpha = 0.0
                            } else {
                                strongSelf.animatingSelection = true
                                let previousAvatarNodeAlpha = strongSelf.avatarNode.alpha
                                strongSelf.avatarNode.alpha = 0.0
                                strongSelf.avatarNode.layer.animateAlpha(from: previousAvatarNodeAlpha, to: 0.0, duration: appearanceDuration)
                                videoNode.layer.animateScale(from: 0.01, to: 1.0, duration: appearanceDuration, completion: { [weak self] _ in
                                    self?.animatingSelection = false
                                })
                                videoNode.alpha = 1.0
                            }
                        } else {
                            if active {
                                if canUpdateAvatarVisibility {
                                    strongSelf.avatarNode.alpha = 1.0
                                }
                                videoNode.alpha = 0.0
                            } else {
                                strongSelf.avatarNode.alpha = 0.0
                                videoNode.alpha = 1.0
                            }
                        }
                    } else if canUpdateAvatarVisibility {
                        strongSelf.avatarNode.alpha = 1.0
                    }
                                        
                    strongSelf.iconNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.animationNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.raiseHandNode?.frame = CGRect(origin: CGPoint(), size: animationSize).insetBy(dx: -6.0, dy: -6.0).offsetBy(dx: -2.0, dy: 0.0)
                    
                    strongSelf.actionButtonNode.transform = CATransform3DMakeScale(animationScale, animationScale, 1.0)
                    transition.updateFrame(node: strongSelf.actionButtonNode, frame: animationFrame)
                                        
                    strongSelf.updateIsHighlighted(transition: transition)

                    if strongSelf.isCurrentlyInHierarchyDisposable == nil {
                        strongSelf.isCurrentlyInHierarchyDisposable = (item.context.sharedContext.applicationBindings.applicationInForeground
                        |> deliverOnMainQueue).start(next: { value in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.isCurrentlyInHierarchy = value
                        })
                    }
                }
            })
        }
    }
    
    var isHighlighted = false
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {

    }
    
    override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)
             
        self.isHighlighted = highlighted
            
        self.updateIsHighlighted(transition: (animated && !highlighted) ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
    
    override func headers() -> [ListViewItemHeader]? {
        return nil
    }
    
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
        
        self.updateIsEnabled()
    }
}
