import Foundation
import libphonenumber

public final class InteractivePhoneFormatter {
    private let formatter = NBAsYouTypeFormatter(regionCode: "US")!
    
    public init() {
    }

    public func updateText(_ text: String) -> (String?, String) {
        self.formatter.clear()
        let string = self.formatter.inputString(text)
        
        var regionPrefix = self.formatter.regionPrefix
        if let string = string, string.hasPrefix("+383") {
            regionPrefix = "+383"
        }
        return (regionPrefix, string ?? "")
    }
}
