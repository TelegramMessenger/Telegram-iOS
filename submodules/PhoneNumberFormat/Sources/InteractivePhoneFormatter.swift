import Foundation
import libphonenumber

public final class InteractivePhoneFormatter {
    private let formatter = NBAsYouTypeFormatter(regionCode: "US")!
    
    public init() {
    }

    public func updateText(_ text: String) -> (String?, String) {
        self.formatter.clear()
        let string = self.formatter.inputString(text)
        return (self.formatter.regionPrefix, string ?? "")
    }
}
