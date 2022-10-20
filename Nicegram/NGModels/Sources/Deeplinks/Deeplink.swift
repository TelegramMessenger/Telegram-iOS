public protocol Deeplink {
    
}

public struct AssistantDeeplink: Deeplink {
    public init() {}
}

public struct PurchaseEsimDeeplink: Deeplink {
    public let bundleId: Int?
    
    public init(bundleId: Int?) {
        self.bundleId = bundleId
    }
}

