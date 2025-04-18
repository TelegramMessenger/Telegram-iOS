import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import OverlayStatusController
import AccountContext

private enum CallFeedbackReason: Int32, CaseIterable {
    case videoDistorted
    case videoLowQuality
    
    case echo
    case noise
    case interruption
    case distortedSpeech
    case silentLocal
    case silentRemote
    case dropped
    
    var hashtag: String {
        switch self {
            case .echo:
                return "echo"
            case .noise:
                return "noise"
            case .interruption:
                return "interruptions"
            case .distortedSpeech:
                return "distorted_speech"
            case .silentLocal:
                return "silent_local"
            case .silentRemote:
                return "silent_remote"
            case .dropped:
                return "dropped"
            case .videoDistorted:
                return "distorted_video"
            case .videoLowQuality:
                return "pixelated_video"
        }
    }
    
    var isVideoRelated: Bool {
        switch self {
        case .videoDistorted, .videoLowQuality:
            return true
        default:
            return false
        }
    }
    
    static func localizedString(for reason: CallFeedbackReason, strings: PresentationStrings) -> String {
        switch reason {
            case .echo:
                return strings.CallFeedback_ReasonEcho
            case .noise:
                return strings.CallFeedback_ReasonNoise
            case .interruption:
                return strings.CallFeedback_ReasonInterruption
            case .distortedSpeech:
                return strings.CallFeedback_ReasonDistortedSpeech
            case .silentLocal:
                return strings.CallFeedback_ReasonSilentLocal
            case .silentRemote:
                return strings.CallFeedback_ReasonSilentRemote
            case .dropped:
                return strings.CallFeedback_ReasonDropped
            case .videoDistorted:
                return strings.CallFeedback_VideoReasonDistorted
            case .videoLowQuality:
                return strings.CallFeedback_VideoReasonLowQuality
        }
    }
}

private final class CallFeedbackControllerArguments {
    let updateComment: (String) -> Void
    let scrollToComment: () -> Void
    let toggleReason: (CallFeedbackReason, Bool) -> Void
    let toggleIncludeLogs: (Bool) -> Void
    
    init(updateComment: @escaping (String) -> Void, scrollToComment: @escaping () -> Void, toggleReason: @escaping (CallFeedbackReason, Bool) -> Void, toggleIncludeLogs: @escaping (Bool) -> Void) {
        self.updateComment = updateComment
        self.scrollToComment = scrollToComment
        self.toggleReason = toggleReason
        self.toggleIncludeLogs = toggleIncludeLogs
    }
}

private enum CallFeedbackControllerSection: Int32 {
    case reasons
    case comment
    case logs
}

