import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

private final class MessageContext {
    let disposable: Disposable
    
    init(disposable: Disposable) {
        self.disposable = disposable
    }
    
    deinit {
        self.disposable.dispose()
    }
}

final class ChatEditMessageMediaContext {
    private let context: AccountContext
    
    private let contexts: [MessageId: MessageContext] = [:]
    
    init(context: AccountContext) {
        self.context = context
    }
    
    func update(id: MessageId, text: String, entities: TextEntitiesMessageAttribute?, disableUrlPreview: Bool, media: RequestEditMessageMedia) {
        
    }
}
