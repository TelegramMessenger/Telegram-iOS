import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import BuildConfig
import TelegramPresentationData

private var sharedTempContext: SharedAccountContextImpl?

public func makeTempContext(
    sharedContainerPath: String,
    rootPath: String,
    appGroupPath: String,
    accountManager: AccountManager<TelegramAccountManagerTypes>,
    appLockContext: AppLockContext,
    encryptionParameters: ValueBoxEncryptionParameters,
    applicationBindings: TelegramApplicationBindings,
    initialPresentationDataAndSettings: InitialPresentationDataAndSettings,
    networkArguments: NetworkInitializationArguments,
    buildConfig: BuildConfig
) -> Signal<AccountContext, NoError> {
    let sharedContext = sharedTempContext ?? SharedAccountContextImpl(
        mainWindow: nil,
        sharedContainerPath: sharedContainerPath,
        basePath: rootPath,
        encryptionParameters: encryptionParameters,
        accountManager: accountManager,
        appLockContext: appLockContext,
        notificationController: nil,
        applicationBindings: applicationBindings,
        initialPresentationDataAndSettings: initialPresentationDataAndSettings,
        networkArguments: networkArguments,
        hasInAppPurchases: buildConfig.isAppStoreBuild && buildConfig.apiId == 1,
        rootPath: rootPath,
        legacyBasePath: appGroupPath,
        apsNotificationToken: .single(nil),
        voipNotificationToken: .single(nil),
        firebaseSecretStream: .never(),
        setNotificationCall: { _ in
        },
        navigateToChat: { _, _, _, _ in
        }, displayUpgradeProgress: { _ in
        },
        appDelegate: nil
    )
    sharedTempContext = sharedContext
    
    return sharedContext.activeAccountContexts
    |> take(1)
    |> mapToSignal { accounts -> Signal<AccountContext, NoError> in
        guard let context = accounts.primary else {
            return .complete()
        }
        return .single(context)
    }
}
