import Foundation

public enum LottieBackend: Equatable {
    case rlottie
    case tlottie
}

public struct LottieRenderingSettings: Equatable {
    public var backend: LottieBackend

    public init(backend: LottieBackend) {
        self.backend = backend
    }

    /// For callers with no account to resolve against — currently only the
    /// pre-login AuthorizationUI screens, whose UnauthorizedAccount has no app
    /// configuration to read.
    ///
    /// This is NOT the product default. Where an app configuration exists the
    /// resolved backend is .tlottie unless the server killswitch says otherwise.
    public static let noAccountFallback = LottieRenderingSettings(backend: .rlottie)
}
