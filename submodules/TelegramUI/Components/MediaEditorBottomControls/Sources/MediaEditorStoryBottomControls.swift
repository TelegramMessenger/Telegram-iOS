import Foundation
import UIKit
import Display

public struct MediaEditorStoryBottomControlsGeometry: Equatable {
    public var panelFrame: CGRect
    public var spec: MediaEditorBottomControlsLayoutSpec
}

public func mediaEditorStoryBottomControlsGeometry(size: CGSize, isTablet: Bool, statusBarHeight: CGFloat, safeBottomInset: CGFloat, hasStatusIsland: Bool, hasReservedCorners: Bool, bottomEdgeRightInset: CGFloat = 0.0) -> MediaEditorStoryBottomControlsGeometry {
    let buttonBottomInset: CGFloat = 8.0
    var controlsBottomInset: CGFloat = 0.0
    let sideInset: CGFloat
    if isTablet {
        sideInset = 30.0
    } else {
        let previewHeight = floorToScreenPixels(size.width * 1.77778)
        if size.height < previewHeight + 30.0 {
            controlsBottomInset = -62.0
            if hasStatusIsland {
                controlsBottomInset = min(controlsBottomInset, -(statusBarHeight + 31.0 + 30.0))
            }
            sideInset = (hasStatusIsland || hasReservedCorners) ? 16.0 : 9.0
        } else if size.width > 320.0 {
            sideInset = 16.0
        } else {
            sideInset = 9.0
        }
    }
    let y = size.height - safeBottomInset + buttonBottomInset + controlsBottomInset
    return MediaEditorStoryBottomControlsGeometry(
        panelFrame: CGRect(x: 0.0, y: y, width: size.width, height: mediaEditorBottomControlsButtonSide),
        spec: MediaEditorBottomControlsLayoutSpec(sideInset: sideInset, rightExtraInset: isTablet ? bottomEdgeRightInset : 0.0, middleCentering: .betweenSideButtons)
    )
}

public enum MediaEditorStoryToolsTab: Hashable {
    case adjustments
    case tint
    case blur
    case curves
}

public enum MediaEditorStoryPaintTab: Hashable {
    case drawing
    case sticker
    case text
}

public enum MediaEditorStoryEditorMode: Equatable {
    case story(isEditingStory: Bool, isNarrow: Bool)
    case botPreview
    case sticker(isEmpty: Bool)
    case avatar
    case cover
}

public enum MediaEditorStoryBottomControlsState: Equatable {
    case rest(MediaEditorStoryEditorMode)
    case draw(MediaEditorStoryPaintTab)
    case tools(selected: MediaEditorStoryToolsTab, active: Set<MediaEditorStoryToolsTab>, hidesBlur: Bool)
}

public enum MediaEditorStoryBottomControlsLeft: Equatable {
    case back
    case close

    public var id: String {
        switch self {
        case .back:
            return "back"
        case .close:
            return "close"
        }
    }
}

public enum MediaEditorStoryBottomControlsRight: Equatable {
    case next(isDone: Bool)
    case nextIcon
    case add
    case check

    public var id: String {
        switch self {
        case let .next(isDone):
            return isDone ? "done" : "next"
        case .nextIcon:
            return "nextIcon"
        case .add:
            return "add"
        case .check:
            return "check"
        }
    }
}

public enum MediaEditorStoryBottomControlsMiddle: Hashable {
    case draw
    case text
    case sticker
    case tools
    case rotate
    case flip
    case paint(MediaEditorStoryPaintTab)
    case tool(MediaEditorStoryToolsTab)

    public var id: String {
        switch self {
        case .draw:
            return "story.draw"
        case .text:
            return "story.text"
        case .sticker:
            return "story.sticker"
        case .tools:
            return "story.tools"
        case .rotate:
            return "story.rotate"
        case .flip:
            return "story.flip"
        case let .paint(tab):
            switch tab {
            case .drawing:
                return "paint.draw"
            case .sticker:
                return "paint.sticker"
            case .text:
                return "paint.text"
            }
        case let .tool(tab):
            switch tab {
            case .adjustments:
                return "tool.adjustments"
            case .tint:
                return "tool.tint"
            case .blur:
                return "tool.blur"
            case .curves:
                return "tool.curves"
            }
        }
    }
}

public struct MediaEditorStoryBottomControlsItems: Equatable {
    public var left: MediaEditorStoryBottomControlsLeft
    public var middle: [MediaEditorStoryBottomControlsMiddle]
    public var selected: MediaEditorStoryBottomControlsMiddle?
    public var highlighted: Set<MediaEditorStoryBottomControlsMiddle>
    public var right: MediaEditorStoryBottomControlsRight
}

public func mediaEditorStoryBottomControlsItems(state: MediaEditorStoryBottomControlsState) -> MediaEditorStoryBottomControlsItems {
    switch state {
    case let .rest(mode):
        switch mode {
        case let .story(isEditingStory, isNarrow):
            return MediaEditorStoryBottomControlsItems(left: .back, middle: [.draw, .text, .sticker, .tools], selected: nil, highlighted: [], right: isNarrow ? .nextIcon : .next(isDone: isEditingStory))
        case .botPreview:
            return MediaEditorStoryBottomControlsItems(left: .back, middle: [.draw, .text, .sticker, .tools], selected: nil, highlighted: [], right: .add)
        case let .sticker(isEmpty):
            return MediaEditorStoryBottomControlsItems(left: .back, middle: isEmpty ? [.draw, .text, .sticker] : [.draw, .text, .sticker, .tools], selected: nil, highlighted: [], right: .check)
        case .avatar, .cover:
            return MediaEditorStoryBottomControlsItems(left: .back, middle: [.rotate, .flip, .draw, .tools], selected: nil, highlighted: [], right: .check)
        }
    case let .draw(tab):
        return MediaEditorStoryBottomControlsItems(left: .close, middle: [.paint(.drawing), .paint(.sticker), .paint(.text)], selected: .paint(tab), highlighted: [], right: .check)
    case let .tools(selected, active, hidesBlur):
        let tabs: [MediaEditorStoryToolsTab] = hidesBlur ? [.adjustments, .tint, .curves] : [.adjustments, .tint, .blur, .curves]
        return MediaEditorStoryBottomControlsItems(
            left: .close,
            middle: tabs.map { .tool($0) },
            selected: tabs.contains(selected) ? .tool(selected) : nil,
            highlighted: Set(tabs.filter { active.contains($0) }.map { .tool($0) }),
            right: .check
        )
    }
}

public func mediaEditorStoryBottomControlsHidden(isDisplayingUnadoptedTool: Bool, isDismissing: Bool, isInteractingWithEntities: Bool, isEditingText: Bool, isEditingCaption: Bool) -> Bool {
    return isDisplayingUnadoptedTool || isDismissing || isInteractingWithEntities || isEditingText || isEditingCaption
}
