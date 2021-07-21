#if ENABLE_WALLET

import Foundation
import UIKit
import Display
import WalletUI
import Postbox
import TelegramCore
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import ShareController
import DeviceAccess
import PresentationDataUtils
import WalletCore

extension WalletConfiguration {
    static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        if let data = appConfiguration.data, let config = data["wallet_config"] as? String, let blockchainName = data["wallet_blockchain_name"] as? String {
            var disableProxy = false
            if let value = data["wallet_disable_proxy"] as? String {
                disableProxy = value != "0"
            } else if let value = data["wallet_disable_proxy"] as? Int {
                disableProxy = value != 0
            }
            return WalletConfiguration(config: config, blockchainName: blockchainName, disableProxy: disableProxy)
        } else {
            return .defaultValue
        }
    }
}

final class WalletStorageInterfaceImpl: WalletStorageInterface {
    private let postbox: Postbox
    
    init(postbox: Postbox) {
        self.postbox = postbox
    }
    
    func watchWalletRecords() -> Signal<[WalletStateRecord], NoError> {
        return self.postbox.preferencesView(keys: [PreferencesKeys.walletCollection])
        |> map { view -> [WalletStateRecord] in
            guard let walletCollection = view.values[PreferencesKeys.walletCollection] as? WalletCollection else {
                return []
            }
            return walletCollection.wallets.flatMap { item -> WalletStateRecord? in
                do {
                    return WalletStateRecord(info: try JSONDecoder().decode(WalletInfo.self, from: item.info), exportCompleted: item.exportCompleted, state: item.state.flatMap { try? JSONDecoder().decode(CombinedWalletState.self, from: $0) })
                } catch {
                    return nil
                }
            }
        }
    }
    
    func getWalletRecords() -> Signal<[WalletStateRecord], NoError> {
        return self.postbox.transaction { transaction -> [WalletStateRecord] in
            guard let walletCollection = transaction.getPreferencesEntry(key: PreferencesKeys.walletCollection) as? WalletCollection else {
                return []
            }
            return walletCollection.wallets.flatMap { item -> WalletStateRecord? in
                do {
                    return WalletStateRecord(info: try JSONDecoder().decode(WalletInfo.self, from: item.info), exportCompleted: item.exportCompleted, state: item.state.flatMap { try? JSONDecoder().decode(CombinedWalletState.self, from: $0) })
                } catch {
                    return nil
                }
            }
        }
    }
    
    func updateWalletRecords(_ f: @escaping ([WalletStateRecord]) -> [WalletStateRecord]) -> Signal<[WalletStateRecord], NoError> {
        return self.postbox.transaction { transaction -> [WalletStateRecord] in
            var updatedRecords: [WalletStateRecord] = []
            transaction.updatePreferencesEntry(key: PreferencesKeys.walletCollection, { current in
                var walletCollection = (current as? WalletCollection) ?? WalletCollection(wallets: [])
                let updatedItems = f(walletCollection.wallets.flatMap { item -> WalletStateRecord? in
                    do {
                        return WalletStateRecord(info: try JSONDecoder().decode(WalletInfo.self, from: item.info), exportCompleted: item.exportCompleted, state: item.state.flatMap { try? JSONDecoder().decode(CombinedWalletState.self, from: $0) })
                    } catch {
                        return nil
                    }
                })
                walletCollection.wallets = updatedItems.flatMap { item in
                    do {
                        return WalletCollectionItem(info: try JSONEncoder().encode(item.info), exportCompleted: item.exportCompleted, state: item.state.flatMap {
                            try? JSONEncoder().encode($0)
                        })
                    } catch {
                        return nil
                    }
                }
                return walletCollection
            })
            return updatedRecords
        }
    }
    
    func localWalletConfiguration() -> Signal<LocalWalletConfiguration, NoError> {
        return .single(LocalWalletConfiguration(source: .string(""), blockchainName: ""))
    }
    
    func updateLocalWalletConfiguration(_ f: @escaping (LocalWalletConfiguration) -> LocalWalletConfiguration) -> Signal<Never, NoError> {
        return .complete()
    }
}

final class WalletContextImpl: WalletContext {
    private let context: AccountContext
    
    let storage: WalletStorageInterface
    let tonInstance: TonInstance
    let keychain: TonKeychain
    let strings: PresentationStrings
    let presentationData: WalletPresentationData
    
    let supportsCustomConfigurations: Bool = false
    var termsUrl: String? {
        return self.strings.TelegramWallet_Intro_TermsUrl
    }
    var feeInfoUrl: String? {
        return self.strings.AppWallet_TransactionInfo_FeeInfoURL
    }
    
    var inForeground: Signal<Bool, NoError> {
        return self.context.sharedContext.applicationBindings.applicationInForeground
    }
    
    func downloadFile(url: URL) -> Signal<Data, WalletDownloadFileError> {
        return .fail(.generic)
    }
    
    func updateResolvedWalletConfiguration(source: LocalWalletConfigurationSource, blockchainName: String, resolvedValue: String) -> Signal<Never, NoError> {
        return .complete()
    }
    
