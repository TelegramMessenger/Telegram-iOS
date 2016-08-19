import Foundation

public final class UnsentMessageIndicesView {
    public let indices: Set<MessageIndex>
    
    init(_ indices: Set<MessageIndex>) {
        self.indices = indices
    }
}
