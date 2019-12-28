import Foundation
import AnimatedStickerNode
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import MediaResources
import StickerResources

public final class AnimatedStickerResourceSource: AnimatedStickerNodeSource {
    public let account: Account
    public let resource: MediaResource
    public let fitzModifier: EmojiFitzModifier?
    
    public init(account: Account, resource: MediaResource, fitzModifier: EmojiFitzModifier? = nil) {
        self.account = account
        self.resource = resource
        self.fitzModifier = fitzModifier
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        return chatMessageAnimationData(postbox: self.account.postbox, resource: self.resource, fitzModifier: self.fitzModifier, width: width, height: height, synchronousLoad: false)
        |> filter { data in
            return data.size != 0
        }
        |> map { data -> (String, Bool) in
            return (data.path, data.complete)
        }
    }
    
    public func directDataPath() -> Signal<String, NoError> {
        return self.account.postbox.mediaBox.resourceData(resource)
        |> filter { data in
            return data.complete
        }
        |> map { data -> String in
            return data.path
        }
    }
}
