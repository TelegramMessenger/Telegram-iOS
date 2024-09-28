import Foundation
import AVFoundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import ViewControllerComponent
import Postbox
import TelegramCore
import AccountContext
import PlainButtonComponent
import SwiftSignalKit
import LottieComponent
import BundleIconComponent
import ContextUI
import TelegramPresentationData
import DeviceAccess
import TelegramVoip
import PresentationDataUtils
import UndoUI
import ShareController
import AvatarNode
import TelegramAudio

import PeerInfoUI

import DeleteChatPeerActionSheetItem
import PeerListItemComponent
import LegacyComponents
import LegacyUI
import WebSearchUI
import MapResourceToAvatarSizes
import LegacyMediaPickerUI

private final class VideoChatScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let initialData: VideoChatScreenV2Impl.InitialData
    let call: PresentationGroupCall

    init(
        initialData: VideoChatScreenV2Impl.InitialData,
        call: PresentationGroupCall
    ) {
        self.initialData = initialData
        self.call = call
    }

    static func ==(lhs: VideoChatScreenComponent, rhs: VideoChatScreenComponent) -> Bool {
        return true
    }
    
    private struct PanGestureState {
        var offsetFraction: CGFloat
        
        init(offsetFraction: CGFloat) {
            self.offsetFraction = offsetFraction
        }
    }

    final class View: UIView {
        private let containerView: UIView
        
        private var component: VideoChatScreenComponent?
        private var environment: ViewControllerComponentContainer.Environment?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var panGestureState: PanGestureState?
        private var notifyDismissedInteractivelyOnPanGestureApply: Bool = false
        private var completionOnPanGestureApply: (() -> Void)?
        
        private let videoRenderingContext = VideoRenderingContext()
        
        private let title = ComponentView<Empty>()
        private let navigationLeftButton = ComponentView<Empty>()
        private let navigationRightButton = ComponentView<Empty>()
        private var navigationSidebarButton: ComponentView<Empty>?
        
        private let videoButton = ComponentView<Empty>()
        private let leaveButton = ComponentView<Empty>()
        private let microphoneButton = ComponentView<Empty>()
        
        private let participants = ComponentView<Empty>()
        
        private var reconnectedAsEventsDisposable: Disposable?
        
        private var peer: EnginePeer?
        private var callState: PresentationGroupCallState?
        private var stateDisposable: Disposable?
        
        private var audioOutputState: ([AudioSessionOutput], AudioSessionOutput?)?
        private var audioOutputStateDisposable: Disposable?
        
        private var displayAsPeers: [FoundPeer]?
        private var displayAsPeersDisposable: Disposable?
        
        private var inviteLinks: GroupCallInviteLinks?
        private var inviteLinksDisposable: Disposable?
        
        private var isPushToTalkActive: Bool = false
        
        private var members: PresentationGroupCallMembers?
        private var membersDisposable: Disposable?
        
        private let isPresentedValue = ValuePromise<Bool>(false, ignoreRepeated: true)
        private var applicationStateDisposable: Disposable?
        
        private var expandedParticipantsVideoState: VideoChatParticipantsComponent.ExpandedVideoState?
        
        private let inviteDisposable = MetaDisposable()
        private let currentAvatarMixin = Atomic<TGMediaAvatarMenuMixin?>(value: nil)
        private let updateAvatarDisposable = MetaDisposable()
        private var currentUpdatingAvatar: (TelegramMediaImageRepresentation, Float)?
        
        override init(frame: CGRect) {
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
            super.init(frame: frame)
            
            self.backgroundColor = nil
            self.isOpaque = false
            
            self.addSubview(self.containerView)
            
            self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
            
            self.panGestureState = PanGestureState(offsetFraction: 1.0)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.membersDisposable?.dispose()
            self.applicationStateDisposable?.dispose()
            self.reconnectedAsEventsDisposable?.dispose()
            self.displayAsPeersDisposable?.dispose()
            self.audioOutputStateDisposable?.dispose()
            self.inviteLinksDisposable?.dispose()
            self.updateAvatarDisposable.dispose()
            self.inviteDisposable.dispose()
        }
        
        func animateIn() {
            self.panGestureState = PanGestureState(offsetFraction: 1.0)
            self.state?.updated(transition: .immediate)
            
            self.panGestureState = nil
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        func animateOut(completion: @escaping () -> Void) {
            self.panGestureState = PanGestureState(offsetFraction: 1.0)
            self.completionOnPanGestureApply = completion
            self.state?.updated(transition: .spring(duration: 0.5))
        }
        
        @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                if !self.bounds.height.isZero && !self.notifyDismissedInteractivelyOnPanGestureApply {
                    let translation = recognizer.translation(in: self)
                    self.panGestureState = PanGestureState(offsetFraction: translation.y / self.bounds.height)
                    self.state?.updated(transition: .immediate)
                }
            case .cancelled, .ended:
                if !self.bounds.height.isZero {
                    let translation = recognizer.translation(in: self)
                    let panGestureState = PanGestureState(offsetFraction: translation.y / self.bounds.height)
                    
                    let velocity = recognizer.velocity(in: self)
                    
                    self.panGestureState = nil
                    if abs(panGestureState.offsetFraction) > 0.6 || abs(velocity.y) >= 100.0 {
                        self.panGestureState = PanGestureState(offsetFraction: panGestureState.offsetFraction < 0.0 ? -1.0 : 1.0)
                        self.notifyDismissedInteractivelyOnPanGestureApply = true
                        if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                            controller.notifyDismissed()
                        }
                    }
                    
                    self.state?.updated(transition: .spring(duration: 0.4))
                }
            default:
                break
            }
        }
        
        private func openMoreMenu() {
            guard let sourceView = self.navigationLeftButton.view else {
                return
            }
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() else {
                return
            }
            guard let peer = self.peer else {
                return
            }
            guard let callState = self.callState else {
                return
            }
            
            let canManageCall = callState.canManageCall
            
            var items: [ContextMenuItem] = []
            
            if let displayAsPeers = self.displayAsPeers, displayAsPeers.count > 1 {
                for peer in displayAsPeers {
                    if peer.peer.id == callState.myPeerId {
                        let avatarSize = CGSize(width: 28.0, height: 28.0)
                        items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_DisplayAs, textLayout: .secondLineWithValue(EnginePeer(peer.peer).displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)), icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: component.call.accountContext.account, peer: EnginePeer(peer.peer), size: avatarSize)), action: { [weak self] c, _ in
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
            
            if canManageCall {
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
                if case let .channel(chatPeer) = peer {
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
            //TODO:release
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
            
            if callState.isVideoEnabled && (callState.muteState?.canUnmute ?? true) {
                if component.call.hasScreencast {
                    items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_StopScreenSharing, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/ShareScreen"), color: theme.actionSheet.primaryTextColor)
                    }, action: { [weak self] _, f in
                        f(.default)

                        guard let self, let component = self.component else {
                            return
                        }
                        component.call.disableScreencast()
                    })))
                } else {
                    items.append(.custom(VoiceChatShareScreenContextItem(context: component.call.accountContext, text: environment.strings.VoiceChat_ShareScreen, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/ShareScreen"), color: theme.actionSheet.primaryTextColor)
                    }, action: { _, _ in }), false))
                }
            }

            if canManageCall {
                if let recordingStartTimestamp = callState.recordingStartTimestamp {
                    items.append(.custom(VoiceChatRecordingContextItem(timestamp: recordingStartTimestamp, action: { [weak self] _, f in
                        f(.dismissWithoutContent)

                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        
                        let alertController = textAlertController(context: component.call.accountContext, forceTheme: environment.theme, title: nil, text: environment.strings.VoiceChat_StopRecordingTitle, actions: [TextAlertAction(type: .genericAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: environment.strings.VoiceChat_StopRecordingStop, action: { [weak self] in
                            guard let self, let component = self.component, let environment = self.environment else {
                                return
                            }
                            component.call.setShouldBeRecording(false, title: nil, videoOrientation: nil)

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
                                if case .info = value, let self, let component = self.component, let environment = self.environment, let navigationController = environment.controller()?.navigationController as? NavigationController {
                                    let context = component.call.accountContext
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

                            guard let self, let component = self.component, let environment = self.environment, let peer = self.peer else {
                                return
                            }

                            let controller = VoiceChatRecordingSetupController(context: component.call.accountContext, peer: peer, completion: { [weak self] videoOrientation in
                                guard let self, let component = self.component, let environment = self.environment, let peer = self.peer else {
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

                                let controller = voiceChatTitleEditController(sharedContext: component.call.accountContext.sharedContext, account: component.call.account, forceTheme: environment.theme, title: title, text: text, placeholder: placeholder, value: nil, maxLength: 40, apply: { [weak self] title in
                                    guard let self, let component = self.component, let environment = self.environment, let peer = self.peer, let title else {
                                        return
                                    }
                                    
                                    component.call.setShouldBeRecording(true, title: title, videoOrientation: videoOrientation)

                                    let text: String
                                    if case let .channel(channel) = peer, case .broadcast = channel.info {
                                        text = environment.strings.LiveStream_RecordingStarted
                                    } else {
                                        text = environment.strings.VoiceChat_RecordingStarted
                                    }

                                    self.presentUndoOverlay(content: .voiceChatRecording(text: text), action: { _ in return false })
                                    component.call.playTone(.recordingStarted)
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

                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }

                    let action: () -> Void = { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }

                        let _ = (component.call.leave(terminateIfPossible: true)
                        |> filter { $0 }
                        |> take(1)
                        |> deliverOnMainQueue).start(completed: { [weak self] in
                            guard let self, let environment = self.environment else {
                                return
                            }
                            environment.controller()?.dismiss()
                        })
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

                    let alertController = textAlertController(context: component.call.accountContext, forceTheme: environment.theme, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: environment.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: isScheduled ? environment.strings.VoiceChat_CancelConfirmationEnd : environment.strings.VoiceChat_EndConfirmationEnd, action: {
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

                    guard let self, let component = self.component else {
                        return
                    }

                    let _ = (component.call.leave(terminateIfPossible: false)
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        guard let self, let environment = self.environment else {
                            return
                        }
                        environment.controller()?.dismiss()
                    })
                })))
            }

            let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
            let contextController = ContextController(presentationData: presentationData, source: .reference(VoiceChatContextReferenceContentSource(controller: controller, sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))), gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
        
        private func contextMenuDisplayAsItems() -> [ContextMenuItem] {
            guard let component = self.component, let environment = self.environment else {
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
                    let avatarSignal = peerAvatarCompleteImage(account: component.call.accountContext.account, peer: EnginePeer(peer.peer), size: avatarSize)
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
                    
                    items.append(.action(ContextMenuActionItem(text: EnginePeer(peer.peer).displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), textLayout: subtitle.flatMap { .secondLineWithValue($0) } ?? .singleLine, icon: { _ in nil }, iconSource: ContextMenuActionItemIconSource(size: isSelected ? extendedAvatarSize : avatarSize, signal: avatarSignal), action: { [weak self] _, f in
                        f(.default)
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        if peer.peer.id != myPeerId {
                            component.call.reconnect(as: peer.peer.id)
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
                    
                    guard let self, let component = self.component else {
                        return
                    }
                    
                    component.call.setCurrentAudioOutput(output)
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

                    guard let self, let component = self.component else {
                        return
                    }
                    component.call.updateDefaultParticipantsAreMuted(isMuted: false)
                })))
                items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_SpeakPermissionAdmin, icon: { theme in
                    if !isMuted {
                        return nil
                    } else {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.actionSheet.primaryTextColor)
                    }
                }, action: { [weak self] _, f in
                    f(.dismissWithoutContent)

                    guard let self, let component = self.component else {
                        return
                    }
                    component.call.updateDefaultParticipantsAreMuted(isMuted: true)
                })))
            }
            return items
        }
        
        private func openParticipantContextMenu(id: EnginePeer.Id, sourceView: ContextExtractedContentContainingView, gesture: ContextGesture?) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            guard let members = self.members, let participant = members.participants.first(where: { $0.peer.id == id }) else {
                return
            }
            
            let muteStatePromise = Promise<GroupCallParticipantsContext.Participant.MuteState?>(participant.muteState)
               
            let itemsForEntry: (GroupCallParticipantsContext.Participant.MuteState?) -> [ContextMenuItem] = { [weak self] muteState in
                guard let self, let component = self.component, let environment = self.environment else {
                    return []
                }
                guard let callState = self.callState else {
                    return []
                }
                
                var items: [ContextMenuItem] = []
                
                var hasVolumeSlider = false
                let peer = participant.peer
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
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            if finished && newValue.isZero {
                                let updatedMuteState = component.call.updateMuteState(peerId: peer.id, isMuted: true)
                                muteStatePromise.set(.single(updatedMuteState))
                            } else {
                                component.call.setVolume(peerId: peer.id, volume: Int32(newValue * 10000), sync: finished)
                            }
                        }), true))
                    }
                }
                
                if callState.myPeerId == id && !hasVolumeSlider && ((participant.about?.isEmpty ?? true) || participant.peer.smallProfileImage == nil) {
                    items.append(.custom(VoiceChatInfoContextItem(text: environment.strings.VoiceChat_ImproveYourProfileText, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Tip"), color: theme.actionSheet.primaryTextColor)
                    }), true))
                }
                                    
                if peer.id == callState.myPeerId {
                    if participant.hasRaiseHand {
                        items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_CancelSpeakRequest, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/RevokeSpeak"), color: theme.actionSheet.primaryTextColor)
                        }, action: { [weak self] _, f in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.call.lowerHand()
                            
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
                            guard let self, let component = self.component, let environment = self.environment else {
                                return
                            }
                            let maxBioLength: Int
                            if peer.id.namespace == Namespaces.Peer.CloudUser {
                                maxBioLength = 70
                            } else {
                                maxBioLength = 100
                            }
                            let controller = voiceChatTitleEditController(sharedContext: component.call.accountContext.sharedContext, account: component.call.accountContext.account, forceTheme: environment.theme, title: environment.strings.VoiceChat_EditBioTitle, text: environment.strings.VoiceChat_EditBioText, placeholder: environment.strings.VoiceChat_EditBioPlaceholder, doneButtonTitle: environment.strings.VoiceChat_EditBioSave, value: participant.about, maxLength: maxBioLength, apply: { [weak self] bio in
                                guard let self, let component = self.component, let environment = self.environment, let bio else {
                                    return
                                }
                                if peer.id.namespace == Namespaces.Peer.CloudUser {
                                    let _ = (component.call.accountContext.engine.accountData.updateAbout(about: bio)
                                    |> `catch` { _ -> Signal<Void, NoError> in
                                        return .complete()
                                    }).start()
                                } else {
                                    let _ = (component.call.accountContext.engine.peers.updatePeerDescription(peerId: peer.id, description: bio)
                                    |> `catch` { _ -> Signal<Void, NoError> in
                                        return .complete()
                                    }).start()
                                }
                                
                                self.presentUndoOverlay(content: .info(title: nil, text: environment.strings.VoiceChat_EditBioSuccess, timeout: nil, customUndoText: nil), action: { _ in return false })
                            })
                            environment.controller()?.present(controller, in: .window(.root))
                        }
                    })))
                    
                    if let peer = peer as? TelegramUser {
                        items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_ChangeName, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/ChangeName"), color: theme.actionSheet.primaryTextColor)
                        }, action: { [weak self] _, f in
                            f(.default)
                               
                            Queue.mainQueue().after(0.1) {
                                guard let self, let component = self.component, let environment = self.environment else {
                                    return
                                }
                                let controller = voiceChatUserNameController(sharedContext: component.call.accountContext.sharedContext, account: component.call.accountContext.account, forceTheme: environment.theme, title: environment.strings.VoiceChat_ChangeNameTitle, firstNamePlaceholder: environment.strings.UserInfo_FirstNamePlaceholder, lastNamePlaceholder: environment.strings.UserInfo_LastNamePlaceholder, doneButtonTitle: environment.strings.VoiceChat_EditBioSave, firstName: peer.firstName, lastName: peer.lastName, maxLength: 128, apply: { [weak self] firstAndLastName in
                                    guard let self, let component = self.component, let environment = self.environment, let (firstName, lastName) = firstAndLastName else {
                                        return
                                    }
                                    let _ = component.call.accountContext.engine.accountData.updateAccountPeerName(firstName: firstName, lastName: lastName).startStandalone()
                                    
                                    self.presentUndoOverlay(content: .info(title: nil, text: environment.strings.VoiceChat_EditNameSuccess, timeout: nil, customUndoText: nil), action: { _ in return false })
                                })
                                environment.controller()?.present(controller, in: .window(.root))
                            }
                        })))
                    }
                } else {
                    if (callState.canManageCall || callState.adminIds.contains(component.call.accountContext.account.peerId)) {
                        if callState.adminIds.contains(peer.id) {
                            if let _ = muteState {
                            } else {
                                items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_MutePeer, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { [weak self] _, f in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    
                                    let _ = component.call.updateMuteState(peerId: peer.id, isMuted: true)
                                    f(.default)
                                })))
                            }
                        } else {
                            if let muteState = muteState, !muteState.canUnmute {
                                items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_UnmutePeer, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: participant.hasRaiseHand ? "Call/Context Menu/AllowToSpeak" : "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { [weak self] _, f in
                                    guard let self, let component = self.component, let environment = self.environment else {
                                        return
                                    }
                                    
                                    let _ = component.call.updateMuteState(peerId: peer.id, isMuted: false)
                                    f(.default)
                                    
                                    self.presentUndoOverlay(content: .voiceChatCanSpeak(text: environment.strings.VoiceChat_UserCanNowSpeak(EnginePeer(participant.peer).displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string), action: { _ in return true })
                                })))
                            } else {
                                items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_MutePeer, icon: { theme in
                                    return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                                }, action: { [weak self] _, f in
                                    guard let self, let component = self.component else {
                                        return
                                    }
                                    
                                    let _ = component.call.updateMuteState(peerId: peer.id, isMuted: true)
                                    f(.default)
                                })))
                            }
                        }
                    } else {
                        if let muteState = muteState, muteState.mutedByYou {
                            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_UnmuteForMe, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Unmute"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                guard let self, let component = self.component else {
                                    return
                                }
                                
                                let _ = component.call.updateMuteState(peerId: peer.id, isMuted: false)
                                f(.default)
                            })))
                        } else {
                            items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_MuteForMe, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Call/Context Menu/Mute"), color: theme.actionSheet.primaryTextColor)
                            }, action: { [weak self] _, f in
                                guard let self, let component = self.component else {
                                    return
                                }
                                
                                let _ = component.call.updateMuteState(peerId: peer.id, isMuted: true)
                                f(.default)
                            })))
                        }
                    }
                    
                    let openTitle: String
                    let openIcon: UIImage?
                    if [Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup].contains(peer.id.namespace) {
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
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
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        
                        guard let controller = environment.controller() as? VideoChatScreenV2Impl, let navigationController = controller.parentNavigationController else {
                            return
                        }
                    
                        let context = component.call.accountContext
                        environment.controller()?.dismiss(completion: { [weak navigationController] in
                            Queue.mainQueue().after(0.3) {
                                guard let navigationController else {
                                    return
                                }
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(EnginePeer(peer)), keepStack: .always, purposefulAction: {}, peekData: nil))
                            }
                        })
                    
                        f(.dismissWithoutContent)
                    })))
                
                    if (callState.canManageCall && !callState.adminIds.contains(peer.id)), peer.id != component.call.peerId {
                        items.append(.action(ContextMenuActionItem(text: environment.strings.VoiceChat_RemovePeer, textColor: .destructive, icon: { theme in
                            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.actionSheet.destructiveActionTextColor)
                        }, action: { [weak self] c, _ in
                            c?.dismiss(completion: {
                                guard let self, let component = self.component else {
                                    return
                                }

                                let _ = (component.call.accountContext.account.postbox.loadedPeerWithId(component.call.peerId)
                                |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                                    guard let self, let component = self.component, let environment = self.environment else {
                                        return
                                    }
                                    
                                    let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                                    let actionSheet = ActionSheetController(presentationData: presentationData)
                                    var items: [ActionSheetItem] = []
                                    
                                    let nameDisplayOrder = presentationData.nameDisplayOrder
                                    items.append(DeleteChatPeerActionSheetItem(context: component.call.accountContext, peer: EnginePeer(peer), chatPeer: EnginePeer(chatPeer), action: .removeFromGroup, strings: environment.strings, nameDisplayOrder: nameDisplayOrder))

                                    items.append(ActionSheetButtonItem(title: environment.strings.VoiceChat_RemovePeerRemove, color: .destructive, action: { [weak self, weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                        
                                        guard let self, let component = self.component, let environment = self.environment else {
                                            return
                                        }
                                        
                                        let _ = component.call.accountContext.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(engine: component.call.accountContext.engine, peerId: component.call.peerId, memberId: peer.id, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)).start()
                                        component.call.removedPeer(peer.id)
                                        
                                        self.presentUndoOverlay(content: .banned(text: environment.strings.VoiceChat_RemovedPeerText(EnginePeer(peer).displayTitle(strings: environment.strings, displayOrder: nameDisplayOrder)).string), action: { _ in return false })
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
            
            let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
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
        
        private func openAvatarForEditing(fromGallery: Bool = false, completion: @escaping () -> Void = {}) {
            guard let component = self.component else {
                return
            }
            guard let callState = self.callState else {
                return
            }
            let peerId = callState.myPeerId
            
            let _ = (component.call.accountContext.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                TelegramEngine.EngineData.Item.Configuration.SearchBots()
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer, searchBotsConfiguration in
                guard let self, let component = self.component, let environment = self.environment else {
                    return
                }
                guard let peer else {
                    return
                }
                
                let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                
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
                mixin.stickersContext = LegacyPaintStickersContext(context: component.call.accountContext)
                let _ = self.currentAvatarMixin.swap(mixin)
                mixin.requestSearchController = { [weak self] assetsController in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    let controller = WebSearchController(context: component.call.accountContext, peer: peer, chatLocation: nil, configuration: searchBotsConfiguration, mode: .avatar(initialQuery: peer.id.namespace == Namespaces.Peer.CloudUser ? nil : peer.displayTitle(strings: environment.strings, displayOrder: presentationData.nameDisplayOrder), completion: { [weak self] result in
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
                        guard let self, let component = self.component else {
                            return
                        }
                        
                        let _ = self.currentAvatarMixin.swap(nil)
                        let postbox = component.call.accountContext.account.postbox
                        self.updateAvatarDisposable.set((component.call.accountContext.engine.peers.updatePeerPhoto(peerId: peerId, photo: nil, mapResourceToAvatarSizes: { resource, representations in
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
            guard let component = self.component else {
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
            component.call.account.postbox.mediaBox.storeResourceData(resource.id, data: data)
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
            
            self.currentUpdatingAvatar = (representation, 0.0)

            let postbox = component.call.account.postbox
            let signal = peerId.namespace == Namespaces.Peer.CloudUser ? component.call.accountContext.engine.accountData.updateAccountPhoto(resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: postbox, resource: resource, representations: representations)
            }) : component.call.accountContext.engine.peers.updatePeerPhoto(peerId: peerId, photo: component.call.accountContext.engine.peers.uploadedPeerPhoto(resource: resource), mapResourceToAvatarSizes: { resource, representations in
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
            guard let component = self.component else {
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
            component.call.accountContext.account.postbox.mediaBox.storeResourceData(photoResource.id, data: data)
            let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: photoResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
            
            self.currentUpdatingAvatar = (representation, 0.0)

            var videoStartTimestamp: Double? = nil
            if let adjustments = adjustments, adjustments.videoStartValue > 0.0 {
                videoStartTimestamp = adjustments.videoStartValue - adjustments.trimStartValue
            }

            let context = component.call.accountContext
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
        
        private func openTitleEditing() {
            guard let component = self.component else {
                return
            }
            
            let _ = (component.call.accountContext.account.postbox.loadedPeerWithId(component.call.peerId)
            |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                guard let self, let component = self.component, let environment = self.environment else {
                    return
                }
                guard let callState = self.callState, let peer = self.peer else {
                    return
                }
                
                let initialTitle = callState.title

                let title: String
                let text: String
                if case let .channel(channel) = peer, case .broadcast = channel.info {
                    title = environment.strings.LiveStream_EditTitle
                    text = environment.strings.LiveStream_EditTitleText
                } else {
                    title = environment.strings.VoiceChat_EditTitle
                    text = environment.strings.VoiceChat_EditTitleText
                }

                let controller = voiceChatTitleEditController(sharedContext: component.call.accountContext.sharedContext, account: component.call.accountContext.account, forceTheme: environment.theme, title: title, text: text, placeholder: EnginePeer(chatPeer).displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder), value: initialTitle, maxLength: 40, apply: { [weak self] title in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    guard let title = title, title != initialTitle else {
                        return
                    }
                    
                    component.call.updateTitle(title)

                    let text: String
                    if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                        text = title.isEmpty ? environment.strings.LiveStream_EditTitleRemoveSuccess : environment.strings.LiveStream_EditTitleSuccess(title).string
                    } else {
                        text = title.isEmpty ? environment.strings.VoiceChat_EditTitleRemoveSuccess : environment.strings.VoiceChat_EditTitleSuccess(title).string
                    }

                    self.presentUndoOverlay(content: .voiceChatFlag(text: text), action: { _ in return false })
                })
                environment.controller()?.present(controller, in: .window(.root))
            })
        }
        
        private func presentUndoOverlay(content: UndoOverlayContent, action: @escaping (UndoOverlayAction) -> Bool) {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            var animateInAsReplacement = false
            environment.controller()?.forEachController { c in
                if let c = c as? UndoOverlayController {
                    animateInAsReplacement = true
                    c.dismiss()
                }
                return true
            }
            let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
            environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, animateInAsReplacement: animateInAsReplacement, action: action), in: .current)
        }
        
        private func openInviteMembers() {
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
        
        private func presentShare(_ inviteLinks: GroupCallInviteLinks) {
            guard let component = self.component else {
                return
            }
            
            let formatSendTitle: (String) -> String = { string in
                var string = string
                if string.contains("[") && string.contains("]") {
                    if let startIndex = string.firstIndex(of: "["), let endIndex = string.firstIndex(of: "]") {
                        string.removeSubrange(startIndex ... endIndex)
                    }
                } else {
                    string = string.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789-,."))
                }
                return string
            }
            
            let _ = (component.call.accountContext.account.postbox.loadedPeerWithId(component.call.peerId)
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let component = self.component, let environment = self.environment else {
                    return
                }
                guard let peer = self.peer else {
                    return
                }
                guard let callState = self.callState else {
                    return
                }
                var inviteLinks = inviteLinks
                
                if case let .channel(peer) = peer, case .group = peer.info, !peer.flags.contains(.isGigagroup), !(peer.addressName ?? "").isEmpty, let defaultParticipantMuteState = callState.defaultParticipantMuteState {
                    let isMuted = defaultParticipantMuteState == .muted
                    
                    if !isMuted {
                        inviteLinks = GroupCallInviteLinks(listenerLink: inviteLinks.listenerLink, speakerLink: nil)
                    }
                }
                
                var segmentedValues: [ShareControllerSegmentedValue]?
                if let speakerLink = inviteLinks.speakerLink {
                    segmentedValues = [ShareControllerSegmentedValue(title: environment.strings.VoiceChat_InviteLink_Speaker, subject: .url(speakerLink), actionTitle: environment.strings.VoiceChat_InviteLink_CopySpeakerLink, formatSendTitle: { count in
                        return formatSendTitle(environment.strings.VoiceChat_InviteLink_InviteSpeakers(Int32(count)))
                    }), ShareControllerSegmentedValue(title: environment.strings.VoiceChat_InviteLink_Listener, subject: .url(inviteLinks.listenerLink), actionTitle: environment.strings.VoiceChat_InviteLink_CopyListenerLink, formatSendTitle: { count in
                        return formatSendTitle(environment.strings.VoiceChat_InviteLink_InviteListeners(Int32(count)))
                    })]
                }
                let shareController = ShareController(context: component.call.accountContext, subject: .url(inviteLinks.listenerLink), segmentedValues: segmentedValues, forceTheme: environment.theme, forcedActionTitle: environment.strings.VoiceChat_CopyInviteLink)
                shareController.completed = { [weak self] peerIds in
                    guard let self, let component = self.component else {
                        return
                    }
                    let _ = (component.call.accountContext.engine.data.get(
                        EngineDataList(
                            peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                        )
                    )
                    |> deliverOnMainQueue).start(next: { [weak self] peerList in
                        guard let self, let component = self.component, let environment = self.environment else {
                            return
                        }
                        
                        let peers = peerList.compactMap { $0 }
                        let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                        
                        let text: String
                        var isSavedMessages = false
                        if peers.count == 1, let peer = peers.first {
                            isSavedMessages = peer.id == component.call.accountContext.account.peerId
                            let peerName = peer.id == component.call.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.VoiceChat_ForwardTooltip_Chat(peerName).string
                        } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                            let firstPeerName = firstPeer.id == component.call.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            let secondPeerName = secondPeer.id == component.call.accountContext.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.VoiceChat_ForwardTooltip_TwoChats(firstPeerName, secondPeerName).string
                        } else if let peer = peers.first {
                            let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                            text = presentationData.strings.VoiceChat_ForwardTooltip_ManyChats(peerName, "\(peers.count - 1)").string
                        } else {
                            text = ""
                        }
                        
                        environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: isSavedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }), in: .current)
                    })
                }
                shareController.actionCompleted = { [weak self] in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                    environment.controller()?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.VoiceChat_InviteLinkCopiedText), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                }
                environment.controller()?.present(shareController, in: .window(.root))
            })
        }
        
        private func onCameraPressed() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            HapticFeedback().impact(.light)
            if component.call.hasVideo {
                component.call.disableVideo()
            } else {
                let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                DeviceAccess.authorizeAccess(to: .camera(.videoCall), onlyCheck: true, presentationData: presentationData, present: { [weak self] c, a in
                    guard let self, let environment = self.environment, let controller = environment.controller() else {
                        return
                    }
                    controller.present(c, in: .window(.root), with: a)
                }, openSettings: { [weak self] in
                    guard let self, let component = self.component else {
                        return
                    }
                    component.call.accountContext.sharedContext.applicationBindings.openSettings()
                }, _: { [weak self] ready in
                    guard let self, let component = self.component, let environment = self.environment, ready else {
                        return
                    }
                    var isFrontCamera = true
                    let videoCapturer = OngoingCallVideoCapturer()
                    let input = videoCapturer.video()
                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false) {
                        videoView.updateIsEnabled(true)
                        
                        let cameraNode = GroupVideoNode(videoView: videoView, backdropVideoView: nil)
                        let controller = VoiceChatCameraPreviewController(sharedContext: component.call.accountContext.sharedContext, cameraNode: cameraNode, shareCamera: { [weak self] _, unmuted in
                            guard let self, let component = self.component else {
                                return
                            }
                            
                            component.call.setIsMuted(action: unmuted ? .unmuted : .muted(isPushToTalkActive: false))
                            (component.call as! PresentationGroupCallImpl).requestVideo(capturer: videoCapturer, useFrontCamera: isFrontCamera)
                        }, switchCamera: {
                            Queue.mainQueue().after(0.1) {
                                isFrontCamera = !isFrontCamera
                                videoCapturer.switchVideoInput(isFront: isFrontCamera)
                            }
                        })
                        environment.controller()?.present(controller, in: .window(.root))
                    }
                })
            }
        }
        
        private func onAudioRoutePressed() {
            guard let component = self.component, let environment = self.environment else {
                return
            }
            
            HapticFeedback().impact(.light)
            
            guard let (availableOutputs, currentOutput) = self.audioOutputState else {
                return
            }
            guard availableOutputs.count >= 2 else {
                return
            }

            if availableOutputs.count == 2 {
                for output in availableOutputs {
                    if output != currentOutput {
                        component.call.setCurrentAudioOutput(output)
                        break
                    }
                }
            } else {
                let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).withUpdated(theme: environment.theme)
                let actionSheet = ActionSheetController(presentationData: presentationData)
                var items: [ActionSheetItem] = []
                for output in availableOutputs {
                    let title: String
                    var icon: UIImage?
                    switch output {
                    case .builtin:
                        title = UIDevice.current.model
                    case .speaker:
                        title = environment.strings.Call_AudioRouteSpeaker
                        icon = generateScaledImage(image: UIImage(bundleImageName: "Call/CallSpeakerButton"), size: CGSize(width: 48.0, height: 48.0), opaque: false)
                    case .headphones:
                        title = environment.strings.Call_AudioRouteHeadphones
                    case let .port(port):
                        title = port.name
                        if port.type == .bluetooth {
                            var image = UIImage(bundleImageName: "Call/CallBluetoothButton")
                            let portName = port.name.lowercased()
                            if portName.contains("airpods max") {
                                image = UIImage(bundleImageName: "Call/CallAirpodsMaxButton")
                            } else if portName.contains("airpods pro") {
                                image = UIImage(bundleImageName: "Call/CallAirpodsProButton")
                            } else if portName.contains("airpods") {
                                image = UIImage(bundleImageName: "Call/CallAirpodsButton")
                            }
                            icon = generateScaledImage(image: image, size: CGSize(width: 48.0, height: 48.0), opaque: false)
                        }
                    }
                    items.append(CallRouteActionSheetItem(title: title, icon: icon, selected: output == currentOutput, action: { [weak self, weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let self, let component = self.component else {
                            return
                        }
                        component.call.setCurrentAudioOutput(output)
                    }))
                }
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: environment.strings.Call_AudioRouteHide, color: .accent, font: .bold, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                environment.controller()?.present(actionSheet, in: .window(.root))
            }
        }
        
        func update(component: VideoChatScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let themeUpdated = self.environment?.theme !== environment.theme
            
            if self.component == nil {
                self.peer = component.initialData.peer
                self.members = component.initialData.members
                self.callState = component.initialData.callState
                
                self.membersDisposable = (component.call.members
                |> deliverOnMainQueue).startStrict(next: { [weak self] members in
                    guard let self else {
                        return
                    }
                    if self.members != members {
                        var members = members
                        
                        #if DEBUG && false
                        if let membersValue = members {
                            var participants = membersValue.participants
                            for i in 1 ... 20 {
                                for participant in membersValue.participants {
                                    guard let user = participant.peer as? TelegramUser else {
                                        continue
                                    }
                                    let mappedUser = TelegramUser(
                                        id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(user.id.id._internalGetInt64Value() + Int64(i))),
                                        accessHash: user.accessHash,
                                        firstName: user.firstName,
                                        lastName: user.lastName,
                                        username: user.username,
                                        phone: user.phone,
                                        photo: user.photo,
                                        botInfo: user.botInfo,
                                        restrictionInfo: user.restrictionInfo,
                                        flags: user.flags,
                                        emojiStatus: user.emojiStatus,
                                        usernames: user.usernames,
                                        storiesHidden: user.storiesHidden,
                                        nameColor: user.nameColor,
                                        backgroundEmojiId: user.backgroundEmojiId,
                                        profileColor: user.profileColor,
                                        profileBackgroundEmojiId: user.profileBackgroundEmojiId,
                                        subscriberCount: user.subscriberCount
                                    )
                                    participants.append(GroupCallParticipantsContext.Participant(
                                        peer: mappedUser,
                                        ssrc: participant.ssrc,
                                        videoDescription: participant.videoDescription,
                                        presentationDescription: participant.presentationDescription,
                                        joinTimestamp: participant.joinTimestamp,
                                        raiseHandRating: participant.raiseHandRating,
                                        hasRaiseHand: participant.hasRaiseHand,
                                        activityTimestamp: participant.activityTimestamp,
                                        activityRank: participant.activityRank,
                                        muteState: participant.muteState,
                                        volume: participant.volume,
                                        about: participant.about,
                                        joinedVideo: participant.joinedVideo
                                    ))
                                }
                            }
                            members = PresentationGroupCallMembers(
                                participants: participants,
                                speakingParticipants: membersValue.speakingParticipants,
                                totalCount: membersValue.totalCount,
                                loadMoreToken: membersValue.loadMoreToken
                            )
                        }
                        #endif
                        
                        if let membersValue = members {
                            var participants = membersValue.participants
                            participants = participants.sorted(by: { lhs, rhs in
                                guard let lhsIndex = membersValue.participants.firstIndex(where: { $0.peer.id == lhs.peer.id }) else {
                                    return false
                                }
                                guard let rhsIndex = membersValue.participants.firstIndex(where: { $0.peer.id == rhs.peer.id }) else {
                                    return false
                                }
                                
                                if let lhsActivityRank = lhs.activityRank, let rhsActivityRank = rhs.activityRank {
                                    if lhsActivityRank != rhsActivityRank {
                                        return lhsActivityRank < rhsActivityRank
                                    }
                                } else if (lhs.activityRank == nil) != (rhs.activityRank == nil) {
                                    return lhs.activityRank != nil
                                }
                                
                                return lhsIndex < rhsIndex
                            })
                            members = PresentationGroupCallMembers(
                                participants: participants,
                                speakingParticipants: membersValue.speakingParticipants,
                                totalCount: membersValue.totalCount,
                                loadMoreToken: membersValue.loadMoreToken
                            )
                        }
                        
                        self.members = members
                        
                        if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, let members {
                            if !expandedParticipantsVideoState.isMainParticipantPinned, let participant = members.participants.first(where: { participant in
                                if let callState = self.callState, participant.peer.id == callState.myPeerId {
                                    return false
                                }
                                if participant.videoDescription != nil || participant.presentationDescription != nil {
                                    if members.speakingParticipants.contains(participant.peer.id) {
                                        return true
                                    }
                                }
                                return false
                            }) {
                                if participant.peer.id != expandedParticipantsVideoState.mainParticipant.id {
                                    if participant.presentationDescription != nil {
                                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: true), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                    } else {
                                        self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                    }
                                }
                            }
                            
                            if let _ = members.participants.first(where: { participant in
                                if participant.peer.id == expandedParticipantsVideoState.mainParticipant.id {
                                    if expandedParticipantsVideoState.mainParticipant.isPresentation {
                                        if participant.presentationDescription == nil {
                                            return false
                                        }
                                    } else {
                                        if participant.videoDescription == nil {
                                            return false
                                        }
                                    }
                                    return true
                                }
                                return false
                            }) {
                            } else if let participant = members.participants.first(where: { participant in
                                if participant.presentationDescription != nil {
                                    return true
                                }
                                if participant.videoDescription != nil {
                                    return true
                                }
                                return false
                            }) {
                                if participant.presentationDescription != nil {
                                    self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: true), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                } else {
                                    self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: VideoChatParticipantsComponent.VideoParticipantKey(id: participant.peer.id, isPresentation: false), isMainParticipantPinned: false, isUIHidden: expandedParticipantsVideoState.isUIHidden)
                                }
                            } else {
                                self.expandedParticipantsVideoState = nil
                            }
                        } else {
                            self.expandedParticipantsVideoState = nil
                        }
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                })
                
                self.stateDisposable = (component.call.state
                |> deliverOnMainQueue).startStrict(next: { [weak self] callState in
                    guard let self else {
                        return
                    }
                    if self.callState != callState {
                        self.callState = callState
                        
                        if !self.isUpdating {
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    }
                })
                
                self.applicationStateDisposable = (combineLatest(queue: .mainQueue(),
                    component.call.accountContext.sharedContext.applicationBindings.applicationIsActive,
                    self.isPresentedValue.get()
                )
                |> deliverOnMainQueue).startStrict(next: { [weak self] applicationIsActive, isPresented in
                    guard let self, let component = self.component else {
                        return
                    }
                    let suspendVideoChannelRequests = !applicationIsActive || !isPresented
                    component.call.setSuspendVideoChannelRequests(suspendVideoChannelRequests)
                })
                
                self.audioOutputStateDisposable = (component.call.audioOutputState
                |> deliverOnMainQueue).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    
                    var existingOutputs = Set<String>()
                    var filteredOutputs: [AudioSessionOutput] = []
                    for output in state.0 {
                        if case let .port(port) = output {
                            if !existingOutputs.contains(port.name) {
                                existingOutputs.insert(port.name)
                                filteredOutputs.append(output)
                            }
                        } else {
                            filteredOutputs.append(output)
                        }
                    }
                    
                    self.audioOutputState = (filteredOutputs, state.1)
                    self.state?.updated(transition: .spring(duration: 0.4))
                })
                
                let currentAccountPeer = component.call.accountContext.account.postbox.loadedPeerWithId(component.call.accountContext.account.peerId)
                |> map { peer in
                    return [FoundPeer(peer: peer, subscribers: nil)]
                }
                let displayAsPeers: Signal<[FoundPeer], NoError> = currentAccountPeer
                |> then(
                    combineLatest(currentAccountPeer, component.call.accountContext.engine.calls.cachedGroupCallDisplayAsAvailablePeers(peerId: component.call.peerId))
                    |> map { currentAccountPeer, availablePeers -> [FoundPeer] in
                        var result = currentAccountPeer
                        result.append(contentsOf: availablePeers)
                        return result
                    }
                )
                self.displayAsPeersDisposable = (displayAsPeers
                |> deliverOnMainQueue).start(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.displayAsPeers = value
                })
                
                self.inviteLinksDisposable = (component.call.inviteLinks
                |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    self.inviteLinks = value
                })
                
                self.reconnectedAsEventsDisposable = (component.call.reconnectedAsEvents
                |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
                    guard let self, let component = self.component, let environment = self.environment else {
                        return
                    }
                    let text: String
                    if case let .channel(channel) = self.peer, case .broadcast = channel.info {
                        text = environment.strings.LiveStream_DisplayAsSuccess(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                    } else {
                        text = environment.strings.VoiceChat_DisplayAsSuccess(peer.displayTitle(strings: environment.strings, displayOrder: component.call.accountContext.sharedContext.currentPresentationData.with({ $0 }).nameDisplayOrder)).string
                    }
                    self.presentUndoOverlay(content: .invitedToVoiceChat(context: component.call.accountContext, peer: peer, title: nil, text: text, action: nil, duration: 3), action: { _ in return false })
                })
            }
            
            self.isPresentedValue.set(environment.isVisible)
            
            self.component = component
            self.environment = environment
            self.state = state
            
            if themeUpdated {
                self.containerView.backgroundColor = .black
            }
            
            var mappedParticipants: VideoChatParticipantsComponent.Participants?
            if let members = self.members, let callState = self.callState {
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
                
                mappedParticipants = VideoChatParticipantsComponent.Participants(
                    myPeerId: callState.myPeerId,
                    participants: members.participants,
                    totalCount: members.totalCount,
                    loadMoreToken: members.loadMoreToken,
                    inviteType: inviteType
                )
            }
            
            let maxSingleColumnWidth: CGFloat = 620.0
            let isTwoColumnLayout: Bool
            if availableSize.width > maxSingleColumnWidth {
                if let mappedParticipants, mappedParticipants.participants.contains(where: { $0.videoDescription != nil || $0.presentationDescription != nil }) {
                    isTwoColumnLayout = true
                } else {
                    isTwoColumnLayout = false
                }
            } else {
                isTwoColumnLayout = false
            }
            
            var containerOffset: CGFloat = 0.0
            if let panGestureState = self.panGestureState {
                containerOffset = panGestureState.offsetFraction * availableSize.height
                self.containerView.layer.cornerRadius = environment.deviceMetrics.screenCornerRadius
            }
            
            transition.setFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: containerOffset), size: availableSize), completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                if self.panGestureState == nil {
                    self.containerView.layer.cornerRadius = 0.0
                }
                if self.notifyDismissedInteractivelyOnPanGestureApply {
                    self.notifyDismissedInteractivelyOnPanGestureApply = false
                    
                    if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                        if self.isUpdating {
                            DispatchQueue.main.async { [weak controller] in
                                controller?.superDismiss()
                            }
                        } else {
                            controller.superDismiss()
                        }
                    }
                }
                if let completionOnPanGestureApply = self.completionOnPanGestureApply {
                    self.completionOnPanGestureApply = nil
                    DispatchQueue.main.async {
                        completionOnPanGestureApply()
                    }
                }
            })
            
            let sideInset: CGFloat = max(environment.safeInsets.left, 14.0)
            
            let topInset: CGFloat = environment.statusBarHeight + 2.0
            let navigationBarHeight: CGFloat = 61.0
            let navigationHeight = topInset + navigationBarHeight
            
            let navigationButtonAreaWidth: CGFloat = 40.0
            let navigationButtonDiameter: CGFloat = 28.0
            
            let navigationLeftButtonSize = self.navigationLeftButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(
                            name: "anim_profilemore"
                        ),
                        color: .white
                    )),
                    background: AnyComponent(Circle(
                        fillColor: UIColor(white: 1.0, alpha: 0.1),
                        size: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openMoreMenu()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
            )
            
            let navigationRightButtonSize = self.navigationRightButton.update(
                transition: .immediate,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(Image(
                        image: closeButtonImage(dark: false)
                    )),
                    background: AnyComponent(Circle(
                        fillColor: UIColor(white: 1.0, alpha: 0.1),
                        size: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.environment?.controller()?.dismiss()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
            )
            
            let navigationLeftButtonFrame = CGRect(origin: CGPoint(x: sideInset + floor((navigationButtonAreaWidth - navigationLeftButtonSize.width) * 0.5), y: topInset + floor((navigationBarHeight - navigationLeftButtonSize.height) * 0.5)), size: navigationLeftButtonSize)
            if let navigationLeftButtonView = self.navigationLeftButton.view {
                if navigationLeftButtonView.superview == nil {
                    self.containerView.addSubview(navigationLeftButtonView)
                }
                transition.setFrame(view: navigationLeftButtonView, frame: navigationLeftButtonFrame)
            }
            
            let navigationRightButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - sideInset - navigationButtonAreaWidth + floor((navigationButtonAreaWidth - navigationRightButtonSize.width) * 0.5), y: topInset + floor((navigationBarHeight - navigationRightButtonSize.height) * 0.5)), size: navigationRightButtonSize)
            if let navigationRightButtonView = self.navigationRightButton.view {
                if navigationRightButtonView.superview == nil {
                    self.containerView.addSubview(navigationRightButtonView)
                }
                transition.setFrame(view: navigationRightButtonView, frame: navigationRightButtonFrame)
            }
            
            if isTwoColumnLayout, !"".isEmpty {
                var navigationSidebarButtonTransition = transition
                let navigationSidebarButton: ComponentView<Empty>
                if let current = self.navigationSidebarButton {
                    navigationSidebarButton = current
                } else {
                    navigationSidebarButtonTransition = navigationSidebarButtonTransition.withAnimation(.none)
                    navigationSidebarButton = ComponentView()
                    self.navigationSidebarButton = navigationSidebarButton
                }
                let navigationSidebarButtonSize = navigationSidebarButton.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(BundleIconComponent(
                            name: "Call/PanelIcon",
                            tintColor: .white
                        )),
                        background: AnyComponent(Circle(
                            fillColor: UIColor(white: 1.0, alpha: 0.1),
                            size: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                        )),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState {
                                self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(
                                    mainParticipant: expandedParticipantsVideoState.mainParticipant,
                                    isMainParticipantPinned: expandedParticipantsVideoState.isMainParticipantPinned,
                                    isUIHidden: !expandedParticipantsVideoState.isUIHidden
                                )
                                self.state?.updated(transition: .spring(duration: 0.4))
                            } else {
                                
                            }
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: navigationButtonDiameter, height: navigationButtonDiameter)
                )
                let navigationSidebarButtonFrame = CGRect(origin: CGPoint(x: navigationRightButtonFrame.minX - 32.0 - navigationSidebarButtonSize.width, y: topInset + floor((navigationBarHeight - navigationSidebarButtonSize.height) * 0.5)), size: navigationSidebarButtonSize)
                if let navigationSidebarButtonView = navigationSidebarButton.view {
                    if navigationSidebarButtonView.superview == nil {
                        if let navigationRightButtonView = self.navigationRightButton.view {
                            self.containerView.insertSubview(navigationSidebarButtonView, aboveSubview: navigationRightButtonView)
                        }
                    }
                    transition.setFrame(view: navigationSidebarButtonView, frame: navigationSidebarButtonFrame)
                }
            } else if let navigationSidebarButton = self.navigationSidebarButton {
                self.navigationSidebarButton = nil
                if let navigationSidebarButtonView = navigationSidebarButton.view {
                    transition.setScale(view: navigationSidebarButtonView, scale: 0.001)
                    transition.setAlpha(view: navigationSidebarButtonView, alpha: 0.0, completion: { [weak navigationSidebarButtonView] _ in
                        navigationSidebarButtonView?.removeFromSuperview()
                    })
                }
            }
            
            let idleTitleStatusText: String
            if let callState = self.callState, callState.networkState == .connected, let members = self.members {
                idleTitleStatusText = environment.strings.VoiceChat_Panel_Members(Int32(max(1, members.totalCount)))
            } else {
                idleTitleStatusText = "connecting..."
            }
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(VideoChatTitleComponent(
                    title: self.callState?.title ?? self.peer?.debugDisplayTitle ?? " ",
                    status: idleTitleStatusText,
                    strings: environment.strings
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - navigationButtonAreaWidth * 2.0 - 4.0 * 2.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5), y: topInset + floor((navigationBarHeight - titleSize.height) * 0.5)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.containerView.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let areButtonsCollapsed: Bool
            let mainColumnWidth: CGFloat
            let mainColumnSideInset: CGFloat
            
            if isTwoColumnLayout {
                areButtonsCollapsed = false
                
                mainColumnWidth = 320.0
                mainColumnSideInset = 0.0
            } else {
                areButtonsCollapsed = self.expandedParticipantsVideoState != nil
                
                if availableSize.width > maxSingleColumnWidth {
                    mainColumnWidth = 420.0
                    mainColumnSideInset = 0.0
                } else {
                    mainColumnWidth = availableSize.width
                    mainColumnSideInset = sideInset
                }
            }
            
            let actionButtonDiameter: CGFloat = 56.0
            let expandedMicrophoneButtonDiameter: CGFloat = actionButtonDiameter
            var collapsedMicrophoneButtonDiameter: CGFloat = 116.0
            
            let maxActionMicrophoneButtonSpacing: CGFloat = 38.0
            let minActionMicrophoneButtonSpacing: CGFloat = 20.0
            
            if actionButtonDiameter * 2.0 + collapsedMicrophoneButtonDiameter + maxActionMicrophoneButtonSpacing * 2.0 > mainColumnWidth {
                collapsedMicrophoneButtonDiameter = mainColumnWidth - (actionButtonDiameter * 2.0 + minActionMicrophoneButtonSpacing * 2.0)
                collapsedMicrophoneButtonDiameter = max(actionButtonDiameter, collapsedMicrophoneButtonDiameter)
            }
            
            let microphoneButtonDiameter: CGFloat
            if isTwoColumnLayout {
                microphoneButtonDiameter = collapsedMicrophoneButtonDiameter
            } else {
                if areButtonsCollapsed {
                    microphoneButtonDiameter = expandedMicrophoneButtonDiameter
                } else {
                    microphoneButtonDiameter = self.expandedParticipantsVideoState == nil ? collapsedMicrophoneButtonDiameter : expandedMicrophoneButtonDiameter
                }
            }
            
            let buttonsSideInset: CGFloat = 42.0
            
            let buttonsWidth: CGFloat = actionButtonDiameter * 2.0 + microphoneButtonDiameter
            let remainingButtonsSpace: CGFloat = availableSize.width - buttonsSideInset * 2.0 - buttonsWidth
            let actionMicrophoneButtonSpacing = min(maxActionMicrophoneButtonSpacing, floor(remainingButtonsSpace * 0.5))
            
            var collapsedMicrophoneButtonFrame: CGRect = CGRect(origin: CGPoint(x: floor((availableSize.width - collapsedMicrophoneButtonDiameter) * 0.5), y: availableSize.height - 48.0 - environment.safeInsets.bottom - collapsedMicrophoneButtonDiameter), size: CGSize(width: collapsedMicrophoneButtonDiameter, height: collapsedMicrophoneButtonDiameter))
            var expandedMicrophoneButtonFrame: CGRect = CGRect(origin: CGPoint(x: floor((availableSize.width - expandedMicrophoneButtonDiameter) * 0.5), y: availableSize.height - environment.safeInsets.bottom - expandedMicrophoneButtonDiameter - 12.0), size: CGSize(width: expandedMicrophoneButtonDiameter, height: expandedMicrophoneButtonDiameter))
            if isTwoColumnLayout {
                if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.isUIHidden {
                    collapsedMicrophoneButtonFrame.origin.x = availableSize.width - sideInset - mainColumnWidth + floor((mainColumnWidth - collapsedMicrophoneButtonDiameter) * 0.5) + sideInset + mainColumnWidth
                } else {
                    collapsedMicrophoneButtonFrame.origin.x = availableSize.width - sideInset - mainColumnWidth + floor((mainColumnWidth - collapsedMicrophoneButtonDiameter) * 0.5)
                }
                expandedMicrophoneButtonFrame = collapsedMicrophoneButtonFrame
            } else {
                if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.isUIHidden {
                    expandedMicrophoneButtonFrame.origin.y = availableSize.height + expandedMicrophoneButtonDiameter + 12.0
                }
            }
            
            let microphoneButtonFrame: CGRect
            if areButtonsCollapsed {
                microphoneButtonFrame = expandedMicrophoneButtonFrame
            } else {
                microphoneButtonFrame = collapsedMicrophoneButtonFrame
            }
            
            let collapsedParticipantsClippingY: CGFloat
            collapsedParticipantsClippingY = collapsedMicrophoneButtonFrame.minY - 16.0
            
            let expandedParticipantsClippingY: CGFloat
            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.isUIHidden {
                if isTwoColumnLayout {
                    expandedParticipantsClippingY = expandedMicrophoneButtonFrame.minY - 24.0
                } else {
                    expandedParticipantsClippingY = availableSize.height - max(14.0, environment.safeInsets.bottom)
                }
            } else {
                expandedParticipantsClippingY = expandedMicrophoneButtonFrame.minY - 24.0
            }
            
            let leftActionButtonFrame = CGRect(origin: CGPoint(x: microphoneButtonFrame.minX - actionMicrophoneButtonSpacing - actionButtonDiameter, y: microphoneButtonFrame.minY + floor((microphoneButtonFrame.height - actionButtonDiameter) * 0.5)), size: CGSize(width: actionButtonDiameter, height: actionButtonDiameter))
            let rightActionButtonFrame = CGRect(origin: CGPoint(x: microphoneButtonFrame.maxX + actionMicrophoneButtonSpacing, y: microphoneButtonFrame.minY + floor((microphoneButtonFrame.height - actionButtonDiameter) * 0.5)), size: CGSize(width: actionButtonDiameter, height: actionButtonDiameter))
            
            let participantsSize = availableSize
            
            let columnSpacing: CGFloat = 14.0
            let participantsLayout: VideoChatParticipantsComponent.Layout
            if isTwoColumnLayout {
                let mainColumnInsets: UIEdgeInsets = UIEdgeInsets(top: navigationHeight, left: mainColumnSideInset, bottom: availableSize.height - collapsedParticipantsClippingY, right: mainColumnSideInset)
                let videoColumnWidth: CGFloat = max(10.0, availableSize.width - sideInset * 2.0 - mainColumnWidth - columnSpacing)
                participantsLayout = VideoChatParticipantsComponent.Layout(
                    videoColumn: VideoChatParticipantsComponent.Layout.Column(
                        width: videoColumnWidth,
                        insets: UIEdgeInsets(top: navigationHeight, left: 0.0, bottom: max(14.0, environment.safeInsets.bottom), right: 0.0)
                    ),
                    mainColumn: VideoChatParticipantsComponent.Layout.Column(
                        width: mainColumnWidth,
                        insets: mainColumnInsets
                    ),
                    columnSpacing: columnSpacing
                )
            } else {
                let mainColumnInsets: UIEdgeInsets = UIEdgeInsets(top: navigationHeight, left: mainColumnSideInset, bottom: availableSize.height - collapsedParticipantsClippingY, right: mainColumnSideInset)
                participantsLayout = VideoChatParticipantsComponent.Layout(
                    videoColumn: nil,
                    mainColumn: VideoChatParticipantsComponent.Layout.Column(
                        width: mainColumnWidth,
                        insets: mainColumnInsets
                    ),
                    columnSpacing: columnSpacing
                )
            }
            
            let participantsSafeInsets = UIEdgeInsets(
                top: environment.statusBarHeight,
                left: environment.safeInsets.left,
                bottom: max(14.0, environment.safeInsets.bottom),
                right: environment.safeInsets.right
            )
            let participantsExpandedInsets: UIEdgeInsets
            if isTwoColumnLayout {
                participantsExpandedInsets = UIEdgeInsets(
                    top: navigationHeight,
                    left: max(14.0, participantsSafeInsets.left),
                    bottom: participantsSafeInsets.bottom,
                    right: max(14.0, participantsSafeInsets.right)
                )
            } else {
                participantsExpandedInsets = UIEdgeInsets(
                    top: participantsSafeInsets.top,
                    left: participantsSafeInsets.left,
                    bottom: availableSize.height - expandedParticipantsClippingY,
                    right: participantsSafeInsets.right
                )
            }
            
            let _ = self.participants.update(
                transition: transition,
                component: AnyComponent(VideoChatParticipantsComponent(
                    call: component.call,
                    participants: mappedParticipants,
                    speakingParticipants: members?.speakingParticipants ?? Set(),
                    expandedVideoState: self.expandedParticipantsVideoState,
                    theme: environment.theme,
                    strings: environment.strings,
                    layout: participantsLayout,
                    expandedInsets: participantsExpandedInsets,
                    safeInsets: participantsSafeInsets,
                    interfaceOrientation: environment.orientation ?? .portrait,
                    openParticipantContextMenu: { [weak self] id, sourceView, gesture in
                        guard let self else {
                            return
                        }
                        self.openParticipantContextMenu(id: id, sourceView: sourceView, gesture: gesture)
                    },
                    updateMainParticipant: { [weak self] key in
                        guard let self else {
                            return
                        }
                        if let key {
                            if let expandedParticipantsVideoState = self.expandedParticipantsVideoState, expandedParticipantsVideoState.mainParticipant == key {
                                return
                            }
                            self.expandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(mainParticipant: key, isMainParticipantPinned: false, isUIHidden: self.expandedParticipantsVideoState?.isUIHidden ?? false)
                            self.state?.updated(transition: .spring(duration: 0.4))
                        } else if self.expandedParticipantsVideoState != nil {
                            self.expandedParticipantsVideoState = nil
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    updateIsMainParticipantPinned: { [weak self] isPinned in
                        guard let self else {
                            return
                        }
                        guard let expandedParticipantsVideoState = self.expandedParticipantsVideoState else {
                            return
                        }
                        let updatedExpandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(
                            mainParticipant: expandedParticipantsVideoState.mainParticipant,
                            isMainParticipantPinned: isPinned,
                            isUIHidden: expandedParticipantsVideoState.isUIHidden
                        )
                        if self.expandedParticipantsVideoState != updatedExpandedParticipantsVideoState {
                            self.expandedParticipantsVideoState = updatedExpandedParticipantsVideoState
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    updateIsExpandedUIHidden: { [weak self] isUIHidden in
                        guard let self else {
                            return
                        }
                        guard let expandedParticipantsVideoState = self.expandedParticipantsVideoState else {
                            return
                        }
                        let updatedExpandedParticipantsVideoState = VideoChatParticipantsComponent.ExpandedVideoState(
                            mainParticipant: expandedParticipantsVideoState.mainParticipant,
                            isMainParticipantPinned: expandedParticipantsVideoState.isMainParticipantPinned,
                            isUIHidden: isUIHidden
                        )
                        if self.expandedParticipantsVideoState != updatedExpandedParticipantsVideoState {
                            self.expandedParticipantsVideoState = updatedExpandedParticipantsVideoState
                            self.state?.updated(transition: .spring(duration: 0.4))
                        }
                    },
                    openInviteMembers: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.openInviteMembers()
                    }
                )),
                environment: {},
                containerSize: participantsSize
            )
            let participantsFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: participantsSize)
            if let participantsView = self.participants.view {
                if participantsView.superview == nil {
                    self.containerView.addSubview(participantsView)
                }
                transition.setFrame(view: participantsView, frame: participantsFrame)
            }
            
            let micButtonContent: VideoChatMicButtonComponent.Content
            let actionButtonMicrophoneState: VideoChatActionButtonComponent.MicrophoneState
            if let callState = self.callState {
                switch callState.networkState {
                case .connecting:
                    micButtonContent = .connecting
                    actionButtonMicrophoneState = .connecting
                case .connected:
                    if let callState = callState.muteState {
                        if callState.canUnmute {
                            if self.isPushToTalkActive {
                                micButtonContent = .unmuted(pushToTalk: self.isPushToTalkActive)
                                actionButtonMicrophoneState = .unmuted
                            } else {
                                micButtonContent = .muted
                                actionButtonMicrophoneState = .muted
                            }
                        } else {
                            micButtonContent = .raiseHand
                            actionButtonMicrophoneState = .raiseHand
                        }
                    } else {
                        micButtonContent = .unmuted(pushToTalk: false)
                        actionButtonMicrophoneState = .unmuted
                    }
                }
            } else {
                micButtonContent = .connecting
                actionButtonMicrophoneState = .connecting
            }
            
            let _ = self.microphoneButton.update(
                transition: transition,
                component: AnyComponent(VideoChatMicButtonComponent(
                    call: component.call,
                    content: micButtonContent,
                    isCollapsed: areButtonsCollapsed,
                    updateUnmutedStateIsPushToTalk: { [weak self] unmutedStateIsPushToTalk in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        
                        if let unmutedStateIsPushToTalk {
                            if unmutedStateIsPushToTalk {
                                if let muteState = callState.muteState {
                                    if muteState.canUnmute {
                                        self.isPushToTalkActive = true
                                        component.call.setIsMuted(action: .muted(isPushToTalkActive: true))
                                    } else {
                                        self.isPushToTalkActive = false
                                    }
                                } else {
                                    self.isPushToTalkActive = true
                                    component.call.setIsMuted(action: .muted(isPushToTalkActive: true))
                                }
                            } else {
                                if let muteState = callState.muteState {
                                    if muteState.canUnmute {
                                        component.call.setIsMuted(action: .unmuted)
                                    }
                                }
                                self.isPushToTalkActive = false
                            }
                            self.state?.updated(transition: .spring(duration: 0.5))
                        } else {
                            component.call.setIsMuted(action: .muted(isPushToTalkActive: false))
                            self.isPushToTalkActive = false
                            self.state?.updated(transition: .spring(duration: 0.5))
                        }
                    },
                    raiseHand: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        guard let callState = self.callState else {
                            return
                        }
                        if !callState.raisedHand {
                            component.call.raiseHand()
                        }
                    }
                )),
                environment: {},
                containerSize: CGSize(width: microphoneButtonDiameter, height: microphoneButtonDiameter)
            )
            if let microphoneButtonView = self.microphoneButton.view {
                if microphoneButtonView.superview == nil {
                    self.containerView.addSubview(microphoneButtonView)
                }
                transition.setPosition(view: microphoneButtonView, position: microphoneButtonFrame.center)
                transition.setBounds(view: microphoneButtonView, bounds: CGRect(origin: CGPoint(), size: microphoneButtonFrame.size))
            }
            
            let videoButtonContent: VideoChatActionButtonComponent.Content
            if let callState = self.callState, let muteState = callState.muteState, !muteState.canUnmute {
                var buttonAudio: VideoChatActionButtonComponent.Content.Audio = .speaker
                if let (availableOutputs, maybeCurrentOutput) = self.audioOutputState, let currentOutput = maybeCurrentOutput {
                    switch currentOutput {
                    case .builtin:
                        buttonAudio = .builtin
                    case .speaker:
                        buttonAudio = .speaker
                    case .headphones:
                        buttonAudio = .headphones
                    case let .port(port):
                        var type: VideoChatActionButtonComponent.Content.BluetoothType = .generic
                        let portName = port.name.lowercased()
                        if portName.contains("airpods max") {
                            type = .airpodsMax
                        } else if portName.contains("airpods pro") {
                            type = .airpodsPro
                        } else if portName.contains("airpods") {
                            type = .airpods
                        }
                        buttonAudio = .bluetooth(type)
                    }
                    if availableOutputs.count <= 1 {
                        buttonAudio = .none
                    }
                }
                videoButtonContent = .audio(audio: buttonAudio)
            } else {
                //TODO:release
                videoButtonContent = .video(isActive: false)
            }
            let _ = self.videoButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(VideoChatActionButtonComponent(
                        strings: environment.strings,
                        content: videoButtonContent,
                        microphoneState: actionButtonMicrophoneState,
                        isCollapsed: areButtonsCollapsed
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        if let callState = self.callState, let muteState = callState.muteState, !muteState.canUnmute {
                            self.onAudioRoutePressed()
                        } else {
                            self.onCameraPressed()
                        }
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonDiameter, height: actionButtonDiameter)
            )
            if let videoButtonView = self.videoButton.view {
                if videoButtonView.superview == nil {
                    self.containerView.addSubview(videoButtonView)
                }
                transition.setPosition(view: videoButtonView, position: leftActionButtonFrame.center)
                transition.setBounds(view: videoButtonView, bounds: CGRect(origin: CGPoint(), size: leftActionButtonFrame.size))
            }
            
            let _ = self.leaveButton.update(
                transition: transition,
                component: AnyComponent(PlainButtonComponent(
                    content: AnyComponent(VideoChatActionButtonComponent(
                        strings: environment.strings,
                        content: .leave,
                        microphoneState: actionButtonMicrophoneState,
                        isCollapsed: areButtonsCollapsed
                    )),
                    effectAlignment: .center,
                    action: { [weak self] in
                        guard let self, let component = self.component else {
                            return
                        }
                        let _ = component.call.leave(terminateIfPossible: false).startStandalone()
                        
                        if let controller = self.environment?.controller() as? VideoChatScreenV2Impl {
                            controller.dismiss(closing: true, manual: false)
                        }
                    },
                    animateAlpha: false
                )),
                environment: {},
                containerSize: CGSize(width: actionButtonDiameter, height: actionButtonDiameter)
            )
            if let leaveButtonView = self.leaveButton.view {
                if leaveButtonView.superview == nil {
                    self.containerView.addSubview(leaveButtonView)
                }
                transition.setPosition(view: leaveButtonView, position: rightActionButtonFrame.center)
                transition.setBounds(view: leaveButtonView, bounds: CGRect(origin: CGPoint(), size: rightActionButtonFrame.size))
            }
            
            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class VideoChatScreenV2Impl: ViewControllerComponentContainer, VoiceChatController {
    final class InitialData {
        let peer: EnginePeer?
        let members: PresentationGroupCallMembers?
        let callState: PresentationGroupCallState
        
        init(
            peer: EnginePeer?,
            members: PresentationGroupCallMembers?,
            callState: PresentationGroupCallState
        ) {
            self.peer = peer
            self.members = members
            self.callState = callState
        }
    }
    
    public let call: PresentationGroupCall
    public var currentOverlayController: VoiceChatOverlayController?
    public var parentNavigationController: NavigationController?
    
    public var onViewDidAppear: (() -> Void)?
    public var onViewDidDisappear: (() -> Void)?
    
    private var isDismissed: Bool = true
    private var didAppearOnce: Bool = false
    private var isAnimatingDismiss: Bool = false
    
    private var idleTimerExtensionDisposable: Disposable?

    public init(
        initialData: InitialData,
        call: PresentationGroupCall
    ) {
        self.call = call

        let theme = customizeDefaultDarkPresentationTheme(
            theme: defaultDarkPresentationTheme,
            editing: false,
            title: nil,
            accentColor: UIColor(rgb: 0x3E88F7),
            backgroundColors: [],
            bubbleColors: [],
            animateBubbleColors: false
        )
        
        super.init(
            context: call.accountContext,
            component: VideoChatScreenComponent(
                initialData: initialData,
                call: call
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .default,
            presentationMode: .default,
            theme: .custom(theme)
        )
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.idleTimerExtensionDisposable?.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if self.isDismissed {
            self.isDismissed = false
            
            if let componentView = self.node.hostView.componentView as? VideoChatScreenComponent.View {
                componentView.animateIn()
            }
        }
        
        if !self.didAppearOnce {
            self.didAppearOnce = true
            
            self.idleTimerExtensionDisposable?.dispose()
            self.idleTimerExtensionDisposable = self.call.accountContext.sharedContext.applicationBindings.pushIdleTimerExtension()
        }
        
        DispatchQueue.main.async {
            self.onViewDidAppear?()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.idleTimerExtensionDisposable?.dispose()
        self.idleTimerExtensionDisposable = nil
        
        self.didAppearOnce = false
        self.notifyDismissed()
    }
    
    func notifyDismissed() {
        if !self.isDismissed {
            self.isDismissed = true
            DispatchQueue.main.async {
                self.onViewDidDisappear?()
            }
        }
    }

    public func dismiss(closing: Bool, manual: Bool) {
        self.dismiss()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isAnimatingDismiss {
            self.notifyDismissed()
            
            if let componentView = self.node.hostView.componentView as? VideoChatScreenComponent.View {
                self.isAnimatingDismiss = true
                componentView.animateOut(completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isAnimatingDismiss = false
                    self.superDismiss()
                })
            } else {
                self.superDismiss()
            }
        }
    }
    
    func superDismiss() {
        super.dismiss()
    }
    
    static func initialData(call: PresentationGroupCall) -> Signal<InitialData, NoError> {
        return combineLatest(
            call.accountContext.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: call.peerId)
            ),
            call.members |> take(1),
            call.state |> take(1)
        )
        |> map { peer, members, callState -> InitialData in
            return InitialData(
                peer: peer,
                members: members,
                callState: callState
            )
        }
    }
}

private final class ParticipantExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    //let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
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
