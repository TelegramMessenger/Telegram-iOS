import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import PasswordSetupUI

public protocol SettingsController: AnyObject {
    func updateContext(context: AccountContext)
}

public func makePrivacyAndSecurityController(context: AccountContext) -> ViewController {
    return privacyAndSecurityController(context: context, focusOnItemTag: PrivacyAndSecurityEntryTag.autoArchive)
}

public func makeBioPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, present: @escaping (ViewController) -> Void) {
    let signal = settings.get()
    |> take(1)
    |> deliverOnMainQueue
    
    let _ = signal.startStandalone(next: { info in
        if let info = info {
            present(selectivePrivacySettingsController(context: context, kind: .bio, current: info.bio, updated: { updated, _, _, _ in
                let applySetting: Signal<Void, NoError> = settings.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { value -> Signal<Void, NoError> in
                    if let value = value {
                        settings.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: updated, birthday: value.birthday, giftsAutoSave: value.giftsAutoSave, globalSettings: value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                    }
                    return .complete()
                }
                let _ = applySetting.startStandalone()
            }))
        }
    })
}

public func makeBirthdayPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, openedFromBirthdayScreen: Bool, present: @escaping (ViewController) -> Void) {
    let signal = settings.get()
    |> take(1)
    |> deliverOnMainQueue
    
    let _ = signal.startStandalone(next: { info in
        if let info = info {
            present(selectivePrivacySettingsController(context: context, kind: .birthday, current: info.birthday, openedFromBirthdayScreen: openedFromBirthdayScreen, updated: { updated, _, _, _ in
                let applySetting: Signal<Void, NoError> = settings.get()
                |> filter { $0 != nil }
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { value -> Signal<Void, NoError> in
                    if let value = value {
                        settings.set(.single(AccountPrivacySettings(presence: value.presence, groupInvitations: value.groupInvitations, voiceCalls: value.voiceCalls, voiceCallsP2P: value.voiceCallsP2P, profilePhoto: value.profilePhoto, forwards: value.forwards, phoneNumber: value.phoneNumber, phoneDiscoveryEnabled: value.phoneDiscoveryEnabled, voiceMessages: value.voiceMessages, bio: value.bio, birthday: updated, giftsAutoSave: value.giftsAutoSave, globalSettings: value.globalSettings, accountRemovalTimeout: value.accountRemovalTimeout, messageAutoremoveTimeout: value.messageAutoremoveTimeout)))
                    }
                    return .complete()
                }
                let _ = applySetting.startStandalone()
            }))
        }
    })
}

public func makeSetupTwoFactorAuthController(context: AccountContext) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = TwoFactorAuthSplashScreen(sharedContext: context.sharedContext, engine: .authorized(context.engine), mode: .intro(.init(
        title: presentationData.strings.TwoFactorSetup_Intro_Title,
        text: presentationData.strings.TwoFactorSetup_Intro_Text,
        actionText: presentationData.strings.TwoFactorSetup_Intro_Action,
        doneText: presentationData.strings.TwoFactorSetup_Done_Action,
        phoneNumber: nil
    )))
    return controller
}
