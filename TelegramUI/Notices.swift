import Foundation
import Postbox
import SwiftSignalKit

final class ApplicationSpecificBoolNotice: PostboxCoding {
    init() {
    }
    
    init(decoder: PostboxDecoder) {
    }
    
    func encode(_ encoder: PostboxEncoder) {
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

private struct ApplicationSpecificNoticeKeys {
    private static let botPaymentLiabilityNamespace: Int32 = 1
    
    static func botPaymentLiabilityNotice(peerId: PeerId) -> NoticeEntryKey {
        return NoticeEntryKey(namespace: noticeNamespace(namespace: botPaymentLiabilityNamespace), key: noticeKey(peerId: peerId, key: 0))
    }
}

struct ApplicationSpecificNotice {
    static func getBotPaymentLiability(postbox: Postbox, peerId: PeerId) -> Signal<Bool, NoError> {
        return postbox.modify { modifier -> Bool in
            if let _ = modifier.getNoticeEntry(key: ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId)) as? ApplicationSpecificBoolNotice {
                return true
            } else {
                return false
            }
        }
    }
    
    static func setBotPaymentLiability(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
        return postbox.modify { modifier -> Void in
            modifier.setNoticeEntry(key: ApplicationSpecificNoticeKeys.botPaymentLiabilityNotice(peerId: peerId), value: ApplicationSpecificBoolNotice())
        }
    }
}

