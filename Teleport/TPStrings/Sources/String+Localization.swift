import Foundation

extension String {
    
    public func tp_loc(lang: String) -> String {
        let table = "TPLocalizable"
        let bundle = localizationBundle(languageCode: lang)
        
        let fallbackString = {
            let enBundle = localizationBundle(languageCode: "en")
            return enBundle?.localizedString(
                forKey: self,
                value: nil,
                table: table
            ) ?? self
        }
        
        return bundle?.localizedString(
            forKey: self,
            value: nil,
            table: table
        ) ?? fallbackString()
    }
    
    public func tp_loc(lang: String, with args: CVarArg...) -> String {
        String(format: tp_loc(lang: lang), args)
    }
    
    // MARK: - Private methods
    
    private func localizationBundle(
        languageCode: String
    ) -> Bundle? {
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj") {
            Bundle(path: path)
        } else {
            nil
        }
    }
}