private enum CallFeedbackControllerEntryTag: ItemListItemTag {
    case comment
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CallFeedbackControllerEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum CallFeedbackControllerEntry: ItemListNodeEntry {
    case reasonsHeader(PresentationTheme, String)
    case reason(PresentationTheme, CallFeedbackReason, String, Bool)
    case comment(PresentationTheme, String, String)
    case includeLogs(PresentationTheme, String, Bool)
    case includeLogsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .reasonsHeader, .reason:
                return CallFeedbackControllerSection.reasons.rawValue
            case .comment:
                return CallFeedbackControllerSection.comment.rawValue
            case .includeLogs, .includeLogsInfo:
                return CallFeedbackControllerSection.logs.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .reasonsHeader:
                return 0
            case let .reason(_, reason, _, _):
                return 1 + reason.rawValue
            case .comment:
                return 100
            case .includeLogs:
                return 101
            case .includeLogsInfo:
                return 102
        }
    }
    
    static func ==(lhs: CallFeedbackControllerEntry, rhs: CallFeedbackControllerEntry) -> Bool {
        switch lhs {
            case let .reasonsHeader(lhsTheme, lhsText):
                if case let .reasonsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .reason(lhsTheme, lhsReason, lhsText, lhsValue):
                if case let .reason(rhsTheme, rhsReason, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsReason == rhsReason, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .comment(lhsTheme, lhsText, lhsValue):
                if case let .comment(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .includeLogs(lhsTheme, lhsText, lhsValue):
                if case let .includeLogs(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .includeLogsInfo(lhsTheme, lhsText):
                if case let .includeLogsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: CallFeedbackControllerEntry, rhs: CallFeedbackControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CallFeedbackControllerArguments
        switch self {
        case let .reasonsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .reason(_, reason, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, maximumNumberOfLines: 2, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleReason(reason, value)
            })
        case let .comment(_, text, placeholder):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                arguments.updateComment(updatedText)
            }, updatedFocus: { focused in
                if focused {
                    arguments.scrollToComment()
                }
            }, tag: CallFeedbackControllerEntryTag.comment)
        case let .includeLogs(_, title, value):
            return ItemListSwitchItem(presentationData: presentationData, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleIncludeLogs(value)
            })
        case let .includeLogsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct CallFeedbackState: Equatable {
    let reasons: Set<CallFeedbackReason>
    let comment: String
    let includeLogs: Bool
    
    init(reasons: Set<CallFeedbackReason> = Set(), comment: String = "", includeLogs: Bool = true) {
        self.reasons = reasons
        self.comment = comment
        self.includeLogs = includeLogs
    }
    
    func withUpdatedReasons(_ reasons: Set<CallFeedbackReason>) -> CallFeedbackState {
        return CallFeedbackState(reasons: reasons, comment: self.comment, includeLogs: self.includeLogs)
    }
    
    func withUpdatedComment(_ comment: String) -> CallFeedbackState {
        return CallFeedbackState(reasons: self.reasons, comment: comment, includeLogs: self.includeLogs)
    }
    
    func withUpdatedIncludeLogs(_ includeLogs: Bool) -> CallFeedbackState {
        return CallFeedbackState(reasons: self.reasons, comment: self.comment, includeLogs: includeLogs)
    }
}

private func callFeedbackControllerEntries(theme: PresentationTheme, strings: PresentationStrings, state: CallFeedbackState, isVideo: Bool) -> [CallFeedbackControllerEntry] {
    var entries: [CallFeedbackControllerEntry] = []
    
    entries.append(.reasonsHeader(theme, strings.CallFeedback_WhatWentWrong))
    if isVideo {
        for reason in CallFeedbackReason.allCases {
            if !reason.isVideoRelated {
                continue
            }
            entries.append(.reason(theme, reason, CallFeedbackReason.localizedString(for: reason, strings: strings), state.reasons.contains(reason)))
        }
    }
    for reason in CallFeedbackReason.allCases {
        if reason.isVideoRelated {
            continue
        }
        entries.append(.reason(theme, reason, CallFeedbackReason.localizedString(for: reason, strings: strings), state.reasons.contains(reason)))
    }
    
    entries.append(.comment(theme, state.comment, strings.CallFeedback_AddComment))
    
    entries.append(.includeLogs(theme, strings.CallFeedback_IncludeLogs, state.includeLogs))
    entries.append(.includeLogsInfo(theme, strings.CallFeedback_IncludeLogsInfo))
    
    return entries
}

public func callFeedbackController(sharedContext: SharedAccountContext, account: Account, callId: CallId, rating: Int, userInitiated: Bool, isVideo: Bool) -> ViewController {
    let initialState = CallFeedbackState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CallFeedbackState) -> CallFeedbackState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }

    var presentControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var ensureItemVisibleImpl: ((CallFeedbackControllerEntryTag, Bool) -> Void)?
    
    let arguments = CallFeedbackControllerArguments(updateComment: { value in
        updateState { $0.withUpdatedComment(value) }
        ensureItemVisibleImpl?(.comment, false)
    }, scrollToComment: {
        ensureItemVisibleImpl?(.comment, true)
    }, toggleReason: { reason, value in
        updateState { current in
            var reasons = current.reasons
            if value {
                reasons.insert(reason)
            } else {
                reasons.remove(reason)
            }
            return current.withUpdatedReasons(reasons)
        }
    }, toggleIncludeLogs: { value in
        updateState { $0.withUpdatedIncludeLogs(value) }
    })
    
    let signal = combineLatest(sharedContext.presentationData, statePromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.CallFeedback_Send), style: .bold, enabled: true, action: {
            var comment = state.comment
            var hashtags = ""
            for reason in CallFeedbackReason.allCases {
                if state.reasons.contains(reason) {
                    if !hashtags.isEmpty {
                        hashtags.append(" ")
                    }
                    hashtags.append("#\(reason.hashtag)")
                }
            }
            if !comment.isEmpty && !state.reasons.isEmpty {
                comment.append("\n")
            }
            comment.append(hashtags)
            
            let _ = rateCallAndSendLogs(engine: TelegramEngine(account: account), callId: callId, starsCount: rating, comment: comment, userInitiated: userInitiated, includeLogs: state.includeLogs).start()
            dismissImpl?()
            
            presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, type: .starSuccess(presentationData.strings.CallFeedback_Success)))
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.CallFeedback_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: callFeedbackControllerEntries(theme: presentationData.theme, strings: presentationData.strings, state: state, isVideo: isVideo), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    
    let controller = ItemListController(sharedContext: sharedContext, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    ensureItemVisibleImpl = { [weak controller] targetTag, animated in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let _ = controller.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListItemNode {
                    if let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                        resultItemNode = itemNode as? ListViewItemNode
                        return true
                    }
                }
                return false
            })
            
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode, animated: animated)
            }
        })
    }
    return controller
}
