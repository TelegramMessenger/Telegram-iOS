import Foundation
import AppBundle

public let defaultPresentationStrings = PresentationStrings(primaryComponent: PresentationStringsComponent(languageCode: "en", localizedName: "English", pluralizationRulesCode: nil, dict: NSDictionary(contentsOf: URL(fileURLWithPath: getAppBundle().path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en")!)) as! [String : String]), secondaryComponent: nil, groupingSeparator: "")
