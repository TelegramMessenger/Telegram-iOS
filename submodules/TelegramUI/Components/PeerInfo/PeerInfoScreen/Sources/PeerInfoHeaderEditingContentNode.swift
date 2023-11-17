import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import AccountContext
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class PeerInfoHeaderEditingContentNode: ASDisplayNode {
    private let context: AccountContext
    private let requestUpdateLayout: () -> Void
    
    var requestEditing: (() -> Void)?
    
    let avatarNode: PeerInfoEditingAvatarNode
    let avatarTextNode: ImmediateTextNode
    let avatarButtonNode: HighlightableButtonNode
    
    var itemNodes: [PeerInfoHeaderTextFieldNodeKey: PeerInfoHeaderTextFieldNode] = [:]
    
    init(context: AccountContext, requestUpdateLayout: @escaping () -> Void) {
        self.context = context
        self.requestUpdateLayout = requestUpdateLayout
        
        self.avatarNode = PeerInfoEditingAvatarNode(context: context)
        
        self.avatarTextNode = ImmediateTextNode()
        self.avatarButtonNode = HighlightableButtonNode()
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.avatarButtonNode.addSubnode(self.avatarTextNode)
        
        self.avatarButtonNode.addTarget(self, action: #selector(textPressed), forControlEvents: .touchUpInside)
    }
    
    @objc private func textPressed() {
        self.requestEditing?()
    }
    
    func editingTextForKey(_ key: PeerInfoHeaderTextFieldNodeKey) -> String? {
        return self.itemNodes[key]?.text
    }
    
    func shakeTextForKey(_ key: PeerInfoHeaderTextFieldNodeKey) {
        self.itemNodes[key]?.layer.addShakeAnimation()
    }
    
    func update(width: CGFloat, safeInset: CGFloat, statusBarHeight: CGFloat, navigationHeight: CGFloat, isModalOverlay: Bool, peer: Peer?, threadData: MessageHistoryThreadData?, chatLocation: ChatLocation, cachedData: CachedPeerData?, isContact: Bool, isSettings: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) -> CGFloat {
        let avatarSize: CGFloat = isModalOverlay ? 200.0 : 100.0
        let avatarFrame = CGRect(origin: CGPoint(x: floor((width - avatarSize) / 2.0), y: statusBarHeight + 22.0), size: CGSize(width: avatarSize, height: avatarSize))
        transition.updateFrameAdditiveToCenter(node: self.avatarNode, frame: CGRect(origin: avatarFrame.center, size: CGSize()))
        
        var contentHeight: CGFloat = statusBarHeight + 10.0 + avatarSize + 20.0
        
        if canEditPeerInfo(context: self.context, peer: peer, chatLocation: chatLocation, threadData: threadData)  {
            if self.avatarButtonNode.supernode == nil {
                self.addSubnode(self.avatarButtonNode)
            }
            self.avatarTextNode.attributedText = NSAttributedString(string: presentationData.strings.Settings_SetNewProfilePhotoOrVideo, font: Font.regular(17.0), textColor: presentationData.theme.list.itemAccentColor)
            self.avatarButtonNode.accessibilityLabel = self.avatarTextNode.attributedText?.string
            
            let avatarTextSize = self.avatarTextNode.updateLayout(CGSize(width: width, height: 32.0))
            transition.updateFrame(node: self.avatarTextNode, frame: CGRect(origin: CGPoint(), size: avatarTextSize))
            transition.updateFrame(node: self.avatarButtonNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((width - avatarTextSize.width) / 2.0), y: contentHeight - 1.0), size: avatarTextSize))
            contentHeight += 32.0
        }
        
        var isEditableBot = false
        if let user = peer as? TelegramUser, let botInfo = user.botInfo, botInfo.flags.contains(.canEdit) {
            isEditableBot = true
        }
        var fieldKeys: [PeerInfoHeaderTextFieldNodeKey] = []
        if let user = peer as? TelegramUser {
            if !user.isDeleted {
                fieldKeys.append(.firstName)
                if isEditableBot {
                    fieldKeys.append(.description)
                } else if user.botInfo == nil {
                    fieldKeys.append(.lastName)
                }
            }
        } else if let _ = peer as? TelegramGroup {
            fieldKeys.append(.title)
            if canEditPeerInfo(context: self.context, peer: peer, chatLocation: chatLocation, threadData: threadData) {
                fieldKeys.append(.description)
            }
        } else if let _ = peer as? TelegramChannel {
            fieldKeys.append(.title)
            if canEditPeerInfo(context: self.context, peer: peer, chatLocation: chatLocation, threadData: threadData) {
                fieldKeys.append(.description)
            }
        }
        var hasPrevious = false
        for key in fieldKeys {
            let itemNode: PeerInfoHeaderTextFieldNode
            var updateText: String?
            if let current = self.itemNodes[key] {
                itemNode = current
            } else {
                var isMultiline = false
                switch key {
                case .firstName:
                    if let peer = peer as? TelegramUser {
                        if let editableBotInfo = (cachedData as? CachedUserData)?.editableBotInfo {
                            updateText = editableBotInfo.name
                        } else {
                            updateText = peer.firstName ?? ""
                        }
                    }
                case .lastName:
                    updateText = (peer as? TelegramUser)?.lastName ?? ""
                case .title:
                    updateText = peer?.debugDisplayTitle ?? ""
                case .description:
                    isMultiline = true
                    if let cachedData = cachedData as? CachedChannelData {
                        updateText = cachedData.about ?? ""
                    } else if let cachedData = cachedData as? CachedGroupData {
                        updateText = cachedData.about ?? ""
                    } else if let cachedData = cachedData as? CachedUserData {
                        if let editableBotInfo = cachedData.editableBotInfo {
                            updateText = editableBotInfo.about
                        } else {
                            updateText = cachedData.about ?? ""
                        }
                    } else {
                        updateText = ""
                    }
                }
                if isMultiline {
                    itemNode = PeerInfoHeaderMultiLineTextFieldNode(requestUpdateHeight: { [weak self] in
                        self?.requestUpdateLayout()
                    })
                } else {
                    itemNode = PeerInfoHeaderSingleLineTextFieldNode()
                }
                self.itemNodes[key] = itemNode
                self.addSubnode(itemNode)
            }
            let placeholder: String
            var isEnabled = true
            switch key {
            case .firstName:
                placeholder = isEditableBot ? presentationData.strings.UserInfo_BotNamePlaceholder : presentationData.strings.UserInfo_FirstNamePlaceholder
                isEnabled = isContact || isSettings || isEditableBot
            case .lastName:
                placeholder = presentationData.strings.UserInfo_LastNamePlaceholder
                isEnabled = isContact || isSettings
            case .title:
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    placeholder = presentationData.strings.GroupInfo_ChannelListNamePlaceholder
                } else {
                    placeholder = presentationData.strings.GroupInfo_GroupNamePlaceholder
                }
                isEnabled = canEditPeerInfo(context: self.context, peer: peer, chatLocation: chatLocation, threadData: threadData)
            case .description:
                placeholder = presentationData.strings.Channel_Edit_AboutItem
                isEnabled = canEditPeerInfo(context: self.context, peer: peer, chatLocation: chatLocation, threadData: threadData) || isEditableBot
            }
            let itemHeight = itemNode.update(width: width, safeInset: safeInset, isSettings: isSettings, hasPrevious: hasPrevious, hasNext: key != fieldKeys.last, placeholder: placeholder, isEnabled: isEnabled, presentationData: presentationData, updateText: updateText)
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: width, height: itemHeight)))
            contentHeight += itemHeight
            hasPrevious = true
        }
        var removeKeys: [PeerInfoHeaderTextFieldNodeKey] = []
        for (key, _) in self.itemNodes {
            if !fieldKeys.contains(key) {
                removeKeys.append(key)
            }
        }
        for key in removeKeys {
            if let itemNode = self.itemNodes.removeValue(forKey: key) {
                itemNode.removeFromSupernode()
            }
        }
        
        return contentHeight
    }
}
