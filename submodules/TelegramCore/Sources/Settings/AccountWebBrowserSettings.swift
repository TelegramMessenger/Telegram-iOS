import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

public struct AccountWebBrowserException: Codable, Equatable {
    public let domain: String
    public let url: String
    public let title: String
    public let favicon: Int64?
    
    public init(domain: String, url: String, title: String, favicon: Int64?) {
        self.domain = domain
        self.url = url
        self.title = title
        self.favicon = favicon
    }
    
    init(apiWebDomainException: Api.WebDomainException) {
        switch apiWebDomainException {
        case let .webDomainException(data):
            self.init(domain: data.domain, url: data.url, title: data.title, favicon: data.favicon)
        }
    }
}

public struct AccountWebBrowserSettings: Codable, Equatable {
    public let openExternalBrowser: Bool
    public let externalExceptions: [AccountWebBrowserException]
    public let inAppExceptions: [AccountWebBrowserException]
    public let hash: Int64
    
    public static var defaultSettings: AccountWebBrowserSettings {
        return AccountWebBrowserSettings(openExternalBrowser: false, externalExceptions: [], inAppExceptions: [], hash: 0)
    }
    
    public init(openExternalBrowser: Bool, externalExceptions: [AccountWebBrowserException], inAppExceptions: [AccountWebBrowserException], hash: Int64) {
        self.openExternalBrowser = openExternalBrowser
        self.externalExceptions = externalExceptions
        self.inAppExceptions = inAppExceptions
        self.hash = hash
    }
    
    init(apiWebBrowserSettings: Api.account.WebBrowserSettings, current: AccountWebBrowserSettings?) {
        switch apiWebBrowserSettings {
        case let .webBrowserSettings(data):
            self.init(
                openExternalBrowser: (data.flags & (1 << 0)) != 0,
                externalExceptions: data.externalExceptions.map(AccountWebBrowserException.init(apiWebDomainException:)),
                inAppExceptions: data.inappExceptions.map(AccountWebBrowserException.init(apiWebDomainException:)),
                hash: data.hash
            )
        case .webBrowserSettingsNotModified:
            self = current ?? .defaultSettings
        }
    }
    
    public func withUpdatedOpenExternalBrowser(_ openExternalBrowser: Bool) -> AccountWebBrowserSettings {
        return AccountWebBrowserSettings(openExternalBrowser: openExternalBrowser, externalExceptions: self.externalExceptions, inAppExceptions: self.inAppExceptions, hash: 0)
    }
    
    public func withAppliedExceptionUpdate(openExternalBrowser: Bool?, delete: Bool, exception: AccountWebBrowserException) -> AccountWebBrowserSettings {
        var externalExceptions = self.externalExceptions
        var inAppExceptions = self.inAppExceptions
        
        let removeMatching: (inout [AccountWebBrowserException]) -> Void = { list in
            list.removeAll(where: { item in
                if !exception.url.isEmpty && item.url == exception.url {
                    return true
                }
                return item.domain == exception.domain
            })
        }
        
        if delete {
            if let openExternalBrowser {
                if openExternalBrowser {
                    removeMatching(&externalExceptions)
                } else {
                    removeMatching(&inAppExceptions)
                }
            } else {
                removeMatching(&externalExceptions)
                removeMatching(&inAppExceptions)
            }
        } else if let openExternalBrowser {
            if openExternalBrowser {
                removeMatching(&externalExceptions)
                externalExceptions.append(exception)
            } else {
                removeMatching(&inAppExceptions)
                inAppExceptions.append(exception)
            }
        }
        
        return AccountWebBrowserSettings(openExternalBrowser: self.openExternalBrowser, externalExceptions: externalExceptions, inAppExceptions: inAppExceptions, hash: 0)
    }
}

private func storeAccountWebBrowserSettings(postbox: Postbox, settings: AccountWebBrowserSettings) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.updatePreferencesEntry(key: PreferencesKeys.webBrowserSettings, { _ in
            return PreferencesEntry(settings)
        })
    }
}

