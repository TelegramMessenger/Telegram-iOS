import Foundation
import UIKit
import Display
import ContextUI
import TelegramCore
import SwiftSignalKit
import DeleteChatPeerActionSheetItem
import PeerListItemComponent
import LegacyComponents
import LegacyUI
import WebSearchUI
import MapResourceToAvatarSizes
import LegacyMediaPickerUI
import AvatarNode
import PresentationDataUtils
import AccountContext
import CallsEmoji
import AlertComponent
import TelegramPresentationData
import ComponentFlow
import MultilineTextComponent
import AVFoundation

private func resolvedEmojiKey(data: Data) -> [String] {
    let resolvedKey = stringForEmojiHashOfData(data, 4) ?? []
    return resolvedKey
}

private final class EmojiKeyAlertComponet: CombinedComponent {
    let theme: PresentationTheme
    let emojiKey: [String]
    let title: String
    let text: String
    
    init(theme: PresentationTheme, emojiKey: [String], title: String, text: String) {
        self.theme = theme
        self.emojiKey = emojiKey
        self.title = title
        self.text = text
    }
    
    static func ==(lhs: EmojiKeyAlertComponet, rhs: EmojiKeyAlertComponet) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.emojiKey != rhs.emojiKey {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
    
    public static var body: Body {
        //let emojiKeyItems = ChildMap(environment: MultilineTextComponent.self, keyedBy: Int.self)
        let emojiKey = Child(MultilineTextComponent.self)
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        
        return { context in
            /*let emojiKeyItems = context.component.emojiKey.map { item in
                return emojiKeyItems[item].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: context.component.emojiKey.joined(separator: ""), font: Font.semibold(40.0), textColor: context.component.theme.actionSheet.primaryTextColor)),
                        horizontalAlignment: .center
                    )),
                    environment: {},
                    availableSize: CGSize(width: 100.0, height: 100.0),
                    transition: .immediate
                )
            }*/
            
            let emojiKey = emojiKey.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: context.component.emojiKey.joined(separator: ""), font: Font.semibold(40.0), textColor: context.component.theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: .immediate
            )
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: context.component.title, font: Font.semibold(16.0), textColor: context.component.theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: .immediate
            )
            let text = text.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: context.component.text, font: Font.regular(13.0), textColor: context.component.theme.actionSheet.primaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 10000.0),
                transition: .immediate
            )
            
            var size = CGSize(width: 0.0, height: 0.0)
            
            size.width = max(size.width, emojiKey.size.width)
            size.width = max(size.width, title.size.width)
            size.width = max(size.width, text.size.width)
            
            let titleSpacing: CGFloat = 10.0
            let textSpacing: CGFloat = 10.0
            
            size.height += emojiKey.size.height
            size.height += titleSpacing
            size.height += title.size.height
            size.height += textSpacing
            size.height += text.size.height
            
            var contentHeight: CGFloat = 0.0
            let emojiKeyFrame = CGRect(origin: CGPoint(x: floor((size.width - emojiKey.size.width) * 0.5), y: contentHeight), size: emojiKey.size)
            contentHeight += emojiKey.size.height + titleSpacing
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - title.size.width) * 0.5), y: contentHeight), size: title.size)
            contentHeight += title.size.height + textSpacing
            let textFrame = CGRect(origin: CGPoint(x: floor((size.width - text.size.width) * 0.5), y: contentHeight), size: text.size)
            contentHeight += text.size.height + 5.0
            
            context.add(emojiKey
                .position(emojiKeyFrame.center)
            )
            context.add(title
                .position(titleFrame.center)
            )
            context.add(text
                .position(textFrame.center)
            )
            
            return size
        }
    }
}

