import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SwiftSignalKit
import OverlayStatusController
import WalletCore

private final class WalletConfigurationScreenArguments {
    let updateState: ((WalletConfigurationScreenState) -> WalletConfigurationScreenState) -> Void
    let dismissInput: () -> Void
    let updateSelectedMode: (WalletConfigurationScreenMode) -> Void
    let updateBlockchainName: (String) -> Void
    
    init(updateState: @escaping ((WalletConfigurationScreenState) -> WalletConfigurationScreenState) -> Void, dismissInput: @escaping () -> Void, updateSelectedMode: @escaping (WalletConfigurationScreenMode) -> Void, updateBlockchainName: @escaping (String) -> Void) {
        self.updateState = updateState
        self.dismissInput = dismissInput
        self.updateSelectedMode = updateSelectedMode
        self.updateBlockchainName = updateBlockchainName
    }
}

private enum WalletConfigurationScreenMode {
    case url
    case customString
}

private enum WalletConfigurationScreenSection: Int32 {
    case mode
    case configString
    case blockchainName
}

private enum WalletConfigurationScreenEntryTag: ItemListItemTag {
    case configStringText
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? WalletConfigurationScreenEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum WalletConfigurationScreenEntry: ItemListNodeEntry, Equatable {
    case modeHeader(WalletTheme, String)
    case modeUrl(WalletTheme, String, Bool)
    case modeCustomString(WalletTheme, String, Bool)
    case modeInfo(WalletTheme, String)
    case configUrl(WalletTheme, WalletStrings, String, String)
    case configString(WalletTheme, String, String)
    case blockchainNameHeader(WalletTheme, String)
    case blockchainName(WalletTheme, WalletStrings, String, String)
    case blockchainNameInfo(WalletTheme, String)
   
    var section: ItemListSectionId {
        switch self {
        case .modeHeader, .modeUrl, .modeCustomString, .modeInfo:
            return WalletConfigurationScreenSection.mode.rawValue
        case .configUrl, .configString:
            return WalletConfigurationScreenSection.configString.rawValue
        case .blockchainNameHeader, .blockchainName, .blockchainNameInfo:
            return WalletConfigurationScreenSection.blockchainName.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .modeHeader:
            return 0
        case .modeUrl:
            return 1
        case .modeCustomString:
            return 2
        case .modeInfo:
            return 3
        case .configUrl:
            return 4
        case .configString:
            return 5
        case .blockchainNameHeader:
            return 6
        case .blockchainName:
            return 7
        case .blockchainNameInfo:
            return 8
        }
    }
    
    static func <(lhs: WalletConfigurationScreenEntry, rhs: WalletConfigurationScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: Any) -> ListViewItem {
        let arguments = arguments as! WalletConfigurationScreenArguments
        switch self {
        case let .modeHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .modeUrl(theme, text, isSelected):
            return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateSelectedMode(.url)
            })
        case let .modeCustomString(theme, text, isSelected):
            return ItemListCheckboxItem(theme: theme, title: text, style: .left, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateSelectedMode(.customString)
            })
        case let .modeInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        case let .configUrl(theme, strings, placeholder, text):
            return ItemListMultilineInputItem(theme: theme, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: false, autocorrection: false, returnKeyType: .done, minimalHeight: nil, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.configUrl = value
                    return state
                }
            }, shouldUpdateText: { _ in
                return true
            }, processPaste: nil, updatedFocus: nil, tag: WalletConfigurationScreenEntryTag.configStringText, action: nil, inlineAction: nil)
        case let .configString(theme, placeholder, text):
            return ItemListMultilineInputItem(theme: theme, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: false, autocorrection: false, returnKeyType: .done, minimalHeight: nil, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.configString = value
                    return state
                }
            }, shouldUpdateText: { _ in
                return true
            }, processPaste: nil, updatedFocus: nil, tag: WalletConfigurationScreenEntryTag.configStringText, action: nil, inlineAction: nil)
        case let .blockchainNameHeader(theme, title):
            return ItemListSectionHeaderItem(theme: theme, text: title, sectionId: self.section)
        case let .blockchainName(theme, strings, title, value):
            return ItemListSingleLineInputItem(theme: theme, strings: strings, title: NSAttributedString(string: ""), text: value, placeholder: title, sectionId: self.section, textUpdated: { value in
                arguments.updateBlockchainName(value)
            }, action: {})
        case let .blockchainNameInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct WalletConfigurationScreenState: Equatable {
    var mode: WalletConfigurationScreenMode
    var configUrl: String
    var configString: String
    var blockchainName: String
    
    var isEmpty: Bool {
        if self.blockchainName.isEmpty {
            return true
        }
        switch self.mode {
        case .url:
            return self.configUrl.isEmpty || URL(string: self.configUrl) == nil
        case .customString:
            return self.configString.isEmpty
        }
    }
}

