import Foundation
import Postbox
import SwiftSignalKit


func managedNotificationSettingsBehaviors(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.combinedView(keys: [.peerNotificationSettingsBehaviorTimestampView])
    |> mapToSignal { views -> Signal<Never, NoError> in
        guard let view = views.views[.peerNotificationSettingsBehaviorTimestampView] as? PeerNotificationSettingsBehaviorTimestampView else {
            return .complete()
        }
        guard let earliestTimestamp = view.earliestTimestamp else {
            return .complete()
        }
        
        let checkSignal = postbox.transaction { transaction -> Void in
            let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
            for (peerId, notificationSettings) in transaction.getPeerIdsAndNotificationSettingsWithBehaviorTimestampLessThanOrEqualTo(timestamp) {
                if let notificationSettings = notificationSettings as? TelegramPeerNotificationSettings {
                    if case let .muted(untilTimestamp) = notificationSettings.muteState, untilTimestamp <= timestamp {
                        transaction.updateCurrentPeerNotificationSettings([peerId: notificationSettings.withUpdatedMuteState(.unmuted)])
                    }
                }
            }
        }
        |> ignoreValues
        
        let timeout = earliestTimestamp - Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
        if timeout <= 0 {
            return checkSignal
        } else {
            return checkSignal |> delay(Double(timeout), queue: .mainQueue())
        }
    }
}
