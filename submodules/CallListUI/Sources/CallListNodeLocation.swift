import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import Display

enum CallListNodeLocation: Equatable {
    case initial(count: Int)
    case changeType(index: EngineMessage.Index)
    case navigation(index: EngineMessage.Index)
    case scroll(index: EngineMessage.Index, sourceIndex: EngineMessage.Index, scrollPosition: ListViewScrollPosition, animated: Bool)
    
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
    let scope: EngineCallList.Scope
}

enum CallListNodeViewUpdateType {
    case Initial
    case Generic
    case Reload
    case ReloadAnimated
    case UpdateVisible
}

struct CallListNodeViewUpdate {
    let view: EngineCallList
    let type: CallListNodeViewUpdateType
    let scrollPosition: CallListNodeViewScrollPosition?
}

func callListViewForLocationAndType(locationAndType: CallListNodeLocationAndType, engine: TelegramEngine) -> Signal<(CallListNodeViewUpdate, EngineCallList.Scope), NoError> {
    switch locationAndType.location {
    case let .initial(count):
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: EngineMessage.Index.absoluteUpperBound(),
            itemCount: count
        )
        |> map { view -> (CallListNodeViewUpdate, EngineCallList.Scope) in
            return (CallListNodeViewUpdate(view: view, type: .Generic, scrollPosition: nil), locationAndType.scope)
        }
    case let .changeType(index):
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (CallListNodeViewUpdate, EngineCallList.Scope) in
            return (CallListNodeViewUpdate(view: view, type: .ReloadAnimated, scrollPosition: nil), locationAndType.scope)
        }
    case let .navigation(index):
        var first = true
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (CallListNodeViewUpdate, EngineCallList.Scope) in
            let genericType: CallListNodeViewUpdateType
            if first {
                first = false
                genericType = .UpdateVisible
            } else {
                genericType = .Generic
            }
            return (CallListNodeViewUpdate(view: view, type: genericType, scrollPosition: nil), locationAndType.scope)
        }
    case let .scroll(index, sourceIndex, scrollPosition, animated):
        let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
        let callScrollPosition: CallListNodeViewScrollPosition = .index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
        var first = true
        return engine.messages.callList(
            scope: locationAndType.scope,
            index: index,
            itemCount: 120
        )
        |> map { view -> (CallListNodeViewUpdate, EngineCallList.Scope) in
            let genericType: CallListNodeViewUpdateType
            let scrollPosition: CallListNodeViewScrollPosition? = first ? callScrollPosition : nil
            if first {
                first = false
                genericType = .UpdateVisible
            } else {
                genericType = .Generic
            }
            return (CallListNodeViewUpdate(view: view, type: genericType, scrollPosition: scrollPosition), locationAndType.scope)
        }
    }
}
