import Foundation

public struct ChatMediaSendItemOptions: Equatable {
    public var caption: NSAttributedString?
    public var timer: Int32?
    public var spoiler: Bool
    public var price: Int64?
    public var isAnimation: Bool
    public var hasAnimatedPainting: Bool
    public var livePhotoLoopOrBounce: Bool
    public var isLivePhoto: Bool
    public var isMuted: Bool
    public var excludedFromGrouping: Bool

    public init(caption: NSAttributedString? = nil, timer: Int32? = nil, spoiler: Bool = false, price: Int64? = nil, isAnimation: Bool = false, hasAnimatedPainting: Bool = false, livePhotoLoopOrBounce: Bool = false, isLivePhoto: Bool = false, isMuted: Bool = false, excludedFromGrouping: Bool = false) {
        self.caption = caption
        self.timer = timer
        self.spoiler = spoiler
        self.price = price
        self.isAnimation = isAnimation
        self.hasAnimatedPainting = hasAnimatedPainting
        self.livePhotoLoopOrBounce = livePhotoLoopOrBounce
        self.isLivePhoto = isLivePhoto
        self.isMuted = isMuted
        self.excludedFromGrouping = excludedFromGrouping
    }

    public var allowsHd: Bool {
        return !self.isAnimation && !self.hasAnimatedPainting && !self.livePhotoLoopOrBounce && !self.isLivePhoto
    }
}

public struct ChatMediaSendGlobalOptions: Equatable {
    public var grouping: Bool
    public var forcedCaption: NSAttributedString?
    public var forceHd: Bool
    public var saveEditedPhotosToCameraRoll: Bool

    public init(grouping: Bool, forcedCaption: NSAttributedString? = nil, forceHd: Bool = false, saveEditedPhotosToCameraRoll: Bool = false) {
        self.grouping = grouping
        self.forcedCaption = forcedCaption
        self.forceHd = forceHd
        self.saveEditedPhotosToCameraRoll = saveEditedPhotosToCameraRoll
    }
}

public struct ChatMediaSendPlannedItem: Equatable {
    public var index: Int
    public var caption: NSAttributedString?
    public var groupingKey: Int64?
    public var timer: Int32?
    public var spoiler: Bool
    public var price: Int64?

    public init(index: Int, caption: NSAttributedString?, groupingKey: Int64?, timer: Int32?, spoiler: Bool, price: Int64?) {
        self.index = index
        self.caption = caption
        self.groupingKey = groupingKey
        self.timer = timer
        self.spoiler = spoiler
        self.price = price
    }

    public var isExcludedFromCameraRoll: Bool {
        return self.timer != nil
    }
}

public func chatMediaSendPlan(items: [ChatMediaSendItemOptions], global: ChatMediaSendGlobalOptions, makeGroupingKey: () -> Int64) -> [ChatMediaSendPlannedItem] {
    let timers: [Int32?] = items.map { item in
        if let timer = item.timer, timer != 0 {
            return timer
        } else {
            return nil
        }
    }

    var grouping = global.grouping
    var price: Int64?
    for (index, item) in items.enumerated() {
        if timers[index] != nil || item.isAnimation || item.isMuted || item.hasAnimatedPainting || item.livePhotoLoopOrBounce {
            grouping = false
        }
        if price == nil {
            price = item.price
        }
    }

    var groupingKey: Int64?
    if grouping && items.count > 1 {
        groupingKey = makeGroupingKey()
    }

    let hasForcedCaption = (global.forcedCaption?.length ?? 0) > 0

    var result: [ChatMediaSendPlannedItem] = []
    var counter = 0
    for (index, item) in items.enumerated() {
        var caption = global.forcedCaption ?? item.caption
        if hasForcedCaption {
            if grouping && index > 0 {
                caption = nil
            } else if !grouping && index < items.count - 1 {
                caption = nil
            }
        }

        result.append(ChatMediaSendPlannedItem(index: index, caption: caption, groupingKey: timers[index] == nil && !item.excludedFromGrouping ? groupingKey : nil, timer: timers[index], spoiler: item.spoiler, price: price))

        counter += 1
        if groupingKey != nil && counter == 10 {
            counter = 0
            groupingKey = makeGroupingKey()
        }
    }
    return result
}

public let chatMediaSendHighQualityPhotoDefaultsKey = "TG_photoHighQuality_v0"

public func chatMediaSendInitialHighQualityPhoto(defaults: UserDefaults = .standard) -> Bool {
    return defaults.bool(forKey: chatMediaSendHighQualityPhotoDefaultsKey)
}

public func chatMediaSendPersistHighQualityPhoto(_ value: Bool, defaults: UserDefaults = .standard) {
    defaults.set(value, forKey: chatMediaSendHighQualityPhotoDefaultsKey)
}
