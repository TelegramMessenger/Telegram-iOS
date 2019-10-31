import Postbox

public struct PeerStatusSettings: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let canReport = PeerStatusSettings(rawValue: 1 << 1)
    public static let canShareContact = PeerStatusSettings(rawValue: 1 << 2)
    public static let canBlock = PeerStatusSettings(rawValue: 1 << 3)
    public static let canAddContact = PeerStatusSettings(rawValue: 1 << 4)
    public static let addExceptionWhenAddingContact = PeerStatusSettings(rawValue: 1 << 5)
    public static let canReportIrrelevantGeoLocation = PeerStatusSettings(rawValue: 1 << 6)
}
