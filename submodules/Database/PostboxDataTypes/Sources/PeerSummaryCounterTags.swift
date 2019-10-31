import Foundation

public struct PeerSummaryCounterTags: OptionSet, Sequence, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public func makeIterator() -> AnyIterator<PeerSummaryCounterTags> {
        var index = 0
        return AnyIterator { () -> PeerSummaryCounterTags? in
            while index < 31 {
                let currentTags = self.rawValue >> UInt32(index)
                let tag = PeerSummaryCounterTags(rawValue: 1 << UInt32(index))
                index += 1
                if currentTags == 0 {
                    break
                }
                
                if (currentTags & 1) != 0 {
                    return tag
                }
            }
            return nil
        }
    }
}
