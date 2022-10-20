import Foundation

final class MutablePreferencesView: MutablePostboxView {
    fileprivate let keys: Set<ValueBoxKey>
    fileprivate var values: [ValueBoxKey: PreferencesEntry]
    
    init(postbox: PostboxImpl, keys: Set<ValueBoxKey>) {
        self.keys = keys
        var values: [ValueBoxKey: PreferencesEntry] = [:]
        for key in keys {
            if let value = postbox.preferencesTable.get(key: key) {
                values[key] = value
            }
        }
        self.values = values
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for operation in transaction.currentPreferencesOperations {
            switch operation {
                case let .update(key, value):
                    if self.keys.contains(key) {
                        let currentValue = self.values[key]
                        var updatedValue = false
                        if let value = value, let currentValue = currentValue {
                            if value != currentValue {
                                updatedValue = true
                            }
                        } else if (value != nil) != (currentValue != nil) {
                            updatedValue = true
                        }
                        if updatedValue {
                            if let value = value {
                                self.values[key] = value
                            } else {
                                self.values.removeValue(forKey: key)
                            }
                            updated = true
                        }
                    }
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*var values: [ValueBoxKey: PreferencesEntry] = [:]
        for key in self.keys {
            if let value = postbox.preferencesTable.get(key: key) {
                values[key] = value
            }
        }
        if self.values != values {
            self.values = values
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return PreferencesView(self)
    }
}

public final class PreferencesView: PostboxView {
    public let values: [ValueBoxKey: PreferencesEntry]
    
    init(_ view: MutablePreferencesView) {
        self.values = view.values
    }
}
