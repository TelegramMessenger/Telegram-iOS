import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import PeerInfoPaneNode

extension PeerInfoScreenNode {
    /// The message tag listed by a shared-media pane, or nil for panes that do not list messages.
    private func selectAllMessageTag(paneKey: PeerInfoPaneKey) -> EngineMessage.Tags? {
        switch paneKey {
        case .media:
            return .photoOrVideo
        case .files:
            return .file
        case .music:
            return .music
        case .voice:
            return .voiceOrInstantVideo
        case .links:
            return .webPage
        case .gifs:
            return .gif
        default:
            return nil
        }
    }

    /// Selects every message of the current shared-media tab, not only the loaded cells: the ids are
    /// paged from the server search (100 per request, the server maximum) until it reports completion.
    func selectAllMessagesInCurrentPane() {
        guard self.state.selectedMessageIds != nil, let paneKey = self.paneContainerNode.currentPaneKey, let tag = self.selectAllMessageTag(paneKey: paneKey) else {
            return
        }
        let chatLocation = self.sharedMediaChatLocation
        let location: SearchMessagesLocation = .peer(peerId: chatLocation.peerId, fromId: nil, tags: tag, reactions: nil, threadId: chatLocation.chatLocation.threadId, minDate: nil, maxDate: nil)
        let engine = self.context.engine

        // A paged result may repeat the pages before it, so messages are keyed by id. Search results are not
        // stored, so each page is made locally available: Download and Share resolve the selection from storage.
        // Two pages in a row that add nothing end the loop (a failed or rate-limited request returns the state
        // unchanged), so it cannot spin.
        func loadAll(state: SearchMessagesState?, collected: [EngineMessage.Id: EngineMessage], idleRounds: Int) -> Signal<[EngineMessage.Id: EngineMessage], NoError> {
            return engine.messages.searchMessages(location: location, query: "", state: state, limit: 100)
            |> take(1)
            |> mapToSignal { result, updatedState -> Signal<[EngineMessage.Id: EngineMessage], NoError> in
                var merged = collected
                var newMessages: [EngineMessage] = []
                for rawMessage in result.messages {
                    let message = EngineMessage(rawMessage)
                    if merged[message.id] == nil {
                        merged[message.id] = message
                        newMessages.append(message)
                    }
                }
                if !newMessages.isEmpty {
                    engine.messages.ensureMessagesAreLocallyAvailable(messages: newMessages)
                }
                let updatedIdleRounds = newMessages.isEmpty ? idleRounds + 1 : 0
                if result.completed || updatedIdleRounds >= 2 {
                    return .single(merged)
                }
                return loadAll(state: updatedState, collected: merged, idleRounds: updatedIdleRounds)
            }
        }

        self.selectAllDisposable.set((loadAll(state: nil, collected: [:], idleRounds: 0)
        |> deliverOnMainQueue).startStrict(next: { [weak self] messages in
            guard let self, self.state.selectedMessageIds != nil, !messages.isEmpty else {
                return
            }
            self.chatInterfaceInteraction.toggleMessagesSelection(Array(messages.keys), true)
        }))
    }
}
