import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore

public final class StoryContentItem {
    public final class ExternalState {
        public init() {
        }
    }
    
    open class View: UIView {
        open func setIsProgressPaused(_ isProgressPaused: Bool) {
        }
        
        open func rewind() {
        }
    }
    
    public final class Environment: Equatable {
        public let externalState: ExternalState
        public let presentationProgressUpdated: (Double) -> Void
        
        public init(
            externalState: ExternalState,
            presentationProgressUpdated: @escaping (Double) -> Void
        ) {
            self.externalState = externalState
            self.presentationProgressUpdated = presentationProgressUpdated
        }
        
        public static func ==(lhs: Environment, rhs: Environment) -> Bool {
            if lhs.externalState !== rhs.externalState {
                return false
            }
            return true
        }
    }
    
    public let id: AnyHashable
    public let position: Int
    public let component: AnyComponent<StoryContentItem.Environment>
    public let centerInfoComponent: AnyComponent<Empty>?
    public let rightInfoComponent: AnyComponent<Empty>?
    public let peerId: EnginePeer.Id?
    public let storyItem: EngineStoryItem
    public let preload: Signal<Never, NoError>?
    public let delete: (() -> Void)?
    public let markAsSeen: (() -> Void)?
    public let hasLike: Bool
    public let isMy: Bool

    public init(
        id: AnyHashable,
        position: Int,
        component: AnyComponent<StoryContentItem.Environment>,
        centerInfoComponent: AnyComponent<Empty>?,
        rightInfoComponent: AnyComponent<Empty>?,
        peerId: EnginePeer.Id?,
        storyItem: EngineStoryItem,
        preload: Signal<Never, NoError>?,
        delete: (() -> Void)?,
        markAsSeen: (() -> Void)?,
        hasLike: Bool,
        isMy: Bool
    ) {
        self.id = id
        self.position = position
        self.component = component
        self.centerInfoComponent = centerInfoComponent
        self.rightInfoComponent = rightInfoComponent
        self.peerId = peerId
        self.storyItem = storyItem
        self.preload = preload
        self.delete = delete
        self.markAsSeen = markAsSeen
        self.hasLike = hasLike
        self.isMy = isMy
    }
}

public final class StoryContentItemSlice {
    public let id: AnyHashable
    public let focusedItemId: AnyHashable?
    public let items: [StoryContentItem]
    public let totalCount: Int
    public let previousItemId: AnyHashable?
    public let nextItemId: AnyHashable?
    public let update: (StoryContentItemSlice, AnyHashable) -> Signal<StoryContentItemSlice, NoError>

    public init(
        id: AnyHashable,
        focusedItemId: AnyHashable?,
        items: [StoryContentItem],
        totalCount: Int,
        previousItemId: AnyHashable?,
        nextItemId: AnyHashable?,
        update: @escaping (StoryContentItemSlice, AnyHashable) -> Signal<StoryContentItemSlice, NoError>
    ) {
        self.id = id
        self.focusedItemId = focusedItemId
        self.items = items
        self.totalCount = totalCount
        self.previousItemId = previousItemId
        self.nextItemId = nextItemId
        self.update = update
    }
}

public final class StoryContentContextState {
    public final class FocusedSlice: Equatable {
        public let peer: EnginePeer
        public let item: StoryContentItem
        public let totalCount: Int
        public let previousItemId: Int32?
        public let nextItemId: Int32?
        
        public init(
            peer: EnginePeer,
            item: StoryContentItem,
            totalCount: Int,
            previousItemId: Int32?,
            nextItemId: Int32?
        ) {
            self.peer = peer
            self.item = item
            self.totalCount = totalCount
            self.previousItemId = previousItemId
            self.nextItemId = nextItemId
        }
        
        public static func ==(lhs: FocusedSlice, rhs: FocusedSlice) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.item.id != rhs.item.id {
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
    public enum Direction {
        case previous
        case next
    }
    
    case item(Direction)
    case peer(Direction)
}

public protocol StoryContentContext: AnyObject {
    var stateValue: StoryContentContextState? { get }
    var state: Signal<StoryContentContextState, NoError> { get }
    var updated: Signal<Void, NoError> { get }
    
    func resetSideStates()
    func navigate(navigation: StoryContentContextNavigation)
}
