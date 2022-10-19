import Foundation
import AccountContext

protocol GetUserQuickRepliesUseCase {
    func getQuickReplies() -> [QuickReply]
}

class GetUserQuickRepliesUseCaseImpl {
    
    //  MARK: - Dependencies
    
    private let accountContext: AccountContext
    private let quickRepliesRepository: QuickRepliesRepository
    
    //  MARK: - Lifecycle
    
    init(accountContext: AccountContext, quickRepliesRepository: QuickRepliesRepository) {
        self.accountContext = accountContext
        self.quickRepliesRepository = quickRepliesRepository
    }
}

extension GetUserQuickRepliesUseCaseImpl: GetUserQuickRepliesUseCase {
    func getQuickReplies() -> [QuickReply] {
        let items = quickRepliesRepository.getItems(telegramUserId: accountContext.account.peerId.id._internalGetInt64Value())
        
        var result = [QuickReply]()
        var itemsWithEmptyText = [QuickReply]()
        
        for item in items {
            if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                itemsWithEmptyText.append(item)
            } else {
                result.append(item)
            }
        }
        
        if !itemsWithEmptyText.isEmpty {
            quickRepliesRepository.delete(itemsWithEmptyText.map(\.id))
        }
        
        result = result.sorted(by: { $0.createdAt > $1.createdAt })
        
        return result
    }
}

// MARK: Telegram Helpers

private let quickRepliesrepository: QuickRepliesRepository = QuickRepliesRepositoryImpl()

public func getQuickReplies(query: String, context: AccountContext) -> [String] {
    let getUseCase: GetUserQuickRepliesUseCase = GetUserQuickRepliesUseCaseImpl(
        accountContext: context,
        quickRepliesRepository: quickRepliesrepository
    )
    
    let allReplies = getUseCase.getQuickReplies()
    let normalizedQuery = query.normalized()
    
    let filteredReplies: [QuickReply]
    if normalizedQuery.isEmpty {
        filteredReplies = allReplies
    } else {
        filteredReplies = allReplies.filter { $0.text.normalized().contains(normalizedQuery) }
    }
    
    return filteredReplies.map(\.text)
}

private extension String {
    func normalized() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

