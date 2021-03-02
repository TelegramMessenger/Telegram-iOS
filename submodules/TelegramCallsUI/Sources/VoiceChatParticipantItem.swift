import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
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

final class VoiceChatParticipantItem: ListViewItem {
    enum ParticipantText {
        public enum TextColor {
            case generic
            case accent
            case constructive
            case destructive
        }
        
        case presence
        case text(String, TextColor)
        case none
    }
    
    enum Icon {
        case none
        case microphone(Bool, UIColor)
        case invite(Bool)
    }
    
    struct RevealOption {
        enum RevealOptionType {
            case neutral
            case warning
            case destructive
            case accent
        }
        
        var type: RevealOptionType
        var title: String
        var action: () -> Void
        
        init(type: RevealOptionType, title: String, action: @escaping () -> Void) {
            self.type = type
            self.title = title
            self.action = action
        }
    }

    let presentationData: ItemListPresentationData
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let context: AccountContext
    let peer: Peer
    let ssrc: UInt32?
    let presence: PeerPresence?
    let text: ParticipantText
    let icon: Icon
    let enabled: Bool
    public let selectable: Bool
    let getAudioLevel: (() -> Signal<Float, NoError>)?
    let getVideo: () -> GroupVideoNode?
    let revealOptions: [RevealOption]
    let revealed: Bool?
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let action: ((ASDisplayNode) -> Void)?
    let contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    public init(presentationData: ItemListPresentationData, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, context: AccountContext, peer: Peer, ssrc: UInt32?, presence: PeerPresence?, text: ParticipantText, icon: Icon, enabled: Bool, selectable: Bool, getAudioLevel: (() -> Signal<Float, NoError>)?, getVideo: @escaping () -> GroupVideoNode?, revealOptions: [RevealOption], revealed: Bool?, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, action: ((ASDisplayNode) -> Void)?, contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? = nil) {
        self.presentationData = presentationData
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.context = context
        self.peer = peer
        self.ssrc = ssrc
        self.presence = presence
        self.text = text
        self.icon = icon
        self.enabled = enabled
        self.selectable = selectable
        self.getAudioLevel = getAudioLevel
        self.getVideo = getVideo
        self.revealOptions = revealOptions
        self.revealed = revealed
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.action = action
        self.contextAction = contextAction
    }
        
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = VoiceChatParticipantItemNode()
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
            if let nodeValue = node() as? VoiceChatParticipantItemNode {
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

private let avatarFont = avatarPlaceholderFont(size: floor(40.0 * 16.0 / 37.0))

class VoiceChatParticipantItemNode: ItemListRevealOptionsItemNode {
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private var disabledOverlayNode: ASDisplayNode?
    
    let contextSourceNode: ContextExtractedContentContainingNode
    private let containerNode: ContextControllerSourceNode
    private let extractedBackgroundImageNode: ASImageNode
    private let offsetContainerNode: ASDisplayNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
        
    fileprivate let avatarNode: AvatarNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    
    private let actionContainerNode: ASDisplayNode
    private var animationNode: VoiceChatMicrophoneNode?
    private var iconNode: ASImageNode?
    private var actionButtonNode: HighlightableButtonNode
    
    private var audioLevelView: VoiceBlobView?
    private let audioLevelDisposable = MetaDisposable()
    private var didSetupAudioLevel = false
    
    private var absoluteLocation: (CGRect, CGSize)?
    
    private var peerPresenceManager: PeerPresenceStatusManager?
    private var layoutParams: (VoiceChatParticipantItem, ListViewItemLayoutParams, Bool, Bool)?
    private var wavesColor: UIColor?
    
    private var videoNode: GroupVideoNode?
    
    var item: VoiceChatParticipantItem? {
        return self.layoutParams?.0
    }
    
    init() {
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true
        
        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true
        
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.offsetContainerNode = ASDisplayNode()
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale
        
        self.statusNode = TextNode()
        self.statusNode.isUserInteractionEnabled = false
        self.statusNode.contentMode = .left
        self.statusNode.contentsScale = UIScreen.main.scale
        
        self.actionContainerNode = ASDisplayNode()
        self.actionButtonNode = HighlightableButtonNode()
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.isAccessibilityElement = true
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        self.contextSourceNode.contentNode.addSubnode(self.offsetContainerNode)
        self.offsetContainerNode.addSubnode(self.avatarNode)
        self.offsetContainerNode.addSubnode(self.titleNode)
        self.offsetContainerNode.addSubnode(self.statusNode)
        self.offsetContainerNode.addSubnode(self.actionContainerNode)
        self.actionContainerNode.addSubnode(self.actionButtonNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        
        self.actionButtonNode.addTarget(self, action: #selector(self.actionButtonPressed), forControlEvents: .touchUpInside)
        
        self.peerPresenceManager = PeerPresenceStatusManager(update: { [weak self] in
            if let strongSelf = self, let layoutParams = strongSelf.layoutParams {
                let (_, apply) = strongSelf.asyncLayout()(layoutParams.0, layoutParams.1, layoutParams.2, layoutParams.3)
                apply(false, true)
            }
        })
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self else {
                return false
            }
            if strongSelf.actionButtonNode.frame.contains(location) {
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
            guard let strongSelf = self, let item = strongSelf.layoutParams?.0 else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: item.presentationData.theme.list.itemBlocksBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateAlpha(node: strongSelf.actionContainerNode, alpha: isExtracted ? 0.0 : 1.0)
            
            transition.updateSublayerTransformOffset(layer: strongSelf.offsetContainerNode.layer, offset: CGPoint(x: isExtracted ? 12.0 : 0.0, y: 0.0))
           
            transition.updateSublayerTransformOffset(layer: strongSelf.actionContainerNode.layer, offset: CGPoint(x: isExtracted ? -24.0 : 0.0, y: 0.0))
            
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    deinit {
        self.audioLevelDisposable.dispose()
    }
    
    override func selected() {
        super.selected()
        self.layoutParams?.0.action?(self.contextSourceNode)
    }
        
    func asyncLayout() -> (_ item: VoiceChatParticipantItem, _ params: ListViewItemLayoutParams, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, (Bool, Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        var currentDisabledOverlayNode = self.disabledOverlayNode
        
        let currentItem = self.layoutParams?.0
        
        return { item, params, first, last in
            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }
            
            let statusFontSize: CGFloat = floor(item.presentationData.fontSize.itemListBaseFontSize * 14.0 / 17.0)
            
            let titleFont = Font.regular(17.0)
            let statusFont = Font.regular(14.0)
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            let rightInset: CGFloat = params.rightInset
        
            let titleColor = item.presentationData.theme.list.itemPrimaryTextColor
            let currentBoldFont: UIFont = titleFont
            
            if let user = item.peer as? TelegramUser {
                if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                    let string = NSMutableAttributedString()
                    switch item.nameDisplayOrder {
                    case .firstLast:
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                    case .lastFirst:
                        string.append(NSAttributedString(string: lastName, font: currentBoldFont, textColor: titleColor))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: titleColor))
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: titleColor))
                    }
                    titleAttributedString = string
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
            switch item.text {
            case .presence:
                if let user = item.peer as? TelegramUser, let botInfo = user.botInfo {
                    let botStatus: String
                    if botInfo.flags.contains(.hasAccessToChatHistory) {
                        botStatus = item.presentationData.strings.Bot_GroupStatusReadsHistory
                    } else {
                        botStatus = item.presentationData.strings.Bot_GroupStatusDoesNotReadHistory
                    }
                    statusAttributedString = NSAttributedString(string: botStatus, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                } else if let presence = item.presence as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    let (string, _) = stringAndActivityForUserPresence(strings: item.presentationData.strings, dateTimeFormat: item.dateTimeFormat, presence: presence, relativeTo: Int32(timestamp))
                    statusAttributedString = NSAttributedString(string: string, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                } else {
                    statusAttributedString = NSAttributedString(string: item.presentationData.strings.LastSeen_Offline, font: statusFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor)
                }
            case let .text(text, textColor):
                let textColorValue: UIColor
                switch textColor {
                case .generic:
                    textColorValue = item.presentationData.theme.list.itemSecondaryTextColor
                case .accent:
                    textColorValue = item.presentationData.theme.list.itemAccentColor
                    wavesColor = textColorValue
                case .constructive:
                    textColorValue = UIColor(rgb: 0x34c759)
                case .destructive:
                    textColorValue = UIColor(rgb: 0xff3b30)
                    wavesColor = textColorValue
                }
                statusAttributedString = NSAttributedString(string: text, font: statusFont, textColor: textColorValue)
            case .none:
                break
            }

            let leftInset: CGFloat = 65.0 + params.leftInset
            let verticalInset: CGFloat = 8.0
            let verticalOffset: CGFloat = 0.0
            let avatarSize: CGFloat = 40.0
                              
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: titleAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 12.0 - rightInset - 30.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            let (statusLayout, statusApply) = makeStatusLayout(TextNodeLayoutArguments(attributedString: statusAttributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: params.width - leftInset - 8.0 - rightInset - 30.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let insets = UIEdgeInsets()
    
            let titleSpacing: CGFloat = statusLayout.size.height == 0.0 ? 0.0 : 1.0
            
            let minHeight: CGFloat = titleLayout.size.height + verticalInset * 2.0
            let rawHeight: CGFloat = verticalInset * 2.0 + titleLayout.size.height + titleSpacing + statusLayout.size.height
            
            let contentSize = CGSize(width: params.width, height: max(minHeight, rawHeight))
            let separatorHeight = UIScreenPixel
            
            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)
            let layoutSize = layout.size
            
            if !item.enabled {
                if currentDisabledOverlayNode == nil {
                    currentDisabledOverlayNode = ASDisplayNode()
                    currentDisabledOverlayNode?.backgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.5)
                }
            } else {
                currentDisabledOverlayNode = nil
            }
            
            var animateStatusTransitionFromUp: Bool?
            if let currentItem = currentItem {
                if case .presence = currentItem.text, case let .text(_, newColor) = item.text {
                    animateStatusTransitionFromUp = newColor == .constructive
                } else if case let .text(_, currentColor) = currentItem.text, case let .text(_, newColor) = item.text, currentColor != newColor {
                    animateStatusTransitionFromUp = newColor == .constructive
                } else if case .text = currentItem.text, case .presence = item.text {
                    animateStatusTransitionFromUp = false
                }
            }
            
            let peerRevealOptions: [ItemListRevealOption]
            var mappedOptions: [ItemListRevealOption] = []
            var index: Int32 = 0
            for option in item.revealOptions {
                let color: UIColor
                let textColor: UIColor
                switch option.type {
                    case .neutral:
                        color = item.presentationData.theme.list.itemDisclosureActions.constructive.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.constructive.foregroundColor
                    case .warning:
                        color = item.presentationData.theme.list.itemDisclosureActions.warning.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.warning.foregroundColor
                    case .destructive:
                        color = item.presentationData.theme.list.itemDisclosureActions.destructive.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.destructive.foregroundColor
                    case .accent:
                        color = item.presentationData.theme.list.itemDisclosureActions.accent.fillColor
                        textColor = item.presentationData.theme.list.itemDisclosureActions.accent.foregroundColor
                }
                mappedOptions.append(ItemListRevealOption(key: index, title: option.title, icon: .none, color: color, textColor: textColor))
                index += 1
            }
            peerRevealOptions = mappedOptions
            
            return (layout, { [weak self] synchronousLoad, animated in
                if let strongSelf = self {
                    strongSelf.layoutParams = (item, params, first, last)
                    strongSelf.wavesColor = wavesColor
                    
                    let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width - 16.0, height: layout.contentSize.height))
                    let extractedRect = CGRect(origin: CGPoint(), size: layout.contentSize).insetBy(dx: 16.0 + params.leftInset, dy: 0.0)
                    strongSelf.extractedRect = extractedRect
                    strongSelf.nonExtractedRect = nonExtractedRect
                    
                    if strongSelf.contextSourceNode.isExtractedToContextPreview {
                        strongSelf.extractedBackgroundImageNode.frame = extractedRect
                    } else {
                        strongSelf.extractedBackgroundImageNode.frame = nonExtractedRect
                    }
                    strongSelf.contextSourceNode.contentRect = extractedRect
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.offsetContainerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.contextSourceNode.contentNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    strongSelf.containerNode.isGestureEnabled = item.contextAction != nil
                    strongSelf.actionContainerNode.frame = CGRect(origin: CGPoint(), size: layout.contentSize)
                    
                    strongSelf.accessibilityLabel = titleAttributedString?.string
                    var combinedValueString = ""
                    if let statusString = statusAttributedString?.string, !statusString.isEmpty {
                        combinedValueString.append(statusString)
                    }
                    
                    strongSelf.accessibilityValue = combinedValueString
                    
                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
                        strongSelf.bottomStripeNode.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.08)
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                    }
                                        
                    let transition: ContainedViewLayoutTransition
                    if animated {
                        transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
                    } else {
                        transition = .immediate
                    }
                    
                    if let currentDisabledOverlayNode = currentDisabledOverlayNode {
                        if currentDisabledOverlayNode != strongSelf.disabledOverlayNode {
                            strongSelf.disabledOverlayNode = currentDisabledOverlayNode
                            strongSelf.addSubnode(currentDisabledOverlayNode)
                            currentDisabledOverlayNode.alpha = 0.0
                            transition.updateAlpha(node: currentDisabledOverlayNode, alpha: 1.0)
                            currentDisabledOverlayNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight))
                        } else {
                            transition.updateFrame(node: currentDisabledOverlayNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.contentSize.width, height: layout.contentSize.height - separatorHeight)))
                        }
                    } else if let disabledOverlayNode = strongSelf.disabledOverlayNode {
                        transition.updateAlpha(node: disabledOverlayNode, alpha: 0.0, completion: { [weak disabledOverlayNode] _ in
                            disabledOverlayNode?.removeFromSupernode()
                        })
                        strongSelf.disabledOverlayNode = nil
                    }
                    
                    if let animateStatusTransitionFromUp = animateStatusTransitionFromUp {
                        let offset: CGFloat = animateStatusTransitionFromUp ? -7.0 : 7.0
                        if let snapshotView = strongSelf.statusNode.view.snapshotContentTree() {
                            strongSelf.statusNode.view.superview?.insertSubview(snapshotView, belowSubview: strongSelf.statusNode.view)

                            snapshotView.frame = strongSelf.statusNode.frame
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                            snapshotView.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -offset), duration: 0.2, removeOnCompletion: false, additive: true)
                            
                            strongSelf.statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            strongSelf.statusNode.layer.animatePosition(from: CGPoint(x: 0.0, y: offset), to: CGPoint(), duration: 0.2, additive: true)
                        }
                    }
                    
                    let _ = titleApply()
                    let _ = statusApply()
                                        
                    if strongSelf.topStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.topStripeNode, at: 0)
                    }
                    if strongSelf.bottomStripeNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 1)
                    }

                    strongSelf.topStripeNode.isHidden = first
                    strongSelf.bottomStripeNode.isHidden = last
                
                    transition.updateFrame(node: strongSelf.topStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: -min(insets.top, separatorHeight)), size: CGSize(width: layoutSize.width, height: separatorHeight)))
                    transition.updateFrame(node: strongSelf.bottomStripeNode, frame: CGRect(origin: CGPoint(x: leftInset, y: contentSize.height + -separatorHeight), size: CGSize(width: layoutSize.width - leftInset, height: separatorHeight)))
                    
                    transition.updateFrame(node: strongSelf.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: verticalInset + verticalOffset), size: titleLayout.size))
                    transition.updateFrame(node: strongSelf.statusNode, frame: CGRect(origin: CGPoint(x: leftInset, y: strongSelf.titleNode.frame.maxY + titleSpacing), size: statusLayout.size))
                    
                    let avatarFrame = CGRect(origin: CGPoint(x: params.leftInset + 15.0, y: floorToScreenPixels((layout.contentSize.height - avatarSize) / 2.0)), size: CGSize(width: avatarSize, height: avatarSize))
                    transition.updateFrameAsPositionAndBounds(node: strongSelf.avatarNode, frame: avatarFrame)
                    
                    let blobFrame = avatarFrame.insetBy(dx: -14.0, dy: -14.0)
                    if let getAudioLevel = item.getAudioLevel {
                        if !strongSelf.didSetupAudioLevel || currentItem?.peer.id != item.peer.id {
                            strongSelf.audioLevelView?.frame = blobFrame
                            strongSelf.didSetupAudioLevel = true
                            strongSelf.audioLevelDisposable.set((getAudioLevel()
                            |> deliverOnMainQueue).start(next: { value in
                                guard let strongSelf = self else {
                                    return
                                }
                                
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
                                    maskPath.append(UIBezierPath(roundedRect: maskRect.insetBy(dx: 14, dy: 14), cornerRadius: 22))
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
                                    
                                    let avatarScale: CGFloat
                                    if value > 0.0 {
                                        audioLevelView.startAnimating()
                                        avatarScale = 1.03 + level * 0.13
                                        if let wavesColor = strongSelf.wavesColor {
                                            audioLevelView.setColor(wavesColor, animated: true)
                                        }
                                    } else {
                                        audioLevelView.stopAnimating(duration: 0.5)
                                        avatarScale = 1.0
                                    }
                                    
                                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.15, curve: .easeInOut)
                                    transition.updateTransformScale(node: strongSelf.avatarNode, scale: avatarScale, beginWithCurrentState: true)
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
                    strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme, peer: item.peer, overrideImage: overrideImage, emptyColor: item.presentationData.theme.list.mediaPlaceholderColor, synchronousLoad: synchronousLoad)
                
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                    
                    if case let .microphone(muted, color) = item.icon {
                        let animationNode: VoiceChatMicrophoneNode
                        if let current = strongSelf.animationNode {
                            animationNode = current
                        } else {
                            animationNode = VoiceChatMicrophoneNode()
                            strongSelf.animationNode = animationNode
                            strongSelf.actionButtonNode.addSubnode(animationNode)
                            if let _ = strongSelf.iconNode {
                                animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                animationNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                            }
                        }
                        animationNode.update(state: VoiceChatMicrophoneNode.State(muted: muted, color: color), animated: true)
                        strongSelf.actionButtonNode.isUserInteractionEnabled = item.contextAction != nil
                    } else if let animationNode = strongSelf.animationNode {
                        strongSelf.animationNode = nil
                        animationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        animationNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak animationNode] _ in
                            animationNode?.removeFromSupernode()
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
                            
                            if let _ = strongSelf.animationNode {
                                iconNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                iconNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.2)
                            }
                        }
                        
                        if invited {
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Invited"), color: UIColor(rgb: 0x979797))
                        } else {
                            iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: item.presentationData.theme.list.itemAccentColor)
                        }
                        strongSelf.actionButtonNode.isUserInteractionEnabled = false
                    } else if let iconNode = strongSelf.iconNode {
                        strongSelf.iconNode = nil
                        iconNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                        iconNode.layer.animateScale(from: 1.0, to: 0.001, duration: 0.2, removeOnCompletion: false, completion: { [weak iconNode] _ in
                            iconNode?.removeFromSupernode()
                        })
                    }
                    
                    let videoSize = CGSize(width: avatarSize, height: avatarSize)
                    
                    let videoNode = item.getVideo()
                    if let current = strongSelf.videoNode, current !== videoNode {
                        current.removeFromSupernode()
                    }
                    let actionOffset: CGFloat = 0.0
                    strongSelf.videoNode = videoNode
                    if let videoNode = videoNode {
                        
                        videoNode.updateLayout(size: videoSize, transition: .immediate)
                        if videoNode.supernode !== strongSelf.avatarNode {
                            videoNode.clipsToBounds = true
                            videoNode.cornerRadius = avatarSize / 2.0
                            strongSelf.avatarNode.addSubnode(videoNode)
                        }
                        
                        videoNode.frame = CGRect(origin: CGPoint(), size: videoSize)
                    }
                    
                    let animationSize = CGSize(width: 36.0, height: 36.0)
                    strongSelf.iconNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    strongSelf.animationNode?.frame = CGRect(origin: CGPoint(), size: animationSize)
                    
                    strongSelf.actionButtonNode.frame = CGRect(x: params.width - animationSize.width - 6.0 - params.rightInset + actionOffset, y: floor((layout.contentSize.height - animationSize.height) / 2.0) + 1.0, width: animationSize.width, height: animationSize.height)
                    
                    if let presence = item.presence as? TelegramUserPresence {
                        strongSelf.peerPresenceManager?.reset(presence: presence)
                    }
                    
                    strongSelf.updateIsHighlighted(transition: transition)
                    
                    strongSelf.setRevealOptions((left: [], right: peerRevealOptions))
                    strongSelf.setRevealOptionsOpened(item.revealed ?? false, animated: animated)
                }
            })
        }
    }
    
    var isHighlighted = false
    func updateIsHighlighted(transition: ContainedViewLayoutTransition) {
        if self.isHighlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if transition.isAnimated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                            }
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
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
    
    override func header() -> ListViewItemHeader? {
        return nil
    }
    
    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        var rect = rect
        rect.origin.y += self.insets.top
        self.absoluteLocation = (rect, containerSize)
    }
    
    @objc private func actionButtonPressed() {
        if let item = self.layoutParams?.0, let contextAction = item.contextAction {
            contextAction(self.contextSourceNode, nil)
        }
    }
    
    override func updateRevealOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        super.updateRevealOffset(offset: offset, transition: transition)
        
        if let _ = self.layoutParams?.0, let params = self.layoutParams?.1 {
            let leftInset: CGFloat = 65.0 + params.leftInset
                        
            var avatarFrame = self.avatarNode.frame
            avatarFrame.origin.x = offset + leftInset - 50.0
            transition.updateFrame(node: self.avatarNode, frame: avatarFrame)
            
            var titleFrame = self.titleNode.frame
            titleFrame.origin.x = leftInset + offset
            transition.updateFrame(node: self.titleNode, frame: titleFrame)
            
            var statusFrame = self.statusNode.frame
            let previousStatusFrame = statusFrame
            statusFrame.origin.x = leftInset + offset
            self.statusNode.frame = statusFrame
            transition.animatePositionAdditive(node: self.statusNode, offset: CGPoint(x: previousStatusFrame.minX - statusFrame.minX, y: 0))
        }
    }
    
    override func revealOptionsInteractivelyOpened() {
        if let item = self.layoutParams?.0 {
            item.setPeerIdWithRevealedOptions(item.peer.id, nil)
        }
    }
    
    override func revealOptionsInteractivelyClosed() {
        if let item = self.layoutParams?.0 {
            item.setPeerIdWithRevealedOptions(nil, item.peer.id)
        }
    }
    
    override func revealOptionSelected(_ option: ItemListRevealOption, animated: Bool) {
        if let item = self.layoutParams?.0 {
            item.revealOptions[Int(option.key)].action()
        }
        
        self.setRevealOptionsOpened(false, animated: true)
        self.revealOptionsInteractivelyClosed()
    }
}
