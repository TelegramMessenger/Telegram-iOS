import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

private final class UnauthorizedUpdateMessageService: NSObject, NetworkEngineUpdateSink {
    let pipe: ValuePipe<[Api.Update]> = ValuePipe()
    
    override init() {
        super.init()
    }
    
    func networkSessionDidReset() {
    }
    
    func putNext(_ updates: [Api.Update]) {
        self.pipe.putNext(updates)
    }
    
    func networkSessionDidReceive(message: Any) {
        if let updates = (message as? BoxedMessage)?.body as? Api.Updates {
            self.addUpdates(updates)
        }
    }
    
    func addUpdates(_ updates: Api.Updates) {
        switch updates {
        case let .updates(updatesData):
            let updates = updatesData.updates
            self.putNext(updates)
        case let .updatesCombined(updatesCombinedData):
            let updates = updatesCombinedData.updates
            self.putNext(updates)
        case let .updateShort(updateShortData):
            let update = updateShortData.update
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
    private let updateSentCode: (Api.auth.SentCode) -> Void
    private let displayServiceNotification: (String) -> Void
    
    init(
        network: Network,
        updateLoginToken: @escaping () -> Void,
        updateSentCode: @escaping (Api.auth.SentCode) -> Void,
        displayServiceNotification: @escaping (String) -> Void
    ) {
        self.network = network
        self.updateLoginToken = updateLoginToken
        self.updateSentCode = updateSentCode
        self.displayServiceNotification = displayServiceNotification
    }
    
    deinit {
        self.updateServiceDisposable.dispose()
    }
    
    func addUpdates(_ updates: Api.Updates) {
        self.queue.async {
            self.updateService?.addUpdates(updates)
        }
    }
    
    func reset() {
        self.queue.async {
            if self.updateService == nil {
                self.updateService = UnauthorizedUpdateMessageService()
                let updateLoginToken = self.updateLoginToken
                let updateSentCode = self.updateSentCode
                let displayServiceNotification = self.displayServiceNotification
                self.updateServiceDisposable.set(self.updateService!.pipe.signal().start(next: { updates in
                    for update in updates {
                        switch update {
                        case .updateLoginToken:
                            updateLoginToken()
                        case let .updateServiceNotification(updateServiceNotificationData):
                            let (flags, message) = (updateServiceNotificationData.flags, updateServiceNotificationData.message)
                            let popup = (flags & (1 << 0)) != 0
                            if popup {
                                displayServiceNotification(message)
                            }
                        case let .updateSentPhoneCode(updateSentPhoneCodeData):
                            let sentCode = updateSentPhoneCodeData.sentCode
                            updateSentCode(sentCode)
                        default:
                            break
                        }
                    }
                }))
                self.network.addUpdateSink(self.updateService!)
            }
        }
    }
}
