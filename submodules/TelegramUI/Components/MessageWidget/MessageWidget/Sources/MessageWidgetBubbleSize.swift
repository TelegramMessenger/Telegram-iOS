import Foundation
import CoreGraphics

/// A widget message's size anchors (`messageMediaWidget width:int height:int`), in CSS px; 0 is auto, each axis on its own.
public struct MessageWidgetAnchors: Equatable {
    public var width: Int32
    public var height: Int32

    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
}

/// The bubble's size from the anchors (widget-sandbox v0.1.0, integration.md "Bubble sizing", sdk-v1.md §5.6). Every axis
/// is bounded, auto included; 200 / 50 / 600 are the shared v0.1.0 constants.
public enum MessageWidgetBubbleSize {
    public static let minimumWidth: CGFloat = 200.0
    public static let minimumHeight: CGFloat = 50.0
    public static let maximumHeight: CGFloat = 600.0

    /// The width the widget is created with: 0 takes the bubble's width, the widest the chat gives a bubble; W is a
    /// fixed width, clamped to [200, the bubble's maximum width].
    public static func width(anchors: MessageWidgetAnchors, maximumWidth: CGFloat) -> CGFloat {
        if anchors.width <= 0 {
            return maximumWidth
        }
        return min(max(CGFloat(anchors.width), MessageWidgetBubbleSize.minimumWidth), maximumWidth)
    }

    /// The bubble's height. H is fixed from the start, clamp(H, 50, 600), whatever the content reports. 0 is the height
    /// the widget reported, clamped to [50, 600]; before it reports, the height cached for the message, else the default
    /// placeholder.
    public static func height(anchors: MessageWidgetAnchors, reported: CGFloat?, cached: CGFloat?) -> CGFloat {
        if anchors.height > 0 {
            return MessageWidgetBubbleSize.clampedHeight(CGFloat(anchors.height))
        }
        if let reported {
            return MessageWidgetBubbleSize.clampedHeight(reported)
        }
        if let cached {
            return MessageWidgetBubbleSize.clampedHeight(cached)
        }
        return MessageWidgetInstance.placeholderHeight
    }

    private static func clampedHeight(_ height: CGFloat) -> CGFloat {
        return min(max(height, MessageWidgetBubbleSize.minimumHeight), MessageWidgetBubbleSize.maximumHeight)
    }

    /// The edge a widget bubble's next update keeps (integration.md "Which edge stays put"), from what its last layout
    /// showed and what its widget says now: the widget's own once it has reported (it has run its script), else the one
    /// cached with its height (a widget re-created that has not reported or failed to start, one gone to the pill). None
    /// for the first height after the placeholder, which is placed as any new message is (the user's decision), nor for
    /// a fixed height, which no report changes, nor for an update that leaves the height as it is: the chat's scroll
    /// target for it would end a held jump and stop a fling for nothing. The height changes when the widget goes to the
    /// pill or back (widgets switched off or on, a start that failed) or reported one other than the one laid out.
    public static func resizeAnchor(laidOut: MessageWidgetLaidOutHeight, widgetsEnabled: Bool, widget: MessageWidgetRunState?, cachedAnchor: MessageWidgetResizeAnchor?) -> MessageWidgetResizeAnchor? {
        guard laidOut.autoHeight, !laidOut.placeholder else {
            return nil
        }
        let changesHeight: Bool
        if widgetsEnabled != laidOut.widgetsEnabled {
            changesHeight = true
        } else if laidOut.pill {
            changesHeight = false
        } else if widget?.failedToStart == true {
            changesHeight = true
        } else if let reported = widget?.reportedHeight {
            changesHeight = abs(MessageWidgetBubbleSize.height(anchors: MessageWidgetAnchors(width: 0, height: 0), reported: reported, cached: nil) - laidOut.height) > 0.5
        } else {
            changesHeight = false
        }
        guard changesHeight else {
            return nil
        }
        if let widget, widget.reportedHeight != nil {
            return widget.resizeAnchor
        }
        return cachedAnchor
    }
}

