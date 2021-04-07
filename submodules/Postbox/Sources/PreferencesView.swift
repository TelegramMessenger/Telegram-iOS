import Foundation

final class MutablePreferencesView: MutablePostboxView {
    fileprivate let keys: Set<ValueBoxKey>
    fileprivate var values: [ValueBoxKey: PreferencesEntry]
    
    init(postbox: Postbox, keys: Set<ValueBoxKey>) {
        self.keys = keys
        var values: [ValueBoxKey: PreferencesEntry] = [:]
        for key in keys {
            if let value = postbox.preferencesTable.get(key: key) {
                values[key] = value
            }
        }
        self.values = values
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for operation in transaction.currentPreferencesOperations {
            switch operation {
                case let .update(key, value):
                    if self.keys.contains(key) {
                        let currentValue = self.values[key]
                        var updatedValue = false
                        if let value = value, let currentValue = currentValue {
                            if !value.isEqual(to: currentValue) {
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
