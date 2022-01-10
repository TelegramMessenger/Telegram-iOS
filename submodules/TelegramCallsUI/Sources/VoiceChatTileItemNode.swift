import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TelegramPresentationData
import AvatarNode

private let backgroundCornerRadius: CGFloat = 11.0
private let borderLineWidth: CGFloat = 2.0

private let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)

final class VoiceChatTileItem: Equatable {
    enum Icon: Equatable {
        case none
        case microphone(Bool)
        case presentation
    }
    
    let account: Account
    let peer: Peer
    let videoEndpointId: String
    let videoReady: Bool
    let videoTimeouted: Bool
    let isVideoLimit: Bool
    let videoLimit: Int32
    let isPaused: Bool
    let isOwnScreencast: Bool
    let strings: PresentationStrings
    let nameDisplayOrder: PresentationPersonNameOrder
    let icon: Icon
    let text: VoiceChatParticipantItem.ParticipantText
    let additionalText: VoiceChatParticipantItem.ParticipantText?
    let speaking: Bool
    let secondary: Bool
    let isTablet: Bool
    let action: () -> Void
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    let getVideo: (GroupVideoNode.Position) -> GroupVideoNode?
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    
    var id: String {
        return self.videoEndpointId
    }
    
    init(account: Account, peer: Peer, videoEndpointId: String, videoReady: Bool, videoTimeouted: Bool, isVideoLimit: Bool, videoLimit: Int32, isPaused: Bool, isOwnScreencast: Bool, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, speaking: Bool, secondary: Bool, isTablet: Bool, icon: Icon, text: VoiceChatParticipantItem.ParticipantText, additionalText: VoiceChatParticipantItem.ParticipantText?, action:  @escaping () -> Void, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?, getVideo: @escaping (GroupVideoNode.Position) -> GroupVideoNode?, getAudioLevel: (() -> Signal<Float, NoError>)?) {
        self.account = account
        self.peer = peer
        self.videoEndpointId = videoEndpointId
        self.videoReady = videoReady
        self.videoTimeouted = videoTimeouted
        self.isVideoLimit = isVideoLimit
        self.videoLimit = videoLimit
        self.isPaused = isPaused
        self.isOwnScreencast = isOwnScreencast
        self.strings = strings
        self.nameDisplayOrder = nameDisplayOrder
        self.icon = icon
        self.text = text
        self.additionalText = additionalText
        self.speaking = speaking
        self.secondary = secondary
        self.isTablet = isTablet
        self.action = action
        self.contextAction = contextAction
        self.getVideo = getVideo
        self.getAudioLevel = getAudioLevel
    }
    
