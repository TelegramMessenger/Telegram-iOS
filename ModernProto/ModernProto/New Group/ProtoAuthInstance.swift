import Foundation
import SwiftSignalKit

private enum ProtoAuthInstanceState {
    case none
}

final class ProtoAuthInstance {
    private let target: ProtoTarget
    
    private var state: ProtoAuthInstanceState
    
    init(target: ProtoTarget) {
        self.target = target
        
        self.state = .none
    }
    
    func update(sessionState: ProtoSessionState) {
        
    }
}
