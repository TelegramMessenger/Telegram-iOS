import Foundation

final class MutablePreferencesView {
    fileprivate let keys: Set<ValueBoxKey>
    fileprivate var values: [ValueBoxKey: PreferencesEntry]
    
    init(keys: Set<ValueBoxKey>, get: (ValueBoxKey) -> PreferencesEntry?) {
        self.keys = keys
        var values: [ValueBoxKey: PreferencesEntry] = [:]
        for key in keys {
            if let value = get(key) {
                values[key] = value
            }
        }
        self.values = values
    }
    
    func replay(operations: [PreferencesOperation], get: (ValueBoxKey) -> PreferencesEntry?) -> Bool {
        var updated = false
        for operation in operations {
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
}

public final class PreferencesView {
    public let values: [ValueBoxKey: PreferencesEntry]
    
    init(_ view: MutablePreferencesView) {
        self.values = view.values
    }
}