extension VideoChatScreenComponent.View {
    func openMoreMenu() {
        guard let sourceView = self.navigationLeftButton.view else {
            return
        }
        guard let environment = self.environment, let controller = environment.controller() else {
            return
        }
        guard let currentCall = self.currentCall else {
            return
        }
        guard let callState = self.callState else {
            return
        }
        
        let canManageCall = callState.canManageCall

        var isConference = false
        if case let .group(groupCall) = currentCall {
            isConference = groupCall.isConference
        }
        
        var items: [ContextMenuItem] = []
        
        if self.peer != nil, let displayAsPeers = self.displayAsPeers, displayAsPeers.count > 1 {
            for peer in displayAsPeers {
                if peer.peer.id == callState.myPeerId {
                    let avatarSize = CGSize(width: 28.0, height: 28.0)
                    items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_DisplayAs, textLayout: .secondLineWithValue(EnginePeer(peer.peer).displayTitle(strings: environment.strings, displayOrder: currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: currentCall.accountContext.account, peer: EnginePeer(peer.peer), size: avatarSize)), action: { [weak self] c, _ in
                        guard let self else {
                            return
                        }
                        c?.pushItems(items: .single(ContextController.Items(content: .list(self.contextMenuDisplayAsItems()))))
                    })))
                    items.append(.separator)
                    break
                }
            }
        }
        
        if let (availableOutputs, currentOutput) = self.audioOutputState, availableOutputs.count > 1 {
            var currentOutputTitle = ""
            for output in availableOutputs {
                if output == currentOutput {
                let title: String
                    switch output {
                    case .builtin:
                        title = UIDevice.current.model
                    case .speaker:
                        title = environment.strings.Call_AudioRouteSpeaker
                    case .headphones:
                        title = environment.strings.Call_AudioRouteHeadphones
                    case let .port(port):
                        title = port.name
                    }
                    currentOutputTitle = title
                    break
                }
            }
            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_ContextAudio, textLayout: .secondLineWithValue(currentOutputTitle), icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Audio"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] c, _ in
                guard let self else {
                    return
                }
                c?.pushItems(items: .single(ContextController.Items(content: .list(self.contextMenuAudioItems()))))
            })))
        }
        
        if canManageCall && !isConference {
            let text: String
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                text = environment.strings.LiveStream_EditTitle
            } else {
                text = environment.strings.VoiceChat_EditTitle
            }
            items.append(.action(ContextMenuActionItem(text: text, icon: { theme -> UIImage? in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Pencil"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] _, f in
                f(.default)

                guard let self else {
                    return
                }
                self.openTitleEditing()
            })))

            var hasPermissions = true
            if let peer = self.peer, case let .channel(chatPeer) = peer {
                if case .broadcast = chatPeer.info {
                    hasPermissions = false
                } else if chatPeer.flags.contains(.isGigagroup) {
                    hasPermissions = false
                }
            }
            if hasPermissions {
                items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_EditPermissions, icon: { theme -> UIImage? in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Restrict"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] c, _ in
                    guard let self else {
                        return
                    }
                    c?.pushItems(items: .single(ContextController.Items(content: .list(self.contextMenuPermissionItems()))))
                })))
            }
        }
    
        if let inviteLinks = self.inviteLinks {
            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_Share, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.actionSheet.primaryTextColor)
            }, action: { [weak self] _, f in
                f(.default)
                
                guard let self else {
                    return
                }
                self.presentShare(inviteLinks)
            })))
        }
        
        //let isScheduled = strongSelf.isScheduled
        let isScheduled: Bool = !"".isEmpty

        let canSpeak: Bool
        if let muteState = callState.muteState {
            canSpeak = muteState.canUnmute
        } else {
            canSpeak = true
        }
        
        if !isScheduled && canSpeak {
            if #available(iOS 15.0, *) {
                items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_MicrophoneModes, textColor: .primary, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Noise"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    AVCaptureDevice.showSystemUserInterface(.microphoneModes)
                })))
            }
        }
        
        if let members = self.members, members.participants.contains(where: { $0.videoDescription != nil || $0.presentationDescription != nil }) {
            let qualityList: [(Int, String)] = [
                (0, environment.strings.VideoChat_IncomingVideoQuality_AudioOnly),
                (180, "180p"),
                (360, "360p"),
                (Int.max, "720p")
            ]
            
            let videoQualityTitle = qualityList.first(where: { $0.0 == self.maxVideoQuality })?.1 ?? ""
            items.append(.action(ContextMenuActionItem(text: environment.strings.VideoChat_IncomingVideoQuality_Title, textColor: .primary, textLayout: .secondLineWithValue(videoQualityTitle), icon: { _ in
                return nil
            }, action: { [weak self] c, _ in
                guard let self else {
                    c?.dismiss(completion: nil)
                    return
                }
                
                var items: [ContextMenuItem] = []
                items.append(.action(ContextMenuActionItem(text: environment.strings.Common_Back, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
                }, iconPosition: .left, action: { (c, _) in
                    c?.popItems()
                })))
                items.append(.separator)
                
                for (quality, title) in qualityList {
                    let isSelected = self.maxVideoQuality == quality
                    items.append(.action(ContextMenuActionItem(text: title, icon: { _ in
                        if isSelected {
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: .white)
                        } else {
                            return nil
                        }
                    }, action: { [weak self] _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        
                        if self.maxVideoQuality != quality {
                            self.maxVideoQuality = quality
                            self.state?.updated(transition: .immediate)
                        }
                    })))
                }
                
                c?.pushItems(items: .single(ContextController.Items(content: .list(items))))
            })))
        }
        
        if callState.isVideoEnabled && (callState.muteState?.canUnmute ?? true) {
            if currentCall.hasScreencast {
                items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_StopScreenSharing, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/ShareScreen"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.default)

                    guard let self, let currentCall = self.currentCall else {
                        return
                    }
                    currentCall.disableScreencast()
                })))
            } else {
                items.append(.custom(VoiceChatShareScreenContextItem(context: currentCall.accountContext, text: environment.strings.VoiceChat_ShareScreen, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/ShareScreen"), color: theme.actionSheet.primaryTextColor)
                }, action: { _, _ in }), false))
            }
        }

        if canManageCall && !isConference {
            if let recordingStartTimestamp = callState.recordingStartTimestamp {
                items.append(.custom(VoiceChatRecordingContextItem(timestamp: recordingStartTimestamp, action: { [weak self] _, f in
                    f(.dismissWithoutContent)

                    guard let self, let environment = self.environment, let currentCall = self.currentCall else {
                        return
                    }
                    
                    let alertController = textAlertController(context: currentCall.accountContext, forceTheme: environment.theme, title: nil, text: environment.strings.VoiceChat_StopRecordingTitle, actions: [TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: environment.strings.VoiceChat_StopRecordingStop, action: { [weak self] in
                        guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall else {
                            return
                        }
                        groupCall.setShouldBeRecording(false, title: nil, videoOrientation: nil)

                        Queue.mainQueue().after(0.88) {
                            HapticFeedback().success()
                        }
                        
                        let text: String
                        if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                            text = environment.strings.LiveStream_RecordingSaved
                        } else {
                            text = environment.strings.VideoChat_RecordingSaved
                        }
                        self.presentUndoOverlay(content: .forward(savedMessages: true, text: text), action: { [weak self] value in
                            if case .info = value, let self, let environment = self.environment, let currentCall = self.currentCall, let navigationController = environment.controller()?.navigationController as? NavigationController {
                                let context = currentCall.accountContext
                                environment.controller()?.dismiss(completion: { [weak navigationController] in
                                    Queue.mainQueue().justDispatch {
                                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                                        |> deliverOnMainQueue).start(next: { peer in
                                            guard let peer, let navigationController else {
                                                return
                                            }
                                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always, purposefulAction: {}, peekData: nil))
                                        })
                                    }
                                })
                                
                                return true
                            }
                            return false
                        })
                    })])
                    environment.controller()?.present(alertController, in: .window(.root))
                }), false))
            } else {
                let text: String
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    text = environment.strings.LiveStream_StartRecording
                } else {
                    text = environment.strings.VoiceChat_StartRecording
                }
                if callState.scheduleTimestamp == nil {
                    items.append(.action(ContextMenuActionItem(text: text, icon: { theme -> UIImage? in
                        return generateStartRecordingIcon(color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)

                        guard let self, let environment = self.environment, let currentCall = self.currentCall, let peer = self.peer else {
                            return
                        }

                        let controller = VoiceChatRecordingSetupController(context: currentCall.accountContext, peer: peer, completion: { [weak self] videoOrientation in
                            guard let self, let environment = self.environment, let currentCall = self.currentCall, let peer = self.peer else {
                                return
                            }
                            let title: String
                            let text: String
                            let placeholder: String
                            if let _ = videoOrientation {
                                placeholder = environment.strings.VoiceChat_RecordingTitlePlaceholderVideo
                            } else {
                                placeholder = environment.strings.VoiceChat_RecordingTitlePlaceholder
                            }
                            if case let .channel(channel) = peer, case .broadcast = channel.info {
                                title = environment.strings.LiveStream_StartRecordingTitle
                                if let _ = videoOrientation {
                                    text = environment.strings.LiveStream_StartRecordingTextVideo
                                } else {
                                    text = environment.strings.LiveStream_StartRecordingText
                                }
                            } else {
                                title = environment.strings.VoiceChat_StartRecordingTitle
                                if let _ = videoOrientation {
                                    text = environment.strings.VoiceChat_StartRecordingTextVideo
                                } else {
                                    text = environment.strings.VoiceChat_StartRecordingText
                                }
                            }

                            let controller = voiceChatTitleEditController(sharedContext: currentCall.accountContext.sharedContext, account: currentCall.accountContext.account, forceTheme: environment.theme, title: title, text: text, placeholder: placeholder, value: nil, maxLength: 40, apply: { [weak self] title in
                                guard let self, let environment = self.environment, case let .group(groupCall) = self.currentCall, let peer = self.peer, let title else {
                                    return
                                }
                                
                                groupCall.setShouldBeRecording(true, title: title, videoOrientation: videoOrientation)

                                let text: String
                                if case let .channel(channel) = peer, case .broadcast = channel.info {
                                    text = environment.strings.LiveStream_RecordingStarted
                                } else {
                                    text = environment.strings.VoiceChat_RecordingStarted
                                }

                                self.presentUndoOverlay(content: .voiceChatRecording(text: text), action: { _ in return false })
                                groupCall.playTone(.recordingStarted)
                            })
                            environment.controller()?.present(controller, in: .window(.root))
                        })
                        environment.controller()?.present(controller, in: .window(.root))
                    })))
                }
            }
        }
        
        if canManageCall {
            let text: String
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                text = isScheduled ? environment.strings.VoiceChat_CancelLiveStream : environment.strings.VoiceChat_EndLiveStream
            } else {
                text = isScheduled ? environment.strings.VoiceChat_CancelVoiceChat : environment.strings.VoiceChat_EndVoiceChat
            }
            items.append(.action(ContextMenuActionItem(text: text, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)

                guard let self, let environment = self.environment, let currentCall = self.currentCall else {
                    return
                }

                let action: () -> Void = { [weak self] in
                    guard let self, let currentCall = self.currentCall else {
                        return
                    }

                    switch currentCall {
                    case let .group(groupCall):
                        let _ = (groupCall.leave(terminateIfPossible: true)
                        |> filter { $0 }
                        |> take(1)
                        |> deliverOnMainQueue).start(completed: { [weak self] in
                            guard let self, let environment = self.environment else {
                                return
                            }
                            environment.controller()?.dismiss()
                        })
                    case let .conferenceSource(conferenceSource):
                        let _ = (conferenceSource.hangUp()
                        |> filter { $0 }
                        |> take(1)
                        |> deliverOnMainQueue).start(completed: { [weak self] in
                            guard let self, let environment = self.environment else {
                                return
                            }
                            environment.controller()?.dismiss()
                        })
                    }
                }

                let title: String
                let text: String
                if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                    title = isScheduled ? environment.strings.LiveStream_CancelConfirmationTitle : environment.strings.LiveStream_EndConfirmationTitle
                    text = isScheduled ? environment.strings.LiveStream_CancelConfirmationText : environment.strings.LiveStream_EndConfirmationText
                } else {
                    title = isScheduled ? environment.strings.VoiceChat_CancelConfirmationTitle : environment.strings.VoiceChat_EndConfirmationTitle
                    text = isScheduled ? environment.strings.VoiceChat_CancelConfirmationText : environment.strings.VoiceChat_EndConfirmationText
                }

                let alertController = textAlertController(context: currentCall.accountContext, forceTheme: environment.theme, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: isScheduled ? environment.strings.VoiceChat_CancelConfirmationEnd : environment.strings.VoiceChat_EndConfirmationEnd, action: {
                    action()
                })])
                environment.controller()?.present(alertController, in: .window(.root))
            })))
        } else {
            let leaveText: String
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                leaveText = environment.strings.LiveStream_LeaveVoiceChat
            } else {
                leaveText = environment.strings.VoiceChat_LeaveVoiceChat
            }
            items.append(.action(ContextMenuActionItem(text: leaveText, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)

                guard let self, let currentCall = self.currentCall else {
                    return
                }

                switch currentCall {
                case let .group(groupCall):
                    let _ = (groupCall.leave(terminateIfPossible: false)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        guard let self, let environment = self.environment else {
                            return
                        }
                        environment.controller()?.dismiss()
                    })
                case let .conferenceSource(conferenceSource):
                    let _ = (conferenceSource.hangUp()
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        guard let self, let environment = self.environment else {
                            return
                        }
                        environment.controller()?.dismiss()
                    })
                }
            })))
        }

        let presentationData = currentCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
        let contextController = ContextController(presentationData: presentationData, source: .reference(VoiceChatContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
        controller.presentInGlobalOverlay(contextController)
    }
    
    private func contextMenuDisplayAsItems() -> [ContextMenuItem] {
        guard let environment = self.environment else {
            return []
        }
        guard case let .group(groupCall) = self.currentCall else {
            return []
        }
        guard let callState = self.callState else {
            return []
        }
        let myPeerId = callState.myPeerId

        let avatarSize = CGSize(width: 28.0, height: 28.0)

        var items: [ContextMenuItem] = []
        
        items.append(.action(ContextMenuActionItem(text: environment.strings.Common_Back, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
        }, iconPosition: .left, action: { (c, _) in
            c?.popItems()
        })))
        items.append(.separator)
        
        var isGroup = false
        if let displayAsPeers = self.displayAsPeers {
            for peer in displayAsPeers {
                if peer.peer is TelegramGroup {
                    isGroup = true
                    break
                } else if let peer = peer.peer as? TelegramChannel, case .group = peer.info {
                    isGroup = true
                    break
                }
            }
        }
        
        items.append(.custom(VoiceChatInfoContextItem(text: isGroup ? environment.strings.VoiceChat_DisplayAsInfoGroup : environment.strings.VoiceChat_DisplayAsInfo, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Accounts"), color: theme.actionSheet.primaryTextColor)
        }), true))

        if let displayAsPeers = self.displayAsPeers {
            for peer in displayAsPeers {
                var subtitle: String?
                if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                    subtitle = environment.strings.VoiceChat_PersonalAccount
                } else if let subscribers = peer.subscribers {
                    if let peer = peer.peer as? TelegramChannel, case .broadcast = peer.info {
                        subtitle = environment.strings.Conversation_StatusSubscribers(subscribers)
                    } else {
                        subtitle = environment.strings.Conversation_StatusMembers(subscribers)
                    }
                }
                
                let isSelected = peer.peer.id == myPeerId
                let extendedAvatarSize = CGSize(width: 35.0, height: 35.0)
                let theme = environment.theme
                let avatarSignal = peerAvatarCompleteImage(account: groupCall.accountContext.account, peer: EnginePeer(peer.peer), size: avatarSize)
                |> map { image -> UIImage? in
                    if isSelected, let image = image {
                        return generateImage(extendedAvatarSize, rotatedContext: { size, context in
                            let bounds = CGRect(origin: CGPoint(), size: size)
                            context.clear(bounds)
                            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                            context.scaleBy(x: 1.0, y: -1.0)
                            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                            context.draw(image.cgImage!, in: CGRect(x: (extendedAvatarSize.width - avatarSize.width) / 2.0, y: (extendedAvatarSize.height - avatarSize.height) / 2.0, width: avatarSize.width, height: avatarSize.height))
                            
                            let lineWidth = 1.0 + UIScreenPixel
                            context.setLineWidth(lineWidth)
                            context.setStrokeColor(theme.actionSheet.controlAccentColor.cgColor)
                            context.strokeEllipse(in: bounds.insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0))
                        })
                    } else {
                        return image
                    }
                }
                
                items.append(.action(ContextMenuActionItem(text: EnginePeer(peer.peer).displayTitle(strings: environment.strings, displayOrder: groupCall.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), textLayout: subtitle.flatMap { .secondLineWithValue($0) } ?? .singleLine, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: isSelected ? extendedAvatarSize : avatarSize, signal: avatarSignal), action: { [weak self] _, f in
                    f(.default)
                    
                    guard let self, case let .group(groupCall) = self.currentCall else {
                        return
                    }
                    
                    if peer.peer.id != myPeerId {
                        groupCall.reconnect(as: peer.peer.id)
                    }
                })))
                
                if peer.peer.id.namespace == Namespaces.Peer.CloudUser {
                    items.append(.separator)
                }
            }
        }
        return items
    }
    
    private func contextMenuAudioItems() -> [ContextMenuItem] {
        guard let environment = self.environment else {
            return []
        }
        guard let (availableOutputs, currentOutput) = self.audioOutputState else {
            return []
        }

        var items: [ContextMenuItem] = []
        
        items.append(.action(ContextMenuActionItem(text: environment.strings.Common_Back, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
        }, iconPosition: .left, action: { (c, _) in
            c?.popItems()
        })))
        items.append(.separator)
        
        for output in availableOutputs {
            let title: String
            switch output {
            case .builtin:
                title = UIDevice.current.model
            case .speaker:
                title = environment.strings.Call_AudioRouteSpeaker
            case .headphones:
                title = environment.strings.Call_AudioRouteHeadphones
            case let .port(port):
                title = port.name
            }
            items.append(.action(ContextMenuActionItem(text: title, icon: { theme in
                if output == currentOutput {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                } else {
                    return nil
                }
            }, action: { [weak self] _, f in
                f(.default)
                
                guard let self, let currentCall = self.currentCall else {
                    return
                }
                
                currentCall.setCurrentAudioOutput(output)
            })))
        }
        
        return items
    }
    
    private func contextMenuPermissionItems() -> [ContextMenuItem] {
        guard let environment = self.environment, let callState = self.callState else {
            return []
        }
        
        var items: [ContextMenuItem] = []
        if callState.canManageCall, let defaultParticipantMuteState = callState.defaultParticipantMuteState {
            let isMuted = defaultParticipantMuteState == .muted

            items.append(.action(ContextMenuActionItem(text: environment.strings.Common_Back, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
            }, iconPosition: .left, action: { (c, _) in
                c?.popItems()
            })))
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_SpeakPermissionEveryone, icon: { theme in
                if isMuted {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                }
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)

                guard let self, case let .group(groupCall) = self.currentCall else {
                    return
                }
                groupCall.updateDefaultParticipantsAreMuted(isMuted: false)
            })))
            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_SpeakPermissionAdmin, icon: { theme in
                if !isMuted {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                }
            }, action: { [weak self] _, f in
                f(.dismissWithoutContent)

                guard let self, case let .group(groupCall) = self.currentCall else {
                    return
                }
                groupCall.updateDefaultParticipantsAreMuted(isMuted: true)
            })))
        }
        return items
    }
}
