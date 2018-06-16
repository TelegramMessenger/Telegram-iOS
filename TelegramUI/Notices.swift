import Foundation
import Postbox
import SwiftSignalKit

final class ApplicationSpecificBoolNotice: NoticeEntry {
    init() {
    }
    
    init(decoder: PostboxDecoder) {
    }
    
    func encode(_ encoder: PostboxEncoder) {
    }
    
    func isEqual(to: NoticeEntry) -> Bool {
        if let _ = to as? ApplicationSpecificBoolNotice {
            return true
        } else {
            return false
        }
    }
}

final class ApplicationSpecificVariantNotice: NoticeEntry {
    let value: Bool
    
    init(value: Bool) {
        self.value = value
    }
    
    init(decoder: PostboxDecoder) {
        self.value = decoder.decodeInt32ForKey("v", orElse: 0) != 0
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.value ? 1 : 0, forKey: "v")
    }
    
    func isEqual(to: NoticeEntry) -> Bool {
        if let to = to as? ApplicationSpecificVariantNotice {
            if self.value != to.value {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

private func noticeNamespace(namespace: Int32) -> ValueBoxKey {
    let key = ValueBoxKey(length: 4)
    key.setInt32(0, value: namespace)
    return key
}

private func noticeKey(peerId: PeerId, key: Int32) -> ValueBoxKey {
    let v = ValueBoxKey(length: 8 + 4)
    v.setInt64(0, value: peerId.toInt64())
    v.setInt32(8, value: key)
    return v
}

private enum ApplicationSpecificGlobalNotice: Int32 {
    case secretChatInlineBotUsage = 0
    case secretChatLinkPreviews = 1
    case proxyAdsAcknowledgment = 2
    
    var key: ValueBoxKey {
        let v = ValueBoxKey(length: 4)
        v.setInt32(0, value: self.rawValue)
        return v
    }
}

private struct ApplicationSpecificNoticeKeys {
    private static let botPaymentLiabilityNamespace: Int32 = 1
    private static let globalNamespace: Int32 = 2
    
    static func botPaymentLiabilityNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: botPaymentLiabilityNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func secretChatInlineBotUsage() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.secretChatInlineBotUsage.key)
    }
    
    static func secretChatLinkPreviews() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.secretChatLinkPreviews.key)
    }
    
    static func proxyAdsAcknowledgment() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.proxyAdsAcknowledgment.key)
    }
}

struct ApplicationSpecificNotice {
    static func getBotPaymentLiability(postbox: Postbox, peerId: PeerId) -> Signal<Bool, NoError> {
        return postbox.transaction { transaction -> Bool in
            if let _ = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId)) as? ApplicationSpecificBoolNotice {
                return true
            } else {
                return false
            }
        }
    }
    
    static func setBotPaymentLiability(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId), value: ApplicationSpecificBoolNotice())
        }
    }
    
    static func getSecretChatInlineBotUsage(postbox: Postbox) -> Signal<Bool, NoError> {
        return postbox.transaction { transaction -> Bool in
            if let _ = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.secretChatInlineBotUsage()) as? ApplicationSpecificBoolNotice {
                return true
            } else {
                return false
            }
        }
    }
    
    static func setSecretChatInlineBotUsage(postbox: Postbox) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.secretChatInlineBotUsage(), value: ApplicationSpecificBoolNotice())
        }
    }
    
    static func getSecretChatLinkPreviews(postbox: Postbox) -> Signal<Bool?, NoError> {
        return postbox.transaction { transaction -> Bool? in
            if let value = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.secretChatLinkPreviews()) as? ApplicationSpecificVariantNotice {
                return value.value
            } else {
                return nil
            }
        }
    }
    
    static func getSecretChatLinkPreviews(_ entry: NoticeEntry) -> Bool? {
        if let value = entry as? ApplicationSpecificVariantNotice {
            return value.value
        } else {
            return nil
        }
    }
    
    static func setSecretChatLinkPreviews(postbox: Postbox, value: Bool) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.secretChatLinkPreviews(), value: ApplicationSpecificVariantNotice(value: value))
        }
    }
    
    static func secretChatLinkPreviewsKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.secretChatLinkPreviews()
    }
    
    static func getProxyAdsAcknowledgment(postbox: Postbox) -> Signal<Bool, NoError> {
        return postbox.transaction { transaction -> Bool in
            if let _ = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.proxyAdsAcknowledgment()) as? ApplicationSpecificBoolNotice {
                return true
            } else {
                return false
            }
        }
    }
    
    static func setProxyAdsAcknowledgment(postbox: Postbox) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.proxyAdsAcknowledgment(), value: ApplicationSpecificBoolNotice())
        }
    }
    
    static func reset(postbox: Postbox) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            
        }
    }
}
