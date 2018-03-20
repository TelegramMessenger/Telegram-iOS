import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func setSecretChatMessageAutoremoveTimeoutInteractively(account: Account, peerId: PeerId, timeout: Int32?) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if let peer = modifier.getPeer(peerId) as? TelegramSecretChat, let state = modifier.getPeerChatState(peerId) as? SecretChatState {
            if state.messageAutoremoveTimeout != timeout {
                let updatedPeer = peer.withUpdatedMessageAutoremoveTimeout(timeout)
                let updatedState = state.withUpdatedMessageAutoremoveTimeout(timeout)
                if !updatedPeer.isEqual(peer) {
                    updatePeers(modifier: modifier, peers: [updatedPeer], update: { $1 })
                }
                if updatedState != state {
                    modifier.setPeerChatState(peerId, state: updatedState)
                }
                
                let _ = enqueueMessages(modifier: modifier, account: account, peerId: peerId, messages: [(true, .message(text: "", attributes: [], media: TelegramMediaAction(action: TelegramMediaActionType.messageAutoremoveTimeoutUpdated(timeout == nil ? 0 : timeout!)), replyToMessageId: nil, localGroupingKey: nil))])
            }
        }
    }
}

public func addSecretChatMessageScreenshot(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        if let peer = modifier.getPeer(peerId) as? TelegramSecretChat, let state = modifier.getPeerChatState(peerId) as? SecretChatState {
            let _ = enqueueMessages(modifier: modifier, account: account, peerId: peerId, messages: [(true, .message(text: "", attributes: [], media: TelegramMediaAction(action: TelegramMediaActionType.historyScreenshot), replyToMessageId: nil, localGroupingKey: nil))])
        }
    }
}
