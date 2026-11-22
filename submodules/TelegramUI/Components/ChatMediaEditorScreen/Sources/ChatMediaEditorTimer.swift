import Foundation
import UIKit

public protocol ChatMediaEditorTimerAdapter: AnyObject {
    func timer(for uniqueId: String) -> Int32?
    func setTimer(_ timer: Int32?, for uniqueId: String)
}

public func chatMediaEditorTimerValue(_ value: Int32?) -> Int32? {
    guard let value, value != 0 else {
        return nil
    }
    return value
}

public final class ChatMediaEditorTimerModel {
    public let adapter: ChatMediaEditorTimerAdapter
    public let selection: ChatMediaEditorSelectionModel?

    public init(adapter: ChatMediaEditorTimerAdapter, selection: ChatMediaEditorSelectionModel?) {
        self.adapter = adapter
        self.selection = selection
    }

    public func timer(for uniqueId: String) -> Int32? {
        return chatMediaEditorTimerValue(self.adapter.timer(for: uniqueId))
    }

    public func timerUpdated(_ timer: Int32?, for uniqueId: String) {
        self.adapter.setTimer(chatMediaEditorTimerValue(timer), for: uniqueId)
        self.selection?.autoSelect(uniqueId)
    }

    @discardableResult
    public func applySendTimer(_ timer: Int32, currentId: String) -> [String] {
        var ids = self.selection?.adapter.selectedIds() ?? []
        if !ids.contains(currentId) {
            ids.append(currentId)
        }
        let value = chatMediaEditorTimerValue(timer)
        for uniqueId in ids {
            self.adapter.setTimer(value, for: uniqueId)
        }
        return ids
    }

    public func hasAnyTimer(currentId: String) -> Bool {
        if self.timer(for: currentId) != nil {
            return true
        }
        for uniqueId in self.selection?.adapter.selectedIds() ?? [] {
            if self.timer(for: uniqueId) != nil {
                return true
            }
        }
        return false
    }
}

public struct ChatMediaEditorSendMenuOptions: Equatable {
    public var canSendWhenOnline: Bool
    public var canSchedule: Bool
    public var hasTimer: Bool

    public init(canSendWhenOnline: Bool, canSchedule: Bool, hasTimer: Bool) {
        self.canSendWhenOnline = canSendWhenOnline
        self.canSchedule = canSchedule
        self.hasTimer = hasTimer
    }
}

public func chatMediaEditorSendMenuOptions(hasSchedule: Bool, sendWhenOnlineAvailable: Bool, hasTimer: Bool, hasAnyTimer: Bool) -> ChatMediaEditorSendMenuOptions {
    let canSchedule = hasSchedule && !hasAnyTimer
    return ChatMediaEditorSendMenuOptions(canSendWhenOnline: sendWhenOnlineAvailable && canSchedule, canSchedule: canSchedule, hasTimer: hasTimer)
}

public let chatMediaEditorTimerTooltipDefaultsKey = "TG_displayedMediaTimerTooltip_v3"
public let chatMediaEditorTimerTooltipLimit = 3
public let chatMediaEditorTimerTooltipDelay: Double = 0.5
public let chatMediaEditorTimerTooltipDuration: Double = 3.5

public final class ChatMediaEditorTimerTooltipCounter {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private var count: Int {
        return (self.defaults.object(forKey: chatMediaEditorTimerTooltipDefaultsKey) as? NSNumber)?.intValue ?? 0
    }

    public func shouldDisplay(hasTimer: Bool) -> Bool {
        return hasTimer && self.count < chatMediaEditorTimerTooltipLimit
    }

    public func noteDisplayed() {
        self.defaults.set(NSNumber(value: self.count + 1), forKey: chatMediaEditorTimerTooltipDefaultsKey)
    }

    public func suppress() {
        self.defaults.set(NSNumber(value: chatMediaEditorTimerTooltipLimit), forKey: chatMediaEditorTimerTooltipDefaultsKey)
    }
}
