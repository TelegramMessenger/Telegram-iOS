import Foundation
import SwiftSignalKit

private enum ProtoInstanceState {
    case none
}

private final class ProtoInstanceImpl {
    private let target: ProtoTarget
    
    private var state: ProtoInstanceState
    
    init(target: ProtoTarget) {
        self.target = target
        
        self.state = .none
    }
    
    func update(sessionState: ProtoSessionState) {
        
    }
}
