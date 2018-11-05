import Foundation

public let defaultPresentationStrings = PresentationStrings(primaryComponent: PresentationStringsComponent(languageCode: "en", pluralizationRulesCode: nil, dict: NSDictionary(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en")!)) as! [String : String]), secondaryComponent: nil)
