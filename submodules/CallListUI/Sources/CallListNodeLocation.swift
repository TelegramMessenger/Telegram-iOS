import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display

enum CallListNodeLocation: Equatable {
    case initial(count: Int)
    case changeType(index: MessageIndex)
    case navigation(index: MessageIndex)
    case scroll(index: MessageIndex, sourceIndex: MessageIndex, scrollPosition: ListViewScrollPosition, animated: Bool)
    
    static func ==(lhs: CallListNodeLocation, rhs: CallListNodeLocation) -> Bool {
        switch lhs {
            case let .navigation(index):
                switch rhs {
                    case .navigation(index):
                        return true
                    default:
                        return false
                }
            default:
                return false
        }
    }
}

struct CallListNodeLocationAndType: Equatable {
    let location: CallListNodeLocation
    let type: CallListViewType
    
    static func ==(lhs: CallListNodeLocationAndType, rhs: CallListNodeLocationAndType) -> Bool {
        return lhs.location == rhs.location && lhs.type == rhs.type
    }
}

enum CallListNodeViewUpdateType {
    case Initial
    case Generic
    case Reload
    case ReloadAnimated
    case UpdateVisible
}

struct CallListNodeViewUpdate {
    let view: CallListView
    let type: CallListNodeViewUpdateType
    let scrollPosition: CallListNodeViewScrollPosition?
}

func callListViewForLocationAndType(locationAndType: CallListNodeLocationAndType, account: Account) -> Signal<CallListNodeViewUpdate, NoError> {
    switch locationAndType.location {
        case let .initial(count):
            return account.viewTracker.callListView(type: locationAndType.type, index: MessageIndex.absoluteUpperBound(), count: count) |> map { view -> CallListNodeViewUpdate in
                return CallListNodeViewUpdate(view: view, type: .Generic, scrollPosition: nil)
            }
        case let .changeType(index):
            return account.viewTracker.callListView(type: locationAndType.type, index: index, count: 120) |> map { view -> CallListNodeViewUpdate in
                return CallListNodeViewUpdate(view: view, type: .ReloadAnimated, scrollPosition: nil)
            }
        case let .navigation(index):
            var first = true
            return account.viewTracker.callListView(type: locationAndType.type, index: index, count: 120) |> map { view -> CallListNodeViewUpdate in
                let genericType: CallListNodeViewUpdateType
                if first {
                    first = false
                    genericType = .UpdateVisible
                } else {
                    genericType = .Generic
                }
                return CallListNodeViewUpdate(view: view, type: genericType, scrollPosition: nil)
            }
        case let .scroll(index, sourceIndex, scrollPosition, animated):
            let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
            let callScrollPosition: CallListNodeViewScrollPosition = .index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
            var first = true
            return account.viewTracker.callListView(type: locationAndType.type, index: index, count: 120) |> map { view -> CallListNodeViewUpdate in
                let genericType: CallListNodeViewUpdateType
                let scrollPosition: CallListNodeViewScrollPosition? = first ? callScrollPosition : nil
                if first {
                    first = false
                    genericType = .UpdateVisible
                } else {
                    genericType = .Generic
                }
                return CallListNodeViewUpdate(view: view, type: genericType, scrollPosition: scrollPosition)
            }
    }
}
