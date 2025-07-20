import Foundation
import UIKit
import Display
import SSignalKit
import SwiftSignalKit
import AccountContext
import TelegramCore
import ContextUI
import DeleteChatPeerActionSheetItem
import UndoUI
import LegacyComponents
import WebSearchUI
import MapResourceToAvatarSizes
import LegacyUI
import LegacyMediaPickerUI
import AVFoundation

extension VideoChatScreenComponent.View {
    func openParticipantContextMenu(id: EnginePeer.Id, sourceView: ContextExtractedContentContainingView, gesture: ContextGesture?) {
        guard let environment = self.environment else {
            return
        }
        guard let members = self.members, let participant = members.participants.first(where: { $0.id == .peer(id) }) else {
            return
        }
        guard let currentCall = self.currentCall else {
            return
        }
        
        let muteStatePromise = Promise<GroupCallParticipantsContext.Participant.MuteState?>(participant.muteState)
           
        let itemsForEntry: (GroupCallParticipantsContext.Participant.MuteState?) -> [ContextMenuItem] = { [weak self] muteState in
            guard let self, let environment = self.environment, let currentCall = self.currentCall else {
                return []
            }
            guard let callState = self.callState else {
                return []
            }
            
            guard let peer = participant.peer else {
                return []
            }
            
            var items: [ContextMenuItem] = []
            var hasVolumeSlider = false
            
            if let muteState = muteState, !muteState.canUnmute || muteState.mutedByYou {
            } else {
                if callState.canManageCall || callState.myPeerId != id {
                    hasVolumeSlider = true
                    
                    let minValue: CGFloat
                    if callState.canManageCall && callState.adminIds.contains(peer.id) && muteState != nil {
                        minValue = 0.01
                    } else {
                        minValue = 0.0
                    }
                    items.append(.custom(VoiceChatVolumeContextItem(minValue: minValue, value: participant.volume.flatMap { CGFloat($0) / 10000.0 } ?? 1.0, valueChanged: { [weak self] newValue, finished in
                        guard let self, case let .group(groupCall) = self.currentCall else {
                            return
                        }
                        
                        if finished && newValue.isZero {
                            let updatedMuteState = groupCall.updateMuteState(peerId: peer.id, isMuted: true)
                            muteStatePromise.set(.single(updatedMuteState))
                        } else {
                            groupCall.setVolume(peerId: peer.id, volume: Int32(newValue * 10000), sync: finished)
                        }
                    }), true))
                }
            }
            
            if callState.myPeerId == id && !hasVolumeSlider && ((participant.about?.isEmpty ?? true) || participant.peer?.smallProfileImage == nil) {
                items.append(.custom(VoiceChatInfoContextItem(text: environment.strings.VoiceChat_ImproveYourProfileText, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Tip"), color: theme.actionSheet.primaryTextColor)
                }), true))
            }
                                
            if peer.id == callState.myPeerId {
                if participant.hasRaiseHand {
                    items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_CancelSpeakRequest, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/RevokeSpeak"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        guard let self, case let .group(groupCall) = self.currentCall else {
                            return
                        }
                        groupCall.lowerHand()
                        
                        f(.default)
                    })))
                }
                items.append(.action(ContextMenuActionItem(text: peer.smallProfileImage == nil ? environment.strings.VoiceChat_AddPhoto : environment.strings.VoiceChat_ChangePhoto, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Camera"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    Queue.mainQueue().after(0.1) {
                        guard let self else {
                            return
                        }
                        
                        self.openAvatarForEditing(fromGallery: false, completion: {})
                    }
                })))
                
                items.append(.action(ContextMenuActionItem(text: (participant.about?.isEmpty ?? true) ? environment.strings.VoiceChat_AddBio : environment.strings.VoiceChat_EditBio, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    Queue.mainQueue().after(0.1) {
                        guard let self, let environment = self.environment, let currentCall = self.currentCall else {
                            return
                        }
                        let maxBioLength: Int
                        if peer.id.namespace == Namespaces.Peer.CloudUser {
                            maxBioLength = 70
                        } else {
                            maxBioLength = 100
                        }
                        let controller = voiceChatTitleEditController(sharedContext: currentCall.accountContext.sharedContext, account: currentCall.accountContext.account, forceTheme: environment.theme, title: environment.strings.VoiceChat_EditBioTitle, text: environment.strings.VoiceChat_EditBioText, placeholder: environment.strings.VoiceChat_EditBioPlaceholder, doneButtonTitle: environment.strings.VoiceChat_EditBioSave, value: participant.about, maxLength: maxBioLength, apply: { [weak self] bio in
                            guard let self, let environment = self.environment, let currentCall = self.currentCall, let bio else {
                                return
                            }
                            if peer.id.namespace == Namespaces.Peer.CloudUser {
                                let _ = (currentCall.accountContext.engine.accountData.updateAbout(about: bio)
                                |> `catch` { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }).start()
                            } else {
                                let _ = (currentCall.accountContext.engine.peers.updatePeerDescription(peerId: peer.id, description: bio)
                                |> `catch` { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }).start()
                            }
                            
                            self.presentUndoOverlay(content: .info(title: nil, text: environment.strings.VoiceChat_EditBioSuccess, timeout: nil, customUndoText: nil), action: { _ in return false })
                        })
                        environment.controller()?.present(controller, in: .window(.root))
                    }
                })))
                
                if case let .user(peer) = peer {
                    items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_ChangeName, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/ChangeName"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        f(.default)
                           
                        Queue.mainQueue().after(0.1) {
                            guard let self, let environment = self.environment, let currentCall = self.currentCall else {
                                return
                            }
                            let controller = voiceChatUserNameController(sharedContext: currentCall.accountContext.sharedContext, account: currentCall.accountContext.account, forceTheme: environment.theme, title: environment.strings.VoiceChat_ChangeNameTitle, firstNamePlaceholder: environment.strings.UserInfo_FirstNamePlaceholder, lastNamePlaceholder: environment.strings.UserInfo_LastNamePlaceholder, doneButtonTitle: environment.strings.VoiceChat_EditBioSave, firstName: peer.firstName, lastName: peer.lastName, maxLength: 128, apply: { [weak self] firstAndLastName in
                                guard let self, let environment = self.environment, let currentCall = self.currentCall, let (firstName, lastName) = firstAndLastName else {
                                    return
                                }
                                let _ = currentCall.accountContext.engine.accountData.updateAccountPeerName(firstName: firstName, lastName: lastName).startStandalone()
                                
                                self.presentUndoOverlay(content: .info(title: nil, text: environment.strings.VoiceChat_EditNameSuccess, timeout: nil, customUndoText: nil), action: { _ in return false })
                            })
                            environment.controller()?.present(controller, in: .window(.root))
                        }
                    })))
                }
            } else {
                if (callState.canManageCall || callState.adminIds.contains(currentCall.accountContext.account.peerId)) {
                    if callState.adminIds.contains(peer.id) {
                        if let _ = muteState {
                        } else {
                            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_MutePeer, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                guard let self, case let .group(groupCall) = self.currentCall else {
                                    return
                                }
                                
                                let _ = groupCall.updateMuteState(peerId: peer.id, isMuted: true)
                                f(.default)
                            })))
                        }
                    } else {
                        if let muteState = muteState, !muteState.canUnmute {
                            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_UnmutePeer, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: participant.hasRaiseHand ? "Call/Context Menu/AllowToSpeak" : "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                                    return
                                }
                                
                                let _ = groupCall.updateMuteState(peerId: peer.id, isMuted: false)
                                f(.default)
                                
                                if let participantPeer = participant.peer {
                                    self.presentUndoOverlay(content: .voiceChatCanSpeak(text: environment.strings.VoiceChat_UserCanNowSpeak(participantPeer.displayTitle(strings: environment.strings, displayOrder: groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string), action: { _ in return true })
                                }
                            })))
                        } else {
                            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_MutePeer, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                guard let self, case let .group(groupCall) = self.currentCall else {
                                    return
                                }
                                
                                let _ = groupCall.updateMuteState(peerId: peer.id, isMuted: true)
                                f(.default)
                            })))
                        }
                    }
                } else {
                    if let muteState = muteState, muteState.mutedByYou {
                        items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_UnmuteForMe, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                        }, action: { [weak self] _, f in
                            guard let self, case let .group(groupCall) = self.currentCall else {
                                return
                            }
                            let _ = groupCall.updateMuteState(peerId: peer.id, isMuted: false)
                            f(.default)
                        })))
                    } else {
                        items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_MuteForMe, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                        }, action: { [weak self] _, f in
                            guard let self, case let .group(groupCall) = self.currentCall else {
                                return
                            }
                            
                            let _ = groupCall.updateMuteState(peerId: peer.id, isMuted: true)
                            f(.default)
                        })))
                    }
                }
                
                let openTitle: String
                let openIcon: UIImage?
                if [Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup].contains(peer.id.namespace) {
                    if case let .channel(peer) = peer, case .broadcast = peer.info {
                        openTitle = environment.strings.VoiceChat_OpenChannel
                        openIcon = UIImage(bundleImageName: "Chat/Context Menu/Channels")
                    } else {
                        openTitle = environment.strings.VoiceChat_OpenGroup
                        openIcon = UIImage(bundleImageName: "Chat/Context Menu/Groups")
                    }
                } else {
                    openTitle = environment.strings.Conversation_ContextMenuSendMessage
                    openIcon = UIImage(bundleImageName: "Chat/Context Menu/Message")
                }
                items.append(.action(ContextMenuActionItem(text: openTitle, icon: { theme in
                    return generateTintedImage(image: openIcon, color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    guard let self, let environment = self.environment, let currentCall = self.currentCall else {
                        return
                    }
                    
                    guard let controller = environment.controller() as? VideoChatScreenV2Impl, let navigationController = controller.parentNavigationController else {
                        return
                    }
                
                    let context = currentCall.accountContext
                    controller.dismiss(completion: { [weak navigationController] in
                        Queue.mainQueue().after(0.1) {
                            guard let navigationController else {
                                return
                            }
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always, purposefulAction: {}, peekData: nil))
                        }
                    })
                
                    f(.dismissWithoutContent)
                })))
            
                if case let .group(groupCall) = self.currentCall, (callState.canManageCall && !callState.adminIds.contains(peer.id)), peer.id != groupCall.peerId {
                    items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_RemovePeer, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
                    }, action: { [weak self] c, _ in
                        c?.dismiss(completion: {
                            guard let self, case let .group(groupCall) = self.currentCall else {
                                return
                            }
                            
                            let chatPeer: Signal<EnginePeer?, NoError>
                            if let peerId = groupCall.peerId {
                                chatPeer = groupCall.accountContext.engine.data.get(
                                    TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                                )
                            } else {
                                chatPeer = .single(nil)
                            }

                            let _ = (chatPeer
                            |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                                guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                                    return
                                }
                                
                                let presentationData = groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                                let actionSheet = ActionSheetController(presentationData: presentationData)
                                var items: [ActionSheetItem] = []
                                
                                let nameDisplayOrder = presentationData.nameDisplayOrder
                                if let chatPeer {
                                    items.append(DeleteChatPeerActionSheetItem(context: groupCall.accountContext, peer: peer, chatPeer: chatPeer, action: .removeFromGroup, strings: environment.strings, nameDisplayOrder: nameDisplayOrder))
                                } else {
                                    items.append(ActionSheetTextItem(title: environment.strings.VoiceChat_RemoveConferencePeerConfirmation(peer.displayTitle(strings: environment.strings, displayOrder: nameDisplayOrder)).string, parseMarkdown: true))
                                }

                                items.append(ActionSheetButtonItem(title: environment.strings.VoiceChat_RemovePeerRemove, color: .destructive, action: { [weak self, weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                    
                                    guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                                        return
                                    }
                                    
                                    if groupCall.isConference {
                                        groupCall.kickPeer(id: peer.id)
                                    } else {
                                        if let callPeerId = groupCall.peerId {
                                            let _ = groupCall.accountContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: groupCall.accountContext.engine, peerId: callPeerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)).start()
                                            groupCall.removedPeer(peer.id)
                                        }
                                    }
                                    
                                    self.presentUndoOverlay(content: .banned(text: environment.strings.VoiceChat_RemovedPeerText(peer.displayTitle(strings: environment.strings, displayOrder: nameDisplayOrder)).string), action: { _ in return false })
                                }))

                                actionSheet.setItemGroups([
                                    ActionSheetItemGroup(items: items),
                                    ActionSheetItemGroup(items: [
                                        ActionSheetButtonItem(title: environment.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                            actionSheet?.dismissAnimated()
                                        })
                                    ])
                                ])
                                environment.controller()?.present(actionSheet, in: .window(.root))
                            })
                        })
                    })))
                }
            }
            return items
        }
        
        let items = muteStatePromise.get()
        |> map { muteState -> [ContextMenuItem] in
            return itemsForEntry(muteState)
        }
        
        let presentationData = currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
        let contextController = ContextController(
            presentationData: presentationData,
            source: .extracted(ParticipantExtractedContentSource(contentView: sourceView)),
            items: items |> map { items in
                return ContextController.Items(content: .list(items))
            },
            recognizer: nil,
            gesture: gesture
        )
        
        environment.controller()?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
        
        environment.controller()?.presentInGlobalOverlay(contextController)
    }
    
    func openInvitedParticipantContextMenu(id: EnginePeer.Id, sourceView: ContextExtractedContentContainingView, gesture: ContextGesture?) {
        guard let environment = self.environment else {
            return
        }
        guard let currentCall = self.currentCall else {
            return
        }
        guard case .group = self.currentCall else {
            return
        }
           
        let itemsForEntry: () -> [ContextMenuItem] = { [weak self] in
            guard let self, let environment = self.environment else {
                return []
            }
            
            var items: [ContextMenuItem] = []
            
            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_RemovePeer, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(result: .dismissWithoutContent, completion: nil)
                
                guard let self else {
                    return
                }
                guard case let .group(groupCall) = self.currentCall else {
                    return
                }
                
                groupCall.kickPeer(id: id)
            })))
            return items
        }
        
        let items = itemsForEntry()
        
        let presentationData = currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
        let contextController = ContextController(
            presentationData: presentationData,
            source: .extracted(ParticipantExtractedContentSource(contentView: sourceView)),
            items: .single(ContextController.Items(content: .list(items))),
            recognizer: nil,
            gesture: gesture
        )
        
        environment.controller()?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
        
        environment.controller()?.presentInGlobalOverlay(contextController)
    }
    
    private func openAvatarForEditing(fromGallery: Bool = false, completion: @escaping () -> Void = {}) {
        guard let currentCall = self.currentCall else {
            return
        }
        guard let callState = self.callState else {
            return
        }
        let peerId = callState.myPeerId
        
        let _ = (currentCall.accountContext.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
            TelegramEngine.EngineData.Item.Configuration.SearchBots()
        )
        |> deliverOnMainQueue).start(next: { [weak self] peer, searchBotsConfiguration in
            guard let self, let currentCall = self.currentCall, let environment = self.environment else {
                return
            }
            guard let peer else {
                return
            }
            
            let presentationData = currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
            
            let legacyController = LegacyController(presentation: .custom, theme: environment.theme)
            legacyController.statusBar.statusBarStyle = .Ignore
            
            let emptyController = LegacyEmptyController(context: legacyController.context)!
            let navigationController = makeLegacyNavigationController(rootController: emptyController)
            navigationController.setNavigationBarHidden(true, animated: false)
            navigationController.navigationBar.transform = CGAffineTransform(translationX: -1000.0, y: 0.0)
            
            legacyController.bind(controller: navigationController)
            
            self.endEditing(true)
            environment.controller()?.present(legacyController, in: .window(.root))
            
            var hasPhotos = false
            if !peer.profileImageRepresentations.isEmpty {
                hasPhotos = true
            }
                            
            let mixin = TGMediaAvatarMenuMixin(context: legacyController.context, parentController: emptyController, hasSearchButton: true, hasDeleteButton: hasPhotos && !fromGallery, hasViewButton: false, personalPhoto: peerId.namespace == Namespaces.Peer.CloudUser, isVideo: false, saveEditedPhotos: false, saveCapturedMedia: false, signup: false, forum: false, title: nil, isSuggesting: false)!
            mixin.forceDark = true
            mixin.stickersContext = LegacyPaintStickersContext(context: currentCall.accountContext)
            let _ = self.currentAvatarMixin.swap(mixin)
            mixin.requestSearchController = { [weak self] assetsController in
                guard let self, let currentCall = self.currentCall, let environment = self.environment else {
                    return
                }
                let controller = WebSearchController(context: currentCall.accountContext, peer: peer, chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: peer.id.namespace == Namespaces.Peer.CloudUser ? nil : peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder), completion: { [weak self] result in
                    assetsController?.dismiss()
                    
                    guard let self else {
                        return
                    }
                    self.updateProfilePhoto(result)
                }))
                controller.navigationPresentation = .modal
                environment.controller()?.push(controller)
                
                if fromGallery {
                    completion()
                }
            }
            mixin.didFinishWithImage = { [weak self] image in
                if let image = image {
                    completion()
                    self?.updateProfilePhoto(image)
                }
            }
            mixin.didFinishWithVideo = { [weak self] image, asset, adjustments in
                if let image = image, let asset = asset {
                    completion()
                    self?.updateProfileVideo(image, asset: asset, adjustments: adjustments)
                }
            }
            mixin.didFinishWithDelete = { [weak self] in
                guard let self, let environment = self.environment else {
                    return
                }
                
                let proceed = { [weak self] in
                    guard let self, let currentCall = self.currentCall else {
                        return
                    }
                    
                    let _ = self.currentAvatarMixin.swap(nil)
                    let postbox = currentCall.accountContext.account.postbox
                    self.updateAvatarDisposable.set((currentCall.accountContext.engine.peers.updatePeerPhoto(peerId: peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
                        return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
                    })
                    |> deliverOnMainQueue).start())
                }
                
                let actionSheet = ActionSheetController(presentationData: presentationData)
                let items: [ActionSheetItem] = [
                    ActionSheetButtonItem(title: environment.strings.Settings_RemoveConfirmation, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        proceed()
                    })
                ]
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                environment.controller()?.present(actionSheet, in: .window(.root))
            }
            mixin.didDismiss = { [weak self, weak legacyController] in
                guard let self else {
                    return
                }
                let _ = self.currentAvatarMixin.swap(nil)
                legacyController?.dismiss()
            }
            let menuController = mixin.present()
            if let menuController = menuController {
                menuController.customRemoveFromParentViewController = { [weak legacyController] in
                    legacyController?.dismiss()
                }
            }
        })
    }
    
    private func updateProfilePhoto(_ image: UIImage) {
        guard let currentCall = self.currentCall else {
            return
        }
        guard let callState = self.callState else {
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return
        }
        
        let peerId = callState.myPeerId
        
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        currentCall.accountContext.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
        
        self.currentUpdatingAvatar = (representation, 0.0)

        let postbox = currentCall.accountContext.account.postbox
        let signal = peerId.namespace == Namespaces.Peer.CloudUser ? currentCall.accountContext.engine.accountData.updateAccountPhoto(resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mapResourceToAvatarSizes: { resource, representations in
            return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
        }) : currentCall.accountContext.engine.peers.updatePeerPhoto(peerId: peerId, photo: currentCall.accountContext.engine.peers.uploadedPeerPhoto(resource: resource), mapResourceToAvatarSizes: { resource, representations in
            return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
        })
        
        self.updateAvatarDisposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .complete:
                self.currentUpdatingAvatar = nil
                self.state?.updated(transition: .spring(duration: 0.4))
            case let .progress(value):
                self.currentUpdatingAvatar = (representation, value)
            }
        }))
        
        self.state?.updated(transition: .spring(duration: 0.4))
    }
    
    private func updateProfileVideo(_ image: UIImage, asset: Any?, adjustments: TGVideoEditAdjustments?) {
        guard let currentCall = self.currentCall else {
            return
        }
        guard let callState = self.callState else {
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.6) else {
            return
        }
        let peerId = callState.myPeerId
        
        let photoResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        currentCall.accountContext.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
        let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
        
        self.currentUpdatingAvatar = (representation, 0.0)

        var videoStartTimestamp: Double? = nil
        if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
            videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
        }

        let context = currentCall.accountContext
        let account = context.account
        let signal = Signal<TelegramMediaResource, UploadPeerPhotoError> { [weak self] subscriber in
            let entityRenderer: LegacyPaintEntityRenderer? = adjustments.flatMap { adjustments in
                if let paintingData = adjustments.paintingData, paintingData.hasAnimation {
                    return LegacyPaintEntityRenderer(postbox: account.postbox, adjustments: adjustments)
                } else {
                    return nil
                }
            }
            
            let tempFile = EngineTempBox.shared.tempFile(fileName: "video.mp4")
            let uploadInterface = LegacyLiveUploadInterface(context: context)
            let signal: SSignal
            if let url = asset as? URL, url.absoluteString.hasSuffix(".jpg"), let data = try? Data(contentsOf: url, options: [.mappedRead]), let image = UIImage(data: data), let entityRenderer = entityRenderer {
                let durationSignal: SSignal = SSignal(generator: { subscriber in
                    let disposable = (entityRenderer.duration()).start(next: { duration in
                        subscriber.putNext(duration)
                        subscriber.putCompletion()
                    })
                    
                    return SBlockDisposable(block: {
                        disposable.dispose()
                    })
                })
                signal = durationSignal.map(toSignal: { duration -> SSignal in
                    if let duration = duration as? Double {
                        return TGMediaVideoConverter.renderUIImage(image, duration: duration, adjustments: adjustments, path: tempFile.path, watcher: nil, entityRenderer: entityRenderer)!
                    } else {
                        return SSignal.single(nil)
                    }
                })
               
            } else if let asset = asset as? AVAsset {
                signal = TGMediaVideoConverter.convert(asset, adjustments: adjustments, path: tempFile.path, watcher: uploadInterface, entityRenderer: entityRenderer)!
            } else {
                signal = SSignal.complete()
            }
            
            let signalDisposable = signal.start(next: { next in
                if let result = next as? TGMediaVideoConversionResult {
                    if let image = result.coverImage, let data = image.jpegData(compressionQuality: 0.7) {
                        account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
                    }
                    
                    if let timestamp = videoStartTimestamp {
                        videoStartTimestamp = max(0.0, min(timestamp, result.duration - 0.05))
                    }
                    
                    var value = stat()
                    if stat(result.fileURL.path, &value) == 0 {
                        if let data = try? Data(contentsOf: result.fileURL) {
                            let resource: TelegramMediaResource
                            if let liveUploadData = result.liveUploadData as? LegacyLiveUploadInterfaceResult {
                                resource = LocalFileMediaResource(fileId: liveUploadData.id)
                            } else {
                                resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                            }
                            account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                            subscriber.putNext(resource)
                            
                            EngineTempBox.shared.dispose(tempFile)
                        }
                    }
                    subscriber.putCompletion()
                } else if let progress = next as? NSNumber {
                    Queue.mainQueue().async { [weak self] in
                        guard let self else {
                            return
                        }
                        self.currentUpdatingAvatar = (representation, Float(truncating: progress) * 0.25)
                        self.state?.updated(transition: .spring(duration: 0.4))
                    }
                }
            }, error: { _ in
            }, completed: nil)
            
            let disposable = ActionDisposable {
                signalDisposable?.dispose()
            }
            
            return ActionDisposable {
                disposable.dispose()
            }
        }
        
        self.updateAvatarDisposable.set((signal
        |> mapToSignal { videoResource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
            if peerId.namespace == Namespaces.Peer.CloudUser {
                return context.engine.accountData.updateAccountPhoto(resource: photoResource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, markup: nil, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            } else {
                return context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: photoResource), video: context.engine.peers.uploadedPeerVideo(resource: videoResource) |> map(Optional.init), videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: account.postbox, resource: resource, representations: representations)
                })
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            switch result {
            case .complete:
                self.currentUpdatingAvatar = nil
                self.state?.updated(transition: .spring(duration: 0.4))
            case let .progress(value):
                self.currentUpdatingAvatar = (representation, 0.25 + value * 0.75)
                self.state?.updated(transition: .spring(duration: 0.4))
            }
        }))
    }
}

private final class ParticipantExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private let contentView: ContextExtractedContentContainingView
    
    init(contentView: ContextExtractedContentContainingView) {
        self.contentView = contentView
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .view(self.contentView), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
