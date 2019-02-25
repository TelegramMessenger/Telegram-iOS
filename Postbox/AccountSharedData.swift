import Foundation

final class MutableAccountSharedDataView {
    private let keys: Set<ValueBoxKey>
    fileprivate var entries: [ValueBoxKey: PreferencesEntry] = [:]
    
    init(accountManagerImpl: AccountManagerImpl, keys: Set<ValueBoxKey>) {
        self.keys = keys
        for key in keys {
            if let value = accountManagerImpl.sharedDataTable.get(key: key) {
                self.entries[key] = value
            }
        }
    }
    
    func replay(accountManagerImpl: AccountManagerImpl, updatedKeys: Set<ValueBoxKey>) -> Bool {
        var updated = false
        for key in updatedKeys.intersection(self.keys) {
            if let value = accountManagerImpl.sharedDataTable.get(key: key) {
                self.entries[key] = value
            } else {
                self.entries.removeValue(forKey: key)
            }
            updated = true
        }
        return updated
    }
}

public final class AccountSharedDataView {
    public let entries: [ValueBoxKey: PreferencesEntry]
    
    init(_ view: MutableAccountSharedDataView) {
        self.entries = view.entries
    }
}