    static func == (lhs: VoiceChatTileItem, rhs: VoiceChatTileItem) -> Bool {
        if !arePeersEqual(lhs.peer, rhs.peer) {
            return false
        }
        if lhs.videoEndpointId != rhs.videoEndpointId {
            return false
        }
        if lhs.videoReady != rhs.videoReady {
            return false
        }
        if lhs.videoTimeouted != rhs.videoTimeouted {
            return false
        }
        if lhs.isPaused != rhs.isPaused {
            return false
        }
        if lhs.isOwnScreencast != rhs.isOwnScreencast {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.additionalText != rhs.additionalText {
            return false
        }
        if lhs.speaking != rhs.speaking {
            return false
        }
        if lhs.secondary != rhs.secondary {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        return true
    }
}

private let fadeColor = UIColor(rgb: 0x000000, alpha: 0.5)

var tileFadeImage: UIImage? = {
    return generateImage(CGSize(width: fadeHeight, height: fadeHeight), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let colorsArray = [fadeColor.withAlphaComponent(0.0).cgColor, fadeColor.cgColor] as CFArray
        var locations: [CGFloat] = [1.0, 0.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
    })
}()

final class VoiceChatTileItemNode: ASDisplayNode {
    private let context: AccountContext
  
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    let contentNode: ASDisplayNode
    let backgroundNode: ASDisplayNode
    var videoContainerNode: ASDisplayNode
    var videoNode: GroupVideoNode?
    let infoNode: ASDisplayNode
    let fadeNode: ASDisplayNode
    private var shimmerNode: VoiceChatTileShimmeringNode?
    private let titleNode: ImmediateTextNode
    private var iconNode: ASImageNode?
    private var animationNode: VoiceChatMicrophoneNode?
    var highlightNode: VoiceChatTileHighlightNode
    private let statusNode: VoiceChatParticipantStatusNode
    
    let placeholderTextNode: ImmediateTextNode
    let placeholderIconNode: ASImageNode
    
    private var profileNode: VoiceChatPeerProfileNode?
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private var validLayout: (CGSize, CGFloat)?
    var item: VoiceChatTileItem?
    private var isExtracted = false
    
    private let audioLevelDisposable = MetaDisposable()

    private let hierarchyTrackingNode: HierarchyTrackingNode
    private var isCurrentlyInHierarchy = false
    
    init(context: AccountContext) {
        self.context = context
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.contentNode = ASDisplayNode()
        self.contentNode.clipsToBounds = true
        self.contentNode.cornerRadius = backgroundCornerRadius

        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = panelBackgroundColor
        
        self.videoContainerNode = ASDisplayNode()
        self.videoContainerNode.clipsToBounds = true
        
        self.infoNode = ASDisplayNode()
        
        self.fadeNode = ASDisplayNode()
        self.fadeNode.displaysAsynchronously = false
        if let image = tileFadeImage {
            self.fadeNode.backgroundColor = UIColor(patternImage: image)
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        
        self.statusNode = VoiceChatParticipantStatusNode()
        
        self.highlightNode = VoiceChatTileHighlightNode()
        self.highlightNode.alpha = 0.0
        self.highlightNode.updateGlowAndGradientAnimations(type: .speaking)
        
        self.placeholderTextNode = ImmediateTextNode()
        self.placeholderTextNode.alpha = 0.0
        self.placeholderTextNode.maximumNumberOfLines = 2
        self.placeholderTextNode.textAlignment = .center
        
        self.placeholderIconNode = ASImageNode()
        self.placeholderIconNode.alpha = 0.0
        self.placeholderIconNode.contentMode = .scaleAspectFit
        self.placeholderIconNode.displaysAsynchronously = false
        
        var updateInHierarchy: ((Bool) -> Void)?
        self.hierarchyTrackingNode = HierarchyTrackingNode({ value in
            updateInHierarchy?(value)
        })

        super.init()

        self.addSubnode(self.hierarchyTrackingNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.backgroundNode)
        self.contentNode.addSubnode(self.videoContainerNode)
        self.contentNode.addSubnode(self.fadeNode)
        self.contentNode.addSubnode(self.infoNode)
        self.infoNode.addSubnode(self.titleNode)
        self.contentNode.addSubnode(self.placeholderTextNode)
        self.contentNode.addSubnode(self.placeholderIconNode)
        self.contentNode.addSubnode(self.highlightNode)
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let item = strongSelf.item, item.videoReady && !item.isVideoLimit else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let item = strongSelf.item, let contextAction = item.contextAction, !item.isVideoLimit else {
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

        updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                strongSelf.isCurrentlyInHierarchy = value
                strongSelf.highlightNode.isCurrentlyInHierarchy = value
            }
        }
    }
    
    deinit {
        self.audioLevelDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if #available(iOS 13.0, *) {
            self.contentNode.layer.cornerCurve = .continuous
        }
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tap)))
    }
    
    @objc private func tap() {
        if let item = self.item {
            item.action()
        }
    }
    
    private func updateIsExtracted(_ isExtracted: Bool, transition: ContainedViewLayoutTransition) {
        guard self.isExtracted != isExtracted, let extractedRect = self.extractedRect, let nonExtractedRect = self.nonExtractedRect, let item = self.item else {
            return
        }
        self.isExtracted = isExtracted
        
        let springDuration: Double = 0.42
        let springDamping: CGFloat = 124.0
        if isExtracted {
            let profileNode = VoiceChatPeerProfileNode(context: self.context, size: extractedRect.size, sourceSize: nonExtractedRect.size, peer: item.peer, text: item.text, customNode: self.videoContainerNode, additionalEntry: .single(nil), requestDismiss: { [weak self] in
                self?.contextSourceNode.requestDismiss?()
            })
            profileNode.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
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
            
            self.backgroundNode.isHidden = true
            self.fadeNode.isHidden = true
            self.infoNode.isHidden = true
            self.highlightNode.isHidden = true
        } else if let profileNode = self.profileNode {
            self.profileNode = nil
            
            self.infoNode.isHidden = false
            profileNode.animateOut(to: self, targetRect: nonExtractedRect, transition: transition, completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.backgroundNode.isHidden = false
                    strongSelf.fadeNode.isHidden = false
                    strongSelf.highlightNode.isHidden = false
                }
            })
            
            var appearenceTransition = transition
            if transition.isAnimated {
                appearenceTransition = .animated(duration: 0.2, curve: .easeInOut)
            }
            appearenceTransition.updateFrame(node: profileNode, frame: nonExtractedRect)
            
            self.contextSourceNode.contentNode.customHitTest = nil
        }
    }
    
    private var absoluteLocation: (CGRect, CGSize)?
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteLocation = (rect, containerSize)
        if let shimmerNode = self.shimmerNode {
            shimmerNode.updateAbsoluteRect(rect, within: containerSize)
        }
        self.updateIsEnabled()
    }
    
    var visibility = true {
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
            videoNode.updateIsEnabled(self.visibility && isVisibleInContainer)
        }
    }
    
    func update(size: CGSize, availableWidth: CGFloat, item: VoiceChatTileItem, transition: ContainedViewLayoutTransition) {
        guard self.validLayout?.0 != size || self.validLayout?.1 != availableWidth || self.item != item else {
            return
        }
        
        self.validLayout = (size, availableWidth)
        
        if !item.videoReady || item.isOwnScreencast {
            let shimmerNode: VoiceChatTileShimmeringNode
            let shimmerTransition: ContainedViewLayoutTransition
            if let current = self.shimmerNode {
                shimmerNode = current
                shimmerTransition = transition
            } else {
                shimmerNode = VoiceChatTileShimmeringNode(account: item.account, peer: item.peer)
                self.contentNode.insertSubnode(shimmerNode, aboveSubnode: self.fadeNode)
                self.shimmerNode = shimmerNode
                
                if let (rect, containerSize) = self.absoluteLocation {
                    shimmerNode.updateAbsoluteRect(rect, within: containerSize)
                }
                shimmerTransition = .immediate
            }
            shimmerTransition.updateFrame(node: shimmerNode, frame: CGRect(origin: CGPoint(), size: size))
            shimmerNode.update(shimmeringColor: UIColor.white, shimmering: !item.isOwnScreencast && !item.videoTimeouted && !item.isPaused, size: size, transition: shimmerTransition)
        } else if let shimmerNode = self.shimmerNode {
            self.shimmerNode = nil
            shimmerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak shimmerNode] _ in
                shimmerNode?.removeFromSupernode()
            })
        }
        
        var nodeToAnimateIn: ASDisplayNode?
        var placeholderAppeared = false
        
        var itemTransition = transition
        if self.item != item {
            let previousItem = self.item
            self.item = item
            
            if let getAudioLevel = item.getAudioLevel {
                self.audioLevelDisposable.set((getAudioLevel()
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.highlightNode.updateLevel(CGFloat(value))
                }))
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.25, curve: .easeInOut)
            transition.updateAlpha(node: self.highlightNode, alpha: item.speaking ? 1.0 : 0.0)
            
            if previousItem?.videoEndpointId != item.videoEndpointId || self.videoNode == nil {
                if let current = self.videoNode {
                    self.videoNode = nil
                    current.removeFromSupernode()
                }
                
                if let videoNode = item.getVideo(item.secondary ? .list : .tile) {
                    itemTransition = .immediate
                    self.videoNode = videoNode
                    self.videoContainerNode.addSubnode(videoNode)
                    self.updateIsEnabled()
                }
            }
            
            self.videoNode?.updateIsBlurred(isBlurred: item.isPaused, light: true)
            
            var showPlaceholder = false
            if item.isVideoLimit {
                self.placeholderTextNode.attributedText = NSAttributedString(string: item.strings.VoiceChat_VideoParticipantsLimitExceeded(String(item.videoLimit)).string, font: Font.semibold(13.0), textColor: .white)
                self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/VideoUnavailable"), color: .white)
                showPlaceholder = true
            } else if item.isOwnScreencast {
                self.placeholderTextNode.attributedText = NSAttributedString(string: item.strings.VoiceChat_YouAreSharingScreen, font: Font.semibold(13.0), textColor: .white)
                self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: item.isTablet ? "Call/ScreenShareTablet" : "Call/ScreenSharePhone"), color: .white)
                showPlaceholder = true
            } else if item.isPaused {
                self.placeholderTextNode.attributedText = NSAttributedString(string: item.strings.VoiceChat_VideoPaused, font: Font.semibold(13.0), textColor: .white)
                self.placeholderIconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/Pause"), color: .white)
                showPlaceholder = true
            }
            
            placeholderAppeared = self.placeholderTextNode.alpha.isZero && showPlaceholder
            transition.updateAlpha(node: self.placeholderTextNode, alpha: showPlaceholder ? 1.0 : 0.0)
            transition.updateAlpha(node: self.placeholderIconNode, alpha: showPlaceholder ? 1.0 : 0.0)
            
            let titleFont = Font.semibold(13.0)
            let titleColor = UIColor.white
            var titleAttributedString: NSAttributedString?
            if item.isVideoLimit {
                titleAttributedString = nil
            } else if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        switch item.nameDisplayOrder {
                            case .firstLast:
                                string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: lastName, font: titleFont, textColor: titleColor))
                            case .lastFirst:
                                string.append(NSAttributedString(string: lastName, font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                                string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                        }
                        titleAttributedString = string
                } else if let firstName = user.firstName, !firstName.isEmpty {
                    titleAttributedString = NSAttributedString(string: firstName, font: titleFont, textColor: titleColor)
                } else if let lastName = user.lastName, !lastName.isEmpty {
                    titleAttributedString = NSAttributedString(string: lastName, font: titleFont, textColor: titleColor)
                } else {
                    titleAttributedString = NSAttributedString(string: item.strings.User_DeletedAccount, font: titleFont, textColor: titleColor)
                }
            } else if let group = item.peer as? TelegramGroup {
                titleAttributedString = NSAttributedString(string: group.title, font: titleFont, textColor: titleColor)
            } else if let channel = item.peer as? TelegramChannel {
                titleAttributedString = NSAttributedString(string: channel.title, font: titleFont, textColor: titleColor)
            }
            
            var microphoneColor = UIColor.white
            if let additionalText = item.additionalText, case let .text(_, _, color) = additionalText {
                if case .destructive = color {
                    microphoneColor = destructiveColor
                }
            }
            self.titleNode.attributedText = titleAttributedString
            
            var hadMicrophoneNode = false
            var hadIconNode = false
            
            if case let .microphone(muted) = item.icon {
                let animationNode: VoiceChatMicrophoneNode
                if let current = self.animationNode {
                    animationNode = current
                } else {
                    animationNode = VoiceChatMicrophoneNode()
                    self.animationNode = animationNode
                    self.infoNode.addSubnode(animationNode)
                    
                    nodeToAnimateIn = animationNode
                }
                animationNode.alpha = 1.0
                animationNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, filled: true, color: microphoneColor), animated: true)
            } else if let animationNode = self.animationNode {
                hadMicrophoneNode = true
                self.animationNode = nil
                animationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                animationNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak animationNode] _ in
                    animationNode?.removeFromSupernode()
                })
            }
            
            if case .presentation = item.icon {
                let iconNode: ASImageNode
                if let current = self.iconNode {
                    iconNode = current
                } else {
                    iconNode = ASImageNode()
                    iconNode.displaysAsynchronously = false
                    iconNode.contentMode = .center
                    self.iconNode = iconNode
                    self.infoNode.addSubnode(iconNode)
                    
                    nodeToAnimateIn = iconNode
                }
                
                iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/StatusScreen"), color: .white)
            } else if let iconNode = self.iconNode {
                hadIconNode = true
                self.iconNode = nil
                iconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                iconNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak iconNode] _ in
                    iconNode?.removeFromSupernode()
                })
            }
            
            if let node = nodeToAnimateIn, hadMicrophoneNode || hadIconNode {
                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                node.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
            }
        }
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.containerNode.frame = bounds
        self.contextSourceNode.frame = bounds
        self.contextSourceNode.contentNode.frame = bounds
        
        transition.updateFrame(node: self.contentNode, frame: bounds)
        
        let extractedWidth = availableWidth
        let makeStatusLayout = self.statusNode.asyncLayout()
        let (statusLayout, _) = makeStatusLayout(CGSize(width: availableWidth - 30.0, height: CGFloat.greatestFiniteMagnitude), item.text, true)
                
        let extractedRect = CGRect(x: 0.0, y: 0.0, width: extractedWidth, height: extractedWidth + statusLayout.height + 39.0)
        let nonExtractedRect = bounds
        self.extractedRect = extractedRect
        self.nonExtractedRect = nonExtractedRect
        
        self.contextSourceNode.contentRect = extractedRect
        
        if self.videoContainerNode.supernode === self.contentNode {
            if let videoNode = self.videoNode {
                itemTransition.updateFrame(node: videoNode, frame: bounds)
                if videoNode.supernode === self.videoContainerNode {
                    videoNode.updateLayout(size: size, layoutMode: .fillOrFitToSquare, transition: itemTransition)
                }
            }
            transition.updateFrame(node: self.videoContainerNode, frame: bounds)
        }
        
        transition.updateFrame(node: self.backgroundNode, frame: bounds)
        transition.updateFrame(node: self.highlightNode, frame: bounds)
        self.highlightNode.updateLayout(size: bounds.size, transition: transition)
        transition.updateFrame(node: self.infoNode, frame: bounds)
        transition.updateFrame(node: self.fadeNode, frame: CGRect(x: 0.0, y: size.height - fadeHeight, width: size.width, height: fadeHeight))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - 50.0, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: 30.0, y: size.height - titleSize.height - 8.0), size: titleSize)
        
        var transition = transition
        if nodeToAnimateIn != nil || placeholderAppeared {
            transition = .immediate
        }
        
        if let iconNode = self.iconNode, let image = iconNode.image {
            transition.updateFrame(node: iconNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels(16.0 - image.size.width / 2.0), y: floorToScreenPixels(size.height - 15.0 - image.size.height / 2.0)), size: image.size))
        }
        
        if let animationNode = self.animationNode {
            let animationSize = CGSize(width: 36.0, height: 36.0)
            animationNode.bounds = CGRect(origin: CGPoint(), size: animationSize)
            animationNode.transform = CATransform3DMakeScale(0.66667, 0.66667, 1.0)
            transition.updatePosition(node: animationNode, position: CGPoint(x: 16.0, y: size.height - 15.0))
        }
        
        let placeholderTextSize = self.placeholderTextNode.updateLayout(CGSize(width: size.width - 30.0, height: 100.0))
        transition.updateFrame(node: self.placeholderTextNode, frame: CGRect(origin: CGPoint(x: floor((size.width - placeholderTextSize.width) / 2.0), y: floorToScreenPixels(size.height / 2.0) + 10.0), size: placeholderTextSize))
        if let image = self.placeholderIconNode.image {
            let imageScale: CGFloat = item.isVideoLimit ? 1.0 : 0.5
            let imageSize = CGSize(width: image.size.width * imageScale, height: image.size.height * imageScale)
            transition.updateFrame(node: self.placeholderIconNode, frame: CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: floorToScreenPixels(size.height / 2.0) - imageSize.height - 4.0), size: imageSize))
        }
    }
    
    func transitionIn(from sourceNode: ASDisplayNode?) {
        guard let item = self.item else {
            return
        }
        var videoNode: GroupVideoNode?
        if let sourceNode = sourceNode as? VoiceChatFullscreenParticipantItemNode, let _ = sourceNode.item {
            if let sourceVideoNode = sourceNode.videoNode {
                sourceNode.videoNode = nil
                videoNode = sourceVideoNode
            }
        }
        
        if videoNode == nil {
            videoNode = item.getVideo(item.secondary ? .list : .tile)
        }
        
        if let videoNode = videoNode {
            videoNode.alpha = 1.0
            self.videoNode = videoNode
            self.videoContainerNode.addSubnode(videoNode)
            
            videoNode.updateLayout(size: self.bounds.size, layoutMode: .fillOrFitToSquare, transition: .immediate)
            videoNode.frame = self.bounds
            
            self.updateIsEnabled()
        }
    }
}

