import Foundation
import Postbox

final class MutableNoticeEntryView<Types: AccountManagerTypes> {
    private let key: NoticeEntryKey
    fileprivate var value: CodableEntry?
    
    init(accountManagerImpl: AccountManagerImpl<Types>, key: NoticeEntryKey) {
        self.key = key
        self.value = accountManagerImpl.noticeTable.get(key: key)
    }
    
    func replay(accountManagerImpl: AccountManagerImpl<Types>, updatedKeys: Set<NoticeEntryKey>) -> Bool {
        if updatedKeys.contains(self.key) {
            self.value = accountManagerImpl.noticeTable.get(key: self.key)
            return true
        }
        return false
    }
    
    func immutableView() -> NoticeEntryView<Types> {
        return NoticeEntryView(self)
    }
}

public final class NoticeEntryView<Types: AccountManagerTypes> {
    public let value: CodableEntry?
    
    init(_ view: MutableNoticeEntryView<Types>) {
        self.value = view.value
    }
}
