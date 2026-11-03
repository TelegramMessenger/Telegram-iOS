import Foundation

final class MutableLocalNoticeEntryView: MutablePostboxView {
    private let key: NoticeEntryKey
    fileprivate var value: CodableEntry?

    init(postbox: PostboxImpl, key: NoticeEntryKey) {
        self.key = key
        self.value = postbox.noticeTable.get(key: key)
    }

    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if transaction.updatedNoticeEntryKeys.contains(self.key) {
            self.value = postbox.noticeTable.get(key: key)
            updated = true
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }

    func immutableView() -> PostboxView {
        return LocalNoticeEntryView(self)
    }
}

public final class LocalNoticeEntryView: PostboxView {
    public let value: CodableEntry?

    init(_ view: MutableLocalNoticeEntryView) {
        self.value = view.value
    }
}
