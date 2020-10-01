import Foundation

public func patchPurchasePremium() -> Void {
    if #available(iOS 13, *) {
    } else {
        let data = try? JSONEncoder().encode(true)
        
        // Set value to UserDefaults
        UserDefaults.standard.set(data, forKey: "ng:premium")
    }
}
