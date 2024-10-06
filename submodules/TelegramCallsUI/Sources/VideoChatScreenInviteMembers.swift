import Foundation
import UIKit
import Display
import TelegramCore
import SwiftSignalKit
import PeerInfoUI
import OverlayStatusController
import PresentationDataUtils

extension VideoChatScreenComponent.View {
    func openInviteMembers() {
        guard let component = self.component else {
            return
        }
        
        var canInvite = true
        var inviteIsLink = false
        if case let .channel(peer) = self.peer {
            if peer.flags.contains(.isGigagroup) {
                if peer.flags.contains(.isCreator) || peer.adminRights != nil {
                } else {
                    canInvite = false
                }
            }
            if case .broadcast = peer.info, !(peer.addressName?.isEmpty ?? true) {
                inviteIsLink = true
            }
        }
        var inviteType: VideoChatParticipantsComponent.Participants.InviteType?
        if canInvite {
            if inviteIsLink {
                inviteType = .shareLink
            } else {
                inviteType = .invite
            }
        }
        
        guard let inviteType else {
            return
        }
        
        switch inviteType {
        case .invite:
            let groupPeer = component.call.accountContext.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: component.call.peerId))
            let _ = (groupPeer
                     |> deliverOnMainQueue).start(next: { [weak self] groupPeer in
                guard let self, let component = self.component, let environment = self.environment, let groupPeer else {
                    return
                }
                let inviteLinks = self.inviteLinks
                
                if case let .channel(groupPeer) = groupPeer {
                    var canInviteMembers = true
                    if case .broadcast = groupPeer.info, !(groupPeer.addressName?.isEmpty ?? true) {
                        canInviteMembers = false
                    }
                    if !canInviteMembers {
                        if let inviteLinks {
                            self.presentShare(inviteLinks)
                        }
                        return
                    }
                }
                
                var filters: [ChannelMembersSearchFilter] = []
                if let members = self.members {
                    filters.append(.disable(Array(members.participants.map { $0.peer.id })))
                }
                if case let .channel(groupPeer) = groupPeer {
                    if !groupPeer.hasPermission(.inviteMembers) && inviteLinks?.listenerLink == nil {
                        filters.append(.excludeNonMembers)
                    }
                } else if case let .legacyGroup(groupPeer) = groupPeer {
                    if groupPeer.hasBannedPermission(.banAddMembers) {
                        filters.append(.excludeNonMembers)
                    }
                }
                filters.append(.excludeBots)
                
                var dismissController: (() -> Void)?
                let controller = ChannelMembersSearchController(context: component.call.accountContext, peerId: groupPeer.id, forceTheme: environment.theme, mode: .inviteToCall, filters: filters, openPeer: { [weak self] peer, participant in
                    guard let self, let component = self.component, let environment = self.environment else {
                        dismissController?()
                        return
                    }
                    guard let callState = self.callState else {
                        return
                    }
                    
                    let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                    if peer.id == callState.myPeerId {
                        return
                    }
                    if let participant {
                        dismissController?()
                        
                        if component.call.invitePeer(participant.peer.id) {
                            let text: String
                            if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                                text = environment.strings.LiveStream_InvitedPeerText(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                            } else {
                                text = environment.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                            }
                            self.presentUndoOverlay(content: .invitedToVoiceChat(context: component.call.accountContext, peer: EnginePeer(participant.peer), title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                        }
                    } else {
                        if case let .channel(groupPeer) = groupPeer, let listenerLink = inviteLinks?.listenerLink, !groupPeer.hasPermission(.inviteMembers) {
                            let text = environment.strings.VoiceChat_SendPublicLinkText(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), EnginePeer(groupPeer).displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                            
                            environment.controller()?.present(textAlertController(context: component.call.accountContext, forceTheme: environment.theme, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: environment.strings.VoiceChat_SendPublicLinkSend, action: { [weak self] in
                                dismissController?()
                                
                                guard let self, let component = self.component else {
                                    return
                                }
                                
                                let _ = (enqueueMessages(account: component.call.accountContext.account, peerId: peer.id, messages: [.message(text: listenerLink, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
                                         |> deliverOnMainQueue).start(next: { [weak self] _ in
                                    guard let self, let environment = self.environment else {
                                        return
                                    }
                                    self.presentUndoOverlay(content: .forward(savedMessages: false, text: environment.strings.UserInfo_LinkForwardTooltip_Chat_One(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string), action: { _ in return true })
                                })
                            })]), in: .window(.root))
                        } else {
                            let text: String
                            if case let .channel(groupPeer) = groupPeer, case .broadcast = groupPeer.info {
                                text = environment.strings.VoiceChat_InviteMemberToChannelFirstText(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), EnginePeer(groupPeer).displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                            } else {
                                text = environment.strings.VoiceChat_InviteMemberToGroupFirstText(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), groupPeer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                            }
                            
                            environment.controller()?.present(textAlertController(context: component.call.accountContext, forceTheme: environment.theme, title: nil, text: text, actions: [TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: environment.strings.VoiceChat_InviteMemberToGroupFirstAdd, action: { [weak self] in
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                
                                if case let .channel(groupPeer) = groupPeer {
                                    guard let selfController = environment.controller() else {
                                        return
                                    }
                                    let inviteDisposable = self.inviteDisposable
                                    var inviteSignal = component.call.accountContext.peerChannelMemberCategoriesContextsManager.addMembers(engine: component.call.accountContext.engine, peerId: groupPeer.id, memberIds: [peer.id])
                                    var cancelImpl: (() -> Void)?
                                    let progressSignal = Signal<Never, NoError> { [weak selfController] subscriber in
                                        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                            cancelImpl?()
                                        }))
                                        selfController?.present(controller, in: .window(.root))
                                        return ActionDisposable { [weak controller] in
                                            Queue.mainQueue().async() {
                                                controller?.dismiss()
                                            }
                                        }
                                    }
                                    |> runOn(Queue.mainQueue())
                                    |> delay(0.15, queue: Queue.mainQueue())
                                    let progressDisposable = progressSignal.start()
                                    
                                    inviteSignal = inviteSignal
                                    |> afterDisposed {
                                        Queue.mainQueue().async {
                                            progressDisposable.dispose()
                                        }
                                    }
                                    cancelImpl = {
                                        inviteDisposable.set(nil)
                                    }
                                    
                                    inviteDisposable.set((inviteSignal |> deliverOnMainQueue).start(error: { [weak self] error in
                                        dismissController?()
                                        guard let self, let component = self.component, let environment = self.environment else {
                                            return
                                        }
                                        
                                        let text: String
                                        switch error {
                                        case .limitExceeded:
                                            text = environment.strings.Channel_ErrorAddTooMuch
                                        case .tooMuchJoined:
                                            text = environment.strings.Invite_ChannelsTooMuch
                                        case .generic:
                                            text = environment.strings.Login_UnknownError
                                        case .restricted:
                                            text = environment.strings.Channel_ErrorAddBlocked
                                        case .notMutualContact:
                                            if case .broadcast = groupPeer.info {
                                                text = environment.strings.Channel_AddUserLeftError
                                            } else {
                                                text = environment.strings.GroupInfo_AddUserLeftError
                                            }
                                        case .botDoesntSupportGroups:
                                            text = environment.strings.Channel_BotDoesntSupportGroups
                                        case .tooMuchBots:
                                            text = environment.strings.Channel_TooMuchBots
                                        case .bot:
                                            text = environment.strings.Login_UnknownError
                                        case .kicked:
                                            text = environment.strings.Channel_AddUserKickedError
                                        }
                                        environment.controller()?.present(textAlertController(context: component.call.accountContext, forceTheme: environment.theme, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {})]), in: .window(.root))
                                    }, completed: { [weak self] in
                                        guard let self, let component = self.component, let environment = self.environment else {
                                            dismissController?()
                                            return
                                        }
                                        dismissController?()
                                        
                                        if component.call.invitePeer(peer.id) {
                                            let text: String
                                            if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                                                text = environment.strings.LiveStream_InvitedPeerText(peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                            } else {
                                                text = environment.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                            }
                                            self.presentUndoOverlay(content: .invitedToVoiceChat(context: component.call.accountContext, peer: peer, title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                                        }
                                    }))
                                } else if case let .legacyGroup(groupPeer) = groupPeer {
                                    guard let selfController = environment.controller() else {
                                        return
                                    }
                                    let inviteDisposable = self.inviteDisposable
                                    var inviteSignal = component.call.accountContext.engine.peers.addGroupMember(peerId: groupPeer.id, memberId: peer.id)
                                    var cancelImpl: (() -> Void)?
                                    let progressSignal = Signal<Never, NoError> { [weak selfController] subscriber in
                                        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                            cancelImpl?()
                                        }))
                                        selfController?.present(controller, in: .window(.root))
                                        return ActionDisposable { [weak controller] in
                                            Queue.mainQueue().async() {
                                                controller?.dismiss()
                                            }
                                        }
                                    }
                                    |> runOn(Queue.mainQueue())
                                    |> delay(0.15, queue: Queue.mainQueue())
                                    let progressDisposable = progressSignal.start()
                                    
                                    inviteSignal = inviteSignal
                                    |> afterDisposed {
                                        Queue.mainQueue().async {
                                            progressDisposable.dispose()
                                        }
                                    }
                                    cancelImpl = {
                                        inviteDisposable.set(nil)
                                    }
                                    
                                    inviteDisposable.set((inviteSignal |> deliverOnMainQueue).start(error: { [weak self] error in
                                        dismissController?()
                                        guard let self, let component = self.component, let environment = self.environment else {
                                            return
                                        }
                                        let context = component.call.accountContext
                                        
                                        switch error {
                                        case .privacy:
                                            let _ = (component.call.accountContext.account.postbox.loadedPeerWithId(peer.id)
                                                     |> deliverOnMainQueue).start(next: { [weak self] peer in
                                                guard let self, let component = self.component, let environment = self.environment else {
                                                    return
                                                }
                                                environment.controller()?.present(textAlertController(context: component.call.accountContext, title: nil, text: environment.strings.Privacy_GroupsAndChannels_InviteToGroupError(EnginePeer(peer).compactDisplayTitle, EnginePeer(peer).compactDisplayTitle).string, actions: [TextAlertAction(type: .genericAction, title: environment.strings.Common_OK, action: {})]), in: .window(.root))
                                            })
                                        case .notMutualContact:
                                            environment.controller()?.present(textAlertController(context: context, title: nil, text: environment.strings.GroupInfo_AddUserLeftError, actions: [TextAlertAction(type: .genericAction, title: environment.strings.Common_OK, action: {})]), in: .window(.root))
                                        case .tooManyChannels:
                                            environment.controller()?.present(textAlertController(context: context, title: nil, text: environment.strings.Invite_ChannelsTooMuch, actions: [TextAlertAction(type: .genericAction, title: environment.strings.Common_OK, action: {})]), in: .window(.root))
                                        case .groupFull, .generic:
                                            environment.controller()?.present(textAlertController(context: context, forceTheme: environment.theme, title: nil, text: environment.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_OK, action: {})]), in: .window(.root))
                                        }
                                    }, completed: { [weak self] in
                                        guard let self, let component = self.component, let environment = self.environment else {
                                            dismissController?()
                                            return
                                        }
                                        dismissController?()
                                        
                                        if component.call.invitePeer(peer.id) {
                                            let text: String
                                            if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                                                text = environment.strings.LiveStream_InvitedPeerText(peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                            } else {
                                                text = environment.strings.VoiceChat_InvitedPeerText(peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                            }
                                            self.presentUndoOverlay(content: .invitedToVoiceChat(context: component.call.accountContext, peer: peer, title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                                        }
                                    }))
                                }
                            })]), in: .window(.root))
                        }
                    }
                })
                controller.copyInviteLink = { [weak self] in
                    dismissController?()
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    let callPeerId = component.call.peerId
                    
                    let _ = (component.call.accountContext.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: callPeerId),
                        TelegramEngine.EngineData.Item.Peer.ExportedInvitation(id: callPeerId)
                    )
                             |> map { peer, exportedInvitation -> String? in
                        if let link = inviteLinks?.listenerLink {
                            return link
                        } else if let peer = peer, let addressName = peer.addressName, !addressName.isEmpty {
                            return "https://t.me/\(addressName)"
                        } else if let link = exportedInvitation?.link {
                            return link
                        } else {
                            return nil
                        }
                    }
                             |> deliverOnMainQueue).start(next: { [weak self] link in
                        guard let self, let environment = self.environment else {
                            return
                        }
                        
                        if let link {
                            UIPasteboard.general.string = link
                            
                            self.presentUndoOverlay(content: .linkCopied(text: environment.strings.VoiceChat_InviteLinkCopiedText), action: { _ in return false })
                        }
                    })
                }
                dismissController = { [weak controller] in
                    controller?.dismiss()
                }
                environment.controller()?.push(controller)
            })
        case .shareLink:
            guard let inviteLinks = self.inviteLinks else {
                return
            }
            self.presentShare(inviteLinks)
        }
    }
}
