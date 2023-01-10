import Foundation
import UIKit
import AsyncDisplayKit
import Display
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

public func makeSetupTwoFactorAuthController(context: AccountContext) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = TwoFactorAuthSplashScreen(sharedContext: context.sharedContext, engine: .authorized(context.engine), mode: .intro(.init(
        title: presentationData.strings.TwoFactorSetup_Intro_Title,
        text: presentationData.strings.TwoFactorSetup_Intro_Text,
        actionText: presentationData.strings.TwoFactorSetup_Intro_Action,
        doneText: presentationData.strings.TwoFactorSetup_Done_Action
    )))
    return controller
}
