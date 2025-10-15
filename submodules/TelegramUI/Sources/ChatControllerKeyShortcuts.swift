import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import ChatInterfaceState
import TelegramCore
import SwiftSignalKit
import TextFormat
import UndoUI
import PresentationDataUtils
import UIKit
import Display
import ChatPresentationInterfaceState
import ChatControllerInteraction

extension ChatControllerImpl {    
    var keyShortcutsInternal: [KeyShortcut] {
        if !self.traceVisibility() || !isTopmostChatController(self) {
            return []
        }
        
        let strings = self.presentationData.strings
        
        var inputShortcuts: [KeyShortcut]
        if self.chatDisplayNode.isInputViewFocused {
            inputShortcuts = [
                KeyShortcut(title: strings.KeyCommand_SendMessage, input: "\r", action: {}),
                KeyShortcut(input: "B", modifiers: [.command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.bold, value: nil), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "I", modifiers: [.command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.italic, value: nil), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "M", modifiers: [.shift, .command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.monospace, value: nil), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "U", modifiers: [.command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.underline, value: nil), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "X", modifiers: [.command, .shift], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.strikethrough, value: nil), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "P", modifiers: [.command, .shift], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputAddFormattingAttribute(current, attribute: ChatTextInputAttributes.spoiler, value: nil), inputMode)
                        }
                    }
                }),
                KeyShortcut(input: "K", modifiers: [.command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.openLinkEditing()
                    }
                }),
                KeyShortcut(input: "N", modifiers: [.shift, .command], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.interfaceInteraction?.updateTextInputStateAndMode { current, inputMode in
                            return (chatTextInputClearFormattingAttributes(current), inputMode)
                        }
                    }
                })
            ]
        } else if UIResponder.currentFirst() == nil {
            inputShortcuts = [
                KeyShortcut(title: strings.KeyCommand_FocusOnInputField, input: "\r", action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            return state.updatedInterfaceState { interfaceState in
                                return interfaceState.withUpdatedEffectiveInputState(interfaceState.effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            })
                    }
                }),
                KeyShortcut(input: "/", modifiers: [], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            if state.interfaceState.effectiveInputState.inputText.length == 0 {
                                return state.updatedInterfaceState { interfaceState in
                                    let effectiveInputState = ChatTextInputState(inputText: NSAttributedString(string: "/"))
                                    return interfaceState.withUpdatedEffectiveInputState(effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            } else {
                                return state
                            }
                        })
                    }
                }),
                KeyShortcut(input: "2", modifiers: [.shift], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            if state.interfaceState.effectiveInputState.inputText.length == 0 {
                                return state.updatedInterfaceState { interfaceState in
                                    let effectiveInputState = ChatTextInputState(inputText: NSAttributedString(string: "@"))
                                    return interfaceState.withUpdatedEffectiveInputState(effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            } else {
                                return state
                            }
                        })
                    }
                }),
                KeyShortcut(input: "3", modifiers: [.shift], action: { [weak self] in
                    if let strongSelf = self {
                        strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                            if state.interfaceState.effectiveInputState.inputText.length == 0 {
                                return state.updatedInterfaceState { interfaceState in
                                    let effectiveInputState = ChatTextInputState(inputText: NSAttributedString(string: "#"))
                                    return interfaceState.withUpdatedEffectiveInputState(effectiveInputState)
                                }.updatedInputMode({ _ in .text })
                            } else {
                                return state
                            }
                        })
                    }
                })
            ]
        } else {
            inputShortcuts = []
        }
        
        inputShortcuts.append(
            KeyShortcut(
                input: "W",
                modifiers: [.command],
                action: { [weak self] in
                    self?.dismiss(animated: true, completion: nil)
                }
            )
        )
        
        if canReplyInChat(self.presentationInterfaceState, accountPeerId: self.context.account.peerId) {
            inputShortcuts.append(
                KeyShortcut(
                    input: UIKeyCommand.inputUpArrow,
                    modifiers: [.alternate, .command],
                    action: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                        
                        if let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject {
                            if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(before: replyMessageSubject.messageId) {
                                strongSelf.updateChatPresentationInterfaceState(interactive: true, { state in
                                    var updatedState = state.updatedInterfaceState({ state in
                                        return state.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(
                                            messageId: message.id,
                                            quote: nil,
                                            todoItemId: nil
                                        ))
                                    })
                                    if updatedState.inputMode == .none {
                                        updatedState = updatedState.updatedInputMode({ _ in .text })
                                    }
                                    return updatedState
                                })
                                
                                strongSelf.navigateToMessage(messageLocation: .id(message.id, NavigateToMessageParams(timestamp: nil, quote: nil)), animated: true)
                            }
                        } else {
                            strongSelf.scrollToEndOfHistory()
                            Queue.mainQueue().after(0.1, {
                                let lastMessage = strongSelf.chatDisplayNode.historyNode.latestMessageInCurrentHistoryView()
                                strongSelf.updateChatPresentationInterfaceState(interactive: true, { state in
                                    var updatedState = state.updatedInterfaceState({ state in
                                        return state.withUpdatedReplyMessageSubject((lastMessage?.id).flatMap { id in
                                            return ChatInterfaceState.ReplyMessageSubject(
                                                messageId: id,
                                                quote: nil,
                                                todoItemId: nil
                                            )
                                        })
                                    })
                                    if updatedState.inputMode == .none {
                                        updatedState = updatedState.updatedInputMode({ _ in .text })
                                    }
                                    return updatedState
                                })
                                
                                if let lastMessage = lastMessage {
                                    strongSelf.navigateToMessage(messageLocation: .id(lastMessage.id, NavigateToMessageParams(timestamp: nil, quote: nil)), animated: true)
                                }
                            })
                        }
                    }
                )
            )
            
            inputShortcuts.append(
                KeyShortcut(
                    input: UIKeyCommand.inputDownArrow,
                    modifiers: [.alternate, .command],
                    action: { [weak self] in
                        guard let strongSelf = self else {
                            return
                        }
                     
                        if let replyMessageSubject = strongSelf.presentationInterfaceState.interfaceState.replyMessageSubject {
                            let lastMessage = strongSelf.chatDisplayNode.historyNode.latestMessageInCurrentHistoryView()
                            var updatedReplyMessageSubject: ChatInterfaceState.ReplyMessageSubject?
                            if replyMessageSubject.messageId == lastMessage?.id {
                                updatedReplyMessageSubject = nil
                            } else if let message = strongSelf.chatDisplayNode.historyNode.messageInCurrentHistoryView(after: replyMessageSubject.messageId) {
                                updatedReplyMessageSubject = ChatInterfaceState.ReplyMessageSubject(messageId: message.id, quote: nil, todoItemId: nil)
                            }
                            
                            strongSelf.updateChatPresentationInterfaceState(interactive: true, { state in
                                var updatedState = state.updatedInterfaceState({ state in
                                    return state.withUpdatedReplyMessageSubject(updatedReplyMessageSubject)
                                })
                                if updatedState.inputMode == .none {
                                    updatedState = updatedState.updatedInputMode({ _ in .text })
                                } else if updatedReplyMessageSubject == nil {
                                    updatedState = updatedState.updatedInputMode({ _ in .none })
                                }
                                return updatedState
                            })
                            
                            if let updatedReplyMessageSubject {
                                strongSelf.navigateToMessage(messageLocation: .id(updatedReplyMessageSubject.messageId, NavigateToMessageParams(timestamp: nil, quote: nil)), animated: true)
                            }
                        }
                    }
                )
            )
        }
        
        var canEdit = false
        if self.presentationInterfaceState.interfaceState.effectiveInputState.inputText.length == 0 && self.presentationInterfaceState.interfaceState.editMessage == nil {
            canEdit = true
        }
                
        if canEdit, let message = self.chatDisplayNode.historyNode.firstMessageForEditInCurrentHistoryView() {
            inputShortcuts.append(KeyShortcut(input: UIKeyCommand.inputUpArrow, action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interfaceInteraction?.setupEditMessage(message.id, { _ in })
                }
            }))
        }
        
        let otherShortcuts: [KeyShortcut] = [
            KeyShortcut(title: strings.KeyCommand_ChatInfo, input: "I", modifiers: [.command, .control], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.interfaceInteraction?.openPeerInfo()
                }
            }),
            KeyShortcut(input: "/", modifiers: [.command], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                        return state.updatedInterfaceState { interfaceState in
                            return interfaceState.withUpdatedEffectiveInputState(interfaceState.effectiveInputState)
                        }.updatedInputMode({ _ in ChatInputMode.media(mode: .other, expanded: nil, focused: false) })
                    })
                }
            }),
            KeyShortcut(title: strings.KeyCommand_SearchInChat, input: "F", modifiers: [.command], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.beginMessageSearch("")
                }
            })
        ]
        
        return inputShortcuts + otherShortcuts
    }
}
