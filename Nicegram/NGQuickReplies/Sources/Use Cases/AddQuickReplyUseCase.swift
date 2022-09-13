import Foundation
import AccountContext

protocol AddQuickReplyUseCase {
    func addQuickReply(id: String, text: String) -> QuickReply
    func addQuickReply(text: String) -> QuickReply
}

class AddQuickReplyUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let accountContext: AccountContext
    private let quickRepliesRepository: QuickRepliesRepository
    
    //  MARK: - Lifecycle
    
    init(accountContext: AccountContext, quickRepliesRepository: QuickRepliesRepository) {
        self.accountContext = accountContext
        self.quickRepliesRepository = quickRepliesRepository
    }
}

extension AddQuickReplyUseCaseImpl: AddQuickReplyUseCase {
    func addQuickReply(id: String, text: String) -> QuickReply {
        let quickReply = QuickReply(
            id: id,
            telegramUserId: accountContext.account.peerId.id._internalGetInt64Value(),
            text: text,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        quickRepliesRepository.add(quickReply)
        
        return quickReply
    }
    
    func addQuickReply(text: String) -> QuickReply {
        return addQuickReply(id: UUID().uuidString, text: text)
    }
}