private let blue = UIColor(rgb: 0x007fff)
private let lightBlue = UIColor(rgb: 0x00affe)
private let green = UIColor(rgb: 0x33c659)
private let activeBlue = UIColor(rgb: 0x00a0b9)
private let purple = UIColor(rgb: 0x3252ef)
private let pink = UIColor(rgb: 0xef436c)

class VoiceChatTileHighlightNode: ASDisplayNode {
    enum Gradient {
        case speaking
        case active
        case mutedForYou
        case muted
    }
    
    private var maskView: UIView?
    private let maskLayer = CALayer()
    
    private let foregroundGradientLayer = CAGradientLayer()

    var isCurrentlyInHierarchy = false {
        didSet {
            if self.isCurrentlyInHierarchy != oldValue && self.isCurrentlyInHierarchy {
                self.updateAnimations()
            }
        }
    }
    
    private var audioLevel: CGFloat = 0.0
    private var presentationAudioLevel: CGFloat = 0.0
    
    private var displayLinkAnimator: ConstantDisplayLinkAnimator?
    
    override init() {
        self.foregroundGradientLayer.type = .radial
        self.foregroundGradientLayer.colors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
        self.foregroundGradientLayer.locations = [0.0, 0.85, 1.0]
        self.foregroundGradientLayer.startPoint = CGPoint(x: 1.0, y: 0.0)
        self.foregroundGradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        
        super.init()
        
        self.displayLinkAnimator = ConstantDisplayLinkAnimator() { [weak self] in
            guard let strongSelf = self else { return }
            
            strongSelf.presentationAudioLevel = strongSelf.presentationAudioLevel * 0.9 + strongSelf.audioLevel * 0.1
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.layer.addSublayer(self.foregroundGradientLayer)
        
        let maskView = UIView()
        maskView.layer.addSublayer(self.maskLayer)
        self.maskView = maskView
        
        self.maskLayer.masksToBounds = true
        self.maskLayer.cornerRadius = backgroundCornerRadius - UIScreenPixel
        self.maskLayer.borderColor = UIColor.white.cgColor
        self.maskLayer.borderWidth = borderLineWidth
                
        self.view.mask = self.maskView
    }
    
    func updateAnimations() {
        if !self.isCurrentlyInHierarchy {
            self.foregroundGradientLayer.removeAllAnimations()
            return
        }
        self.setupGradientAnimations()
    }
    
    func updateLevel(_ level: CGFloat) {
        self.audioLevel = level
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        if let maskView = self.maskView {
            transition.updateFrame(view: maskView, frame: bounds)
        }
        transition.updateFrame(layer: self.maskLayer, frame: bounds)
        transition.updateFrame(layer: self.foregroundGradientLayer, frame: bounds)
    }
    
    private func setupGradientAnimations() {
        if let _ = self.foregroundGradientLayer.animation(forKey: "movement") {
        } else {
            let previousValue = self.foregroundGradientLayer.startPoint
            let newValue: CGPoint
            if self.presentationAudioLevel > 0.22 {
                newValue = CGPoint(x: CGFloat.random(in: 0.9 ..< 1.0), y: CGFloat.random(in: 0.15 ..< 0.35))
            } else if self.presentationAudioLevel > 0.01 {
                newValue = CGPoint(x: CGFloat.random(in: 0.57 ..< 0.85), y: CGFloat.random(in: 0.15 ..< 0.45))
            } else {
                newValue = CGPoint(x: CGFloat.random(in: 0.6 ..< 0.75), y: CGFloat.random(in: 0.25 ..< 0.45))
            }
            self.foregroundGradientLayer.startPoint = newValue
            
            CATransaction.begin()
            
            let animation = CABasicAnimation(keyPath: "startPoint")
            animation.duration = Double.random(in: 0.8 ..< 1.4)
            animation.fromValue = previousValue
            animation.toValue = newValue
            
            CATransaction.setCompletionBlock { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if strongSelf.isCurrentlyInHierarchy {
                    strongSelf.setupGradientAnimations()
                }
            }
            
            self.foregroundGradientLayer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }
    
    private var gradient: Gradient?
    func updateGlowAndGradientAnimations(type: Gradient, animated: Bool = true) {
        guard self.gradient != type else {
            return
        }
        self.gradient = type
        let initialColors = self.foregroundGradientLayer.colors
        let targetColors: [CGColor]
        switch type {
            case .speaking:
                targetColors = [activeBlue.cgColor, green.cgColor, green.cgColor]
            case .active:
                targetColors = [lightBlue.cgColor, blue.cgColor, blue.cgColor]
            case .mutedForYou:
                targetColors = [pink.cgColor, destructiveColor.cgColor, destructiveColor.cgColor]
            case .muted:
                targetColors = [pink.cgColor, purple.cgColor, purple.cgColor]
        }
        self.foregroundGradientLayer.colors = targetColors
        if animated {
            self.foregroundGradientLayer.animate(from: initialColors as AnyObject, to: targetColors as AnyObject, keyPath: "colors", timingFunction: CAMediaTimingFunctionName.linear.rawValue, duration: 0.3)
        }
        self.updateAnimations()
    }
}

final class ShimmerEffectForegroundNode: ASDisplayNode {
    private var currentForegroundColor: UIColor?
    private let imageNodeContainer: ASDisplayNode
    private let imageNode: ASDisplayNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    private let size: CGFloat
    
    init(size: CGFloat) {
        self.size = size
        
        self.imageNodeContainer = ASDisplayNode()
        self.imageNodeContainer.isLayerBacked = true
        
        self.imageNode = ASDisplayNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        
        super.init()
        
        self.isLayerBacked = true
        self.clipsToBounds = true
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.addSubnode(self.imageNodeContainer)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(foregroundColor: UIColor) {
        if let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor) {
            return
        }
        self.currentForegroundColor = foregroundColor
        
        let image = generateImage(CGSize(width: self.size, height: 16.0), opaque: false, scale: 1.0, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        })
        if let image = image {
            self.imageNode.backgroundColor = UIColor(patternImage: image)
        }
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            } else {
                self.updateAnimation()
            }
        }
        
