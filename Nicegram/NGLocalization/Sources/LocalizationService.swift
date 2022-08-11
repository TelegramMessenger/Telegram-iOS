public protocol LocalizationService {
    func localized(_: String) -> String
    func localized(_: String, with: CVarArg...) -> String
    func localized(_: String, withArguments: [CVarArg]) -> String
}