/// What a widget bubble's last applied layout showed, for the resize anchor of its next update.
public struct MessageWidgetLaidOutHeight: Equatable {
    /// The height is the widget's own: no fixed height anchor.
    public var autoHeight: Bool
    /// The 160 pt placeholder: nothing reported or cached yet.
    public var placeholder: Bool
    /// The unsupported pill instead of the widget.
    public var pill: Bool
    /// Whether widgets could run (`chatMessageWidgetRenderingEnabled`).
    public var widgetsEnabled: Bool
    /// The widget area's height.
    public var height: CGFloat

    public init(autoHeight: Bool, placeholder: Bool, pill: Bool, widgetsEnabled: Bool, height: CGFloat) {
        self.autoHeight = autoHeight
        self.placeholder = placeholder
        self.pill = pill
        self.widgetsEnabled = widgetsEnabled
        self.height = height
    }
}

/// A bubble's widget as its registry has it now, for the resize anchor of the bubble's next update.
public struct MessageWidgetRunState: Equatable {
    /// The height it last reported, nil until it has.
    public var reportedHeight: CGFloat?
    /// The edge it asked for, top until it has.
    public var resizeAnchor: MessageWidgetResizeAnchor
    /// It did not start: the next layout shows the pill.
    public var failedToStart: Bool

    public init(reportedHeight: CGFloat?, resizeAnchor: MessageWidgetResizeAnchor, failedToStart: Bool) {
        self.reportedHeight = reportedHeight
        self.resizeAnchor = resizeAnchor
        self.failedToStart = failedToStart
    }
}

/// The edge of a widget's bubble that stays put on screen when its height changes (`TelegramWidget.setResizeAnchor`,
/// sdk-v1 §5.6, widget-sandbox v0.1.3): `top`, the default, grows the bubble downward; `bottom` upward.
public enum MessageWidgetResizeAnchor: Equatable {
    case top
    case bottom
}

/// The last auto height each message's widget reported, and its resize anchor, so a message that scrolls back in opens
/// at that height and the list does not jump (integration.md: "cache it per message", "keep the anchor next to the
/// cached height"). In memory for the process. Main thread only. Past `capacity` entries, the least recently set is
/// dropped.
public final class MessageWidgetHeightCache {
    public static let shared = MessageWidgetHeightCache()

    private let capacity: Int
    private var entries: [AnyHashable: (height: CGFloat, anchor: MessageWidgetResizeAnchor, stamp: UInt64)] = [:]
    /// Keys in the order they were set; an entry whose stamp no longer matches was set again later.
    private var order: [(key: AnyHashable, stamp: UInt64)] = []
    private var orderStart = 0
    private var nextStamp: UInt64 = 0

    public init(capacity: Int = 4096) {
        self.capacity = max(1, capacity)
    }

    /// Tests only: the entries the eviction order holds, stale ones included.
    var bookkeepingCountForTesting: Int {
        return self.order.count - self.orderStart
    }

    public func height(for key: AnyHashable) -> CGFloat? {
        return self.entries[key]?.height
    }

    public func entry(for key: AnyHashable) -> (height: CGFloat, anchor: MessageWidgetResizeAnchor)? {
        return self.entries[key].map { ($0.height, $0.anchor) }
    }

    public func set(_ height: CGFloat, anchor: MessageWidgetResizeAnchor = .top, for key: AnyHashable) {
        self.nextStamp += 1
        self.entries[key] = (height, anchor, self.nextStamp)
        self.order.append((key, self.nextStamp))
        while self.entries.count > self.capacity, self.orderStart < self.order.count {
            let oldest = self.order[self.orderStart]
            self.orderStart += 1
            if self.entries[oldest.key]?.stamp == oldest.stamp {
                self.entries[oldest.key] = nil
            }
        }
        // Setting a key again leaves its earlier entry in `order` stale; a layout pass sets its message every time, so
        // rebuild the order from the live entries once stale ones could outnumber them.
        if self.order.count - self.orderStart > 2 * self.capacity {
            self.order = self.entries.map { (key: $0.key, stamp: $0.value.stamp) }.sorted { $0.stamp < $1.stamp }
            self.orderStart = 0
        } else if self.orderStart > self.capacity {
            self.order.removeFirst(self.orderStart)
            self.orderStart = 0
        }
    }
}
