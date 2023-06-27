import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Postbox
import TelegramPresentationData

public final class StoryContentItem: Equatable {
    public final class ExternalState {
        public init() {
        }
    }
    
    public final class SharedState {
        public var useAmbientMode: Bool = true
        
        public init() {
        }
    }
    
    open class View: UIView {
        open func setIsProgressPaused(_ isProgressPaused: Bool) {
        }
        
        open func rewind() {
        }
        
        open func leaveAmbientMode() {
        }
        
        open func enterAmbientMode() {
        }
        
        open var videoPlaybackPosition: Double? {
            return nil
        }
    }
    
    public final class Environment: Equatable {
        public let externalState: ExternalState
        public let sharedState: SharedState
        public let theme: PresentationTheme
        public let presentationProgressUpdated: (Double, Bool) -> Void
        public let markAsSeen: (StoryId) -> Void
        
        public init(
            externalState: ExternalState,
            sharedState: SharedState,
            theme: PresentationTheme,
            presentationProgressUpdated: @escaping (Double, Bool) -> Void,
            markAsSeen: @escaping (StoryId) -> Void
        ) {
            self.externalState = externalState
            self.sharedState = sharedState
            self.theme = theme
            self.presentationProgressUpdated = presentationProgressUpdated
            self.markAsSeen = markAsSeen
        }
        
        public static func ==(lhs: Environment, rhs: Environment) -> Bool {
            if lhs.externalState !== rhs.externalState {
                return false
            }
            if lhs.sharedState !== rhs.sharedState {
                return false
            }
            if lhs.theme !== rhs.theme {
                return false
            }
            return true
        }
    }
    
    public let position: Int?
    public let peerId: EnginePeer.Id?
    public let storyItem: EngineStoryItem

    public init(
        position: Int?,
        peerId: EnginePeer.Id?,
        storyItem: EngineStoryItem
    ) {
        self.position = position
        self.peerId = peerId
        self.storyItem = storyItem
    }
    
    public static func ==(lhs: StoryContentItem, rhs: StoryContentItem) -> Bool {
        if lhs.position != rhs.position {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.storyItem != rhs.storyItem {
            return false
        }
        return true
    }
}

public final class StoryContentContextState {
    public final class AdditionalPeerData: Equatable {
        public static func == (lhs: StoryContentContextState.AdditionalPeerData, rhs: StoryContentContextState.AdditionalPeerData) -> Bool {
            return lhs.isMuted == rhs.isMuted && lhs.areVoiceMessagesAvailable == rhs.areVoiceMessagesAvailable
        }
        
        public let isMuted: Bool
        public let areVoiceMessagesAvailable: Bool
        
        public init(
            isMuted: Bool,
            areVoiceMessagesAvailable: Bool
        ) {
            self.isMuted = isMuted
            self.areVoiceMessagesAvailable = areVoiceMessagesAvailable
        }
    }
    
    public final class FocusedSlice: Equatable {
        public let peer: EnginePeer
        public let additionalPeerData: AdditionalPeerData
        public let item: StoryContentItem
        public let totalCount: Int
        public let previousItemId: Int32?
        public let nextItemId: Int32?
        public let allItems: [StoryContentItem]
        
        public init(
            peer: EnginePeer,
            additionalPeerData: AdditionalPeerData,
            item: StoryContentItem,
            totalCount: Int,
            previousItemId: Int32?,
            nextItemId: Int32?,
            allItems: [StoryContentItem]
        ) {
            self.peer = peer
            self.additionalPeerData = additionalPeerData
            self.item = item
            self.totalCount = totalCount
            self.previousItemId = previousItemId
            self.nextItemId = nextItemId
            self.allItems = allItems
        }
        
        public static func ==(lhs: FocusedSlice, rhs: FocusedSlice) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.additionalPeerData != rhs.additionalPeerData {
                return false
            }
            if lhs.item != rhs.item {
                return false
            }
            if lhs.totalCount != rhs.totalCount {
                return false
            }
            if lhs.previousItemId != rhs.previousItemId {
                return false
            }
            if lhs.nextItemId != rhs.nextItemId {
                return false
            }
            if lhs.allItems != rhs.allItems {
                return false
            }
            return true
        }
    }
    
    public let slice: FocusedSlice?
    public let previousSlice: FocusedSlice?
    public let nextSlice: FocusedSlice?
    
    public init(
        slice: FocusedSlice?,
        previousSlice: FocusedSlice?,
        nextSlice: FocusedSlice?
    ) {
        self.slice = slice
        self.previousSlice = previousSlice
        self.nextSlice = nextSlice
    }
}

public enum StoryContentContextNavigation {
    public enum ItemDirection {
        case previous
        case next
        case id(Int32)
    }
    
    public enum PeerDirection {
        case previous
        case next
    }
    
    case item(ItemDirection)
    case peer(PeerDirection)
}

public protocol StoryContentContext: AnyObject {
    var stateValue: StoryContentContextState? { get }
    var state: Signal<StoryContentContextState, NoError> { get }
    var updated: Signal<Void, NoError> { get }
    
    func resetSideStates()
    func navigate(navigation: StoryContentContextNavigation)
    func markAsSeen(id: StoryId)
}
