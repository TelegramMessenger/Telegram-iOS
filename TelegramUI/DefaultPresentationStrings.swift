import Foundation

public let defaultPresentationStrings = PresentationStrings(languageCode: "en", dict: NSDictionary(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en")!)) as! [String : String])
