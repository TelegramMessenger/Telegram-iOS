import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Bots: commands, menu buttons, attachment-menu bots and web views.
extension UpdateInterpreter {
    mutating func applyBotCommands(_ updateBotCommandsData: Api.Update.Cons_updateBotCommands) {
        let (peer, botId, apiCommands) = (updateBotCommandsData.peer, updateBotCommandsData.botId, updateBotCommandsData.commands)
        let botPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))
        let commands: [BotCommand] = apiCommands.map { command in
            switch command {
            case let .botCommand(botCommandData):
                let (flags, command, description) = (botCommandData.flags, botCommandData.command, botCommandData.description)
                return BotCommand(text: command, description: description, isEphemeral: (flags & (1 << 0)) != 0)
            }
        }
        updatedState.updateCachedPeerData(peer.peerId, { current in
            if peer.peerId.namespace == Namespaces.Peer.CloudUser, let previous = current as? CachedUserData {
                if let botInfo = previous.botInfo {
                    return previous.withUpdatedBotInfo(BotInfo(description: botInfo.description, photo: botInfo.photo, video: botInfo.video, commands: commands, menuButton: botInfo.menuButton, privacyPolicyUrl: botInfo.privacyPolicyUrl, appSettings: botInfo.appSettings, verifierSettings: botInfo.verifierSettings))
                }
            } else if peer.peerId.namespace == Namespaces.Peer.CloudGroup, let previous = current as? CachedGroupData {
                if let index = previous.botInfos.firstIndex(where: { $0.peerId == botPeerId }) {
                    var updatedBotInfos = previous.botInfos
                    let previousBotInfo = updatedBotInfos[index]
                    updatedBotInfos.remove(at: index)
                    updatedBotInfos.insert(CachedPeerBotInfo(peerId: botPeerId, botInfo: BotInfo(description: previousBotInfo.botInfo.description, photo: previousBotInfo.botInfo.photo, video: previousBotInfo.botInfo.video, commands: commands, menuButton: previousBotInfo.botInfo.menuButton, privacyPolicyUrl: previousBotInfo.botInfo.privacyPolicyUrl, appSettings: previousBotInfo.botInfo.appSettings, verifierSettings: previousBotInfo.botInfo.verifierSettings)), at: index)
                    return previous.withUpdatedBotInfos(updatedBotInfos)
                }
            } else if peer.peerId.namespace == Namespaces.Peer.CloudChannel, let previous = current as? CachedChannelData {
                if let index = previous.botInfos.firstIndex(where: { $0.peerId == botPeerId }) {
                    var updatedBotInfos = previous.botInfos
                    let previousBotInfo = updatedBotInfos[index]
                    updatedBotInfos.remove(at: index)
                    updatedBotInfos.insert(CachedPeerBotInfo(peerId: botPeerId, botInfo: BotInfo(description: previousBotInfo.botInfo.description, photo: previousBotInfo.botInfo.photo, video: previousBotInfo.botInfo.video, commands: commands, menuButton: previousBotInfo.botInfo.menuButton, privacyPolicyUrl: previousBotInfo.botInfo.privacyPolicyUrl, appSettings: previousBotInfo.botInfo.appSettings, verifierSettings: previousBotInfo.botInfo.verifierSettings)), at: index)
                    return previous.withUpdatedBotInfos(updatedBotInfos)
                }
            }
            return current
        })
    }
    
    mutating func applyBotMenuButton(_ updateBotMenuButtonData: Api.Update.Cons_updateBotMenuButton) {
        let (botId, button) = (updateBotMenuButtonData.botId, updateBotMenuButtonData.button)
        let botPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId))
        let menuButton = BotMenuButton(apiBotMenuButton: button)
        updatedState.updateCachedPeerData(botPeerId, { current in
            if let previous = current as? CachedUserData {
                if let botInfo = previous.botInfo {
                    return previous.withUpdatedBotInfo(BotInfo(description: botInfo.description, photo: botInfo.photo, video: botInfo.video, commands: botInfo.commands, menuButton: menuButton, privacyPolicyUrl: botInfo.privacyPolicyUrl, appSettings: botInfo.appSettings, verifierSettings: botInfo.verifierSettings))
                }
            }
            return current
        })
    }
    
    mutating func applyAttachMenuBots() {
        updatedState.addUpdateAttachMenuBots()
    }
    
    mutating func applyWebViewResultSent(_ updateWebViewResultSentData: Api.Update.Cons_updateWebViewResultSent) {
        updatedState.addDismissWebView(updateWebViewResultSentData.queryId)
    }
    
    mutating func applyJoinChatWebViewDecision(_ updateJoinChatWebViewDecisionData: Api.Update.Cons_updateJoinChatWebViewDecision) {
        updatedState.addJoinChatWebViewDecision(JoinChatWebViewDecision(peerId: updateJoinChatWebViewDecisionData.peer.peerId, queryId: updateJoinChatWebViewDecisionData.queryId, result: JoinChatWebViewResult(apiResult: updateJoinChatWebViewDecisionData.result)))
    }
}