        if frameUpdated {
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = self.size
        self.imageNode.frame = CGRect(origin: CGPoint(x: -gradientHeight, y: 0.0), size: CGSize(width: gradientHeight, height: containerSize.height))
        let animation = self.imageNode.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.width + gradientHeight) as NSNumber, keyPath: "position.x", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageNode.layer.add(animation, forKey: "shimmer")
    }
}

private class VoiceChatTileShimmeringNode: ASDisplayNode {
    private let backgroundNode: ImageNode
    private let effectNode: ShimmerEffectForegroundNode
    
    private let borderNode: ASDisplayNode
    private var borderMaskView: UIView?
    private let borderEffectNode: ShimmerEffectForegroundNode
    
    private var currentShimmeringColor: UIColor?
    private var currentShimmering: Bool?
    private var currentSize: CGSize?
    
    public init(account: Account, peer: Peer) {
        self.backgroundNode = ImageNode(enableHasImage: false, enableEmpty: false, enableAnimatedTransition: true)
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.contentMode = .scaleAspectFill
        
        self.effectNode = ShimmerEffectForegroundNode(size: 240.0)
        
        self.borderNode = ASDisplayNode()
        self.borderEffectNode = ShimmerEffectForegroundNode(size: 320.0)
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = backgroundCornerRadius
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.effectNode)
        self.addSubnode(self.borderNode)
        self.borderNode.addSubnode(self.borderEffectNode)
        
