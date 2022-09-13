protocol DeleteQuickReplyUseCase {
    func deleteQuickReply(id: String)
}

class DeleteQuickReplyUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let quickRepliesRepository: QuickRepliesRepository
    
    //  MARK: - Lifecycle
    
    init(quickRepliesRepository: QuickRepliesRepository) {
        self.quickRepliesRepository = quickRepliesRepository
    }
}

extension DeleteQuickReplyUseCaseImpl: DeleteQuickReplyUseCase {
    func deleteQuickReply(id: String) {
        quickRepliesRepository.delete(id)
    }
}
