import Foundation

final class MutableNoticeEntryView: MutablePostboxView {
    private let key: NoticeEntryKey
    fileprivate var value: NoticeEntry?
    
    init(postbox: Postbox, key: NoticeEntryKey) {
        self.key = key
        self.value = postbox.noticeTable.get(key: key)
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        if transaction.updatedNoticeEntryKeys.contains(self.key) {
            self.value = postbox.noticeTable.get(key: key)
            return true
        }
        return false
    }
    
    func immutableView() -> PostboxView {
        return NoticeEntryView(self)
    }
}

public final class NoticeEntryView: PostboxView {
    public let value: NoticeEntry?
    
    init(_ view: MutableNoticeEntryView) {
        self.value = view.value
    }
}
