import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import AppBundle
import SwiftSignalKit
import AnimatedAvatarSetNode

private let titleFont = Font.semibold(15.0)
private let subtitleFont = Font.regular(13.0)

public enum GroupCallPanelSource {
    case none
    case all
    case peer(PeerId)
}

public final class GroupCallPanelData {
    public let peerId: PeerId
    public let info: GroupCallInfo
    public let topParticipants: [GroupCallParticipantsContext.Participant]
    public let participantCount: Int
    public let groupCall: PresentationGroupCall?
    
    public init(
        peerId: PeerId,
        info: GroupCallInfo,
        topParticipants: [GroupCallParticipantsContext.Participant],
        participantCount: Int,
        groupCall: PresentationGroupCall?
    ) {
        self.peerId = peerId
        self.info = info
        self.topParticipants = topParticipants
        self.participantCount = participantCount
        self.groupCall = groupCall
    }
}

public final class GroupCallNavigationAccessoryPanel: ASDisplayNode {
    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let tapAction: () -> Void
    
    private let contentNode: ASDisplayNode
    
    private let tapButton: HighlightTrackingButtonNode
    
    private let joinButton: HighlightableButtonNode
    private let joinButtonTitleNode: ImmediateTextNode
    private let joinButtonBackgroundNode: ASImageNode
    
    private let micButton: HighlightTrackingButtonNode
    private let micButtonForegroundNode: VoiceChatMicrophoneNode
    private let micButtonBackgroundNode: ASImageNode
    
    let titleNode: ImmediateTextNode
    let textNode: ImmediateTextNode
    private let muteIconNode: ASImageNode
    
    private let avatarsContext: AnimatedAvatarSetContext
    private var avatarsContent: AnimatedAvatarSetContext.Content?
    private let avatarsNode: AnimatedAvatarSetNode
    
    private let separatorNode: ASDisplayNode
    
    private let membersDisposable = MetaDisposable()
    private let isMutedDisposable = MetaDisposable()
    
    private var currentData: GroupCallPanelData?
    private var validLayout: (CGSize, CGFloat, CGFloat)?
    
    public init(context: AccountContext, presentationData: PresentationData, tapAction: @escaping () -> Void) {
        self.context = context
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        
        self.tapAction = tapAction
        
        self.contentNode = ASDisplayNode()
        
        self.tapButton = HighlightTrackingButtonNode()
        
        self.joinButton = HighlightableButtonNode()
        self.joinButtonTitleNode = ImmediateTextNode()
        self.joinButtonBackgroundNode = ASImageNode()
        
        self.micButton = HighlightTrackingButtonNode()
        self.micButtonForegroundNode = VoiceChatMicrophoneNode()
        self.micButtonBackgroundNode = ASImageNode()
        
        self.titleNode = ImmediateTextNode()
        self.textNode = ImmediateTextNode()
        
        self.muteIconNode = ASImageNode()
        
        self.avatarsContext = AnimatedAvatarSetContext()
        self.avatarsNode = AnimatedAvatarSetNode()
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.contentNode)
        
        self.tapButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.textNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.textNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.textNode.alpha = 1.0
                    strongSelf.textNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.contentNode.addSubnode(self.titleNode)
        self.contentNode.addSubnode(self.textNode)
        self.contentNode.addSubnode(self.muteIconNode)
        
        self.contentNode.addSubnode(self.avatarsNode)
        
        self.tapButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        self.contentNode.addSubnode(self.tapButton)
        
