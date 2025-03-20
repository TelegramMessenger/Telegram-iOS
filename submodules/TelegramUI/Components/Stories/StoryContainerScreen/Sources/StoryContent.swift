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
    
    public enum AudioMode {
        case ambient
        case on
        case off
    }
    
    public struct DayCounters: Equatable {
        public var position: Int
        public var totalCount: Int
        
        public init(position: Int, totalCount: Int) {
            self.position = position
            self.totalCount = totalCount
        }
    }
    
    public final class SharedState {
        public var replyDrafts: [StoryId: NSAttributedString] = [:]
        public var baseRate: Double = 1.0
        
        public init() {
        }
    }
    
    public enum ProgressMode {
        case play
        case pause
        case blurred
    }
    
    open class View: UIView {
        open func setProgressMode(_ progressMode: ProgressMode) {
        }
        
        open func rewind() {
        }
        
        open func leaveAmbientMode() {
        }
        
        open func enterAmbientMode(ambient: Bool) {
        }
        
        open func setBaseRate(_ baseRate: Double) {
        }
        
        open var videoPlaybackPosition: Double? {
            return nil
        }
    }
    
    public final class Environment: Equatable {
        public let externalState: ExternalState
        public let sharedState: SharedState
        public let theme: PresentationTheme
        public let presentationProgressUpdated: (Double, Bool, Bool) -> Void
        public let markAsSeen: (StoryId) -> Void
        
        public init(
            externalState: ExternalState,
            sharedState: SharedState,
            theme: PresentationTheme,
            presentationProgressUpdated: @escaping (Double, Bool, Bool) -> Void,
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
    
    public let id: StoryId
    public let position: Int?
    public let dayCounters: DayCounters?
    public let peerId: EnginePeer.Id?
    public let storyItem: EngineStoryItem
    public let entityFiles: [EngineMedia.Id: TelegramMediaFile]
    public let itemPeer: EnginePeer?

    public init(
        id: StoryId,
        position: Int?,
        dayCounters: DayCounters?,
        peerId: EnginePeer.Id?,
        storyItem: EngineStoryItem,
        entityFiles: [EngineMedia.Id: TelegramMediaFile],
        itemPeer: EnginePeer?
    ) {
        self.id = id
        self.position = position
        self.dayCounters = dayCounters
        self.peerId = peerId
        self.storyItem = storyItem
        self.entityFiles = entityFiles
        self.itemPeer = itemPeer
    }
    
    public static func ==(lhs: StoryContentItem, rhs: StoryContentItem) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.position != rhs.position {
            return false
        }
        if lhs.dayCounters != rhs.dayCounters {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.storyItem != rhs.storyItem {
            return false
        }
        if lhs.entityFiles != rhs.entityFiles {
            return false
        }
        if lhs.itemPeer != rhs.itemPeer {
            return false
        }
        return true
    }
}

public final class StoryContentContextState {
    public final class AdditionalPeerData: Equatable {
        public let isMuted: Bool
        public let areVoiceMessagesAvailable: Bool
        public let presence: EnginePeer.Presence?
        public let canViewStats: Bool
        public let isPremiumRequiredForMessaging: Bool
        public let preferHighQualityStories: Bool
        public let boostsToUnrestrict: Int32?
        public let appliedBoosts: Int32?
        public let sendPaidMessageStars: StarsAmount?
        
        public init(
            isMuted: Bool,
            areVoiceMessagesAvailable: Bool,
            presence: EnginePeer.Presence?,
            canViewStats: Bool,
            isPremiumRequiredForMessaging: Bool,
            preferHighQualityStories: Bool,
            boostsToUnrestrict: Int32?,
            appliedBoosts: Int32?,
            sendPaidMessageStars: StarsAmount?
        ) {
            self.isMuted = isMuted
            self.areVoiceMessagesAvailable = areVoiceMessagesAvailable
            self.presence = presence
            self.canViewStats = canViewStats
            self.isPremiumRequiredForMessaging = isPremiumRequiredForMessaging
            self.preferHighQualityStories = preferHighQualityStories
            self.boostsToUnrestrict = boostsToUnrestrict
            self.appliedBoosts = appliedBoosts
            self.sendPaidMessageStars = sendPaidMessageStars
        }
        
        public static func == (lhs: StoryContentContextState.AdditionalPeerData, rhs: StoryContentContextState.AdditionalPeerData) -> Bool {
            if lhs.isMuted != rhs.isMuted {
                return false
            }
            if lhs.areVoiceMessagesAvailable != rhs.areVoiceMessagesAvailable {
                return false
            }
            if lhs.presence != rhs.presence {
                return false
            }
            if lhs.canViewStats != rhs.canViewStats {
                return false
            }
            if lhs.isPremiumRequiredForMessaging != rhs.isPremiumRequiredForMessaging {
                return false
            }
            if lhs.preferHighQualityStories != rhs.preferHighQualityStories {
                return false
            }
            if lhs.boostsToUnrestrict != rhs.boostsToUnrestrict {
                return false
            }
            if lhs.appliedBoosts != rhs.appliedBoosts {
                return false
            }
            if lhs.sendPaidMessageStars != rhs.sendPaidMessageStars {
                return false
            }
            return true
        }
    }
    
    public final class FocusedSlice: Equatable {
        public let peer: EnginePeer
        public let additionalPeerData: AdditionalPeerData
        public let item: StoryContentItem
        public let totalCount: Int
        public let previousItemId: StoryId?
        public let nextItemId: StoryId?
        public let allItems: [StoryContentItem]
        public let forwardInfoStories: [StoryId: Promise<EngineStoryItem?>]
        
        var effectivePeer: EnginePeer {
            return self.item.itemPeer ?? self.peer
        }
        
        public init(
            peer: EnginePeer,
            additionalPeerData: AdditionalPeerData,
            item: StoryContentItem,
            totalCount: Int,
            previousItemId: StoryId?,
            nextItemId: StoryId?,
            allItems: [StoryContentItem],
            forwardInfoStories: [StoryId: Promise<EngineStoryItem?>]
        ) {
            self.peer = peer
            self.additionalPeerData = additionalPeerData
            self.item = item
            self.totalCount = totalCount
            self.previousItemId = previousItemId
            self.nextItemId = nextItemId
            self.allItems = allItems
            self.forwardInfoStories = forwardInfoStories
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
        case id(StoryId)
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
