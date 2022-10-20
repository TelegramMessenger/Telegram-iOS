import Foundation

struct QuickReply {
    let id: String
    let telegramUserId: Int64
    let text: String
    let createdAt: Date
    let updatedAt: Date
}

extension QuickReply: Equatable {}

extension QuickReply {
    func with(text: String) -> QuickReply {
        return QuickReply(id: self.id, telegramUserId: self.telegramUserId, text: text, createdAt: self.createdAt, updatedAt: self.updatedAt)
    }
    
    func with(updatedAt: Date) -> QuickReply {
        return QuickReply(id: self.id, telegramUserId: self.telegramUserId, text: self.text, createdAt: self.createdAt, updatedAt: updatedAt)
    }
}
