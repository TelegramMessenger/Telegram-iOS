import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

final class SecretChatEncryptionConfig: Coding {
    let g: Int32
    let p: MemoryBuffer
    let version: Int32
    
    init(g: Int32, p: MemoryBuffer, version: Int32) {
        self.g = g
        self.p = p
        self.version = version
    }
    
    init(decoder: Decoder) {
        self.g = decoder.decodeInt32ForKey("g", orElse: 0)
        self.p = decoder.decodeBytesForKey("p")!
        self.version = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.g, forKey: "g")
        encoder.encodeBytes(self.p, forKey: "p")
        encoder.encodeInt32(self.version, forKey: "v")
    }
}

func validatedEncryptionConfig(postbox: Postbox, network: Network) -> Signal<SecretChatEncryptionConfig, NoError> {
    return network.request(Api.functions.messages.getDhConfig(version: 0, randomLength: 0))
        |> retryRequest
        |> map { result -> SecretChatEncryptionConfig in
            switch result {
                case let .dhConfig(g, p, version, _):
                    return SecretChatEncryptionConfig(g: g, p: MemoryBuffer(p), version: version)
                case .dhConfigNotModified(_):
                    preconditionFailure()
            }
        }
}
