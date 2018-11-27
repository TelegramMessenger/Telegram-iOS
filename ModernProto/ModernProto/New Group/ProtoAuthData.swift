import Foundation

struct ProtoAuthKey: Equatable {
    let id: Int64
    let value: Data
}

final class ProtoAuthData {
    let key: ProtoAuthKey
    
    init(key: ProtoAuthKey) {
        self.key = key
    }
}