        self.joinButton.addSubnode(self.joinButtonBackgroundNode)
        self.joinButton.addSubnode(self.joinButtonTitleNode)
        self.contentNode.addSubnode(self.joinButton)
        self.joinButton.addTarget(self, action: #selector(self.tapped), forControlEvents: [.touchUpInside])
        
        self.micButton.addSubnode(self.micButtonBackgroundNode)
        self.micButton.addSubnode(self.micButtonForegroundNode)
        self.contentNode.addSubnode(self.micButton)
        self.micButton.addTarget(self, action: #selector(self.micTapped), forControlEvents: [.touchUpInside])
        
        self.contentNode.addSubnode(self.separatorNode)
        
        self.updatePresentationData(presentationData)
    }
    
    deinit {
        self.membersDisposable.dispose()
        self.isMutedDisposable.dispose()
    }
    
    public override func didLoad() {
        super.didLoad()
        
        let longTapRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.micButtonPressGesture(_:)))
        longTapRecognizer.minimumPressDuration = 0.01
        self.micButton.view.addGestureRecognizer(longTapRecognizer)
    }
    
    @objc private func tapped() {
        self.tapAction()
    }
    
    @objc private func micTapped() {
        guard let call = self.currentData?.groupCall else {
            return
        }
        call.toggleIsMuted()
    }
    
    private var actionButtonPressGestureStartTime: Double = 0.0
    
    @objc private func micButtonPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let call = self.currentData?.groupCall else {
            return
        }
        switch gestureRecognizer.state {
            case .began:
                self.actionButtonPressGestureStartTime = CACurrentMediaTime()
                call.setIsMuted(action: .muted(isPushToTalkActive: true))
            case .ended, .cancelled:
                let timestamp = CACurrentMediaTime()
                if timestamp - self.actionButtonPressGestureStartTime < 0.2 {
                    call.toggleIsMuted()
                } else {
                    call.setIsMuted(action: .muted(isPushToTalkActive: false))
                }
            default:
                break
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.strings = presentationData.strings
        
        self.contentNode.backgroundColor = self.theme.rootController.navigationBar.backgroundColor
        
        self.theme = presentationData.theme
        
        self.separatorNode.backgroundColor = presentationData.theme.chat.historyNavigation.strokeColor
        
        self.joinButtonTitleNode.attributedText = NSAttributedString(string: presentationData.strings.Channel_JoinChannel.uppercased(), font: Font.semibold(15.0), textColor: presentationData.theme.chat.inputPanel.actionControlForegroundColor)
        self.joinButtonBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: presentationData.theme.chat.inputPanel.actionControlFillColor)
        
        //TODO:localize
        self.micButtonBackgroundNode.image = generateStretchableFilledCircleImage(diameter: 36.0, color: UIColor(rgb: 0x30b251))
        
        //TODO:localize
        self.titleNode.attributedText = NSAttributedString(string: "Voice Chat", font: Font.semibold(15.0), textColor: presentationData.theme.chat.inputPanel.primaryTextColor)
        self.textNode.attributedText = NSAttributedString(string: self.textNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: presentationData.theme.chat.inputPanel.secondaryTextColor)
        
        self.muteIconNode.image = PresentationResourcesChat.chatTitleMuteIcon(presentationData.theme)
    }
    
    public func update(data: GroupCallPanelData) {
        let previousData = self.currentData
        self.currentData = data
        
        if previousData?.groupCall !== data.groupCall {
            let membersText: String
            if data.participantCount == 0 {
                membersText = self.strings.PeopleNearby_NoMembers
            } else {
                membersText = self.strings.Conversation_StatusMembers(Int32(data.participantCount))
            }
            
            self.avatarsContent = self.avatarsContext.update(peers: data.topParticipants.map { $0.peer }, animated: false)
            
            self.textNode.attributedText = NSAttributedString(string: membersText, font: Font.regular(13.0), textColor: self.theme.chat.inputPanel.secondaryTextColor)
            
            self.membersDisposable.set(nil)
            self.isMutedDisposable.set(nil)
            
            if let groupCall = data.groupCall {
                self.membersDisposable.set((groupCall.summaryState
                |> deliverOnMainQueue).start(next: { [weak self] summaryState in
                    guard let strongSelf = self, let summaryState = summaryState else {
                        return
                    }
                    
                    let membersText: String
                    if summaryState.participantCount == 0 {
                        membersText = strongSelf.strings.PeopleNearby_NoMembers
                    } else {
                        membersText = strongSelf.strings.Conversation_StatusMembers(Int32(summaryState.participantCount))
                    }
                    
                    strongSelf.avatarsContent = strongSelf.avatarsContext.update(peers: summaryState.topParticipants.map { $0.peer }, animated: false)
                    
                    strongSelf.textNode.attributedText = NSAttributedString(string: membersText, font: Font.regular(13.0), textColor: strongSelf.theme.chat.inputPanel.secondaryTextColor)
                    if let (size, leftInset, rightInset) = strongSelf.validLayout {
                        strongSelf.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
                    }
                }))
                
                self.isMutedDisposable.set((groupCall.isMuted
                |> deliverOnMainQueue).start(next: { [weak self] isMuted in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.micButtonForegroundNode.update(state: VoiceChatMicrophoneNode.State(muted: isMuted, color: UIColor.white), animated: true)
                }))
            }
        } else if data.groupCall == nil {
            let membersText: String
            if data.participantCount == 0 {
                membersText = self.strings.PeopleNearby_NoMembers
            } else {
                membersText = self.strings.Conversation_StatusMembers(Int32(data.participantCount))
            }
            
            self.avatarsContent = self.avatarsContext.update(peers: data.topParticipants.map { $0.peer }, animated: false)
            
            self.textNode.attributedText = NSAttributedString(string: membersText, font: Font.regular(13.0), textColor: self.theme.chat.inputPanel.secondaryTextColor)
        }
        
        if let (size, leftInset, rightInset) = self.validLayout {
            self.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: .immediate)
        }
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, leftInset, rightInset)
        
        let panelHeight = size.height
        
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: size))
        
        self.tapButton.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width - 7.0 - 36.0 - 7.0, height: panelHeight))
        
        if let avatarsContent = self.avatarsContent {
            let avatarsSize = self.avatarsNode.update(context: self.context, content: avatarsContent, itemSize: CGSize(width: 32.0, height: 32.0), animated: true, synchronousLoad: true)
            transition.updateFrame(node: self.avatarsNode, frame: CGRect(origin: CGPoint(x: 7.0, y: floor((size.height - avatarsSize.height) / 2.0)), size: avatarsSize))
        }
        
        let joinButtonTitleSize = self.joinButtonTitleNode.updateLayout(CGSize(width: 150.0, height: .greatestFiniteMagnitude))
        let joinButtonSize = CGSize(width: joinButtonTitleSize.width + 20.0, height: 28.0)
        let joinButtonFrame = CGRect(origin: CGPoint(x: size.width - rightInset - 7.0 - joinButtonSize.width, y: floor((panelHeight - joinButtonSize.height) / 2.0)), size: joinButtonSize)
        transition.updateFrame(node: self.joinButton, frame: joinButtonFrame)
        transition.updateFrame(node: self.joinButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: joinButtonFrame.size))
        transition.updateFrame(node: self.joinButtonTitleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((joinButtonFrame.width - joinButtonTitleSize.width) / 2.0), y: floorToScreenPixels((joinButtonFrame.height - joinButtonTitleSize.height) / 2.0)), size: joinButtonTitleSize))
        
        let micButtonSize = CGSize(width: 36.0, height: 36.0)
        let micButtonFrame = CGRect(origin: CGPoint(x: size.width - rightInset - 7.0 - micButtonSize.width, y: floor((panelHeight - micButtonSize.height) / 2.0)), size: micButtonSize)
        transition.updateFrame(node: self.micButton, frame: micButtonFrame)
        transition.updateFrame(node: self.micButtonBackgroundNode, frame: CGRect(origin: CGPoint(), size: micButtonFrame.size))
        
        let animationSize = CGSize(width: 36.0, height: 36.0)
        transition.updateFrame(node: self.micButtonForegroundNode, frame: CGRect(origin: CGPoint(x: floor((micButtonFrame.width - animationSize.width) / 2.0), y: floor((micButtonFrame.height - animationSize.height) / 2.0)), size: animationSize))
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: size.width, height: .greatestFiniteMagnitude))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: 9.0), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.textNode, frame: CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: titleFrame.maxY + 1.0), size: textSize))
        
        if let image = self.muteIconNode.image {
            transition.updateFrame(node: self.muteIconNode, frame: CGRect(origin: CGPoint(x: titleFrame.maxX + 4.0, y: titleFrame.minY + 5.0), size: image.size))
        }
        self.muteIconNode.isHidden = self.currentData?.groupCall != nil
        self.joinButton.isHidden = self.currentData?.groupCall != nil
        self.micButton.isHidden = self.currentData?.groupCall == nil
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: panelHeight - UIScreenPixel), size: CGSize(width: size.width, height: UIScreenPixel)))
    }
    
    public func animateIn(_ transition: ContainedViewLayoutTransition) {
        self.clipsToBounds = true
        let contentPosition = self.contentNode.layer.position
        transition.animatePosition(node: self.contentNode, from: CGPoint(x: contentPosition.x, y: contentPosition.y - 50.0), completion: { [weak self] _ in
            self?.clipsToBounds = false
        })
    }
    
    public func animateOut(_ transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.clipsToBounds = true
        let contentPosition = self.contentNode.layer.position
        transition.animatePosition(node: self.contentNode, to: CGPoint(x: contentPosition.x, y: contentPosition.y - 50.0), removeOnCompletion: false, completion: { [weak self] _ in
            self?.clipsToBounds = false
            completion()
        })
    }
    
    func rightButtonSnapshotViews() -> (background: UIView, foreground: UIView)? {
        if !self.joinButton.isHidden {
            if let foregroundView = self.joinButtonTitleNode.view.snapshotContentTree() {
                let backgroundFrame = self.joinButtonBackgroundNode.view.convert(self.joinButtonBackgroundNode.bounds, to: nil)
                let foregroundFrame = self.joinButtonTitleNode.view.convert(self.joinButtonTitleNode.bounds, to: nil)
                
                let backgroundView = UIView()
                backgroundView.backgroundColor = self.theme.chat.inputPanel.actionControlFillColor
                backgroundView.frame = backgroundFrame
                backgroundView.layer.cornerRadius = backgroundFrame.height / 2.0
                    
                foregroundView.frame = foregroundFrame
                return (backgroundView, foregroundView)
            }
        } else if !self.micButton.isHidden {
            if let foregroundView = self.micButtonForegroundNode.view.snapshotContentTree() {
                let backgroundFrame = self.micButtonBackgroundNode.view.convert(self.micButtonBackgroundNode.bounds, to: nil)
                let foregroundFrame = self.micButtonForegroundNode.view.convert(self.micButtonForegroundNode.bounds, to: nil)
                
                let backgroundView = UIView()
                backgroundView.backgroundColor = UIColor(rgb: 0x30b251)
                backgroundView.frame = backgroundFrame
                backgroundView.layer.cornerRadius = backgroundFrame.height / 2.0
                    
                foregroundView.frame = foregroundFrame
                return (backgroundView, foregroundView)
            }
        }
        
        return nil
    }
}
