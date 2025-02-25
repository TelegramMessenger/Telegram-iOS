import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AnimationCache
import MultiAnimationRenderer

public enum StorySharingSubject {
    case messages([Message])
    case gift(StarGift.UniqueGift)
}

public protocol ShareControllerAccountContext: AnyObject {
    var accountId: AccountRecordId { get }
    var accountPeerId: EnginePeer.Id { get }
    var stateManager: AccountStateManager { get }
    var engineData: TelegramEngine.EngineData { get }
    var animationCache: AnimationCache { get }
    var animationRenderer: MultiAnimationRenderer { get }
    var contentSettings: ContentSettings { get }
    var appConfiguration: AppConfiguration { get }
    
    func resolveInlineStickers(fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError>
}

public protocol ShareControllerEnvironment: AnyObject {
    var presentationData: PresentationData { get }
    var updatedPresentationData: Signal<PresentationData, NoError> { get }
    var isMainApp: Bool { get }
    var energyUsageSettings: EnergyUsageSettings { get }
    
    var mediaManager: MediaManager? { get }
    
    func setAccountUserInterfaceInUse(id: AccountRecordId) -> Disposable
    func donateSendMessageIntent(account: ShareControllerAccountContext, peerIds: [EnginePeer.Id])
}

public enum ShareControllerExternalStatus {
    case preparing(Bool)
    case progress(Float)
    case done
}

public enum ShareControllerError {
    case generic
    case fileTooBig(Int64)
}

public enum ShareControllerSubject {
    public final class PublicLinkPrefix {
        public let visibleString: String
        public let actualString: String
        
        public init(visibleString: String, actualString: String) {
            self.visibleString = visibleString
            self.actualString = actualString
        }
    }
    
    public final class MediaParameters {
        public let startAtTimestamp: Int32?
        public let publicLinkPrefix: PublicLinkPrefix?
        
        public init(startAtTimestamp: Int32?, publicLinkPrefix: PublicLinkPrefix?) {
            self.startAtTimestamp = startAtTimestamp
            self.publicLinkPrefix = publicLinkPrefix
        }
    }
    
    case url(String)
    case text(String)
    case quote(text: String, url: String)
    case messages([Message])
    case image([ImageRepresentationWithReference])
    case media(AnyMediaReference, MediaParameters?)
    case mapMedia(TelegramMediaMap)
    case fromExternal(Int, ([PeerId], [PeerId: Int64], [PeerId: StarsAmount], String, ShareControllerAccountContext, Bool) -> Signal<ShareControllerExternalStatus, ShareControllerError>)
}
