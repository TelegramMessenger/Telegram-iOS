import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import SyncCore

private final class UnauthorizedUpdateMessageService: NSObject, MTMessageService {
    let pipe: ValuePipe<[Api.Update]> = ValuePipe()
    var mtProto: MTProto?
    
    override init() {
        super.init()
    }
    
    func mtProtoWillAdd(_ mtProto: MTProto!) {
        self.mtProto = mtProto
    }
    
    func mtProtoDidChangeSession(_ mtProto: MTProto!) {
    }
    
    func mtProtoServerDidChangeSession(_ mtProto: MTProto!, firstValidMessageId: Int64, otherValidMessageIds: [Any]!) {
    }
    
    func putNext(_ updates: [Api.Update]) {
        self.pipe.putNext(updates)
    }
    
    func mtProto(_ mtProto: MTProto!, receivedMessage message: MTIncomingMessage!) {
        if let updates = (message.body as? BoxedMessage)?.body as? Api.Updates {
            self.addUpdates(updates)
        }
    }
    
    func addUpdates(_ updates: Api.Updates) {
        switch updates {
        case let .updates(updates, _, _, _, _):
            self.putNext(updates)
        case let .updatesCombined(updates, _, _, _, _, _):
            self.putNext(updates)
        case let .updateShort(update, _):
            self.putNext([update])
        case .updateShortChatMessage, .updateShortMessage, .updatesTooLong, .updateShortSentMessage:
                break
        }
    }
}


final class UnauthorizedAccountStateManager {
    private let queue = Queue()
    private let network: Network
    private var updateService: UnauthorizedUpdateMessageService?
    private let updateServiceDisposable = MetaDisposable()
    private let updateLoginToken: () -> Void
    
    init(network: Network, updateLoginToken: @escaping () -> Void) {
        self.network = network
        self.updateLoginToken = updateLoginToken
    }
    
    deinit {
        self.updateServiceDisposable.dispose()
    }
    
    func reset() {
        self.queue.async {
            if self.updateService == nil {
                self.updateService = UnauthorizedUpdateMessageService()
                let updateLoginToken = self.updateLoginToken
                self.updateServiceDisposable.set(self.updateService!.pipe.signal().start(next: { updates in
                    for update in updates {
                        switch update {
                        case .updateLoginToken:
                            updateLoginToken()
                        default:
                            break
                        }
                    }
                }))
                self.network.mtProto.add(self.updateService)
            }
        }
    }
}