private func walletConfigurationScreenEntries(presentationData: WalletPresentationData, state: WalletConfigurationScreenState) -> [WalletConfigurationScreenEntry] {
    var entries: [WalletConfigurationScreenEntry] = []
   
    entries.append(.modeHeader(presentationData.theme, presentationData.strings.Wallet_Configuration_SourceHeader))
    entries.append(.modeUrl(presentationData.theme, presentationData.strings.Wallet_Configuration_SourceURL, state.mode == .url))
    entries.append(.modeCustomString(presentationData.theme, presentationData.strings.Wallet_Configuration_SourceJSON, state.mode == .customString))
    entries.append(.modeInfo(presentationData.theme, presentationData.strings.Wallet_Configuration_SourceInfo))
    
    switch state.mode {
    case .url:
        entries.append(.configUrl(presentationData.theme, presentationData.strings, presentationData.strings.Wallet_Configuration_SourceURL, state.configUrl))
    case .customString:
        entries.append(.configString(presentationData.theme, presentationData.strings.Wallet_Configuration_SourceJSON, state.configString))
    }
    
    entries.append(.blockchainNameHeader(presentationData.theme, presentationData.strings.Wallet_Configuration_BlockchainIdHeader))
    entries.append(.blockchainName(presentationData.theme, presentationData.strings, presentationData.strings.Wallet_Configuration_BlockchainIdPlaceholder, state.blockchainName))
    entries.append(.blockchainNameInfo(presentationData.theme, presentationData.strings.Wallet_Configuration_BlockchainIdInfo))
    
    return entries
}

protocol WalletConfigurationScreen {
}

private final class WalletConfigurationScreenImpl: ItemListController, WalletConfigurationScreen {
    override func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        return CGSize(width: layout.size.width, height: layout.size.height - 174.0)
    }
}

private func presentError(context: WalletContext, present: ((ViewController, Any?) -> Void)?, title: String?, text: String) {
    present?(standardTextAlertController(theme: context.presentationData.theme.alert, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: context.presentationData.strings.Wallet_Alert_OK, action: {})]), nil)
}

