import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import LegacyComponents

final class ChatTitleView: UIView, NavigationBarTitleView {
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private let titleNode: ASTextNode
    private let infoNode: ASTextNode
    private let typingNode: ASTextNode
    private var typingIndicator: TGModernConversationTitleActivityIndicator?
    private let button: HighlightTrackingButton
    
    private var presenceManager: PeerPresenceStatusManager?
    
    var inputActivities: (PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            if let (peerId, inputActivities) = self.inputActivities, !inputActivities.isEmpty {
                self.typingNode.isHidden = false
                self.infoNode.isHidden = true
                var stringValue = ""
                var first = true
                var mergedActivity = inputActivities[0].1
                for (_, activity) in inputActivities {
                    if activity != mergedActivity {
                        mergedActivity = .typingText
                        break
                    }
                }
                if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat {
                    switch mergedActivity {
                        case .recordingVoice:
                            stringValue = strings.Activity_RecordingAudio
                        default:
                            stringValue = strings.Conversation_typing
                    }
                } else {
                    for (peer, _) in inputActivities {
                        let title = peer.compactDisplayTitle
                        if !title.isEmpty {
                            if first {
                                first = false
                            } else {
                                stringValue += ", "
                            }
                            stringValue += title
                        }
                    }
                }
                let string = NSAttributedString(string: stringValue, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.accentTextColor)
                if self.typingNode.attributedText == nil || !self.typingNode.attributedText!.isEqual(to: string) {
                    self.typingNode.attributedText = string
                    self.setNeedsLayout()
                }
                if self.typingIndicator == nil {
                    let typingIndicator = TGModernConversationTitleActivityIndicator()
                    //typingIndicator.setColor(self.theme.rootController.navigationBar.accentTextColor)
                    self.addSubview(typingIndicator)
                    self.typingIndicator = typingIndicator
                }
                switch mergedActivity {
                    case .typingText:
                        self.typingIndicator?.setTyping()
                    case .recordingVoice:
                        self.typingIndicator?.setAudioRecording()
                    case .uploadingFile:
                        self.typingIndicator?.setUploading()
                    case .playingGame:
                        self.typingIndicator?.setPlaying()
                    case .recordingInstantVideo:
                        self.typingIndicator?.setAudioRecording()
                    case .uploadingInstantVideo:
                        self.typingIndicator?.setUploading()
                }
            } else {
                self.typingNode.isHidden = true
                self.infoNode.isHidden = false
                self.typingNode.attributedText = nil
                if let typingIndicator = self.typingIndicator {
                    typingIndicator.removeFromSuperview()
                    self.typingIndicator = nil
                }
            }
        }
    }
    
    var pressed: (() -> Void)?
    
    var peerView: PeerView? {
        didSet {
            if let peerView = self.peerView, let peer = peerViewMainPeer(peerView) {
                let string = NSAttributedString(string: peer.displayTitle, font: Font.medium(17.0), textColor: self.theme.rootController.navigationBar.primaryTextColor)
                
                if self.titleNode.attributedText == nil || !self.titleNode.attributedText!.isEqual(to: string) {
                    self.titleNode.attributedText = string
                    self.setNeedsLayout()
                }
                
                self.updateStatus()
            }
        }
    }
    
    private func updateStatus() {
        var shouldUpdateLayout = false
        if let peerView = self.peerView, let peer = peerViewMainPeer(peerView) {
            if let user = peer as? TelegramUser {
                if let _ = user.botInfo {
                    let string = NSAttributedString(string: self.strings.Bot_GenericBotStatus, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                } else if let peer = peerViewMainPeer(peerView), let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    let (string, activity) = stringAndActivityForUserPresence(strings: self.strings, presence: presence, relativeTo: Int32(timestamp))
                    let attributedString = NSAttributedString(string: string, font: Font.regular(13.0), textColor: activity ? self.theme.rootController.navigationBar.accentTextColor : self.theme.rootController.navigationBar.secondaryTextColor)
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: attributedString) {
                        self.infoNode.attributedText = attributedString
                        shouldUpdateLayout = true
                    }
                    
                    self.presenceManager?.reset(presence: presence)
                } else {
                    let string = NSAttributedString(string: strings.Presence_offline, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                }
            } else if let group = peer as? TelegramGroup {
                var onlineCount = 0
                if let cachedGroupData = peerView.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    for participant in participants.participants {
                        if let presence = peerView.peerPresences[participant.peerId] as? TelegramUserPresence {
                            let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: Int32(timestamp))
                            switch relativeStatus {
                                case .online:
                                    onlineCount += 1
                                default:
                                    break
                            }
                        }
                    }
                }
                if onlineCount > 1 {
                    let string = NSMutableAttributedString()
                    
                    string.append(NSAttributedString(string: "\(strings.Conversation_StatusMembers(Int32(group.participantCount))), ", font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor))
                    string.append(NSAttributedString(string: strings.Conversation_StatusOnline(Int32(onlineCount)), font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor))
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                } else {
                    let string = NSAttributedString(string: strings.Conversation_StatusMembers(Int32(group.participantCount)), font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                }
            } else if let channel = peer as? TelegramChannel {
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                    let string = NSAttributedString(string: strings.Conversation_StatusMembers(memberCount), font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                } else {
                    switch channel.info {
                        case .group:
                            let string = NSAttributedString(string: strings.Group_Status, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                            if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                                self.infoNode.attributedText = string
                                shouldUpdateLayout = true
                            }
                        case .broadcast:
                            let string = NSAttributedString(string: strings.Channel_Status, font: Font.regular(13.0), textColor: self.theme.rootController.navigationBar.secondaryTextColor)
                            if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                                self.infoNode.attributedText = string
                                shouldUpdateLayout = true
                            }
                    }
                }
            }
            
            if shouldUpdateLayout {
                self.setNeedsLayout()
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.strings = strings
        
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.infoNode = ASTextNode()
        self.infoNode.displaysAsynchronously = false
        self.infoNode.maximumNumberOfLines = 1
        self.infoNode.truncationMode = .byTruncatingTail
        self.infoNode.isOpaque = false
        
        self.typingNode = ASTextNode()
        self.typingNode.displaysAsynchronously = false
        self.typingNode.maximumNumberOfLines = 1
        self.typingNode.truncationMode = .byTruncatingTail
        self.typingNode.isOpaque = false
        
        self.button = HighlightTrackingButton()
        
        super.init(frame: CGRect())
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.infoNode)
        self.addSubnode(self.typingNode)
        self.addSubview(self.button)
        
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            self?.updateStatus()
        })
        
        self.button.addTarget(self, action: #selector(buttonPressed), for: [.touchUpInside])
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.infoNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.typingNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.infoNode.alpha = 0.4
                    strongSelf.typingNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.infoNode.alpha = 1.0
                    strongSelf.typingNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.infoNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.typingNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        if size.height > 40.0 {
            let titleSize = self.titleNode.measure(size)
            let infoSize = self.infoNode.measure(size)
            let typingSize = self.typingNode.measure(size)
            let titleInfoSpacing: CGFloat = 0.0
            
            let combinedHeight = titleSize.height + infoSize.height + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - infoSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + titleInfoSpacing), size: infoSize)
            self.typingNode.frame = CGRect(origin: CGPoint(x: floor((size.width - typingSize.width + 14.0) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + titleInfoSpacing), size: typingSize)
            
            if let typingIndicator = self.typingIndicator {
                typingIndicator.frame = CGRect(x: self.typingNode.frame.origin.x - 24.0, y: self.typingNode.frame.origin.y, width: 24.0, height: 16.0)
            }
        } else {
            let titleSize = self.titleNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            let infoSize = self.infoNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            let typingSize = self.typingNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            
            let titleInfoSpacing: CGFloat = 8.0
            let combinedWidth = titleSize.width + infoSize.width + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0 + titleSize.width + titleInfoSpacing), y: floor((size.height - infoSize.height) / 2.0)), size: infoSize)
            self.typingNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0 + titleSize.width + titleInfoSpacing), y: floor((size.height - typingSize.height) / 2.0)), size: typingSize)
        }
    }
    
    @objc func buttonPressed() {
        if let pressed = self.pressed {
            pressed()
        }
    }
    
    func animateLayoutTransition() {
        UIView.transition(with: self, duration: 0.25, options: [.transitionCrossDissolve], animations: {
            
        }, completion: nil)
    }
}
