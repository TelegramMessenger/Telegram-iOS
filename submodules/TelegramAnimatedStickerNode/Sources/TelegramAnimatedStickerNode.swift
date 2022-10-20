import Foundation
import AnimatedStickerNode
import SwiftSignalKit
import Postbox
import TelegramCore
import MediaResources
import StickerResources
import LocalMediaResources
import AppBundle

public final class AnimatedStickerNodeLocalFileSource: AnimatedStickerNodeSource {
    public var fitzModifier: EmojiFitzModifier? = nil
    public let isVideo: Bool = false
    
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
        
    public func directDataPath(attemptSynchronously: Bool) -> Signal<String?, NoError> {
        if let path = self.path {
            return .single(path)
        } else {
            return .single(nil)
        }
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        return .never()
    }
    
    func maybeCachedDataPath(width: Int, height: Int) -> (String, Bool)? {
        return nil
    }
    
    public var path: String? {
        if let path = getAppBundle().path(forResource: self.name, ofType: "tgs") {
            return path
        } else if let path = getAppBundle().path(forResource: self.name, ofType: "json") {
            return path
        } else {
            return nil
        }
    }
}

public final class AnimatedStickerResourceSource: AnimatedStickerNodeSource {
    public let account: Account
    public let resource: MediaResource
    public let fitzModifier: EmojiFitzModifier?
    public let isVideo: Bool
    
    public init(account: Account, resource: MediaResource, fitzModifier: EmojiFitzModifier? = nil, isVideo: Bool = false) {
        self.account = account
        self.resource = resource
        self.fitzModifier = fitzModifier
        self.isVideo = isVideo
    }
    
    public func cachedDataPath(width: Int, height: Int) -> Signal<(String, Bool), NoError> {
        return chatMessageAnimationData(mediaBox: self.account.postbox.mediaBox, resource: self.resource, fitzModifier: self.fitzModifier, isVideo: self.isVideo, width: width, height: height, synchronousLoad: false)
        |> filter { data in
            return data.size != 0
        }
        |> map { data -> (String, Bool) in
            return (data.path, data.complete)
        }
    }
    
    public func directDataPath(attemptSynchronously: Bool) -> Signal<String?, NoError> {
        return self.account.postbox.mediaBox.resourceData(self.resource, attemptSynchronously: attemptSynchronously)
        |> map { data -> String? in
            if data.complete {
                return data.path
            } else {
                return nil
            }
        }
    }
}
