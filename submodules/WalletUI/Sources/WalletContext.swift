import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit

public protocol WalletContext {
    var postbox: Postbox { get }
    var network: Network { get }
    var tonInstance: TonInstance { get }
    var keychain: TonKeychain { get }
    var presentationData: WalletPresentationData { get }
    
    var inForeground: Signal<Bool, NoError> { get }
    
    func presentNativeController(_ controller: UIViewController)
    
    func idleTimerExtension() -> Disposable
    func openUrl(_ url: String)
    func shareUrl(_ url: String)
    func openPlatformSettings()
    func authorizeAccessToCamera(completion: @escaping () -> Void)
    func pickImage(completion: @escaping (UIImage) -> Void)
}
