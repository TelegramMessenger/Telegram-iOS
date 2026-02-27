import Foundation
import UIKit
import TelegramCore
import EncryptionKeyVisualizationImpl

public func secretChatKeyImage(_ fingerprint: SecretChatKeyFingerprint, size: CGSize) -> UIImage? {
    let keySignatureData = fingerprint.sha1.data()
    let additionalSignature = fingerprint.sha256.data()
    return SecretChatKeyVisualization(keySignatureData, additionalSignature, size)
}