    init(context: AccountContext, tonContext: TonContext) {
        self.context = context
        
        self.storage = WalletStorageInterfaceImpl(postbox: self.context.account.postbox)

        self.tonInstance = tonContext.instance
        self.keychain = tonContext.keychain
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.strings = presentationData.strings
        let theme = presentationData.theme
        let strings = presentationData.strings
        let timeFormat: WalletTimeFormat
        switch presentationData.dateTimeFormat.timeFormat {
        case .military:
            timeFormat = .military
        case .regular:
            timeFormat = .regular
        }
        let dateFormat: WalletDateFormat
        switch presentationData.dateTimeFormat.dateFormat {
        case .dayFirst:
            dateFormat = .dayFirst
        case .monthFirst:
            dateFormat = .monthFirst
        }
        
        let navigationBarData = NavigationBarPresentationData(presentationData: presentationData)
        
        self.presentationData = WalletPresentationData(
            theme: WalletTheme(
                info: WalletInfoTheme(
                    buttonBackgroundColor: UIColor(rgb: 0x32aafe),
                    buttonTextColor: .white,
                    incomingFundsTitleColor: theme.chatList.secretTitleColor,
                    outgoingFundsTitleColor: theme.list.itemDestructiveColor
                ), transaction: WalletTransactionTheme(
                    descriptionBackgroundColor: theme.chat.message.incoming.bubble.withoutWallpaper.fill,
                    descriptionTextColor: theme.chat.message.incoming.primaryTextColor
                ), setup: WalletSetupTheme(
                    buttonFillColor: theme.list.itemCheckColors.fillColor,
                    buttonForegroundColor: theme.list.itemCheckColors.foregroundColor,
                    inputBackgroundColor: theme.actionSheet.inputBackgroundColor,
                    inputPlaceholderColor: theme.actionSheet.inputPlaceholderColor,
                    inputTextColor: theme.actionSheet.inputTextColor,
                    inputClearButtonColor: theme.actionSheet.inputClearButtonColor.withAlphaComponent(0.8)
                ),
                list: WalletListTheme(
                    itemPrimaryTextColor: theme.list.itemPrimaryTextColor,
                    itemSecondaryTextColor: theme.list.itemSecondaryTextColor,
                    itemPlaceholderTextColor: theme.list.itemPlaceholderTextColor,
                    itemDestructiveColor: theme.list.itemDestructiveColor,
                    itemAccentColor: theme.list.itemAccentColor,
                    itemDisabledTextColor: theme.list.itemDisabledTextColor,
                    plainBackgroundColor: theme.list.plainBackgroundColor,
                    blocksBackgroundColor: theme.list.blocksBackgroundColor,
                    itemPlainSeparatorColor: theme.list.itemPlainSeparatorColor,
                    itemBlocksBackgroundColor: theme.list.itemBlocksBackgroundColor,
                    itemBlocksSeparatorColor: theme.list.itemBlocksSeparatorColor,
                    itemHighlightedBackgroundColor: theme.list.itemHighlightedBackgroundColor,
                    sectionHeaderTextColor: theme.list.sectionHeaderTextColor,
                    freeTextColor: theme.list.freeTextColor,
                    freeTextErrorColor: theme.list.freeTextErrorColor,
                    inputClearButtonColor: theme.list.inputClearButtonColor
                ),
                statusBarStyle: theme.rootController.statusBarStyle.style,
                navigationBar: navigationBarData.theme,
                keyboardAppearance: theme.rootController.keyboardColor.keyboardAppearance,
                alert: AlertControllerTheme(presentationData: presentationData),
                actionSheet: ActionSheetControllerTheme(presentationData: presentationData)
            ), strings: WalletStrings(
                primaryComponent: WalletStringsComponent(
                    languageCode: strings.primaryComponent.languageCode,
                    localizedName: strings.primaryComponent.localizedName,
                    pluralizationRulesCode: strings.primaryComponent.pluralizationRulesCode,
                    dict: strings.primaryComponent.dict
                ),
                secondaryComponent: strings.secondaryComponent.flatMap { component in
                    return WalletStringsComponent(
                        languageCode: component.languageCode,
                        localizedName: component.localizedName,
                        pluralizationRulesCode: component.pluralizationRulesCode,
                        dict: component.dict
                    )
                },
                groupingSeparator: strings.groupingSeparator
            ), dateTimeFormat: WalletPresentationDateTimeFormat(
                timeFormat: timeFormat,
                dateFormat: dateFormat,
                dateSeparator: presentationData.dateTimeFormat.dateSeparator,
                decimalSeparator: presentationData.dateTimeFormat.decimalSeparator,
                groupingSeparator: presentationData.dateTimeFormat.groupingSeparator
            )
        )
    }
    
    func getServerSalt() -> Signal<Data, WalletContextGetServerSaltError> {
        return getServerWalletSalt(network: self.context.account.network)
        |> mapError { _ -> WalletContextGetServerSaltError in
            return .generic
        }
    }
    
    func presentNativeController(_ controller: UIViewController) {
        self.context.sharedContext.mainWindow?.presentNative(controller)
    }
    
    func idleTimerExtension() -> Disposable {
        return self.context.sharedContext.applicationBindings.pushIdleTimerExtension()
    }
    
    func openUrl(_ url: String) {
        return self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
    }
    
    func shareUrl(_ url: String) {
        let controller = ShareController(context: self.context, subject: .url(url))
        self.context.sharedContext.mainWindow?.present(controller, on: .root)
    }
    
    func openPlatformSettings() {
        self.context.sharedContext.applicationBindings.openSettings()
    }
    
    func authorizeAccessToCamera(completion: @escaping () -> Void) {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        DeviceAccess.authorizeAccess(to: .camera(.video), presentationData: presentationData, present: { c, a in
            c.presentationArguments = a
            self.context.sharedContext.mainWindow?.present(c, on: .root)
        }, openSettings: { [weak self] in
            self?.openPlatformSettings()
        }, { granted in
            guard granted else {
                return
            }
            completion()
        })
    }
    
    func pickImage(present: @escaping (ViewController) -> Void, completion: @escaping (UIImage) -> Void) {
        self.context.sharedContext.openImagePicker(context: self.context, completion: { image in
            completion(image)
        }, present: { [weak self] controller in
            present(controller)
        })
    }
}

#endif
