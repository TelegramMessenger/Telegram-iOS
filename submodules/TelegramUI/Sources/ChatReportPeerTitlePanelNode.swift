import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import LocalizedPeerData
import TelegramStringFormatting
import TextFormat
import Markdown
import ChatPresentationInterfaceState
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import AccountContext
import PremiumUI

private enum ChatReportPeerTitleButton: Equatable {
    case block
    case addContact(String?, Bool)
    case shareMyPhoneNumber
    case reportSpam
    case reportUserSpam
    case unarchive
    case addMembers
    case restartTopic
    
    func title(strings: PresentationStrings) -> String {
        switch self {
        case .block:
            return strings.Conversation_BlockUser
        case let .addContact(name, long):
            if let name = name {
                return strings.Conversation_AddNameToContacts(name).string
            } else {
                if long {
                    return strings.Conversation_AddToContactsLong
                } else {
                    return strings.Conversation_AddToContacts
                }
            }
        case .shareMyPhoneNumber:
            return strings.Conversation_ShareMyPhoneNumber
        case .reportSpam:
            return strings.Conversation_ReportSpamAndLeave
        case .reportUserSpam:
            return strings.Conversation_ReportSpam
        case .unarchive:
            return strings.Conversation_Unarchive
        case .addMembers:
            return strings.Conversation_AddMembers
        case .restartTopic:
            return strings.Chat_PanelRestartTopic
        }
    }
}

private func peerButtons(_ state: ChatPresentationInterfaceState) -> [ChatReportPeerTitleButton] {
    var buttons: [ChatReportPeerTitleButton] = []
    if let peer = state.renderedPeer?.chatMainPeer as? TelegramUser, let contactStatus = state.contactStatus, let peerStatusSettings = contactStatus.peerStatusSettings {
        if peerStatusSettings.contains(.autoArchived) {
            if peerStatusSettings.contains(.canBlock) || peerStatusSettings.contains(.canReport) {
                if peer.isDeleted {
                    buttons.append(.reportUserSpam)
                } else {
                    if !state.peerIsBlocked {
                        buttons.append(.block)
                    }
                }
            }
            
            buttons.append(.unarchive)
        } else if contactStatus.canAddContact && peerStatusSettings.contains(.canAddContact) {
            if peerStatusSettings.contains(.canBlock) || peerStatusSettings.contains(.canReport) {
                if !state.peerIsBlocked {
                    buttons.append(.block)
                }
            }
            if buttons.isEmpty, let phone = peer.phone, !phone.isEmpty {
                buttons.append(.addContact(EnginePeer(peer).compactDisplayTitle, buttons.isEmpty))
            } else {
                buttons.append(.addContact(nil, buttons.isEmpty))
            }
        } else {
            if peerStatusSettings.contains(.canBlock) || peerStatusSettings.contains(.canReport) {
                if peer.isDeleted {
                    buttons.append(.reportUserSpam)
                } else {
                    if !state.peerIsBlocked {
                        buttons.append(.block)
                    }
                }
            }
        }
        if buttons.isEmpty {
            if peerStatusSettings.contains(.canShareContact) {
                buttons.append(.shareMyPhoneNumber)
            }
        }
    } else if let peer = state.renderedPeer?.chatMainPeer {
        if let channel = peer as? TelegramChannel, channel.isForumOrMonoForum {
            if let threadData = state.threadData {
                if threadData.isClosed {
                    var canManage = false
                    if channel.flags.contains(.isCreator) {
                        canManage = true
                    } else if channel.hasPermission(.manageTopics) {
                        canManage = true
                    } else if threadData.isOwnedByMe {
                        canManage = true
                    }
                    
                    if canManage {
                        return [.restartTopic]
                    }
                }
            }
        }
        
        if case .peer = state.chatLocation {
            if let contactStatus = state.contactStatus, let peerStatusSettings = contactStatus.peerStatusSettings, peerStatusSettings.contains(.suggestAddMembers) {
                buttons.append(.addMembers)
            } else if let contactStatus = state.contactStatus, let peerStatusSettings = contactStatus.peerStatusSettings, peerStatusSettings.contains(.autoArchived) {
                buttons.append(.reportUserSpam)
                buttons.append(.unarchive)
            } else {
                buttons.append(.reportSpam)
            }
        }
    }
    return buttons
}

