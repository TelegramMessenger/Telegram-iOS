import Foundation
import Postbox

final class MutableAccountSharedDataView<Types: AccountManagerTypes> {
    private let keys: Set<ValueBoxKey>
    fileprivate var entries: [ValueBoxKey: PreferencesEntry] = [:]
    
    init(accountManagerImpl: AccountManagerImpl<Types>, keys: Set<ValueBoxKey>) {
        self.keys = keys
        for key in keys {
            if let value = accountManagerImpl.sharedDataTable.get(key: key) {
                self.entries[key] = value
            }
        }
    }
    
    func replay(accountManagerImpl: AccountManagerImpl<Types>, updatedKeys: Set<ValueBoxKey>) -> Bool {
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

public final class AccountSharedDataView<Types: AccountManagerTypes> {
    public let entries: [ValueBoxKey: PreferencesEntry]
    
    init(_ view: MutableAccountSharedDataView<Types>) {
        self.entries = view.entries
    }
}
