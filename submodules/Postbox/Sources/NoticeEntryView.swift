import Foundation

final class MutableNoticeEntryView {
    private let key: NoticeEntryKey
    fileprivate var value: NoticeEntry?
    
    init(accountManagerImpl: AccountManagerImpl, key: NoticeEntryKey) {
        self.key = key
        self.value = accountManagerImpl.noticeTable.get(key: key)
    }
    
    func replay(accountManagerImpl: AccountManagerImpl, updatedKeys: Set<NoticeEntryKey>) -> Bool {
        if updatedKeys.contains(self.key) {
            self.value = accountManagerImpl.noticeTable.get(key: self.key)
            return true
        }
        return false
    }
    
    func immutableView() -> NoticeEntryView {
        return NoticeEntryView(self)
    }
}

public final class NoticeEntryView {
    public let value: NoticeEntry?
    
    init(_ view: MutableNoticeEntryView) {
        self.value = view.value
    }
}
