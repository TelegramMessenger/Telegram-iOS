import Foundation

/// Only the foreground Share Extension can host a WEB carrier. Headless extensions
/// must not create WebKit processes. The main app can bootstrap before it has a window.
public struct WebProxyProcessPolicy {
    public static let current: WebProxyProcessPolicy = {
        let bundle = Bundle.main
        let extensionInfo = bundle.infoDictionary?["NSExtension"] as? [String: Any]
        return WebProxyProcessPolicy(
            isAppExtension: bundle.bundlePath.hasSuffix(".appex"),
            extensionPointIdentifier: extensionInfo?["NSExtensionPointIdentifier"] as? String
        )
    }()

    public let allowsCarrier: Bool
    private let requiresViewHost: Bool

    init(isAppExtension: Bool, extensionPointIdentifier: String?) {
        self.allowsCarrier = !isAppExtension || extensionPointIdentifier == "com.apple.share-services"
        self.requiresViewHost = isAppExtension
    }

    func shouldRun(hasConfiguration: Bool, hasDemand: Bool, hasViewHost: Bool) -> Bool {
        return self.allowsCarrier && hasConfiguration && hasDemand && (!self.requiresViewHost || hasViewHost)
    }
}
