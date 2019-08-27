import Foundation

#if os(macOS)
import libphonenumbermac
#else
import libphonenumber
#endif

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
