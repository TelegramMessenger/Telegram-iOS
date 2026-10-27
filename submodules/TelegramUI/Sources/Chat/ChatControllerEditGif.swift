import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AsyncDisplayKit
import Display
import AccountContext
import ChatControllerInteraction
import LegacyMediaPickerUI
import MediaPickerUI
import ChatMediaEditorScreen

extension ChatControllerImpl {
    func openGifEditing(file: FileMediaReference, addCaption: Bool) {
        guard let peer = self.presentationInterfaceState.renderedPeer?.peer else {
            return
        }
        let hasSilentPosting = peer.id != self.context.account.peerId
        let hasSchedule = self.presentationInterfaceState.subject != .scheduledMessages && peer.id.namespace != Namespaces.Peer.SecretChat && self.presentationInterfaceState.sendPaidMessageStars == nil
        let mode: LegacyMediaEditorMode = addCaption ? .caption : .default
        if self.context.routesToChatMediaEditorV2(.animatedFileEditor), let initialTool = chatMediaEditorInitialTool(mode) {
            presentChatMediaEditor(
                context: self.context,
                media: file.abstract,
                initialTool: initialTool,
                initialCaption: NSAttributedString(),
                recipientName: chatMediaEditorRecipientName(context: self.context, peer: EnginePeer(peer), threadTitle: nil),
                getCaptionPanelView: { [weak self] in
                    return self?.getCaptionPanelView(isFile: false, hasTimer: false)
                },
                hasSilentPosting: hasSilentPosting,
                hasSchedule: hasSchedule,
                reminder: peer.id == self.context.account.peerId,
                presentSchedulePicker: { [weak self] done in
                    guard let self else {
                        return
                    }
                    self.presentScheduleTimePicker(style: .media, completion: { [weak self] result in
                        guard let self else {
                            return
                        }
                        done(result.time, result.silentPosting)
                        if self.presentationInterfaceState.subject != .scheduledMessages && result.time != scheduleWhenOnlineTimestamp {
                            self.openScheduledMessages()
                        }
                    })
                },
                isAnimation: chatMediaEditorIsAnimation(mode: mode, mediaIsAnimated: true),
                originalMediaReference: { [weak self] in
                    return self?.presentationInterfaceState.sendPaidMessageStars == nil ? file.abstract : nil
                },
                sendMessages: { [weak self] messages, silentPosting, scheduleTime, isCaptionAbove in
                    guard let self else {
                        return
                    }
                    let parameters = ChatSendMessageActionSheetController.SendParameters(
                        effect: nil,
                        textIsAboveMedia: isCaptionAbove
                    )
                    self.enqueuePreparedMediaMessages(
                        messages,
                        count: 1,
                        silentPosting: silentPosting,
                        scheduleTime: scheduleTime == 0 ? nil : scheduleTime,
                        replyToSubject: nil,
                        parameters: parameters
                    )
                },
                present: { [weak self] c, _ in
                    c.navigationPresentation = .flatModal
                    self?.push(c)
                }
            )
            return
        }
        legacyMediaEditor(
            context: self.context,
            peer: EnginePeer(peer),
            threadTitle: nil,
            media: file.abstract,
            mode: mode,
            initialCaption: NSAttributedString(),
            snapshots: [],
            transitionCompletion: {
            },
            getCaptionPanelView: { [weak self] in
                return self?.getCaptionPanelView(isFile: false, hasTimer: false)
            },
            photoToolbarView: { [context = self.context] backButton, doneButton, solidBackground, hasSendStarsButton in
                return makeMediaPickerPhotoToolbarView(context: context, backButton: backButton, doneButton: doneButton, solidBackground: solidBackground, hasSendStarsButton: hasSendStarsButton)
            },
            hasSilentPosting: hasSilentPosting,
            hasSchedule: hasSchedule,
            reminder: peer.id == self.context.account.peerId,
            presentSchedulePicker: { [weak self] _, done in
                guard let self else {
                    return
                }
                self.presentScheduleTimePicker(style: .media, completion: { [weak self] result in
                    guard let self else {
                        return
                    }
                    done(result.time, result.silentPosting)
                    if self.presentationInterfaceState.subject != .scheduledMessages && result.time != scheduleWhenOnlineTimestamp {
                        self.openScheduledMessages()
                    }
                })
            },
            sendMessagesWithSignals: { [weak self] signals, silentPosting, scheduleTime, isCaptionAbove in
                guard let self else {
                    return
                }
                let parameters = ChatSendMessageActionSheetController.SendParameters(
                    effect: nil,
                    textIsAboveMedia: isCaptionAbove
                )
                self.enqueueMediaMessages(
                    fromGallery: false,
                    signals: signals,
                    originalMediaReference: file.abstract,
                    silentPosting: silentPosting,
                    scheduleTime: scheduleTime == 0 ? nil : scheduleTime,
                    replyToSubject: nil,
                    parameters: parameters,
                    getAnimatedTransitionSource: nil,
                    completion: {}
                )
            },
            present: { [weak self] c, a in
                c.navigationPresentation = .flatModal
                self?.push(c)
            }
        )
    }
}