private final class ChatInfoTitlePanelInviteInfoNode: ASDisplayNode {
    private var theme: PresentationTheme?
    
    private let labelNode: ImmediateTextNode

    private let backgroundNode: NavigationBackgroundNode
    
    init(openInvitePeer: @escaping () -> Void) {
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.textAlignment = .center

        self.backgroundNode = NavigationBackgroundNode(color: .clear)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.labelNode)
        
        self.labelNode.highlightAttributeAction = { attributes in
            for (key, _) in attributes {
                if key.rawValue == "_Link" {
                    return key
                }
            }
            return nil
        }
        self.labelNode.tapAttributeAction = { attributes, _ in
            for (key, _) in attributes {
                if key.rawValue == "_Link" {
                    openInvitePeer()
                }
            }
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result == self.view {
            return nil
        }
        return result
    }
    
    func update(width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, chatPeer: Peer, invitedBy: Peer, transition: ContainedViewLayoutTransition) -> CGFloat {
        let primaryTextColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper).primaryText
        
        if self.theme !== theme {
            self.theme = theme
            
            self.labelNode.linkHighlightColor = primaryTextColor.withAlphaComponent(0.3)
        }
        
        let topInset: CGFloat = 6.0
        let bottomInset: CGFloat = 6.0
        let sideInset: CGFloat = 16.0
        
        let stringAndRanges: PresentationStrings.FormattedString
        if let channel = chatPeer as? TelegramChannel, case .broadcast = channel.info {
            stringAndRanges = strings.Conversation_NoticeInvitedByInChannel(EnginePeer(invitedBy).compactDisplayTitle)
        } else {
            stringAndRanges = strings.Conversation_NoticeInvitedByInGroup(EnginePeer(invitedBy).compactDisplayTitle)
        }
        
        let attributedString = NSMutableAttributedString(string: stringAndRanges.string, font: Font.regular(13.0), textColor: primaryTextColor)
        
        let boldAttributes = [NSAttributedString.Key.font: Font.semibold(13.0), NSAttributedString.Key(rawValue: "_Link"): true as NSNumber]
        for range in stringAndRanges.ranges {
            attributedString.addAttributes(boldAttributes, range: range.range)
        }
        
        self.labelNode.attributedText = attributedString
        let labelLayout = self.labelNode.updateLayoutFullInfo(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        var labelRects = labelLayout.linesRects()
        if labelRects.count > 1 {
            let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                            labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                            labelRects[index].size.width = labelRects[index + j].size.width
                        }
                    }
                }
            }
        }
        for i in 0 ..< labelRects.count {
            labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
            labelRects[i].size.height = 20.0
            labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
        }
        
        let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
        
        let labelFrame = CGRect(origin: CGPoint(x: floor((width - labelLayout.size.width) / 2.0), y: topInset + floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
        self.labelNode.frame = labelFrame

        let backgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: 1.0).insetBy(dx: -5.0, dy: -2.0)
        self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: theme, wallpaper: wallpaper), enableBlur: dateFillNeedsBlur(theme: theme, wallpaper: wallpaper), transition: .immediate)
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: self.backgroundNode.bounds.size.height / 2.0, transition: transition)
        
        return topInset + backgroundSize.height + bottomInset
    }
}

private final class ChatInfoTitlePanelPeerNearbyInfoNode: ASDisplayNode {
    private var theme: PresentationTheme?
    
    private let labelNode: ImmediateTextNode
    private let filledBackgroundNode: LinkHighlightingNode
    
    private let openPeersNearby: () -> Void
    
