import Foundation

protocol UpdateQuickReplyUseCase {
    func updateQuickReply(id: String, text: String) -> QuickReply
}

class UpdateQuickReplyUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let quickRepliesRepository: QuickRepliesRepository
    private let addUseCase: AddQuickReplyUseCase
    
    //  MARK: - Lifecycle
    
    init(quickRepliesRepository: QuickRepliesRepository, addUseCase: AddQuickReplyUseCase) {
        self.quickRepliesRepository = quickRepliesRepository
        self.addUseCase = addUseCase
    }
}

extension UpdateQuickReplyUseCaseImpl: UpdateQuickReplyUseCase {
    func updateQuickReply(id: String, text: String) -> QuickReply {
        guard let quickReply = quickRepliesRepository.getItemWith(id: id) else {
            return addUseCase.addQuickReply(id: id, text: text)
        }
        let updatedReply = quickReply
            .with(text: text)
            .with(updatedAt: Date())
        quickRepliesRepository.update(updatedReply)
        return updatedReply
    }
}