func walletConfigurationScreen(context: WalletContext, currentConfiguration: LocalWalletConfiguration) -> ViewController {
    var configUrl = ""
    var configString = ""
    switch currentConfiguration.source {
    case let .url(url):
        configUrl = url
    case let .string(string):
        configString = string
    }
    let initialState = WalletConfigurationScreenState(mode: configString.isEmpty ? .url : .customString, configUrl: configUrl, configString: configString, blockchainName: currentConfiguration.blockchainName)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((WalletConfigurationScreenState) -> WalletConfigurationScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var ensureItemVisibleImpl: ((WalletConfigurationScreenEntryTag, Bool) -> Void)?
    
    weak var currentStatusController: ViewController?
    let arguments = WalletConfigurationScreenArguments(updateState: { f in
        updateState(f)
    }, dismissInput: {
        dismissInputImpl?()
    }, updateSelectedMode: { mode in
        updateState { state in
            var state = state
            state.mode = mode
            return state
        }
    }, updateBlockchainName: { value in
        updateState { state in
            var state = state
            state.blockchainName = value
            return state
        }
    })
    
    let signal = combineLatest(queue: .mainQueue(), .single(context.presentationData), statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Navigation_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Configuration_Apply), style: .bold, enabled: !state.isEmpty, action: {
            let state = stateValue.with { $0 }
            let source: LocalWalletConfigurationSource
            let blockchainName = state.blockchainName
            if blockchainName.isEmpty {
                return
            }
            switch state.mode {
            case .url:
                if state.configUrl.isEmpty {
                    return
                } else {
                    source = .url(state.configUrl)
                }
            case .customString:
                if state.configString.isEmpty {
                    return
                } else {
                    source = .string(state.configString)
                }
            }
            if currentConfiguration.source != source || currentConfiguration.blockchainName != blockchainName {
                let applyResolved: (String) -> Void = { resolvedConfig in
                    let proceed: () -> Void = {
                        let _ = (context.updateResolvedWalletConfiguration(source: source, blockchainName: blockchainName, resolvedValue: resolvedConfig)
                        |> deliverOnMainQueue).start(completed: {
                            dismissImpl?()
                        })
                    }
                    
                    if blockchainName != currentConfiguration.blockchainName {
                        presentControllerImpl?(standardTextAlertController(theme: context.presentationData.theme.alert, title: context.presentationData.strings.Wallet_Configuration_BlockchainNameChangedTitle, text: context.presentationData.strings.Wallet_Configuration_BlockchainNameChangedText, actions: [
                            TextAlertAction(type: .genericAction, title: context.presentationData.strings.Wallet_Alert_Cancel, action: {}),
                            TextAlertAction(type: .destructiveAction, title: context.presentationData.strings.Wallet_Configuration_BlockchainNameChangedProceed, action: {
                                proceed()
                            }),
                        ]), nil)
                    } else {
                        proceed()
                    }
                }
                
                let presentationData = context.presentationData
                
                switch source {
                case let .url(url):
                    if let parsedUrl = URL(string: url) {
                        let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                        presentControllerImpl?(statusController, nil)
                        
                        let _ = (context.downloadFile(url: parsedUrl)
                        |> deliverOnMainQueue).start(next: { data in
                            statusController.dismiss()
                            
                            guard let string = String(data: data, encoding: .utf8) else {
                                let presentationData = context.presentationData
                                presentError(context: context, present: presentControllerImpl, title: presentationData.strings.Wallet_Configuration_ApplyErrorTitle, text: presentationData.strings.Wallet_Configuration_ApplyErrorTextURLInvalidData)
                                return
                            }
                            
                            let _ = (context.tonInstance.validateConfig(config: string, blockchainName: blockchainName)
                            |> deliverOnMainQueue).start(error: { _ in
                                let presentationData = context.presentationData
                                presentError(context: context, present: presentControllerImpl, title: presentationData.strings.Wallet_Configuration_ApplyErrorTitle, text: presentationData.strings.Wallet_Configuration_ApplyErrorTextURLInvalidData)
                            }, completed: {
                                applyResolved(string)
                            })
                        }, error: { _ in
                            statusController.dismiss()
                            
                            let presentationData = context.presentationData
                            presentError(context: context, present: presentControllerImpl, title: presentationData.strings.Wallet_Configuration_ApplyErrorTitle, text: presentationData.strings.Wallet_Configuration_ApplyErrorTextURLUnreachable(url).0)
                        })
                    } else {
                        presentError(context: context, present: presentControllerImpl, title: presentationData.strings.Wallet_Configuration_ApplyErrorTitle, text: presentationData.strings.Wallet_Configuration_ApplyErrorTextURLInvalid)
                        return
                    }
                case let .string(string):
                    let _ = (context.tonInstance.validateConfig(config: string, blockchainName: blockchainName)
                    |> deliverOnMainQueue).start(error: { _ in
                        let presentationData = context.presentationData
                        presentError(context: context, present: presentControllerImpl, title: presentationData.strings.Wallet_Configuration_ApplyErrorTitle, text: presentationData.strings.Wallet_Configuration_ApplyErrorTextJSONInvalidData)
                    }, completed: {
                        applyResolved(string)
                    })
                }
            } else {
                dismissImpl?()
            }
        })
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_Configuration_Title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Wallet_Navigation_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletConfigurationScreenEntries(presentationData: presentationData, state: state), style: .blocks, focusItemTag: nil, ensureVisibleItemTag: nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletConfigurationScreenImpl(theme: context.presentationData.theme, strings: context.presentationData.strings, updatedPresentationData: .single((context.presentationData.theme, context.presentationData.strings)), state: signal, tabBarItem: nil)
    controller.navigationPresentation = .modal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    controller.experimentalSnapScrollToItem = true
    controller.didAppear = { _ in
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        let _ = controller?.dismiss()
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    ensureItemVisibleImpl = { [weak controller] targetTag, animated in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            var resultItemNode: ListViewItemNode?
            let state = stateValue.with({ $0 })
            let _ = controller.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListItemNode {
                    if let tag = itemNode.tag, tag.isEqual(to: targetTag) {
                        resultItemNode = itemNode as? ListViewItemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode, animated: animated)
            }
        })
    }
    return controller
}