    init(openPeersNearby: @escaping () -> Void) {
        self.openPeersNearby = openPeersNearby
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.textAlignment = .center
        
        self.filledBackgroundNode = LinkHighlightingNode(color: .clear)
        
        super.init()
        
        self.addSubnode(self.filledBackgroundNode)
        self.addSubnode(self.labelNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    @objc private func tapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
        self.openPeersNearby()
    }
    
    func update(width: CGFloat, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, chatPeer: Peer, distance: Int32, transition: ContainedViewLayoutTransition) -> CGFloat {
        let primaryTextColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper).primaryText
        
        if self.theme !== theme {
            self.theme = theme
            
            self.labelNode.linkHighlightColor = primaryTextColor.withAlphaComponent(0.3)
        }
        
        let topInset: CGFloat = 6.0
        let bottomInset: CGFloat = 6.0
        let sideInset: CGFloat = 16.0
        
        let stringAndRanges = strings.Conversation_PeerNearbyDistance(EnginePeer(chatPeer).compactDisplayTitle, shortStringForDistance(strings: strings, distance: distance))
        
        let attributedString = NSMutableAttributedString(string: stringAndRanges.string, font: Font.regular(13.0), textColor: primaryTextColor)
        
        let boldAttributes = [NSAttributedString.Key.font: Font.semibold(13.0), NSAttributedString.Key(rawValue: "_Link"): true as NSNumber]
        for range in stringAndRanges.ranges.prefix(1) {
            attributedString.addAttributes(boldAttributes, range: range.range)
        }
        
        self.labelNode.attributedText = attributedString
        let labelLayout = self.labelNode.updateLayoutFullInfo(CGSize(width: width - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        var labelRects = labelLayout.linesRects()
        if labelRects.count > 1 {
            let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
            for i in 0 ..< sortedIndices.count {
                let index = sortedIndices[i]
                for j in -1 ... 1 {
                    if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                        if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                            labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                            labelRects[index].size.width = labelRects[index + j].size.width
                        }
                    }
                }
            }
        }
        for i in 0 ..< labelRects.count {
            labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
            labelRects[i].size.height = 20.0
            labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
        }
        
        let backgroundLayout = self.filledBackgroundNode.asyncLayout()
        let serviceColor = serviceMessageColorComponents(theme: theme, wallpaper: wallpaper)
        let backgroundApply = backgroundLayout(serviceColor.fill, labelRects, 10.0, 10.0, 0.0)
        backgroundApply()
        
        let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
        
        let labelFrame = CGRect(origin: CGPoint(x: floor((width - labelLayout.size.width) / 2.0), y: topInset + floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
        self.labelNode.frame = labelFrame
        self.filledBackgroundNode.frame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
        
        return topInset + backgroundSize.height + bottomInset
    }
}

final class ChatReportPeerTitlePanelNode: ChatTitleAccessoryPanelNode {
    private let context: AccountContext
    private let animationCache: AnimationCache
    private let animationRenderer: MultiAnimationRenderer
        
    private let separatorNode: ASDisplayNode
    
    private let closeButton: HighlightableButtonNode
    private var buttons: [(ChatReportPeerTitleButton, UIButton)] = []
    private let textNode: ImmediateTextNode
    private var emojiStatusTextNode: ImmediateTextNodeWithEntities?
    private let emojiSeparatorNode: ASDisplayNode
    
    private var theme: PresentationTheme?
    private var presentationInterfaceState: ChatPresentationInterfaceState?
    
    private var inviteInfoNode: ChatInfoTitlePanelInviteInfoNode?
    private var peerNearbyInfoNode: ChatInfoTitlePanelPeerNearbyInfoNode?
    
    private var cachedChevronImage: (UIImage, PresentationTheme)?
    
    private var emojiStatusPackDisposable = MetaDisposable()
    private var emojiStatusFileId: Int64?
    private var emojiStatusFileAndPackTitle = Promise<(TelegramMediaFile, LoadedStickerPack)?>()
    
    private var tapGestureRecognizer: UITapGestureRecognizer?
    
    init(context: AccountContext, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer) {
        self.context = context
        self.animationCache = animationCache
        self.animationRenderer = animationRenderer
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        self.emojiSeparatorNode = ASDisplayNode()
        self.emojiSeparatorNode.isLayerBacked = true
        
        self.closeButton = HighlightableButtonNode()
        self.closeButton.hitTestSlop = UIEdgeInsets(top: -8.0, left: -8.0, bottom: -8.0, right: -8.0)
        self.closeButton.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 3
        self.textNode.textAlignment = .center
        
        super.init()

        self.addSubnode(self.separatorNode)
        self.addSubnode(self.emojiSeparatorNode)
        self.addSubnode(self.textNode)
        
        self.closeButton.addTarget(self, action: #selector(self.closePressed), forControlEvents: [.touchUpInside])
        self.addSubnode(self.closeButton)
    }
    
    deinit {
        self.emojiStatusPackDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapped))
        tapGestureRecognizer.isEnabled = false
        self.view.addGestureRecognizer(tapGestureRecognizer)
        self.tapGestureRecognizer = tapGestureRecognizer
    }
    
    @objc func tapped() {
        self.interfaceInteraction?.presentChatRequestAdminInfo()
    }
    
    private func openPremiumEmojiStatusDemo() {
        guard let navigationController = self.interfaceInteraction?.getNavigationController(), let peerId = self.presentationInterfaceState?.chatLocation.peerId, let emojiStatus = self.presentationInterfaceState?.renderedPeer?.peer?.emojiStatus, case let .emoji(fileId) = emojiStatus.content else {
            return
        }
        
        let source: Signal<PremiumSource, NoError> = self.emojiStatusFileAndPackTitle.get()
        |> take(1)
        |> mapToSignal { emojiStatusFileAndPack -> Signal<PremiumSource, NoError> in
            if let (file, pack) = emojiStatusFileAndPack {
                return .single(.emojiStatus(peerId, fileId, file, pack))
            } else {
                return .complete()
            }
        }
  
        let _ = (source
        |> deliverOnMainQueue).startStandalone(next: { [weak self, weak navigationController] source in
            guard let self, let navigationController else {
                return
            }
            let controller = PremiumIntroScreen(context: self.context, source: source)
            if let textView = self.emojiStatusTextNode?.view {
                controller.sourceView = textView
                controller.sourceRect = CGRect(origin: .zero, size: CGSize(width: textView.frame.height, height: textView.frame.height))
            }
            controller.containerView = navigationController.view
            navigationController.pushViewController(controller)
        })
    }
    
    override func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        if interfaceState.theme !== self.theme {
            self.theme = interfaceState.theme
            
            self.closeButton.setImage(PresentationResourcesChat.chatInputPanelEncircledCloseIconImage(interfaceState.theme), for: [])
            self.separatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
            self.emojiSeparatorNode.backgroundColor = interfaceState.theme.rootController.navigationBar.separatorColor
        }
        self.presentationInterfaceState = interfaceState
        
        var panelHeight: CGFloat = 40.0
        
        let contentRightInset: CGFloat = 14.0 + rightInset
        
        let updatedButtons: [ChatReportPeerTitleButton]
        if let _ = interfaceState.renderedPeer?.peer {
            updatedButtons = peerButtons(interfaceState)
        } else {
            updatedButtons = []
        }
                
        var buttonsUpdated = false
        if self.buttons.count != updatedButtons.count {
            buttonsUpdated = true
        } else {
            for i in 0 ..< updatedButtons.count {
                if self.buttons[i].0 != updatedButtons[i] {
                    buttonsUpdated = true
                    break
                }
            }
        }
        
        if buttonsUpdated {
            for (_, view) in self.buttons {
                view.removeFromSuperview()
            }
            self.buttons.removeAll()
            for button in updatedButtons {
                let view = UIButton()
                view.setTitle(button.title(strings: interfaceState.strings), for: [])
                view.titleLabel?.font = Font.regular(16.0)
                switch button {
                    case .block, .reportSpam, .reportUserSpam:
                    view.setTitleColor(interfaceState.theme.chat.inputPanel.panelControlDestructiveColor, for: [])
                    view.setTitleColor(interfaceState.theme.chat.inputPanel.panelControlDestructiveColor.withAlphaComponent(0.7), for: [.highlighted])
                    default:
                    view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor, for: [])
                    view.setTitleColor(interfaceState.theme.rootController.navigationBar.accentTextColor.withAlphaComponent(0.7), for: [.highlighted])
                }
                view.addTarget(self, action: #selector(self.buttonPressed(_:)), for: [.touchUpInside])
                self.view.addSubview(view)
                self.buttons.append((button, view))
            }
        }
        
        let additionalRightInset: CGFloat = 36.0
        if !self.buttons.isEmpty {
            let maxInset = max(contentRightInset, leftInset)
            if self.buttons.count == 1 {
                let buttonWidth = floor((width - maxInset * 2.0 - additionalRightInset) / CGFloat(self.buttons.count))
                var nextButtonOrigin: CGFloat = maxInset
                for (_, view) in self.buttons {
                    view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - buttonWidth) / 2.0), y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight))
                    nextButtonOrigin += buttonWidth
                }
            } else {
                var areaWidth = width - maxInset * 2.0 - additionalRightInset
                let maxButtonWidth = floor(areaWidth / CGFloat(self.buttons.count))
                let buttonSizes = self.buttons.map { button -> CGFloat in
                    return button.1.sizeThatFits(CGSize(width: maxButtonWidth, height: 100.0)).width
                }
                let buttonsWidth = buttonSizes.reduce(0.0, +)
                if buttonsWidth < areaWidth - 20.0 {
                    areaWidth += additionalRightInset
                }
                let maxButtonSpacing = floor((areaWidth - buttonsWidth) / CGFloat(self.buttons.count - 1))
                let buttonSpacing = min(maxButtonSpacing, 110.0)
                let updatedButtonsWidth = buttonsWidth + CGFloat(self.buttons.count - 1) * buttonSpacing
                var nextButtonOrigin = maxInset + floor((areaWidth - updatedButtonsWidth) / 2.0)
                
                let buttonWidth = floor(updatedButtonsWidth / CGFloat(self.buttons.count))
                
                var buttonFrames: [CGRect] = []
                for _ in 0 ..< self.buttons.count {
                    buttonFrames.append(CGRect(origin: CGPoint(x: nextButtonOrigin, y: 0.0), size: CGSize(width: buttonWidth, height: panelHeight)))
                    nextButtonOrigin += buttonWidth
                }
                
                if buttonFrames[buttonFrames.count - 1].maxX >= width - 20.0 {
                    for i in 0 ..< buttonFrames.count {
                        buttonFrames[i].origin.x -= 16.0
                    }
                }
                
                for i in 0 ..< self.buttons.count {
                    self.buttons[i].1.frame = buttonFrames[i]
                }
            }
        }
        
        if let requestChatTitle = interfaceState.contactStatus?.peerStatusSettings?.requestChatTitle, let requestChatIsChannel = interfaceState.contactStatus?.peerStatusSettings?.requestChatIsChannel, let renderedPeer = interfaceState.renderedPeer, let peer = renderedPeer.chatMainPeer {
            let text: NSAttributedString
            let regular = MarkdownAttributeSet(font: Font.regular(15.0), textColor: interfaceState.theme.rootController.navigationBar.primaryTextColor)
            let bold = MarkdownAttributeSet(font: Font.bold(15.0), textColor: interfaceState.theme.rootController.navigationBar.primaryTextColor)
            
            if requestChatIsChannel {
                text = addAttributesToStringWithRanges(interfaceState.strings.Conversation_InviteRequestAdminChannel(EnginePeer(peer).compactDisplayTitle, requestChatTitle)._tuple, body: regular, argumentAttributes: [0: bold, 1: bold])
            } else {
                text = addAttributesToStringWithRanges(interfaceState.strings.Conversation_InviteRequestAdminGroup(EnginePeer(peer).compactDisplayTitle, requestChatTitle)._tuple, body: regular, argumentAttributes: [0: bold, 1: bold])
            }
            self.textNode.attributedText = text
            
            transition.updateAlpha(node: self.textNode, alpha: 1.0)
            
            let textSize = self.textNode.updateLayout(CGSize(width: width - leftInset - rightInset - 80.0, height: 40.0))
            self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - textSize.width) / 2.0), y: 10.0), size: textSize)
            
            for (_, view) in self.buttons {
                transition.updateAlpha(layer: view.layer, alpha: 0.0)
            }
            
            self.tapGestureRecognizer?.isEnabled = true
            
            panelHeight += 15.0
        } else {
            transition.updateAlpha(node: self.textNode, alpha: 0.0)
            
            for (_, view) in self.buttons {
                transition.updateAlpha(layer: view.layer, alpha: 1.0)
            }
            
            self.tapGestureRecognizer?.isEnabled = false
        }
        
        let closeButtonSize = self.closeButton.measure(CGSize(width: 100.0, height: 100.0))
        transition.updateFrame(node: self.closeButton, frame: CGRect(origin: CGPoint(x: width - contentRightInset - closeButtonSize.width, y: floorToScreenPixels((panelHeight - closeButtonSize.height) / 2.0)), size: closeButtonSize))
        if updatedButtons.contains(.restartTopic) {
            self.closeButton.isHidden = true
        } else {
            self.closeButton.isHidden = false
        }
        
        var emojiStatus: PeerEmojiStatus?
        if let user = interfaceState.renderedPeer?.peer as? TelegramUser, let emojiStatusValue = user.emojiStatus {
            if user.isFake || user.isScam { 
            } else {
                emojiStatus = emojiStatusValue
            }
        } else if let channel = interfaceState.renderedPeer?.peer as? TelegramChannel, let emojiStatusValue = channel.emojiStatus {
            if channel.isFake || channel.isScam {
            } else {
                emojiStatus = emojiStatusValue
            }
        }
        
        if let emojiStatus {
            let fileId = emojiStatus.fileId
            if self.emojiStatusFileId != fileId {
                self.emojiStatusFileId = fileId
                
                let emojiFileAndPack = self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                |> mapToSignal { result in
                    if let emojiFile = result.first?.value {
                        for attribute in emojiFile.attributes {
                            if case let .CustomEmoji(_, _, _, packReference) = attribute, let packReference = packReference {
                                return self.context.engine.stickers.loadedStickerPack(reference: packReference, forceActualized: false)
                                |> filter { result in
                                    if case .result = result {
                                        return true
                                    } else {
                                        return false
                                    }
                                }
                                |> mapToSignal { result -> Signal<(TelegramMediaFile, LoadedStickerPack)?, NoError> in
                                    if case let .result(_, items, _) = result {
                                        return .single(items.first.flatMap { ($0.file._parse(), result) })
                                    } else {
                                        return .complete()
                                    }
                                }
                            }
                        }
                    }
                    return .complete()
                }
                self.emojiStatusPackDisposable.set(emojiFileAndPack.startStrict(next: { [weak self] fileAndPackTitle in
                    guard let self else {
                        return
                    }
                    self.emojiStatusFileAndPackTitle.set(.single(fileAndPackTitle))
                }))
            }

            self.emojiSeparatorNode.isHidden = false
            
            transition.updateFrame(node: self.emojiSeparatorNode, frame: CGRect(origin: CGPoint(x: leftInset + 12.0, y: 40.0), size: CGSize(width: width - leftInset - rightInset - 24.0, height: UIScreenPixel)))
            
            let emojiStatusTextNode: ImmediateTextNodeWithEntities
            if let current = self.emojiStatusTextNode {
                emojiStatusTextNode = current
            } else {
                emojiStatusTextNode = ImmediateTextNodeWithEntities()
                emojiStatusTextNode.maximumNumberOfLines = 0
                emojiStatusTextNode.textAlignment = .center
                emojiStatusTextNode.linkHighlightInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0)
                emojiStatusTextNode.highlightAttributeAction = { attributes in
                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                        return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                    } else {
                        return nil
                    }
                }
                emojiStatusTextNode.tapAttributeAction = { [weak self] attributes, _ in
                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                        self?.openPremiumEmojiStatusDemo()
                    }
                }
                self.emojiStatusTextNode = emojiStatusTextNode
                self.addSubnode(emojiStatusTextNode)
            }
            
            if self.cachedChevronImage == nil || self.cachedChevronImage?.1 !== interfaceState.theme {
                self.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Item List/InlineTextRightArrow"), color: interfaceState.theme.rootController.navigationBar.accentTextColor)!, interfaceState.theme)
            }
            
            let plainText = interfaceState.strings.Chat_PanelCustomStatusShortInfo("#").string
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: Font.regular(12.0), textColor: interfaceState.theme.rootController.navigationBar.secondaryTextColor), bold: MarkdownAttributeSet(font: Font.semibold(12.0), textColor: interfaceState.theme.rootController.navigationBar.secondaryTextColor), link: MarkdownAttributeSet(font: Font.regular(12.0), textColor: interfaceState.theme.rootController.navigationBar.accentTextColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let attributedString = parseMarkdownIntoAttributedString(plainText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
            if let range = attributedString.string.range(of: ">"), let chevronImage = self.cachedChevronImage?.0 {
                attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
            }
            if let range = attributedString.string.range(of: "#") {
                attributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: emojiStatus.fileId, file: nil), range: NSRange(range, in: attributedString.string))
            }
            emojiStatusTextNode.attributedText = attributedString
            emojiStatusTextNode.arguments = TextNodeWithEntities.Arguments(
                context: self.context,
                cache: self.animationCache,
                renderer: self.animationRenderer,
                placeholderColor: interfaceState.theme.list.mediaPlaceholderColor,
                attemptSynchronous: false
            )
            emojiStatusTextNode.linkHighlightColor = interfaceState.theme.list.itemAccentColor.withAlphaComponent(0.1)
            
            let emojiStatusTextSize = emojiStatusTextNode.updateLayout(CGSize(width: width - leftInset * 2.0 - 8.0 * 2.0, height: CGFloat.greatestFiniteMagnitude))
            transition.updateFrame(node: emojiStatusTextNode, frame: CGRect(origin: CGPoint(x: floor((width - emojiStatusTextSize.width) / 2.0), y: panelHeight + 10.0), size: emojiStatusTextSize))
            panelHeight += emojiStatusTextSize.height + 20.0
            
            emojiStatusTextNode.visibility = true
        } else {
            self.emojiSeparatorNode.isHidden = true
            
            if let emojiStatusTextNode = self.emojiStatusTextNode {
                self.emojiStatusTextNode = nil
                emojiStatusTextNode.removeFromSupernode()
            }
        }

        let initialPanelHeight = panelHeight
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        var panelInset: CGFloat = 0.0
        if let _ = interfaceState.translationState {
            panelInset += 40.0
        }
        
        var chatPeer: Peer?
        if let renderedPeer = interfaceState.renderedPeer {
            chatPeer = renderedPeer.peers[renderedPeer.peerId]
        }
        var hitTestSlop: CGFloat = 0.0
        if let chatPeer = chatPeer, (updatedButtons.contains(.block) || updatedButtons.contains(.reportSpam) || updatedButtons.contains(.reportUserSpam)), let invitedBy = interfaceState.contactStatus?.invitedBy {
            var inviteInfoTransition = transition
            let inviteInfoNode: ChatInfoTitlePanelInviteInfoNode
            if let current = self.inviteInfoNode {
                inviteInfoNode = current
            } else {
                inviteInfoTransition = .immediate
                inviteInfoNode = ChatInfoTitlePanelInviteInfoNode(openInvitePeer: { [weak self] in
                    self?.interfaceInteraction?.navigateToProfile(invitedBy.id)
                })
                self.addSubnode(inviteInfoNode)
                self.inviteInfoNode = inviteInfoNode
                inviteInfoNode.alpha = 0.0
                transition.updateAlpha(node: inviteInfoNode, alpha: 1.0)
            }
            
            if let inviteInfoNode = self.inviteInfoNode {
                let inviteHeight = inviteInfoNode.update(width: width, theme: interfaceState.theme, strings: interfaceState.strings, wallpaper: interfaceState.chatWallpaper, chatPeer: chatPeer, invitedBy: invitedBy, transition: inviteInfoTransition)
                inviteInfoTransition.updateFrame(node: inviteInfoNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight + panelInset), size: CGSize(width: width, height: inviteHeight)))
                panelHeight += inviteHeight
                hitTestSlop = -inviteHeight
            }
        } else if let inviteInfoNode = self.inviteInfoNode {
            self.inviteInfoNode = nil
            transition.updateAlpha(node: inviteInfoNode, alpha: 0.0, completion: { [weak inviteInfoNode] _ in
                inviteInfoNode?.removeFromSupernode()
            })
        }
        
        if let chatPeer = chatPeer, let distance = interfaceState.contactStatus?.peerStatusSettings?.geoDistance {
            var peerNearbyInfoTransition = transition
            let peerNearbyInfoNode: ChatInfoTitlePanelPeerNearbyInfoNode
            if let current = self.peerNearbyInfoNode {
                peerNearbyInfoNode = current
            } else {
                peerNearbyInfoTransition = .immediate
                peerNearbyInfoNode = ChatInfoTitlePanelPeerNearbyInfoNode(openPeersNearby: { [weak self] in
                    self?.interfaceInteraction?.openPeersNearby()
                })
                self.addSubnode(peerNearbyInfoNode)
                self.peerNearbyInfoNode = peerNearbyInfoNode
                peerNearbyInfoNode.alpha = 0.0
                transition.updateAlpha(node: peerNearbyInfoNode, alpha: 1.0)
            }
            
            if let peerNearbyInfoNode = self.peerNearbyInfoNode {
                let peerNearbyHeight = peerNearbyInfoNode.update(width: width, theme: interfaceState.theme, strings: interfaceState.strings, wallpaper: interfaceState.chatWallpaper, chatPeer: chatPeer, distance: distance, transition: peerNearbyInfoTransition)
                peerNearbyInfoTransition.updateFrame(node: peerNearbyInfoNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight + panelInset), size: CGSize(width: width, height: peerNearbyHeight)))
                panelHeight += peerNearbyHeight
            }
        } else if let peerNearbyInfoNode = self.peerNearbyInfoNode {
            self.peerNearbyInfoNode = nil
            transition.updateAlpha(node: peerNearbyInfoNode, alpha: 0.0, completion: { [weak peerNearbyInfoNode] _ in
                peerNearbyInfoNode?.removeFromSupernode()
            })
        }
        return LayoutResult(backgroundHeight: initialPanelHeight, insetHeight: panelHeight + panelInset, hitTestSlop: hitTestSlop)
    }
    
    @objc func buttonPressed(_ view: UIButton) {
        for (button, buttonView) in self.buttons {
            if buttonView === view {
                switch button {
                case .shareMyPhoneNumber:
                    self.interfaceInteraction?.shareAccountContact()
                case .block, .reportSpam, .reportUserSpam:
                    self.interfaceInteraction?.reportPeer()
                case .unarchive:
                    self.interfaceInteraction?.unarchivePeer()
                case .addMembers:
                    self.interfaceInteraction?.presentInviteMembers()
                case .addContact:
                    self.interfaceInteraction?.presentPeerContact()
                case .restartTopic:
                    self.interfaceInteraction?.restartTopic()
                }
                break
            }
        }
    }
    
    @objc func closePressed() {
        self.interfaceInteraction?.dismissReportPeer()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.closeButton.isHidden, let result = self.closeButton.hitTest(CGPoint(x: point.x - self.closeButton.frame.minX, y: point.y - self.closeButton.frame.minY), with: event) {
            return result
        }
        if let inviteInfoNode = self.inviteInfoNode {
            if let result = inviteInfoNode.view.hitTest(self.view.convert(point, to: inviteInfoNode.view), with: event) {
                return result
            }
        }
        if let _ = self.emojiStatusTextNode {
            
        } else if point.y > 40.0 {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
