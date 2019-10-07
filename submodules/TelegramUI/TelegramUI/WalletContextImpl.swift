import Foundation
import UIKit
import WalletUI
import Postbox
import TelegramCore
import AccountContext
import SwiftSignalKit
import TelegramPresentationData
import ShareController
import DeviceAccess

final class WalletContextImpl: WalletContext {
    private let context: AccountContext
    
    let postbox: Postbox
    let network: Network
    let tonInstance: TonInstance
    let keychain: TonKeychain
    let presentationData: PresentationData
    
    var inForeground: Signal<Bool, NoError> {
        return self.context.sharedContext.applicationBindings.applicationInForeground
    }
    
    init(context: AccountContext, tonContext: TonContext) {
        self.context = context
        
        self.postbox = self.context.account.postbox
        self.network = self.context.account.network
        self.tonInstance = tonContext.instance
        self.keychain = tonContext.keychain
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
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
        DeviceAccess.authorizeAccess(to: .camera, presentationData: presentationData, present: { c, a in
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
    
    func pickImage(completion: @escaping (UIImage) -> Void) {
        self.context.sharedContext.openImagePicker(context: self.context, completion: { image in
            completion(image)
        }, present: { [weak self] controller in
            self?.context.sharedContext.mainWindow?.present(controller, on: .root)
        })
    }
}