func _internal_getAccountWebBrowserSettings(postbox: Postbox, network: Network, forceUpdate: Bool = false) -> Signal<AccountWebBrowserSettings, NoError> {
    let fetch: (AccountWebBrowserSettings?, Int64) -> Signal<AccountWebBrowserSettings, NoError> = { current, hash in
        return network.request(Api.functions.account.getWebBrowserSettings(hash: hash))
        |> retryRequestIfNotFrozen
        |> mapToSignal { result -> Signal<AccountWebBrowserSettings, NoError> in
            guard let result else {
                return .complete()
            }
            switch result {
            case .webBrowserSettingsNotModified:
                return .complete()
            case .webBrowserSettings:
                let settings = AccountWebBrowserSettings(apiWebBrowserSettings: result, current: current)
                if let current, settings == current {
                    return .complete()
                } else {
                    return storeAccountWebBrowserSettings(postbox: postbox, settings: settings)
                    |> mapToSignal { _ -> Signal<AccountWebBrowserSettings, NoError> in
                        return .single(settings)
                    }
                }
            }
        }
    }
    
    return postbox.transaction { transaction -> AccountWebBrowserSettings in
        return transaction.getPreferencesEntry(key: PreferencesKeys.webBrowserSettings)?.get(AccountWebBrowserSettings.self) ?? AccountWebBrowserSettings.defaultSettings
    }
    |> mapToSignal { current -> Signal<AccountWebBrowserSettings, NoError> in
        let hash: Int64 = forceUpdate ? 0 : current.hash
        return .single(current)
        |> then(fetch(current, hash))
    }
}

public func updateRemoteWebBrowserSettings(postbox: Postbox, network: Network, openExternalBrowser: Bool) -> Signal<Void, NoError> {
    var flags: Int32 = 0
    if openExternalBrowser {
        flags |= (1 << 0)
    }
    return network.request(Api.functions.account.updateWebBrowserSettings(flags: flags))
    |> retryRequestIfNotFrozen
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result else {
            return .complete()
        }
        return postbox.transaction { transaction -> AccountWebBrowserSettings? in
            return transaction.getPreferencesEntry(key: PreferencesKeys.webBrowserSettings)?.get(AccountWebBrowserSettings.self)
        }
        |> mapToSignal { current -> Signal<Void, NoError> in
            return storeAccountWebBrowserSettings(postbox: postbox, settings: AccountWebBrowserSettings(apiWebBrowserSettings: result, current: current))
        }
    }
}

public func toggleWebBrowserSettingsException(postbox: Postbox, network: Network, openExternalBrowser: Bool?, delete: Bool, url: String) -> Signal<Bool, NoError> {
    var flags: Int32 = 0
    var apiOpenExternalBrowser: Api.Bool?
    if let openExternalBrowser {
        flags |= (1 << 0)
        apiOpenExternalBrowser = openExternalBrowser ? .boolTrue : .boolFalse 
    }
    if delete {
        flags |= (1 << 1)
    }
    return network.request(Api.functions.account.toggleWebBrowserSettingsException(flags: flags, openExternalBrowser: apiOpenExternalBrowser, url: url))
    |> retryRequestIfNotFrozen
    |> mapToSignal { result -> Signal<Bool, NoError> in
        guard let result else {
            return .single(false)
        }

        return postbox.transaction { transaction -> Bool in
            var settings = transaction.getPreferencesEntry(key: PreferencesKeys.webBrowserSettings)?.get(AccountWebBrowserSettings.self) ?? AccountWebBrowserSettings.defaultSettings
            var updated = false
            for update in result.allUpdates {
                switch update {
                case let .updateWebBrowserSettings(updateWebBrowserSettingsData):
                    settings = settings.withUpdatedOpenExternalBrowser((updateWebBrowserSettingsData.flags & (1 << 0)) != 0)
                    updated = true
                case let .updateWebBrowserException(updateWebBrowserExceptionData):
                    let openExternalBrowser: Bool?
                    if let value = updateWebBrowserExceptionData.openExternalBrowser {
                        switch value {
                        case .boolFalse:
                            openExternalBrowser = false
                        case .boolTrue:
                            openExternalBrowser = true
                        }
                    } else {
                        openExternalBrowser = nil
                    }

                    settings = settings.withAppliedExceptionUpdate(
                        openExternalBrowser: openExternalBrowser,
                        delete: (updateWebBrowserExceptionData.flags & (1 << 1)) != 0,
                        exception: AccountWebBrowserException(apiWebDomainException: updateWebBrowserExceptionData.exception)
                    )
                    updated = true
                default:
                    break
                }
            }

            if updated {
                transaction.updatePreferencesEntry(key: PreferencesKeys.webBrowserSettings, { _ in
                    return PreferencesEntry(settings)
                })
            }

            return updated
        }
    }
}

public func deleteWebBrowserSettingsExceptions(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.account.deleteWebBrowserSettingsExceptions())
    |> retryRequestIfNotFrozen
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result else {
            return .complete()
        }
        return postbox.transaction { transaction -> AccountWebBrowserSettings? in
            return transaction.getPreferencesEntry(key: PreferencesKeys.webBrowserSettings)?.get(AccountWebBrowserSettings.self)
        }
        |> mapToSignal { current -> Signal<Void, NoError> in
            return storeAccountWebBrowserSettings(postbox: postbox, settings: AccountWebBrowserSettings(apiWebBrowserSettings: result, current: current))
        }
    }
}
