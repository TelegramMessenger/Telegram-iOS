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

final class ApplicationSpecificCounterNotice: NoticeEntry {
    let value: Int32
    
    init(value: Int32) {
        self.value = value
    }
    
    init(decoder: PostboxDecoder) {
        self.value = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.value, forKey: "v")
    }
    
    func isEqual(to: NoticeEntry) -> Bool {
        if let to = to as? ApplicationSpecificCounterNotice {
            if self.value != to.value {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

final class ApplicationSpecificTimestampNotice: NoticeEntry {
    let value: Int32
    
    init(value: Int32) {
        self.value = value
    }
    
    init(decoder: PostboxDecoder) {
        self.value = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.value, forKey: "v")
    }
    
    func isEqual(to: NoticeEntry) -> Bool {
        if let to = to as? ApplicationSpecificTimestampNotice {
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
    case chatMediaMediaRecordingTips = 3
    case profileCallTips = 4
    case setPublicChannelLink = 5
    case passcodeLockTips = 6
    case contactsPermissionWarning = 7
    case notificationsPermissionWarning = 8
    var key: ValueBoxKey {
        let v = ValueBoxKey(length: 4)
        v.setInt32(0, value: self.rawValue)
        return v
    }
}

private struct ApplicationSpecificNoticeKeys {
    private static let botPaymentLiabilityNamespace: Int32 = 1
    private static let globalNamespace: Int32 = 2
    private static let permissionsNamespace: Int32 = 3
    
    static func botPaymentLiabilityNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: botPaymentLiabilityNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
    
    static func secretChatInlineBotUsage() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.secretChatInlineBotUsage.key)
    }
    
    static func secretChatLinkPreviews() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.secretChatLinkPreviews.key)
    }
    
    static func chatMediaMediaRecordingTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.chatMediaMediaRecordingTips.key)
    }
    
    static func profileCallTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.profileCallTips.key)
    }
    
    static func proxyAdsAcknowledgment() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.proxyAdsAcknowledgment.key)
    }
    
    static func setPublicChannelLink() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.setPublicChannelLink.key)
    }
    
    static func passcodeLockTips() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: globalNamespace), key: ApplicationSpecificGlobalNotice.passcodeLockTips.key)
    }
    
    static func contactsPermissionWarning() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: permissionsNamespace), key: ApplicationSpecificGlobalNotice.contactsPermissionWarning.key)
    }
    
    static func notificationsPermissionWarning() -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: permissionsNamespace), key: ApplicationSpecificGlobalNotice.notificationsPermissionWarning.key)
    }
}

public struct ApplicationSpecificNotice {
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
    
    public static func setSecretChatInlineBotUsage(transaction: Transaction) {
        transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.secretChatInlineBotUsage(), value: ApplicationSpecificBoolNotice())
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
    
    public static func setSecretChatLinkPreviews(transaction: Transaction, value: Bool) {
        transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.secretChatLinkPreviews(), value: ApplicationSpecificVariantNotice(value: value))
    }
    
    static func secretChatLinkPreviewsKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.secretChatLinkPreviews()
    }
    
    static func getChatMediaMediaRecordingTips(postbox: Postbox) -> Signal<Int32, NoError> {
        return postbox.transaction { transaction -> Int32 in
            if let value = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.chatMediaMediaRecordingTips()) as? ApplicationSpecificCounterNotice {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    static func incrementChatMediaMediaRecordingTips(postbox: Postbox, count: Int32 = 1) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.chatMediaMediaRecordingTips()) as? ApplicationSpecificCounterNotice {
                currentValue = value.value
            }
            currentValue += count
            
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.chatMediaMediaRecordingTips(), value: ApplicationSpecificCounterNotice(value: currentValue))
        }
    }
    
    static func getProfileCallTips(postbox: Postbox) -> Signal<Int32, NoError> {
        return postbox.transaction { transaction -> Int32 in
            if let value = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.profileCallTips()) as? ApplicationSpecificCounterNotice {
                return value.value
            } else {
                return 0
            }
        }
    }
    
    static func incrementProfileCallTips(postbox: Postbox, count: Int32 = 1) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            var currentValue: Int32 = 0
            if let value = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.profileCallTips()) as? ApplicationSpecificCounterNotice {
                currentValue = value.value
            }
            currentValue += count
            
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.profileCallTips(), value: ApplicationSpecificCounterNotice(value: currentValue))
        }
    }
    
    static func getSetPublicChannelLink(postbox: Postbox) -> Signal<Bool, NoError> {
        return postbox.transaction { transaction -> Bool in
            if let value = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.profileCallTips()) as? ApplicationSpecificCounterNotice {
                return value.value < 1
            } else {
                return true
            }
        }
    }
    
    static func markAsSeenSetPublicChannelLink(postbox: Postbox) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.profileCallTips(), value: ApplicationSpecificCounterNotice(value: 1))
        }
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
    
    static func getPasscodeLockTips(postbox: Postbox) -> Signal<Bool, NoError> {
        return postbox.transaction { transaction -> Bool in
            if let _ = transaction.getNoticeEntry(key: ApplicationSpecificNoticeKeys.passcodeLockTips()) as? ApplicationSpecificBoolNotice {
                return true
            } else {
                return false
            }
        }
    }
    
    static func setPasscodeLockTips(postbox: Postbox) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.passcodeLockTips(), value: ApplicationSpecificBoolNotice())
        }
    }
    
    public static func contactsPermissionWarningKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.contactsPermissionWarning()
    }
    
    public static func setContactsPermissionWarning(postbox: Postbox, value: Int32) {
        let _ =  postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.contactsPermissionWarning(), value: ApplicationSpecificTimestampNotice(value: value))
        }.start()
    }
    
    public static func notificationsPermissionWarningKey() -> NoticeEntryKey {
        return ApplicationSpecificNoticeKeys.notificationsPermissionWarning()
    }
    
    public static func getTimestampValue(_ entry: NoticeEntry) -> Int32? {
        if let value = entry as? ApplicationSpecificTimestampNotice {
            return value.value
        } else {
            return nil
        }
    }
    
    public static func setNotificationsPermissionWarning(postbox: Postbox, value: Int32) {
        let _ = postbox.transaction { transaction -> Void in
            transaction.setNoticeEntry(key: ApplicationSpecificNoticeKeys.notificationsPermissionWarning(), value: ApplicationSpecificTimestampNotice(value: value))
        }.start()
    }

    static func reset(postbox: Postbox) -> Signal<Void, NoError> {
        return postbox.transaction { transaction -> Void in
            
        }
    }
}