        self.backgroundNode.setSignal(peerAvatarCompleteImage(account: account, peer: EnginePeer(peer), size: CGSize(width: 250.0, height: 250.0), round: false, font: Font.regular(16.0), drawLetters: false, fullSize: false, blurred: true))
    }
    
    public override func didLoad() {
        super.didLoad()
        
        if self.effectNode.supernode != nil {
            self.effectNode.layer.compositingFilter = "screenBlendMode"
            self.borderEffectNode.layer.compositingFilter = "screenBlendMode"
            
            let borderMaskView = UIView()
            borderMaskView.layer.borderWidth = 1.0
            borderMaskView.layer.borderColor = UIColor.white.cgColor
            borderMaskView.layer.cornerRadius = backgroundCornerRadius
            self.borderMaskView = borderMaskView
            
            if let size = self.currentSize {
                borderMaskView.frame = CGRect(origin: CGPoint(), size: size)
            }
            self.borderNode.view.mask = borderMaskView
            
            if #available(iOS 13.0, *) {
                borderMaskView.layer.cornerCurve = .continuous
            }
        }
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
    }
    
    public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.effectNode.updateAbsoluteRect(rect, within: containerSize)
        self.borderEffectNode.updateAbsoluteRect(rect, within: containerSize)
    }
    
    public func update(shimmeringColor: UIColor, shimmering: Bool, size: CGSize, transition: ContainedViewLayoutTransition) {
        if let currentShimmeringColor = self.currentShimmeringColor, currentShimmeringColor.isEqual(shimmeringColor) && self.currentSize == size && self.currentShimmering == shimmering {
            return
        }
        
        let firstTime = self.currentShimmering == nil
        self.currentShimmeringColor = shimmeringColor
        self.currentShimmering = shimmering
        self.currentSize = size
        
        let transition: ContainedViewLayoutTransition = firstTime ? .immediate : (transition.isAnimated ? transition : .animated(duration: 0.45, curve: .easeInOut))
        transition.updateAlpha(node: self.effectNode, alpha: shimmering ? 1.0 : 0.0)
        transition.updateAlpha(node: self.borderNode, alpha: shimmering ? 1.0 : 0.0)
        
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        self.effectNode.update(foregroundColor: shimmeringColor.withAlphaComponent(0.3))
        transition.updateFrame(node: self.effectNode, frame: bounds)
        
        self.borderEffectNode.update(foregroundColor: shimmeringColor.withAlphaComponent(0.45))
        transition.updateFrame(node: self.borderEffectNode, frame: bounds)
        
        transition.updateFrame(node: self.backgroundNode, frame: bounds)
        transition.updateFrame(node: self.borderNode, frame: bounds)
        if let borderMaskView = self.borderMaskView {
            transition.updateFrame(view: borderMaskView, frame: bounds)
        }
    }
}
