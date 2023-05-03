import Foundation
import UIKit
import CoreServices
import Display
import ComponentFlow
import LegacyComponents
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AppBundle
import PresentationDataUtils
import LegacyComponents
import ComponentDisplayAdapters
import LottieAnimationComponent
import ViewControllerComponent
import BlurredBackgroundComponent
import ContextUI
import ChatEntityKeyboardInputNode
import EntityKeyboard
import TelegramUIPreferences
import FastBlur

enum DrawingToolState: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case brushState
        case eraserState
    }
    
    enum Key: Int32, RawRepresentable, CaseIterable, Codable {
        case pen = 0
        case arrow = 1
        case marker = 2
        case neon = 3
        case blur = 4
        case eraser = 5
    }
    
    struct BrushState: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case color
            case size
        }
        
        let color: DrawingColor
        let size: CGFloat
        
        init(color: DrawingColor, size: CGFloat) {
            self.color = color
            self.size = size
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.color = try container.decode(DrawingColor.self, forKey: .color)
            self.size = try container.decode(CGFloat.self, forKey: .size)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.color, forKey: .color)
            try container.encode(self.size, forKey: .size)
        }
        
        func withUpdatedColor(_ color: DrawingColor) -> BrushState {
            return BrushState(color: color, size: self.size)
        }
        
        func withUpdatedSize(_ size: CGFloat) -> BrushState {
            return BrushState(color: self.color, size: size)
        }
    }
    
    struct EraserState: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case size
        }
        
        let size: CGFloat
        
        init(size: CGFloat) {
            self.size = size
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.size = try container.decode(CGFloat.self, forKey: .size)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.size, forKey: .size)
        }
        
        func withUpdatedSize(_ size: CGFloat) -> EraserState {
            return EraserState(size: size)
        }
    }
    
    case pen(BrushState)
    case arrow(BrushState)
    case marker(BrushState)
    case neon(BrushState)
    case blur(EraserState)
    case eraser(EraserState)
    
    func withUpdatedColor(_ color: DrawingColor) -> DrawingToolState {
        switch self {
        case let .pen(state):
            return .pen(state.withUpdatedColor(color))
        case let .arrow(state):
            return .arrow(state.withUpdatedColor(color))
        case let .marker(state):
            return .marker(state.withUpdatedColor(color))
        case let .neon(state):
            return .neon(state.withUpdatedColor(color))
        case .blur, .eraser:
            return self
        }
    }
    
    func withUpdatedSize(_ size: CGFloat) -> DrawingToolState {
        switch self {
        case let .pen(state):
            return .pen(state.withUpdatedSize(size))
        case let .arrow(state):
            return .arrow(state.withUpdatedSize(size))
        case let .marker(state):
            return .marker(state.withUpdatedSize(size))
        case let .neon(state):
            return .neon(state.withUpdatedSize(size))
        case let .blur(state):
            return .blur(state.withUpdatedSize(size))
        case let .eraser(state):
            return .eraser(state.withUpdatedSize(size))
        }
    }
    
    var color: DrawingColor? {
        switch self {
        case let .pen(state), let .arrow(state), let .marker(state), let .neon(state):
            return state.color
        default:
            return nil
        }
    }
    
    var size: CGFloat? {
        switch self {
        case let .pen(state), let .arrow(state), let .marker(state), let .neon(state):
            return state.size
        case let .blur(state), let .eraser(state):
            return state.size
        }
    }
    
    var key: DrawingToolState.Key {
        switch self {
        case .pen:
            return .pen
        case .arrow:
            return .arrow
        case .marker:
            return .marker
        case .neon:
            return .neon
        case .blur:
            return .blur
        case .eraser:
            return .eraser
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeValue = try container.decode(Int32.self, forKey: .type)
        if let type = DrawingToolState.Key(rawValue: typeValue) {
            switch type {
            case .pen:
                self = .pen(try container.decode(BrushState.self, forKey: .brushState))
            case .arrow:
                self = .arrow(try container.decode(BrushState.self, forKey: .brushState))
            case .marker:
                self = .marker(try container.decode(BrushState.self, forKey: .brushState))
            case .neon:
                self = .neon(try container.decode(BrushState.self, forKey: .brushState))
            case .blur:
                self = .blur(try container.decode(EraserState.self, forKey: .eraserState))
            case .eraser:
                self = .eraser(try container.decode(EraserState.self, forKey: .eraserState))
            }
        } else {
            self = .pen(BrushState(color: DrawingColor(rgb: 0x000000), size: 0.5))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .pen(state):
            try container.encode(DrawingToolState.Key.pen.rawValue, forKey: .type)
            try container.encode(state, forKey: .brushState)
        case let .arrow(state):
            try container.encode(DrawingToolState.Key.arrow.rawValue, forKey: .type)
            try container.encode(state, forKey: .brushState)
        case let .marker(state):
            try container.encode(DrawingToolState.Key.marker.rawValue, forKey: .type)
            try container.encode(state, forKey: .brushState)
        case let .neon(state):
            try container.encode(DrawingToolState.Key.neon.rawValue, forKey: .type)
            try container.encode(state, forKey: .brushState)
        case let .blur(state):
            try container.encode(DrawingToolState.Key.blur.rawValue, forKey: .type)
            try container.encode(state, forKey: .eraserState)
        case let .eraser(state):
            try container.encode(DrawingToolState.Key.eraser.rawValue, forKey: .type)
            try container.encode(state, forKey: .eraserState)
        }
    }
}

struct DrawingState: Equatable {
    let selectedTool: DrawingToolState.Key
    let tools: [DrawingToolState]
    
    var currentToolState: DrawingToolState {
        return self.toolState(for: self.selectedTool)
    }
    
    func toolState(for key: DrawingToolState.Key) -> DrawingToolState {
        for tool in self.tools {
            if tool.key == key {
                return tool
            }
        }
        return .eraser(DrawingToolState.EraserState(size: 0.5))
    }
    
    func withUpdatedSelectedTool(_ selectedTool: DrawingToolState.Key) -> DrawingState {
        return DrawingState(
            selectedTool: selectedTool,
            tools: self.tools
        )
    }
    
    func withUpdatedTools(_ tools: [DrawingToolState]) -> DrawingState {
        return DrawingState(
            selectedTool: self.selectedTool,
            tools: tools
        )
    }
    
    func withUpdatedColor(_ color: DrawingColor) -> DrawingState {
        var tools = self.tools
        if let index = tools.firstIndex(where: { $0.key == self.selectedTool }) {
            let updated = tools[index].withUpdatedColor(color)
            tools.remove(at: index)
            tools.insert(updated, at: index)
        }
        
        return DrawingState(
            selectedTool: self.selectedTool,
            tools: tools
        )
    }
    
    func withUpdatedSize(_ size: CGFloat) -> DrawingState {
        var tools = self.tools
        if let index = tools.firstIndex(where: { $0.key == self.selectedTool }) {
            let updated = tools[index].withUpdatedSize(size)
            tools.remove(at: index)
            tools.insert(updated, at: index)
        }
        
        return DrawingState(
            selectedTool: self.selectedTool,
            tools: tools
        )
    }
            
    static var initial: DrawingState {
        return DrawingState(
            selectedTool: .pen,
            tools: [
                .pen(DrawingToolState.BrushState(color: DrawingColor(rgb: 0xff453a), size: 0.23)),
                .arrow(DrawingToolState.BrushState(color: DrawingColor(rgb: 0xff8a00), size: 0.23)),
                .marker(DrawingToolState.BrushState(color: DrawingColor(rgb: 0xffd60a), size: 0.75)),
                .neon(DrawingToolState.BrushState(color: DrawingColor(rgb: 0x34c759), size: 0.4)),
                .blur(DrawingToolState.EraserState(size: 0.5)),
                .eraser(DrawingToolState.EraserState(size: 0.5))
            ]
        )
    }
    
    func forVideo() -> DrawingState {
        return DrawingState(
            selectedTool: self.selectedTool,
            tools: self.tools.filter { tool in
                if case .blur = tool {
                    return false
                } else {
                    return true
                }
            }
        )
    }
}

final class DrawingSettings: Codable, Equatable {
    let tools: [DrawingToolState]
    let colors: [DrawingColor]
    
    init(tools: [DrawingToolState], colors: [DrawingColor]) {
        self.tools = tools
        self.colors = colors
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        if let data = try container.decodeIfPresent(Data.self, forKey: "tools"), let tools = try? JSONDecoder().decode([DrawingToolState].self, from: data) {
            self.tools = tools
        } else {
            self.tools = DrawingState.initial.tools
        }
        
        if let data = try container.decodeIfPresent(Data.self, forKey: "colors"), let colors = try? JSONDecoder().decode([DrawingColor].self, from: data) {
            self.colors = colors
        } else {
            self.colors = []
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        if let data = try? JSONEncoder().encode(self.tools) {
            try container.encode(data, forKey: "tools")
        }
        if let data = try? JSONEncoder().encode(self.colors) {
            try container.encode(data, forKey: "colors")
        }
    }
    
    static func ==(lhs: DrawingSettings, rhs: DrawingSettings) -> Bool {
        return lhs.tools == rhs.tools && lhs.colors == rhs.colors
    }
}

private final class ReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView
    private let contentArea: CGRect
    private let customPosition: CGPoint
    
    init(sourceView: UIView, contentArea: CGRect, customPosition: CGPoint) {
        self.sourceView = sourceView
        self.contentArea = contentArea
        self.customPosition = customPosition
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: self.contentArea, customPosition: self.customPosition, actionsPosition: .top)
    }
}

private final class BlurredGradientComponent: Component {
    enum Position {
        case top
        case bottom
    }
    
    let position: Position
    let tag: AnyObject?

    public init(
        position: Position,
        tag: AnyObject?
    ) {
        self.position = position
        self.tag = tag
    }
    
    public static func ==(lhs: BlurredGradientComponent, rhs: BlurredGradientComponent) -> Bool {
        if lhs.position != rhs.position {
            return false
        }
        return true
    }
    
    public final class View: BlurredBackgroundView, ComponentTaggedView {
        private var component: BlurredGradientComponent?
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private var gradientMask = UIImageView()
        private var gradientForeground = SimpleGradientLayer()
        
        public func update(component: BlurredGradientComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            self.isUserInteractionEnabled = false
            
            self.updateColor(color: UIColor(rgb: 0x000000, alpha: component.position == .top ? 0.15 : 0.25), transition: transition.containedViewLayoutTransition)
           
            if self.mask == nil {
                self.mask = self.gradientMask
                self.gradientMask.image = generateGradientImage(
                    size: CGSize(width: 1.0, height: availableSize.height),
                    colors: [UIColor(rgb: 0xffffff, alpha: 1.0), UIColor(rgb: 0xffffff, alpha: 1.0), UIColor(rgb: 0xffffff, alpha: 0.0)],
                    locations: component.position == .top ? [0.0, 0.8, 1.0] : [1.0, 0.5, 0.0],
                    direction: .vertical
                )
                
                self.gradientForeground.colors = [UIColor(rgb: 0x000000, alpha: 0.35).cgColor, UIColor(rgb: 0x000000, alpha: 0.0).cgColor]
                self.gradientForeground.startPoint = CGPoint(x: 0.5, y: component.position == .top ? 0.0 : 1.0)
                self.gradientForeground.endPoint = CGPoint(x: 0.5, y: component.position == .top ? 1.0 : 0.0)
                
                self.layer.addSublayer(self.gradientForeground)
            }
            
            transition.setFrame(view: self.gradientMask, frame: CGRect(origin: .zero, size: availableSize))
            transition.setFrame(layer: self.gradientForeground, frame: CGRect(origin: .zero, size: availableSize))
            
            self.update(size: availableSize, transition: transition.containedViewLayoutTransition)
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(color: nil, enableBlur: true)
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}


enum DrawingScreenTransition {
    case animateIn
    case animateOut
}

private let topGradientTag = GenericComponentViewTag()
private let bottomGradientTag = GenericComponentViewTag()
private let undoButtonTag = GenericComponentViewTag()
private let redoButtonTag = GenericComponentViewTag()
private let clearAllButtonTag = GenericComponentViewTag()
private let colorButtonTag = GenericComponentViewTag()
private let addButtonTag = GenericComponentViewTag()
private let toolsTag = GenericComponentViewTag()
private let modeTag = GenericComponentViewTag()
private let flipButtonTag = GenericComponentViewTag()
private let fillButtonTag = GenericComponentViewTag()
private let zoomOutButtonTag = GenericComponentViewTag()
private let textSettingsTag = GenericComponentViewTag()
private let sizeSliderTag = GenericComponentViewTag()
private let fontTag = GenericComponentViewTag()
private let color1Tag = GenericComponentViewTag()
private let color2Tag = GenericComponentViewTag()
private let color3Tag = GenericComponentViewTag()
private let color4Tag = GenericComponentViewTag()
private let color5Tag = GenericComponentViewTag()
private let color6Tag = GenericComponentViewTag()
private let color7Tag = GenericComponentViewTag()
private let color8Tag = GenericComponentViewTag()
private let colorTags = [color1Tag, color2Tag, color3Tag, color4Tag, color5Tag, color6Tag, color7Tag, color8Tag]
private let doneButtonTag = GenericComponentViewTag()

private final class DrawingScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let isVideo: Bool
    let isAvatar: Bool
    let present: (ViewController) -> Void
    let updateState: ActionSlot<DrawingView.NavigationState>
    let updateColor: ActionSlot<DrawingColor>
    let performAction: ActionSlot<DrawingView.Action>
    let updateToolState: ActionSlot<DrawingToolState>
    let updateSelectedEntity: ActionSlot<DrawingEntity?>
    let insertEntity: ActionSlot<DrawingEntity>
    let deselectEntity: ActionSlot<Void>
    let updateEntitiesPlayback: ActionSlot<Bool>
    let previewBrushSize: ActionSlot<CGFloat?>
    let dismissEyedropper: ActionSlot<Void>
    let requestPresentColorPicker: ActionSlot<Void>
    let toggleWithEraser: ActionSlot<Void>
    let toggleWithPreviousTool: ActionSlot<Void>
    let apply: ActionSlot<Void>
    let dismiss: ActionSlot<Void>
    
    let presentColorPicker: (DrawingColor) -> Void
    let presentFastColorPicker: (UIView) -> Void
    let updateFastColorPickerPan: (CGPoint) -> Void
    let dismissFastColorPicker: () -> Void
    let presentFontPicker: (UIView) -> Void
    
    init(
        context: AccountContext,
        isVideo: Bool,
        isAvatar: Bool,
        present: @escaping (ViewController) -> Void,
        updateState: ActionSlot<DrawingView.NavigationState>,
        updateColor: ActionSlot<DrawingColor>,
        performAction: ActionSlot<DrawingView.Action>,
        updateToolState: ActionSlot<DrawingToolState>,
        updateSelectedEntity: ActionSlot<DrawingEntity?>,
        insertEntity: ActionSlot<DrawingEntity>,
        deselectEntity: ActionSlot<Void>,
        updateEntitiesPlayback: ActionSlot<Bool>,
        previewBrushSize: ActionSlot<CGFloat?>,
        dismissEyedropper: ActionSlot<Void>,
        requestPresentColorPicker: ActionSlot<Void>,
        toggleWithEraser: ActionSlot<Void>,
        toggleWithPreviousTool: ActionSlot<Void>,
        apply: ActionSlot<Void>,
        dismiss: ActionSlot<Void>,
        presentColorPicker: @escaping (DrawingColor) -> Void,
        presentFastColorPicker: @escaping (UIView) -> Void,
        updateFastColorPickerPan: @escaping (CGPoint) -> Void,
        dismissFastColorPicker: @escaping () -> Void,
        presentFontPicker: @escaping (UIView) -> Void
    ) {
        self.context = context
        self.isVideo = isVideo
        self.isAvatar = isAvatar
        self.present = present
        self.updateState = updateState
        self.updateColor = updateColor
        self.performAction = performAction
        self.updateToolState = updateToolState
        self.updateSelectedEntity = updateSelectedEntity
        self.insertEntity = insertEntity
        self.deselectEntity = deselectEntity
        self.updateEntitiesPlayback = updateEntitiesPlayback
        self.previewBrushSize = previewBrushSize
        self.dismissEyedropper = dismissEyedropper
        self.requestPresentColorPicker = requestPresentColorPicker
        self.toggleWithEraser = toggleWithEraser
        self.toggleWithPreviousTool = toggleWithPreviousTool
        self.apply = apply
        self.dismiss = dismiss
        self.presentColorPicker = presentColorPicker
        self.presentFastColorPicker = presentFastColorPicker
        self.updateFastColorPickerPan = updateFastColorPickerPan
        self.dismissFastColorPicker = dismissFastColorPicker
        self.presentFontPicker = presentFontPicker
    }
    
    static func ==(lhs: DrawingScreenComponent, rhs: DrawingScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.isAvatar != rhs.isAvatar {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        enum ImageKey: Hashable {
            case undo
            case redo
            case done
            case add
            case fill
            case stroke
            case flip
            case zoomOut
        }
        private var cachedImages: [ImageKey: UIImage] = [:]
        func image(_ key: ImageKey) -> UIImage {
            if let image = self.cachedImages[key] {
                return image
            } else {
                var image: UIImage
                switch key {
                case .undo:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Undo"), color: .white)!
                case .redo:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Redo"), color: .white)!
                case .done:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Done"), color: .white)!
                case .add:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/Add"), color: .white)!
                case .fill:
                    image = UIImage(bundleImageName: "Media Editor/Fill")!
                case .stroke:
                    image = UIImage(bundleImageName: "Media Editor/Stroke")!
                case .flip:
                    image = UIImage(bundleImageName: "Media Editor/Flip")!
                case .zoomOut:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/ZoomOut"), color: .white)!
                }
                cachedImages[key] = image
                return image
            }
        }
        
        enum Mode {
            case drawing
            case sticker
            case text
        }
        
        private let context: AccountContext
        private let updateToolState: ActionSlot<DrawingToolState>
        private let insertEntity: ActionSlot<DrawingEntity>
        private let deselectEntity: ActionSlot<Void>
        private let updateEntitiesPlayback: ActionSlot<Bool>
        private let dismissEyedropper: ActionSlot<Void>
        private let toggleWithEraser: ActionSlot<Void>
        private let toggleWithPreviousTool: ActionSlot<Void>
        private let present: (ViewController) -> Void
        
        var currentMode: Mode
        var drawingState: DrawingState
        var drawingViewState: DrawingView.NavigationState
        var currentColor: DrawingColor
        var selectedEntity: DrawingEntity?
        
        var lastSize: CGFloat = 0.5
        
        private let stickerPickerInputData = Promise<StickerPickerInputData>()
            
        init(context: AccountContext, updateToolState: ActionSlot<DrawingToolState>, insertEntity: ActionSlot<DrawingEntity>, deselectEntity: ActionSlot<Void>, updateEntitiesPlayback: ActionSlot<Bool>, dismissEyedropper: ActionSlot<Void>, toggleWithEraser: ActionSlot<Void>, toggleWithPreviousTool: ActionSlot<Void>, present: @escaping (ViewController) -> Void) {
            self.context = context
            self.updateToolState = updateToolState
            self.insertEntity = insertEntity
            self.deselectEntity = deselectEntity
            self.updateEntitiesPlayback = updateEntitiesPlayback
            self.dismissEyedropper = dismissEyedropper
            self.toggleWithEraser = toggleWithEraser
            self.toggleWithPreviousTool = toggleWithPreviousTool
            self.present = present
            
            self.currentMode = .drawing
            self.drawingState = .initial
            self.drawingViewState = DrawingView.NavigationState(canUndo: false, canRedo: false, canClear: false, canZoomOut: false, isDrawing: false)
            self.currentColor = self.drawingState.tools.first?.color ?? DrawingColor(rgb: 0xffffff)
            
            self.updateToolState.invoke(self.drawingState.currentToolState)
                        
            let stickerPickerInputData = self.stickerPickerInputData
            Queue.concurrentDefaultQueue().after(0.5, {
                let emojiItems = EmojiPagerContentComponent.emojiInputData(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    isStandalone: false,
                    isStatusSelection: false,
                    isReactionSelection: false,
                    isEmojiSelection: true,
                    hasTrending: false,
                    topReactionItems: [],
                    areUnicodeEmojiEnabled: true,
                    areCustomEmojiEnabled: true,
                    chatPeerId: context.account.peerId,
                    hasSearch: false,
                    forceHasPremium: true
                )
                
                let stickerItems = EmojiPagerContentComponent.stickerInputData(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
                    stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
                    chatPeerId: context.account.peerId,
                    hasSearch: false,
                    hasTrending: true,
                    forceHasPremium: true
                )
                
                let maskItems = EmojiPagerContentComponent.stickerInputData(
                    context: context,
                    animationCache: context.animationCache,
                    animationRenderer: context.animationRenderer,
                    stickerNamespaces: [Namespaces.ItemCollection.CloudMaskPacks],
                    stickerOrderedItemListCollectionIds: [],
                    chatPeerId: context.account.peerId,
                    hasSearch: false,
                    hasTrending: false,
                    forceHasPremium: true
                )
                
                let signal = combineLatest(queue: .mainQueue(),
                    emojiItems,
                    stickerItems,
                    maskItems
                ) |> map { emoji, stickers, masks -> StickerPickerInputData in
                    return StickerPickerInputData(emoji: emoji, stickers: stickers, masks: masks)
                }
                
                stickerPickerInputData.set(signal)
            })
                        
            super.init()
            
            self.loadToolState()
            
            self.toggleWithEraser.connect { [weak self] _ in
                if let strongSelf = self {
                    if strongSelf.drawingState.selectedTool == .eraser {
                        strongSelf.updateSelectedTool(strongSelf.nextToEraserTool)
                    } else {
                        strongSelf.updateSelectedTool(.eraser)
                    }
                }
            }
            
            self.toggleWithPreviousTool.connect { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.updateSelectedTool(strongSelf.previousTool)
                }
            }
        }
        
        func loadToolState() {
            let _ = (self.context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.drawingSettings])
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] sharedData in
                guard let strongSelf = self else {
                    return
                }
                if let drawingSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.drawingSettings]?.get(DrawingSettings.self) {
                    strongSelf.drawingState = strongSelf.drawingState.withUpdatedTools(drawingSettings.tools)
                    strongSelf.currentColor = strongSelf.drawingState.currentToolState.color ?? strongSelf.currentColor
                    strongSelf.updated(transition: .immediate)
                    strongSelf.updateToolState.invoke(strongSelf.drawingState.currentToolState)
                }
            })
        }
        
        func saveToolState() {
            let tools = self.drawingState.tools
            let _ = (self.context.sharedContext.accountManager.transaction { transaction -> Void in
                transaction.updateSharedData(ApplicationSpecificSharedDataKeys.drawingSettings, { _ in
                    return PreferencesEntry(DrawingSettings(tools: tools, colors: []))
                })
            }).start()
        }
                
        private var currentToolState: DrawingToolState {
            return self.drawingState.toolState(for: self.drawingState.selectedTool)
        }
        
        func updateColor(_ color: DrawingColor, animated: Bool = false) {
            self.currentColor = color
            if let selectedEntity = self.selectedEntity {
                selectedEntity.color = color
                selectedEntity.currentEntityView?.update()
            } else {
                self.drawingState = self.drawingState.withUpdatedColor(color)
                self.updateToolState.invoke(self.drawingState.currentToolState)
            }
            self.updated(transition: animated ? .easeInOut(duration: 0.2) : .immediate)
        }
        
        var previousTool: DrawingToolState.Key = .eraser
        var nextToEraserTool: DrawingToolState.Key = .pen
        
        func updateSelectedTool(_ tool: DrawingToolState.Key, update: Bool = true) {
            if self.selectedEntity != nil {
                self.skipSelectedEntityUpdate = true
                self.updateCurrentMode(.drawing, update: false)
                self.skipSelectedEntityUpdate = false
            }
            
            if tool != self.drawingState.selectedTool {
                if self.drawingState.selectedTool == .eraser {
                    self.nextToEraserTool = tool
                } else if tool == .eraser {
                    self.nextToEraserTool = self.drawingState.selectedTool
                }
                self.previousTool = self.drawingState.selectedTool
            }
            
            self.drawingState = self.drawingState.withUpdatedSelectedTool(tool)
            self.currentColor = self.drawingState.currentToolState.color ?? self.currentColor
            self.updateToolState.invoke(self.drawingState.currentToolState)
            if update {
                self.updated(transition: .easeInOut(duration: 0.2))
            }
        }
        
        func updateBrushSize(_ size: CGFloat) {
            if let selectedEntity = self.selectedEntity {
                if let textEntity = selectedEntity as? DrawingTextEntity {
                    textEntity.fontSize = size
                } else {
                    selectedEntity.lineWidth = size
                }
                selectedEntity.currentEntityView?.update()
            } else {
                self.drawingState = self.drawingState.withUpdatedSize(size)
                self.updateToolState.invoke(self.drawingState.currentToolState)
            }
            self.updated(transition: .immediate)
        }
                
        func updateDrawingState(_ state: DrawingView.NavigationState) {
            self.drawingViewState = state
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        var skipSelectedEntityUpdate = false
        func updateSelectedEntity(_ entity: DrawingEntity?) {
            self.dismissEyedropper.invoke(Void())
            
            self.selectedEntity = entity
            if let entity = entity {
                if !entity.color.isClear {
                    self.currentColor = entity.color
                }
                if entity is DrawingStickerEntity {
                    self.currentMode = .sticker
                } else if entity is DrawingTextEntity {
                    self.currentMode = .text
                } else {
                    self.currentMode = .drawing
                }
            } else {
                self.currentMode = .drawing
                self.currentColor = self.drawingState.currentToolState.color ?? self.currentColor
            }
            if !self.skipSelectedEntityUpdate {
                self.updated(transition: .easeInOut(duration: 0.2))
            }
        }
        
        func presentShapePicker(_ sourceView: UIView) {
            let strings = self.context.sharedContext.currentPresentationData.with { $0 }.strings
            
            let items: [ContextMenuItem] = [
                .action(
                    ContextMenuActionItem(
                        text: strings.Paint_Rectangle,
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/ShapeRectangle"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.insertEntity.invoke(DrawingSimpleShapeEntity(shapeType: .rectangle, drawType: .stroke, color: strongSelf.currentColor, lineWidth: 0.15))
                            }
                        }
                    )
                ),
                .action(
                    ContextMenuActionItem(
                        text: strings.Paint_Ellipse,
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/ShapeEllipse"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.insertEntity.invoke(DrawingSimpleShapeEntity(shapeType: .ellipse, drawType: .stroke, color: strongSelf.currentColor, lineWidth: 0.15))
                            }
                        }
                    )
                ),
                .action(
                    ContextMenuActionItem(
                        text: strings.Paint_Bubble,
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/ShapeBubble"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.insertEntity.invoke(DrawingBubbleEntity(drawType: .stroke, color: strongSelf.currentColor, lineWidth: 0.15))
                            }
                        }
                    )
                ),
                .action(
                    ContextMenuActionItem(
                        text: strings.Paint_Star,
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/ShapeStar"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.insertEntity.invoke(DrawingSimpleShapeEntity(shapeType: .star, drawType: .stroke, color: strongSelf.currentColor, lineWidth: 0.15))
                            }
                        }
                    )
                ),
                .action(
                    ContextMenuActionItem(
                        text: strings.Paint_Arrow,
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/ShapeArrow"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.insertEntity.invoke(DrawingVectorEntity(type: .oneSidedArrow, color: strongSelf.currentColor, lineWidth: 0.3))
                            }
                        }
                    )
                )
            ]
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(ReferenceContentSource(sourceView: sourceView, contentArea: UIScreen.main.bounds, customPosition: CGPoint(x: 7.0, y: 3.0))), items: .single(ContextController.Items(content: .list(items))))
            self.present(contextController)
        }
        
        func updateCurrentMode(_ mode: Mode, update: Bool = true) {
            self.currentMode = mode
            if let selectedEntity = self.selectedEntity {
                if selectedEntity is DrawingStickerEntity || selectedEntity is DrawingTextEntity {
                    self.deselectEntity.invoke(Void())
                }
            }
            if update {
                self.updated(transition: .easeInOut(duration: 0.2))
            }
        }
        
        func addTextEntity() {
            let textEntity = DrawingTextEntity(text: NSAttributedString(), style: .regular, animation: .none, font: .sanFrancisco, alignment: .center, fontSize: 1.0, color: DrawingColor(color: .white))
            self.insertEntity.invoke(textEntity)
        }
        
        func presentStickerPicker() {
            self.currentMode = .sticker
            
            self.updateEntitiesPlayback.invoke(false)
            let controller = StickerPickerScreen(context: self.context, inputData: self.stickerPickerInputData.get())
            controller.completion = { [weak self] file in
                self?.updateEntitiesPlayback.invoke(true)
                
                if let file = file {
                    let stickerEntity = DrawingStickerEntity(content: .file(file))
                    self?.insertEntity.invoke(stickerEntity)
                } else {
                    self?.updateCurrentMode(.drawing)
                }
            }
            self.present(controller)
            self.updated(transition: .easeInOut(duration: 0.2))
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, updateToolState: self.updateToolState, insertEntity: self.insertEntity, deselectEntity: self.deselectEntity, updateEntitiesPlayback: self.updateEntitiesPlayback, dismissEyedropper: self.dismissEyedropper, toggleWithEraser: self.toggleWithEraser, toggleWithPreviousTool: self.toggleWithPreviousTool, present: self.present)
    }
    
    static var body: Body {
        let topGradient = Child(BlurredGradientComponent.self)
        let bottomGradient = Child(BlurredGradientComponent.self)

        let undoButton = Child(Button.self)
        
        let redoButton = Child(Button.self)
        let clearAllButton = Child(Button.self)
        
        let zoomOutButton = Child(Button.self)

        let tools = Child(ToolsComponent.self)
        let modeAndSize = Child(ModeAndSizeComponent.self)
        
        let colorButton = Child(ColorSwatchComponent.self)
        
        let textSettings = Child(TextSettingsComponent.self)
        
        let swatch1Button = Child(ColorSwatchComponent.self)
        let swatch2Button = Child(ColorSwatchComponent.self)
        let swatch3Button = Child(ColorSwatchComponent.self)
        let swatch4Button = Child(ColorSwatchComponent.self)
        let swatch5Button = Child(ColorSwatchComponent.self)
        let swatch6Button = Child(ColorSwatchComponent.self)
        let swatch7Button = Child(ColorSwatchComponent.self)
        let swatch8Button = Child(ColorSwatchComponent.self)
        
        let addButton = Child(Button.self)
        
        let flipButton = Child(Button.self)
        let fillButton = Child(Button.self)
        
        let backButton = Child(Button.self)
        let doneButton = Child(Button.self)
        
        let textSize = Child(TextSizeSliderComponent.self)
        let textCancelButton = Child(Button.self)
        let textDoneButton = Child(Button.self)
        
        let presetColors: [DrawingColor] = [
            DrawingColor(rgb: 0xff453a),
            DrawingColor(rgb: 0xff8a00),
            DrawingColor(rgb: 0xffd60a),
            DrawingColor(rgb: 0x34c759),
            DrawingColor(rgb: 0x63e6e2),
            DrawingColor(rgb: 0x0a84ff),
            DrawingColor(rgb: 0xbf5af2),
            DrawingColor(rgb: 0xffffff)
        ]
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            let controller = environment.controller
            
            let strings = environment.strings
                        
            let previewBrushSize = component.previewBrushSize
            let performAction = component.performAction
            let dismissEyedropper = component.dismissEyedropper
            
            let apply = component.apply
            let dismiss = component.dismiss
            
            let presentColorPicker = component.presentColorPicker
            let presentFastColorPicker = component.presentFastColorPicker
            let updateFastColorPickerPan = component.updateFastColorPickerPan
            let dismissFastColorPicker = component.dismissFastColorPicker
            let presentFontPicker = component.presentFontPicker
            
            component.updateState.connect { [weak state] updatedState in
                state?.updateDrawingState(updatedState)
            }
            component.updateColor.connect { [weak state] color in
                if let state = state {
                    if [.eraser, .blur].contains(state.drawingState.selectedTool) || state.selectedEntity is DrawingStickerEntity {
                        state.updateSelectedTool(.pen, update: false)
                        state.updateColor(color, animated: true)
                    } else {
                        state.updateColor(color)
                    }
                    
                }
            }
            component.updateSelectedEntity.connect { [weak state] entity in
                state?.updateSelectedEntity(entity)
            }
            component.requestPresentColorPicker.connect { [weak state] _ in
                if let state = state {
                    presentColorPicker(state.currentColor)
                }
            }
                 
            let topInset = environment.safeInsets.top + 31.0
            let bottomInset: CGFloat = environment.inputHeight > 0.0 ? environment.inputHeight : 145.0
            
            var leftEdge: CGFloat = environment.safeInsets.left
            var rightEdge: CGFloat = context.availableSize.width - environment.safeInsets.right
            var availableWidth = context.availableSize.width
            if case .regular = environment.metrics.widthClass {
                availableWidth = 430.0
                leftEdge = floorToScreenPixels((context.availableSize.width - availableWidth) / 2.0)
                rightEdge = floorToScreenPixels((context.availableSize.width - availableWidth) / 2.0) + availableWidth
            }
            
            let topGradient = topGradient.update(
                component: BlurredGradientComponent(
                    position: .top,
                    tag: topGradientTag
                ),
                availableSize: CGSize(width: context.availableSize.width, height: topInset + 15.0),
                transition: .immediate
            )
            context.add(topGradient
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topGradient.size.height / 2.0))
            )
            
            let bottomGradient = bottomGradient.update(
                component: BlurredGradientComponent(
                    position: .bottom,
                    tag: bottomGradientTag
                    
                ),
                availableSize: CGSize(width: context.availableSize.width, height: 155.0),
                transition: .immediate
            )
            context.add(bottomGradient
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomGradient.size.height / 2.0))
            )
            
            if let textEntity = state.selectedEntity as? DrawingTextEntity {
                let textSettings = textSettings.update(
                    component: TextSettingsComponent(
                        color: nil,
                        style: DrawingTextStyle(style: textEntity.style),
                        animation: DrawingTextAnimation(animation: textEntity.animation),
                        alignment: DrawingTextAlignment(alignment: textEntity.alignment),
                        font: DrawingTextFont(font: textEntity.font),
                        isEmojiKeyboard: false,
                        tag: textSettingsTag,
                        fontTag: fontTag,
                        toggleStyle: { [weak state, weak textEntity] in
                            guard let textEntity = textEntity else {
                                return
                            }
                            var nextStyle: DrawingTextEntity.Style
                            switch textEntity.style {
                            case .regular:
                                nextStyle = .filled
                            case .filled:
                                nextStyle = .semi
                            case .semi:
                                nextStyle = .stroke
                            case .stroke:
                                nextStyle = .regular
                            }
                            textEntity.style = nextStyle
                            if let entityView = textEntity.currentEntityView {
                                entityView.update()
                            }
                            state?.updated(transition: .easeInOut(duration: 0.2))
                        },
                        toggleAnimation: { [weak state, weak textEntity] in
                            guard let textEntity = textEntity else {
                                return
                            }
                            var nextAnimation: DrawingTextEntity.Animation
                            switch textEntity.animation {
                            case .none:
                                nextAnimation = .typing
                            case .typing:
                                nextAnimation = .wiggle
                            case .wiggle:
                                nextAnimation = .zoomIn
                            case .zoomIn:
                                nextAnimation = .none
                            }
                            textEntity.animation = nextAnimation
                            if let entityView = textEntity.currentEntityView {
                                entityView.update()
                            }
                            state?.updated(transition: .easeInOut(duration: 0.2))
                        },
                        toggleAlignment: { [weak state, weak textEntity] in
                            guard let textEntity = textEntity else {
                                return
                            }
                            var nextAlignment: DrawingTextEntity.Alignment
                            switch textEntity.alignment {
                            case .left:
                                nextAlignment = .center
                            case .center:
                                nextAlignment = .right
                            case .right:
                                nextAlignment = .left
                            }
                            textEntity.alignment = nextAlignment
                            if let entityView = textEntity.currentEntityView {
                                entityView.update()
                            }
                            state?.updated(transition: .easeInOut(duration: 0.2))
                        },
                        presentFontPicker: {
                            if let controller = controller() as? DrawingScreen, let buttonView = controller.node.componentHost.findTaggedView(tag: fontTag) {
                                presentFontPicker(buttonView)
                            }
                        },
                        toggleKeyboard: nil
                    ),
                    availableSize: CGSize(width: availableWidth - 84.0, height: 44.0),
                    transition: context.transition
                )
                context.add(textSettings
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - textSettings.size.height / 2.0 - 89.0))
                    .appear(Transition.Appear({ _, view, transition in
                        if let view = view as? TextSettingsComponent.View, !transition.animation.isImmediate {
                            view.animateIn()
                        }
                    }))
                    .disappear(Transition.Disappear({ view, transition, completion in
                        if let view = view as? TextSettingsComponent.View, !transition.animation.isImmediate {
                            view.animateOut(completion: completion)
                        } else {
                            completion()
                        }
                    }))
                )
            }
            

            let rightButtonPosition = rightEdge - 24.0
            var offsetX: CGFloat = leftEdge + 24.0
            let delta: CGFloat = (rightButtonPosition - offsetX) / 7.0
            
            let applySwatchColor: (DrawingColor) -> Void = { [weak state] color in
                dismissEyedropper.invoke(Void())
                if let state = state {
                    if [.eraser, .blur].contains(state.drawingState.selectedTool) || state.selectedEntity is DrawingStickerEntity {
                        state.updateSelectedTool(.pen, update: false)
                    }
                    state.updateColor(color, animated: true)
                }
            }
            
            var currentColor: DrawingColor? = state.currentColor
            if [.eraser, .blur].contains(state.drawingState.selectedTool) || state.selectedEntity is DrawingStickerEntity {
                currentColor = nil
            }
            
            var delay: Double = 0.0
            let swatch1Button = swatch1Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[0]),
                    color: presetColors[0],
                    tag: color1Tag,
                    action: {
                        applySwatchColor(presetColors[0])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch1Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch1Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
            offsetX += delta
        
            let swatch2Button = swatch2Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[1]),
                    color: presetColors[1],
                    tag: color2Tag,
                    action: {
                        applySwatchColor(presetColors[1])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch2Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch2Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0, delay: 0.025)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: 0.025)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
            offsetX += delta
            
            let swatch3Button = swatch3Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[2]),
                    color: presetColors[2],
                    tag: color3Tag,
                    action: {
                        applySwatchColor(presetColors[2])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch3Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch3Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0, delay: 0.05)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: 0.05)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
            offsetX += delta
            
            let swatch4Button = swatch4Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[3]),
                    color: presetColors[3],
                    tag: color4Tag,
                    action: {
                        applySwatchColor(presetColors[3])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch4Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch4Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0, delay: 0.075)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: 0.075)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
            offsetX += delta
            
            let swatch5Button = swatch5Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[4]),
                    color: presetColors[4],
                    tag: color5Tag,
                    action: {
                        applySwatchColor(presetColors[4])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch5Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch5Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0, delay: 0.1)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: 0.1)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
            offsetX += delta
            delay += 0.025
            
            let swatch6Button = swatch6Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[5]),
                    color: presetColors[5],
                    tag: color6Tag,
                    action: {
                        applySwatchColor(presetColors[5])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch6Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch6Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0, delay: 0.125)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: 0.125)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
            offsetX += delta
            
            let swatch7Button = swatch7Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[6]),
                    color: presetColors[6],
                    tag: color7Tag,
                    action: {
                        applySwatchColor(presetColors[6])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch7Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch7Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0, delay: 0.15)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: 0.15)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
            offsetX += delta
            
            let swatch8Button = swatch8Button.update(
                component: ColorSwatchComponent(
                    type: .pallete(currentColor == presetColors[7]),
                    color: presetColors[7],
                    tag: color8Tag,
                    action: {
                        applySwatchColor(presetColors[7])
                    }
                ),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(swatch8Button
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch7Button.size.height / 2.0 - 57.0))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0, delay: 0.175)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0, delay: 0.175)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                })
            )
         
            if state.selectedEntity is DrawingStickerEntity || state.selectedEntity is DrawingTextEntity {
            } else {
                let tools = tools.update(
                    component: ToolsComponent(
                        state: component.isVideo ? state.drawingState.forVideo() : state.drawingState,
                        isFocused: false,
                        tag: toolsTag,
                        toolPressed: { [weak state] tool in
                            dismissEyedropper.invoke(Void())
                            if let state = state {
                                state.updateSelectedTool(tool)
                            }
                        },
                        toolResized: { [weak state] _, size in
                            dismissEyedropper.invoke(Void())
                            state?.updateBrushSize(size)
                            if state?.selectedEntity == nil {
                                previewBrushSize.invoke(size)
                            }
                        },
                        sizeReleased: {
                            previewBrushSize.invoke(nil)
                        }
                    ),
                    availableSize: CGSize(width: availableWidth - environment.safeInsets.left - environment.safeInsets.right, height: 120.0),
                    transition: context.transition
                )
                context.add(tools
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - tools.size.height / 2.0 - 78.0))
                    .appear(Transition.Appear({ _, view, transition in
                        if let view = view as? ToolsComponent.View, !transition.animation.isImmediate {
                            view.animateIn(completion: {})
                        }
                    }))
                    .disappear(Transition.Disappear({ view, transition, completion in
                        if let view = view as? ToolsComponent.View, !transition.animation.isImmediate {
                            view.animateOut(completion: completion)
                        } else {
                            completion()
                        }
                    }))
                )
            }
            
            var hasTopButtons = false
            if let entity = state.selectedEntity {
                var isFilled: Bool?
                if let entity = entity as? DrawingSimpleShapeEntity {
                    isFilled = entity.drawType == .fill
                } else if let entity = entity as? DrawingBubbleEntity {
                    isFilled = entity.drawType == .fill
                } else if let _ = entity as? DrawingVectorEntity {
                    isFilled = false
                }
                
                var hasFlip = false
                if state.selectedEntity is DrawingBubbleEntity || state.selectedEntity is DrawingStickerEntity {
                    hasFlip = true
                }
                
                hasTopButtons = isFilled != nil || hasFlip
                
                if let isFilled = isFilled {
                    let fillButton = fillButton.update(
                        component: Button(
                            content: AnyComponent(
                                Image(image: state.image(isFilled ? .fill : .stroke))
                            ),
                            action: { [weak state] in
                                guard let state = state else {
                                    return
                                }
                                if let entity = state.selectedEntity as? DrawingSimpleShapeEntity {
                                    if case .fill = entity.drawType {
                                        entity.drawType = .stroke
                                    } else {
                                        entity.drawType = .fill
                                    }
                                    entity.currentEntityView?.update()
                                } else if let entity = state.selectedEntity as? DrawingBubbleEntity {
                                    if case .fill = entity.drawType {
                                        entity.drawType = .stroke
                                    } else {
                                        entity.drawType = .fill
                                    }
                                    entity.currentEntityView?.update()
                                } else if let entity = state.selectedEntity as? DrawingVectorEntity {
                                    if case .oneSidedArrow = entity.type {
                                        entity.type = .twoSidedArrow
                                    } else if case .twoSidedArrow = entity.type {
                                        entity.type = .line
                                    } else {
                                        entity.type = .oneSidedArrow
                                    }
                                    entity.currentEntityView?.update()
                                }
                                state.updated(transition: .easeInOut(duration: 0.2))
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(fillButtonTag),
                        availableSize: CGSize(width: 30.0, height: 30.0),
                        transition: .immediate
                    )
                    context.add(fillButton
                        .position(CGPoint(x: context.availableSize.width / 2.0 - (hasFlip ? 46.0 : 0.0), y: environment.safeInsets.top + 31.0))
                        .appear(.default(scale: true))
                        .disappear(.default(scale: true))
                    )
                }
                
                if hasFlip {
                    let flipButton = flipButton.update(
                        component: Button(
                            content: AnyComponent(
                                Image(image: state.image(.flip))
                            ),
                            action: { [weak state] in
                                guard let state = state else {
                                    return
                                }
                                if let entity = state.selectedEntity as? DrawingBubbleEntity {
                                    var updatedTailPosition = entity.tailPosition
                                    updatedTailPosition.x = 1.0 - updatedTailPosition.x
                                    entity.tailPosition = updatedTailPosition
                                    entity.currentEntityView?.update()
                                } else if let entity = state.selectedEntity as? DrawingStickerEntity {
                                    entity.mirrored = !entity.mirrored
                                    entity.currentEntityView?.update(animated: true)
                                }
                                state.updated(transition: .easeInOut(duration: 0.2))
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(flipButtonTag),
                        availableSize: CGSize(width: 30.0, height: 30.0),
                        transition: .immediate
                    )
                    context.add(flipButton
                        .position(CGPoint(x: context.availableSize.width / 2.0 + (isFilled != nil ? 46.0 : 0.0), y: environment.safeInsets.top + 31.0))
                        .appear(.default(scale: true))
                        .disappear(.default(scale: true))
                    )
                }
            }
            
            var sizeSliderVisible = false
            var isEditingText = false
            var sizeValue: CGFloat?
            if let textEntity = state.selectedEntity as? DrawingTextEntity, let entityView = textEntity.currentEntityView as? DrawingTextEntityView {
                sizeSliderVisible = true
                isEditingText = entityView.isEditing
                sizeValue = textEntity.fontSize
            } else {
                if state.selectedEntity == nil || !(state.selectedEntity is DrawingStickerEntity) {
                    sizeSliderVisible = true
                    if state.selectedEntity == nil {
                        sizeValue = state.drawingState.currentToolState.size
                    } else if let entity = state.selectedEntity {
                        if let entity = entity as? DrawingSimpleShapeEntity {
                            sizeSliderVisible = entity.drawType == .stroke
                        } else if let entity = entity as? DrawingBubbleEntity {
                            sizeSliderVisible = entity.drawType == .stroke
                        }
                        sizeValue = entity.lineWidth
                    }
                }
                if state.drawingViewState.canZoomOut && !hasTopButtons {
                    let zoomOutButton = zoomOutButton.update(
                        component: Button(
                            content: AnyComponent(
                                ZoomOutButtonContent(
                                    title: strings.Paint_ZoomOut,
                                    image: state.image(.zoomOut)
                                )
                            ),
                            action: {
                                dismissEyedropper.invoke(Void())
                                performAction.invoke(.zoomOut)
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(zoomOutButtonTag),
                        availableSize: CGSize(width: 120.0, height: 33.0),
                        transition: .immediate
                    )
                    context.add(zoomOutButton
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: environment.safeInsets.top + 32.0 - UIScreenPixel))
                        .appear(.default(scale: true, alpha: true))
                        .disappear(.default(scale: true, alpha: true))
                    )
                }
            }
            if let sizeValue {
                state.lastSize = sizeValue
            }
            if state.drawingViewState.isDrawing {
                sizeSliderVisible = false
            }
            
            let textSize = textSize.update(
                component: TextSizeSliderComponent(
                    value: sizeValue ?? state.lastSize,
                    tag: sizeSliderTag,
                    updated: { [weak state] size in
                        if let state = state {
                            dismissEyedropper.invoke(Void())
                            state.updateBrushSize(size)
                            if state.selectedEntity == nil {
                                previewBrushSize.invoke(size)
                            }
                        }
                    }, released: {
                        previewBrushSize.invoke(nil)
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 240.0),
                transition: context.transition
            )
            context.add(textSize
                .position(CGPoint(x: textSize.size.width / 2.0, y: topInset + (context.availableSize.height - topInset - bottomInset) / 2.0))
                .opacity(sizeSliderVisible ? 1.0 : 0.0)
            )
            
            let undoButton = undoButton.update(
                component: Button(
                    content: AnyComponent(
                        Image(image: state.image(.undo))
                    ),
                    isEnabled: state.drawingViewState.canUndo,
                    action: {
                        dismissEyedropper.invoke(Void())
                        performAction.invoke(.undo)
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(undoButtonTag),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(undoButton
                .position(CGPoint(x: environment.safeInsets.left + undoButton.size.width / 2.0 + 2.0, y: topInset))
                .scale(isEditingText ? 0.01 : 1.0)
                .opacity(isEditingText ? 0.0 : 1.0)
            )
            
            
            let redoButton = redoButton.update(
                component: Button(
                    content: AnyComponent(
                        Image(image: state.image(.redo))
                    ),
                    action: {
                        dismissEyedropper.invoke(Void())
                        performAction.invoke(.redo)
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(redoButtonTag),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: context.transition
            )
            context.add(redoButton
                .position(CGPoint(x: environment.safeInsets.left + undoButton.size.width + 2.0 + redoButton.size.width / 2.0, y: topInset))
                .scale(state.drawingViewState.canRedo && !isEditingText ? 1.0 : 0.01)
                .opacity(state.drawingViewState.canRedo && !isEditingText ? 1.0 : 0.0)
            )
            
            let clearAllButton = clearAllButton.update(
                component: Button(
                    content: AnyComponent(
                        Text(text: strings.Paint_Clear, font: Font.regular(17.0), color: .white)
                    ),
                    isEnabled: state.drawingViewState.canClear,
                    action: {
                        dismissEyedropper.invoke(Void())
                        performAction.invoke(.clear)
                    }
                ).tagged(clearAllButtonTag),
                availableSize: CGSize(width: 100.0, height: 30.0),
                transition: context.transition
            )
            context.add(clearAllButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - clearAllButton.size.width / 2.0 - 13.0, y: topInset))
                .scale(isEditingText ? 0.01 : 1.0)
                .opacity(isEditingText ? 0.0 : 1.0)
            )
            
            let textCancelButton = textCancelButton.update(
                component: Button(
                    content: AnyComponent(
                        Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: .white)
                    ),
                    action: { [weak state] in
                        if let entity = state?.selectedEntity as? DrawingTextEntity, let entityView = entity.currentEntityView as? DrawingTextEntityView {
                            entityView.endEditing(reset: true)
                        }
                    }
                ),
                availableSize: CGSize(width: 100.0, height: 30.0),
                transition: context.transition
            )
            context.add(textCancelButton
                .position(CGPoint(x: environment.safeInsets.left + textCancelButton.size.width / 2.0 + 13.0, y: topInset))
                .scale(isEditingText ? 1.0 : 0.01)
                .opacity(isEditingText ? 1.0 : 0.0)
            )
            
            let textDoneButton = textDoneButton.update(
                component: Button(
                    content: AnyComponent(
                        Text(text: environment.strings.Common_Done, font: Font.semibold(17.0), color: .white)
                    ),
                    action: { [weak state] in
                        if let entity = state?.selectedEntity as? DrawingTextEntity, let entityView = entity.currentEntityView as? DrawingTextEntityView {
                            entityView.endEditing()
                        }
                    }
                ),
                availableSize: CGSize(width: 100.0, height: 30.0),
                transition: context.transition
            )
            context.add(textDoneButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - textDoneButton.size.width / 2.0 - 13.0, y: topInset))
                .scale(isEditingText ? 1.0 : 0.01)
                .opacity(isEditingText ? 1.0 : 0.0)
            )
                        
            var color: DrawingColor?
            if let entity = state.selectedEntity, presetColors.contains(entity.color) {
                color = nil
            } else if presetColors.contains(state.currentColor) {
                color = nil
            } else if state.selectedEntity is DrawingStickerEntity {
                color = nil
            } else if [.eraser, .blur].contains(state.drawingState.selectedTool) {
                color = nil
            } else {
                color = state.currentColor
            }
                
            let colorButton = colorButton.update(
                component: ColorSwatchComponent(
                    type: .main,
                    color: color,
                    tag: colorButtonTag,
                    action: { [weak state] in
                        if let state = state {
                            presentColorPicker(state.currentColor)
                        }
                    },
                    holdAction: {
                        if let controller = controller() as? DrawingScreen, let buttonView = controller.node.componentHost.findTaggedView(tag: colorButtonTag) {
                            presentFastColorPicker(buttonView)
                        }
                    },
                    pan: { point in
                        updateFastColorPickerPan(point)
                    },
                    release: {
                        dismissFastColorPicker()
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: context.transition
            )
            context.add(colorButton
                .position(CGPoint(x: leftEdge + colorButton.size.width / 2.0 + 2.0, y: context.availableSize.height - environment.safeInsets.bottom - colorButton.size.height / 2.0 - 89.0))
                .appear(.default(scale: true))
                .disappear(.default(scale: true))
            )
      
            let modeRightInset: CGFloat = 57.0
            let addButton = addButton.update(
                component: Button(
                    content: AnyComponent(ZStack([
                        AnyComponentWithIdentity(
                            id: "background",
                            component: AnyComponent(
                                BlurredBackgroundComponent(
                                    color:  UIColor(rgb: 0x888888, alpha: 0.3),
                                    cornerRadius: 12.0
                                )
                            )
                        ),
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(
                                Image(image: state.image(.add))
                            )
                        ),
                    ])),
                    action: { [weak state] in
                        guard let controller = controller() as? DrawingScreen, let state = state else {
                            return
                        }
                        switch state.currentMode {
                        case .drawing:
                            dismissEyedropper.invoke(Void())
                            if let buttonView = controller.node.componentHost.findTaggedView(tag: addButtonTag) as? Button.View {
                                state.presentShapePicker(buttonView)
                            }
                        case .sticker:
                            dismissEyedropper.invoke(Void())
                            state.presentStickerPicker()
                        case .text:
                            dismissEyedropper.invoke(Void())
                            state.addTextEntity()
                        }
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(addButtonTag),
                availableSize: CGSize(width: 24.0, height: 24.0),
                transition: .immediate
            )
            context.add(addButton
                .position(CGPoint(x: rightEdge - addButton.size.width / 2.0 - 2.0, y: context.availableSize.height - environment.safeInsets.bottom - addButton.size.height / 2.0 - 89.0))
                .appear(.default(scale: true))
                .disappear(.default(scale: true))
                .cornerRadius(12.0)
            )
            
            let doneButton = doneButton.update(
                component: Button(
                    content: AnyComponent(
                        Image(image: state.image(.done))
                    ),
                    action: { [weak state] in
                        dismissEyedropper.invoke(Void())
                        state?.saveToolState()
                        apply.invoke(Void())
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(doneButtonTag),
                availableSize: CGSize(width: 33.0, height: 33.0),
                transition: .immediate
            )
            context.add(doneButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - doneButton.size.width / 2.0 - 3.0, y: context.availableSize.height - environment.safeInsets.bottom - doneButton.size.height / 2.0 - 2.0 - UIScreenPixel))
                .appear(Transition.Appear { _, view, transition in
                    transition.animateScale(view: view, from: 0.1, to: 1.0)
                    transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                    
                    transition.animatePosition(view: view, from: CGPoint(x: 12.0, y: 0.0), to: CGPoint(), additive: true)
                })
                .disappear(Transition.Disappear { view, transition, completion in
                    transition.setScale(view: view, scale: 0.1)
                    transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                        completion()
                    })
                    transition.animatePosition(view: view, from: CGPoint(), to: CGPoint(x: 12.0, y: 0.0), additive: true)
                })
            )
            
            let selectedIndex: Int
            switch state.currentMode {
            case .drawing:
                selectedIndex = 0
            case .sticker:
                selectedIndex = 1
            case .text:
                selectedIndex = 2
            }
                        
            var selectedSize: CGFloat = 0.0
            if let entity = state.selectedEntity {
                selectedSize = entity.lineWidth
            } else {
                selectedSize = state.drawingState.toolState(for: state.drawingState.selectedTool).size ?? 0.0
            }
                  
            let modeAndSize = modeAndSize.update(
                component: ModeAndSizeComponent(
                    values: [ strings.Paint_Draw, strings.Paint_Sticker, strings.Paint_Text],
                    sizeValue: selectedSize,
                    isEditing: false,
                    isEnabled: true,
                    rightInset: modeRightInset - 57.0,
                    tag: modeTag,
                    selectedIndex: selectedIndex,
                    selectionChanged: { [weak state] index in
                        dismissEyedropper.invoke(Void())
                        guard let state = state else {
                            return
                        }
                        switch index {
                        case 1:
                            state.presentStickerPicker()
                        case 2:
                            state.addTextEntity()
                        default:
                            state.updateCurrentMode(.drawing)
                        }
                    },
                    sizeUpdated: { [weak state] size in
                        if let state = state {
                            dismissEyedropper.invoke(Void())
                            state.updateBrushSize(size)
                            if state.selectedEntity == nil {
                                previewBrushSize.invoke(size)
                            }
                        }
                    },
                    sizeReleased: {
                        previewBrushSize.invoke(nil)
                    }
                ),
                availableSize: CGSize(width: availableWidth - 57.0 - modeRightInset, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(modeAndSize
                .position(CGPoint(x: context.availableSize.width / 2.0 - (modeRightInset - 57.0) / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - modeAndSize.size.height / 2.0 - 9.0))
            )
            
            var animatingOut = false
            if let appearanceTransition = context.transition.userData(DrawingScreenTransition.self), case .animateOut = appearanceTransition {
                animatingOut = true
            }
            
            let backButton = backButton.update(
                component: Button(
                    content: AnyComponent(
                        LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "media_backToCancel",
                                mode: .animating(loop: false),
                                range: animatingOut || component.isAvatar ? (0.5, 1.0) : (0.0, 0.5)
                            ),
                            colors: ["__allcolors__": .white],
                            size: CGSize(width: 33.0, height: 33.0)
                        )
                    ),
                    action: { [weak state] in
                        if let state = state {
                            dismissEyedropper.invoke(Void())
                            state.saveToolState()
                            dismiss.invoke(Void())
                        }
                    }
                ).minSize(CGSize(width: 44.0, height: 44.0)),
                availableSize: CGSize(width: 33.0, height: 33.0),
                transition: .immediate
            )
            context.add(backButton
                .position(CGPoint(x: environment.safeInsets.left + backButton.size.width / 2.0 + 3.0, y: context.availableSize.height - environment.safeInsets.bottom - backButton.size.height / 2.0 - 2.0 - UIScreenPixel))
            )
            
            return context.availableSize
        }
    }
}

public class DrawingScreen: ViewController, TGPhotoDrawingInterfaceController, UIDropInteractionDelegate {
    fileprivate final class Node: ViewControllerTracingNode {
        private weak var controller: DrawingScreen?
        private let context: AccountContext
        private let updateState: ActionSlot<DrawingView.NavigationState>
        private let updateColor: ActionSlot<DrawingColor>
        private let performAction: ActionSlot<DrawingView.Action>
        private let updateToolState: ActionSlot<DrawingToolState>
        private let updateSelectedEntity: ActionSlot<DrawingEntity?>
        fileprivate let insertEntity: ActionSlot<DrawingEntity>
        private let deselectEntity: ActionSlot<Void>
        private let updateEntitiesPlayback: ActionSlot<Bool>
        private let previewBrushSize: ActionSlot<CGFloat?>
        private let dismissEyedropper: ActionSlot<Void>
        
        private let requestPresentColorPicker: ActionSlot<Void>
        private let toggleWithEraser: ActionSlot<Void>
        private let toggleWithPreviousTool: ActionSlot<Void>
        
        private let apply: ActionSlot<Void>
        private let dismiss: ActionSlot<Void>
        
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        
        private let textEditAccessoryView: UIInputView
        private let textEditAccessoryHost: ComponentView<Empty>
        
        private var presentationData: PresentationData
        private let hapticFeedback = HapticFeedback()
        private var validLayout: (ContainerViewLayout, UIInterfaceOrientation?)?
        
        private var _drawingView: DrawingView?
        var drawingView: DrawingView {
            if self._drawingView == nil, let controller = self.controller {
                self._drawingView = DrawingView(size: controller.size)
                self._drawingView?.animationsEnabled = self.context.sharedContext.energyUsageSettings.fullTranslucency
                self._drawingView?.shouldBegin = { [weak self] _ in
                    if let strongSelf = self {
                        if strongSelf._entitiesView?.hasSelection == true {
                            strongSelf._entitiesView?.selectEntity(nil)
                            return false
                        }
                        return true
                    } else {
                        return false
                    }
                }
                self._drawingView?.stateUpdated = { [weak self] state in
                    if let strongSelf = self {
                        strongSelf.updateState.invoke(state)
                    }
                }
                self._drawingView?.requestedColorPicker = { [weak self] in
                    if let strongSelf = self {
                        if let _ = strongSelf.colorPickerScreen {
                            strongSelf.dismissColorPicker()
                        } else {
                            strongSelf.requestPresentColorPicker.invoke(Void())
                        }
                    }
                }
                self._drawingView?.requestedEraserToggle = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.toggleWithEraser.invoke(Void())
                    }
                }
                self._drawingView?.requestedToolsToggle = { [weak self] in
                    if let strongSelf = self {
                        strongSelf.toggleWithPreviousTool.invoke(Void())
                    }
                }
                self.performAction.connect { [weak self] action in
                    if let strongSelf = self {
                        if action == .clear {
                            let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme))
                            actionSheet.setItemGroups([
                                ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Paint_ClearConfirm, color: .destructive, action: { [weak actionSheet, weak self] in
                                        actionSheet?.dismissAnimated()
                                        
                                        self?._drawingView?.performAction(action)
                                    })
                                ]),
                                ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                ])
                            ])
                            strongSelf.controller?.present(actionSheet, in: .window(.root))
                        } else {
                            strongSelf._drawingView?.performAction(action)
                        }
                    }
                }
                self.updateToolState.connect { [weak self] state in
                    if let strongSelf = self {
                        strongSelf._drawingView?.updateToolState(state)
                    }
                }
                self.previewBrushSize.connect { [weak self] size in
                    if let strongSelf = self {
                        strongSelf._drawingView?.setBrushSizePreview(size)
                    }
                }
                self.dismissEyedropper.connect { [weak self] in
                    if let strongSelf = self {
                        strongSelf.dismissCurrentEyedropper()
                    }
                }
            }
            return self._drawingView!
        }
        
        private weak var currentMenuController: ContextMenuController?
        private var _entitiesView: DrawingEntitiesView?
        var entitiesView: DrawingEntitiesView {
            if self._entitiesView == nil, let controller = self.controller {
                if let externalEntitiesView = controller.externalEntitiesView {
                    self._entitiesView = externalEntitiesView
                } else {
                    self._entitiesView = DrawingEntitiesView(context: self.context, size: controller.size)
                    //self._entitiesView = DrawingEntitiesView(context: self.context, size: controller.originalSize)
                }
                self._drawingView?.entitiesView = self._entitiesView
                self._entitiesView?.drawingView = self._drawingView
                self._entitiesView?.entityAdded = { [weak self] entity in
                    self?._drawingView?.onEntityAdded(entity)
                }
                self._entitiesView?.entityRemoved = { [weak self] entity in
                    self?._drawingView?.onEntityRemoved(entity)
                }
                self._drawingView?.getFullImage = { [weak self] in
                    if let strongSelf = self, let controller = strongSelf.controller, let currentImage = controller.getCurrentImage() {
                        let size = controller.size.fitted(CGSize(width: 256.0, height: 256.0))
                        
                        if let imageContext = DrawingContext(size: size, scale: 1.0, opaque: true, clear: false) {
                            imageContext.withFlippedContext { c in
                                let bounds = CGRect(origin: .zero, size: size)
                                if let cgImage = currentImage.cgImage {
                                    c.draw(cgImage, in: bounds)
                                }
                                if let cgImage = strongSelf.drawingView.drawingImage?.cgImage {
                                    c.draw(cgImage, in: bounds)
                                }
                                telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
                                telegramFastBlurMore(Int32(imageContext.size.width * imageContext.scale), Int32(imageContext.size.height * imageContext.scale), Int32(imageContext.bytesPerRow), imageContext.bytes)
                            }
                            return imageContext.generateImage()
                        } else {
                            return nil
                        }
                    } else {
                        return nil
                    }
                }
                self._entitiesView?.selectionContainerView = self.selectionContainerView
                self._entitiesView?.selectionChanged = { [weak self] entity in
                    if let strongSelf = self {
                        strongSelf.updateSelectedEntity.invoke(entity)
                    }
                }
                self._entitiesView?.requestedMenuForEntityView = { [weak self] entityView, isTopmost in
                    guard let strongSelf = self else {
                        return
                    }
                    if strongSelf.currentMenuController != nil {
                        if let entityView = entityView as? DrawingTextEntityView {
                            entityView.beginEditing(accessoryView: strongSelf.textEditAccessoryView)
                        }
                        return
                    }
                    var actions: [ContextMenuAction] = []
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Paint_Delete, accessibilityLabel: strongSelf.presentationData.strings.Paint_Delete), action: { [weak self, weak entityView] in
                        if let strongSelf = self, let entityView = entityView {
                            strongSelf.entitiesView.remove(uuid: entityView.entity.uuid, animated: true)
                        }
                    }))
                    if let entityView = entityView as? DrawingTextEntityView {
                        actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Paint_Edit, accessibilityLabel: strongSelf.presentationData.strings.Paint_Edit), action: { [weak self, weak entityView] in
                            if let strongSelf = self, let entityView = entityView {
                                entityView.beginEditing(accessoryView: strongSelf.textEditAccessoryView)
                                strongSelf.entitiesView.selectEntity(entityView.entity)
                            }
                        }))
                    }
                    if !isTopmost {
                        actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Paint_MoveForward, accessibilityLabel: strongSelf.presentationData.strings.Paint_MoveForward), action: { [weak self, weak entityView] in
                            if let strongSelf = self, let entityView = entityView {
                                strongSelf.entitiesView.bringToFront(uuid: entityView.entity.uuid)
                            }
                        }))
                    }
                    actions.append(ContextMenuAction(content: .text(title: strongSelf.presentationData.strings.Paint_Duplicate, accessibilityLabel: strongSelf.presentationData.strings.Paint_Duplicate), action: { [weak self, weak entityView] in
                        if let strongSelf = self, let entityView = entityView {
                            let newEntity = strongSelf.entitiesView.duplicate(entityView.entity)
                            strongSelf.entitiesView.selectEntity(newEntity)
                        }
                    }))
                    let entityFrame = entityView.convert(entityView.selectionBounds, to: strongSelf.view).offsetBy(dx: 0.0, dy: -6.0)
                    let controller = ContextMenuController(actions: actions)
                    strongSelf.currentMenuController = controller
                    strongSelf.controller?.present(
                        controller,
                        in: .window(.root),
                        with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                            if let strongSelf = self {
                                return (strongSelf, entityFrame, strongSelf, strongSelf.bounds.insetBy(dx: 0.0, dy: 160.0))
                            } else {
                                return nil
                            }
                        })
                    )
                }
                self.insertEntity.connect { [weak self] entity in
                    if let strongSelf = self, let entitiesView = strongSelf._entitiesView {
                        entitiesView.prepareNewEntity(entity)
                        entitiesView.add(entity)
                        entitiesView.selectEntity(entity)
                        
                        if let entityView = entitiesView.getView(for: entity.uuid) {
                            if let textEntityView = entityView as? DrawingTextEntityView {
                                textEntityView.beginEditing(accessoryView: strongSelf.textEditAccessoryView)
                            } else {
                                entityView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                                entityView.layer.animateScale(from: 0.1, to: entity.scale, duration: 0.2)
                                
                                if let selectionView = entityView.selectionView {
                                    selectionView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, delay: 0.2)
                                }
                            }
                        }
                    }
                }
                self.deselectEntity.connect { [weak self] in
                    if let strongSelf = self, let entitiesView = strongSelf._entitiesView {
                        entitiesView.selectEntity(nil)
                    }
                }
                self.updateEntitiesPlayback.connect { [weak self] play in
                    if let strongSelf = self, let entitiesView = strongSelf._entitiesView {
                        if play {
                            entitiesView.play()
                        } else {
                            entitiesView.pause()
                        }
                    }
                }
            }
            return self._entitiesView!
        }
        
        private var _selectionContainerView: DrawingSelectionContainerView?
        var selectionContainerView: DrawingSelectionContainerView {
            if self._selectionContainerView == nil {
                self._selectionContainerView = DrawingSelectionContainerView(frame: .zero)
            }
            return self._selectionContainerView!
        }
        
        private var _contentWrapperView: PortalSourceView?
        var contentWrapperView: PortalSourceView {
            if self._contentWrapperView == nil {
                self._contentWrapperView = PortalSourceView()
            }
            return self._contentWrapperView!
        }
        
        init(controller: DrawingScreen) {
            self.controller = controller
            self.context = controller.context
            self.updateState = ActionSlot<DrawingView.NavigationState>()
            self.updateColor = ActionSlot<DrawingColor>()
            self.performAction = ActionSlot<DrawingView.Action>()
            self.updateToolState = ActionSlot<DrawingToolState>()
            self.updateSelectedEntity = ActionSlot<DrawingEntity?>()
            self.insertEntity = ActionSlot<DrawingEntity>()
            self.deselectEntity = ActionSlot<Void>()
            self.updateEntitiesPlayback = ActionSlot<Bool>()
            self.previewBrushSize = ActionSlot<CGFloat?>()
            self.dismissEyedropper = ActionSlot<Void>()
            self.requestPresentColorPicker = ActionSlot<Void>()
            self.toggleWithEraser = ActionSlot<Void>()
            self.toggleWithPreviousTool = ActionSlot<Void>()
            self.apply = ActionSlot<Void>()
            self.dismiss = ActionSlot<Void>()
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            self.textEditAccessoryView = UIInputView(frame: CGRect(origin: .zero, size: CGSize(width: 100.0, height: 44.0)), inputViewStyle: .keyboard)
            self.textEditAccessoryHost = ComponentView<Empty>()
            
            super.init()
            
            self.apply.connect { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.controller?.requestApply()
                }
            }
            self.dismiss.connect { [weak self] _ in
                if let strongSelf = self {
                    if strongSelf.drawingView.canUndo || strongSelf.entitiesView.hasChanges {
                        let actionSheet = ActionSheetController(presentationData: strongSelf.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme))
                        actionSheet.setItemGroups([
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.PhotoEditor_DiscardChanges, color: .accent, action: { [weak actionSheet, weak self] in
                                    actionSheet?.dismissAnimated()
                                    
                                    self?.controller?.requestDismiss()
                                })
                            ]),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.controller?.present(actionSheet, in: .window(.root))
                    } else {
                        strongSelf.controller?.requestDismiss()
                    }
                }
            }
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
            self.view.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        private var currentEyedropperView: EyedropperView?
        func presentEyedropper(retryLaterForVideo: Bool = true, dismissed: @escaping () -> Void) {
            guard let controller = self.controller else {
                return
            }
            self.entitiesView.pause()
            
            if controller.isVideo && retryLaterForVideo {
                controller.updateVideoPlayback(false)
                Queue.mainQueue().after(0.1) {
                    self.presentEyedropper(retryLaterForVideo: false, dismissed: dismissed)
                }
                return
            }
            
            guard let currentImage = controller.getCurrentImage() else {
                self.entitiesView.play()
                controller.updateVideoPlayback(true)
                return
            }
            
            let sourceImage = generateImage(controller.drawingView.imageSize, contextGenerator: { size, context in
                let bounds = CGRect(origin: .zero, size: size)
                if let cgImage = currentImage.cgImage {
                    context.draw(cgImage, in: bounds)
                }
                if let cgImage = controller.drawingView.drawingImage?.cgImage {
                    context.draw(cgImage, in: bounds)
                }
                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                controller.entitiesView.layer.render(in: context)
            }, opaque: true, scale: 1.0)
            guard let sourceImage = sourceImage else {
                return
            }
            
            let eyedropperView = EyedropperView(containerSize: controller.contentWrapperView.frame.size, drawingView: controller.drawingView, sourceImage: sourceImage)
            eyedropperView.completed = { [weak self, weak controller] color in
                if let strongSelf = self, let controller = controller {
                    strongSelf.updateColor.invoke(color)
                    controller.entitiesView.play()
                    controller.updateVideoPlayback(true)
                    dismissed()
                }
            }
            eyedropperView.dismissed = {
                controller.entitiesView.play()
                controller.updateVideoPlayback(true)
            }
            eyedropperView.frame = controller.contentWrapperView.convert(controller.contentWrapperView.bounds, to: controller.view)
            controller.view.addSubview(eyedropperView)
            self.currentEyedropperView = eyedropperView
        }
        
        func dismissCurrentEyedropper() {
            if let currentEyedropperView = self.currentEyedropperView {
                self.currentEyedropperView = nil
                currentEyedropperView.dismiss()
            }
        }
        
        private weak var colorPickerScreen: ColorPickerScreen?
        func presentColorPicker(initialColor: DrawingColor, dismissed: @escaping () -> Void = {}) {
            self.dismissCurrentEyedropper()
            self.dismissFontPicker()
            
            guard let controller = self.controller else {
                return
            }
            self.hapticFeedback.impact(.medium)
            var didDismiss = false
            let colorController = ColorPickerScreen(context: self.context, initialColor: initialColor, updated: { [weak self] color in
                self?.updateColor.invoke(color)
            }, openEyedropper: { [weak self] in
                self?.presentEyedropper(dismissed: dismissed)
            }, dismissed: {
                if !didDismiss {
                    didDismiss = true
                    dismissed()
                }
            })
            controller.present(colorController, in: .window(.root))
            self.colorPickerScreen = colorController
        }
        
        func dismissColorPicker() {
            if let colorPickerScreen = self.colorPickerScreen {
                self.colorPickerScreen = nil
                colorPickerScreen.dismiss()
            }
        }
        
        private var fastColorPickerView: ColorSpectrumPickerView?
        func presentFastColorPicker(sourceView: UIView) {
            self.dismissCurrentEyedropper()
            self.dismissFontPicker()
            
            guard self.fastColorPickerView == nil, let superview = sourceView.superview else {
                return
            }
            
            self.hapticFeedback.impact(.medium)
            
            let size = CGSize(width: min(350.0, superview.frame.width - 8.0 - 24.0), height: 296.0)
            
            let fastColorPickerView = ColorSpectrumPickerView(frame: CGRect(origin: CGPoint(x: sourceView.frame.minX + 5.0, y: sourceView.frame.maxY - size.height - 6.0), size: size))
            fastColorPickerView.selected = { [weak self] color in
                self?.updateColor.invoke(color)
            }
            let _ = fastColorPickerView.updateLayout(size: size, selectedColor: nil)
            sourceView.superview?.addSubview(fastColorPickerView)
            
            fastColorPickerView.animateIn()
            
            self.fastColorPickerView = fastColorPickerView
        }
        
        func updateFastColorPickerPan(_ point: CGPoint) {
            guard let fastColorPickerView = self.fastColorPickerView else {
                return
            }
            fastColorPickerView.handlePan(point: point)
        }
        
        func dismissFastColorPicker() {
            guard let fastColorPickerView = self.fastColorPickerView else {
                return
            }
            self.fastColorPickerView = nil
            fastColorPickerView.animateOut(completion: { [weak fastColorPickerView] in
                fastColorPickerView?.removeFromSuperview()
            })
        }
        
        private weak var currentFontPicker: ContextController?
        func presentFontPicker(sourceView: UIView) {
            guard !self.dismissFontPicker(), let validLayout = self.validLayout?.0 else {
                return
            }
            
            if let entityView = self.entitiesView.selectedEntityView as? DrawingTextEntityView {
                entityView.textChanged = { [weak self] in
                    self?.dismissFontPicker()
                }
            }
            
            let fonts: [DrawingTextFont] = [
                .sanFrancisco,
                .other("AmericanTypewriter", "Typewriter"),
                .other("AvenirNext-DemiBoldItalic", "Avenir Next"),
                .other("CourierNewPS-BoldMT", "Courier New"),
                .other("Noteworthy-Bold", "Noteworthy"),
                .other("Georgia-Bold", "Georgia"),
                .other("Papyrus", "Papyrus"),
                .other("SnellRoundhand-Bold", "Snell Roundhand")
            ]
            
            var items: [ContextMenuItem] = []
            for font in fonts {
                items.append(.action(ContextMenuActionItem(text: font.title, textFont: .custom(font: font.uiFont(size: 17.0), height: 42.0, verticalOffset: font.title == "Noteworthy" ? -6.0 : nil), icon: { _ in return nil }, animationName: nil, action: { [weak self] f in
                    f.dismissWithResult(.default)
                    guard let strongSelf = self, let entityView = strongSelf.entitiesView.selectedEntityView as? DrawingTextEntityView, let textEntity = entityView.entity as? DrawingTextEntity else {
                        return
                    }
                    textEntity.font = font.font
                    entityView.update()
                    
                    if let (layout, orientation) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout: layout, orientation: orientation, forceUpdate: true, transition: .easeInOut(duration: 0.2))
                    }
                })))
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(ReferenceContentSource(sourceView: sourceView, contentArea: CGRect(origin: .zero, size: CGSize(width: validLayout.size.width, height: validLayout.size.height - (validLayout.inputHeight ?? 0.0))), customPosition: CGPoint(x: 0.0, y: 1.0))), items: .single(ContextController.Items(content: .list(items))))
            self.controller?.present(contextController, in: .window(.root))
            self.currentFontPicker = contextController
            contextController.view.disablesInteractiveKeyboardGestureRecognizer = true
        }
        
        @discardableResult
        func dismissFontPicker() -> Bool {
            if let currentFontPicker = self.currentFontPicker {
                self.currentFontPicker = nil
                currentFontPicker.dismiss()
                return true
            }
            return false
        }
        
        func animateIn() {
            if let view = self.componentHost.findTaggedView(tag: topGradientTag) {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            if let view = self.componentHost.findTaggedView(tag: bottomGradientTag) {
                view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: undoButtonTag) {
                buttonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                buttonView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: clearAllButtonTag) {
                buttonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                buttonView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: addButtonTag) {
                buttonView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                buttonView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3)
            }
            var delay: Double = 0.0
            for tag in colorTags {
                if let view = self.componentHost.findTaggedView(tag: tag) {
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3, delay: delay)
                    view.layer.animateScale(from: 0.01, to: 1.0, duration: 0.3, delay: delay)
                    delay += 0.02
                }
            }
            if let view = self.componentHost.findTaggedView(tag: sizeSliderTag) {
                view.layer.animatePosition(from: CGPoint(x: -33.0, y: 0.0), to: CGPoint(), duration: 0.3, additive: true)
            }
        }
        
        func animateOut(completion: @escaping () -> Void) {
            if let (layout, orientation) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, orientation: orientation, animateOut: true, transition: .easeInOut(duration: 0.2))
            }
            
            if let view = self.componentHost.findTaggedView(tag: topGradientTag) {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
            if let view = self.componentHost.findTaggedView(tag: bottomGradientTag) {
                view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: undoButtonTag) {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                buttonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: redoButtonTag), buttonView.alpha > 0.0 {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                buttonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: clearAllButtonTag) {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                buttonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            }
            if let view = self.componentHost.findTaggedView(tag: colorButtonTag) as? ColorSwatchComponent.View {
                view.animateOut()
            }
            if let buttonView = self.componentHost.findTaggedView(tag: addButtonTag) {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                buttonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: flipButtonTag) {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                buttonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: fillButtonTag) {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                buttonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            }
            if let buttonView = self.componentHost.findTaggedView(tag: zoomOutButtonTag) {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                buttonView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
            }
            if let view = self.componentHost.findTaggedView(tag: sizeSliderTag) {
                view.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -33.0, y: 0.0), duration: 0.3, removeOnCompletion: false, additive: true)
            }
            
            for tag in colorTags {
                if let view = self.componentHost.findTaggedView(tag: tag) {
                    view.alpha = 0.0
                    view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.3)
                }
            }
            
            if let view = self.componentHost.findTaggedView(tag: toolsTag) as? ToolsComponent.View {
                view.animateOut(completion: {
                    completion()
                })
            } else if let view = self.componentHost.findTaggedView(tag: textSettingsTag) as? TextSettingsComponent.View {
                view.animateOut(completion: {
                    completion()
                })
            }
            
            if let view = self.componentHost.findTaggedView(tag: modeTag) as? ModeAndSizeComponent.View {
                view.animateOut()
            }
            if let buttonView = self.componentHost.findTaggedView(tag: doneButtonTag) {
                buttonView.alpha = 0.0
                buttonView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view {
                return nil
            }
            return result
        }
        
        func containerLayoutUpdated(layout: ContainerViewLayout, orientation: UIInterfaceOrientation?, forceUpdate: Bool = false, animateOut: Bool = false, transition: Transition) {
            guard let controller = self.controller else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = (layout, orientation)
                        
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(
                    top: layout.intrinsicInsets.top + layout.safeInsets.top,
                    left: layout.safeInsets.left,
                    bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom,
                    right: layout.safeInsets.right
                ),
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: orientation,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )
            
            var transition = transition
            if isFirstTime {
                transition = transition.withUserData(DrawingScreenTransition.animateIn)
            } else if animateOut {
                transition = transition.withUserData(DrawingScreenTransition.animateOut)
            }
            
            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    DrawingScreenComponent(
                        context: self.context,
                        isVideo: controller.isVideo,
                        isAvatar: controller.isAvatar,
                        present: { [weak self] c in
                            self?.controller?.present(c, in: .window(.root))
                        },
                        updateState: self.updateState,
                        updateColor: self.updateColor,
                        performAction: self.performAction,
                        updateToolState: self.updateToolState,
                        updateSelectedEntity: self.updateSelectedEntity,
                        insertEntity: self.insertEntity,
                        deselectEntity: self.deselectEntity,
                        updateEntitiesPlayback: self.updateEntitiesPlayback,
                        previewBrushSize: self.previewBrushSize,
                        dismissEyedropper: self.dismissEyedropper,
                        requestPresentColorPicker: self.requestPresentColorPicker,
                        toggleWithEraser: self.toggleWithEraser,
                        toggleWithPreviousTool: self.toggleWithPreviousTool,
                        apply: self.apply,
                        dismiss: self.dismiss,
                        presentColorPicker: { [weak self] initialColor in
                            self?.presentColorPicker(initialColor: initialColor)
                        },
                        presentFastColorPicker: { [weak self] sourceView in
                            self?.presentFastColorPicker(sourceView: sourceView)
                        },
                        updateFastColorPickerPan: { [weak self] point in
                            self?.updateFastColorPickerPan(point)
                        },
                        dismissFastColorPicker: { [weak self] in
                            self?.dismissFastColorPicker()
                        },
                        presentFontPicker: { [weak self] sourceView in
                            self?.presentFontPicker(sourceView: sourceView)
                        }
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: forceUpdate || animateOut,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.view.insertSubview(componentView, at: 0)
                    componentView.clipsToBounds = true
                }
                
                let componentFrame = CGRect(origin: .zero, size: componentSize)
                transition.setFrame(view: componentView, frame: CGRect(origin: componentFrame.origin, size: CGSize(width: componentFrame.width, height: componentFrame.height)))
                
                if isFirstTime {
                    self.animateIn()
                }
            }
            
            if let entityView = self.entitiesView.selectedEntityView as? DrawingTextEntityView, let textEntity = entityView.entity as? DrawingTextEntity {
                var isFirstTime = true
                if let componentView = self.textEditAccessoryHost.view, componentView.superview != nil {
                    isFirstTime = false
                }
                UIView.performWithoutAnimation {
                    let accessorySize = self.textEditAccessoryHost.update(
                        transition: isFirstTime ? .immediate : .easeInOut(duration: 0.2),
                        component: AnyComponent(
                            TextSettingsComponent(
                                color: textEntity.color,
                                style: DrawingTextStyle(style: textEntity.style),
                                animation: DrawingTextAnimation(animation: textEntity.animation),
                                alignment: DrawingTextAlignment(alignment: textEntity.alignment),
                                font: DrawingTextFont(font: textEntity.font),
                                isEmojiKeyboard: entityView.textView.inputView != nil,
                                tag: nil,
                                fontTag: fontTag,
                                presentColorPicker: { [weak self] in
                                    guard let strongSelf = self, let entityView = strongSelf.entitiesView.selectedEntityView as? DrawingTextEntityView, let textEntity = entityView.entity as? DrawingTextEntity else {
                                        return
                                    }
                                    entityView.suspendEditing()
                                    self?.presentColorPicker(initialColor: textEntity.color, dismissed: {
                                        entityView.resumeEditing()
                                    })
                                },
                                presentFastColorPicker: { [weak self] buttonTag in
                                    if let buttonView = self?.textEditAccessoryHost.findTaggedView(tag: buttonTag) {
                                        self?.presentFastColorPicker(sourceView: buttonView)
                                    }
                                },
                                updateFastColorPickerPan: { [weak self] point in
                                    self?.updateFastColorPickerPan(point)
                                },
                                dismissFastColorPicker: { [weak self] in
                                    self?.dismissFastColorPicker()
                                },
                                toggleStyle: { [weak self] in
                                    self?.dismissFontPicker()
                                    guard let strongSelf = self, let entityView = strongSelf.entitiesView.selectedEntityView as? DrawingTextEntityView, let textEntity = entityView.entity as? DrawingTextEntity else {
                                        return
                                    }
                                    var nextStyle: DrawingTextEntity.Style
                                    switch textEntity.style {
                                    case .regular:
                                        nextStyle = .filled
                                    case .filled:
                                        nextStyle = .semi
                                    case .semi:
                                        nextStyle = .stroke
                                    case .stroke:
                                        nextStyle = .regular
                                    }
                                    textEntity.style = nextStyle
                                    entityView.update()
                                    
                                    if let (layout, orientation) = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout: layout, orientation: orientation, transition: .immediate)
                                    }
                                },
                                toggleAnimation: { [weak self] in
                                    self?.dismissFontPicker()
                                    guard let strongSelf = self, let entityView = strongSelf.entitiesView.selectedEntityView as? DrawingTextEntityView, let textEntity = entityView.entity as? DrawingTextEntity else {
                                        return
                                    }
                                    var nextAnimation: DrawingTextEntity.Animation
                                    switch textEntity.animation {
                                    case .none:
                                        nextAnimation = .typing
                                    case .typing:
                                        nextAnimation = .wiggle
                                    case .wiggle:
                                        nextAnimation = .zoomIn
                                    case .zoomIn:
                                        nextAnimation = .none
                                    }
                                    textEntity.animation = nextAnimation
                                    entityView.update()
                                    
                                    if let (layout, orientation) = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout: layout, orientation: orientation, transition: .immediate)
                                    }
                                },
                                toggleAlignment: { [weak self] in
                                    self?.dismissFontPicker()
                                    guard let strongSelf = self, let entityView = strongSelf.entitiesView.selectedEntityView as? DrawingTextEntityView, let textEntity = entityView.entity as? DrawingTextEntity else {
                                        return
                                    }
                                    var nextAlignment: DrawingTextEntity.Alignment
                                    switch textEntity.alignment {
                                    case .left:
                                        nextAlignment = .center
                                    case .center:
                                        nextAlignment = .right
                                    case .right:
                                        nextAlignment = .left
                                    }
                                    textEntity.alignment = nextAlignment
                                    entityView.update()
                                    
                                    if let (layout, orientation) = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout: layout, orientation: orientation, transition: .immediate)
                                    }
                                },
                                presentFontPicker: { [weak self] in
                                    if let buttonView = self?.textEditAccessoryHost.findTaggedView(tag: fontTag) {
                                        self?.presentFontPicker(sourceView: buttonView)
                                    }
                                },
                                toggleKeyboard: { [weak self] in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.dismissFontPicker()
                                    strongSelf.toggleInputMode()
                                }
                            )
                        ),
                        environment: {},
                        forceUpdate: true,
                        containerSize: CGSize(width: layout.size.width, height: 44.0)
                    )
                    if let componentView = self.textEditAccessoryHost.view {
                        if componentView.superview == nil {
                            self.textEditAccessoryView.addSubview(componentView)
                        }
                        
                        self.textEditAccessoryView.frame = CGRect(origin: .zero, size: accessorySize)
                        componentView.frame = CGRect(origin: .zero, size: accessorySize)
                    }
                }
            }
        }
        
        private func toggleInputMode() {
            guard let entityView = self.entitiesView.selectedEntityView as? DrawingTextEntityView else {
                return
            }
            
            let textView = entityView.textView
            var shouldHaveInputView = false
            if textView.isFirstResponder {
                if textView.inputView == nil {
                    shouldHaveInputView = true
                }
            } else {
                shouldHaveInputView = true
            }
            
            if shouldHaveInputView {
                let inputView = EntityInputView(
                    context: self.context,
                    isDark: true,
                    areCustomEmojiEnabled: true,
                    hideBackground: true,
                    forceHasPremium: true
                )
                inputView.insertText = { [weak entityView] text in
                    entityView?.insertText(text)
                }
                inputView.deleteBackwards = { [weak textView] in
                    textView?.deleteBackward()
                }
                inputView.switchToKeyboard = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.toggleInputMode()
                }
                textView.inputView = inputView
            } else {
                textView.inputView = nil
            }
            
            if textView.isFirstResponder {
                textView.reloadInputViews()
            } else {
                textView.becomeFirstResponder()
            }
            
            if let (layout, orientation) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, orientation: orientation, animateOut: false, transition: .immediate)
            }
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let size: CGSize
    private let originalSize: CGSize
    private let isVideo: Bool
    private let isAvatar: Bool
    private let externalEntitiesView: DrawingEntitiesView?
    
    public var requestDismiss: () -> Void = {}
    public var requestApply: () -> Void = {}
    public var getCurrentImage: () -> UIImage? = { return nil }
    public var updateVideoPlayback: (Bool) -> Void = { _ in }
    
    public init(context: AccountContext, size: CGSize, originalSize: CGSize, isVideo: Bool, isAvatar: Bool, entitiesView: (UIView & TGPhotoDrawingEntitiesView)?) {
        self.context = context
        self.size = size
        self.originalSize = originalSize
        self.isVideo = isVideo
        self.isAvatar = isAvatar
        
        if let entitiesView = entitiesView as? DrawingEntitiesView {
            self.externalEntitiesView = entitiesView
        } else {
            self.externalEntitiesView = nil
        }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Hide
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    }
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    public var drawingView: DrawingView {
        return self.node.drawingView
    }
    
    public var entitiesView: DrawingEntitiesView {
        return self.node.entitiesView
    }
    
    public var selectionContainerView: DrawingSelectionContainerView {
        return self.node.selectionContainerView
    }
    
    public var contentWrapperView: PortalSourceView {
        return self.node.contentWrapperView
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
        
        let dropInteraction = UIDropInteraction(delegate: self)
        self.drawingView.addInteraction(dropInteraction)
    }
    
    public func generateResultData() -> TGPaintingData? {
        if self.drawingView.isEmpty && self.entitiesView.entities.isEmpty {
            return nil
        }
        
        let paintingImage = generateImage(self.drawingView.imageSize, contextGenerator: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            if let cgImage = self.drawingView.drawingImage?.cgImage {
                context.draw(cgImage, in: bounds)
            }
        }, opaque: false, scale: 1.0)
        
        var hasAnimatedEntities = false
    
        for entity in self.entitiesView.entities {
            if entity.isAnimated {
                hasAnimatedEntities = true
                break
            }
        }
            
        let finalImage = generateImage(self.drawingView.imageSize, contextGenerator: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            if let cgImage = paintingImage?.cgImage {
                context.draw(cgImage, in: bounds)
            }
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            
            //hide animated
            self.entitiesView.layer.render(in: context)
        }, opaque: false, scale: 1.0)
        
        if #available(iOS 16.0, *) {
            let path = NSTemporaryDirectory() + "img.jpg"
            try? finalImage?.jpegData(compressionQuality: 0.9)?.write(to: URL(filePath: path))
        }
        
        var image = paintingImage
        var stillImage: UIImage?
        if hasAnimatedEntities {
            stillImage = finalImage
        } else {
            image = finalImage
        }
        
        let drawingData = self.drawingView.drawingData
        let entitiesData = self.entitiesView.entitiesData
        
        var stickers: [Any] = []
        for entity in self.entitiesView.entities {
            if let sticker = entity as? DrawingStickerEntity, case let .file(file) = sticker.content {
                let coder = PostboxEncoder()
                coder.encodeRootObject(file)
                stickers.append(coder.makeData())
            } else if let text = entity as? DrawingTextEntity, let subEntities = text.renderSubEntities {
                for sticker in subEntities {
                    if case let .file(file) = sticker.content {
                        let coder = PostboxEncoder()
                        coder.encodeRootObject(file)
                        stickers.append(coder.makeData())
                    }
                }
            }
        }
        
        return TGPaintingData(drawing: drawingData, entitiesData: entitiesData, image: image, stillImage: stillImage, hasAnimation: hasAnimatedEntities, stickers: stickers)
    }
        
    public func animateOut(_ completion: @escaping (() -> Void)) {
        self.selectionContainerView.alpha = 0.0
        
        self.node.animateOut(completion: completion)
    }
    
    private var orientation: UIInterfaceOrientation?
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, orientation: self.orientation, transition: Transition(transition))
    }
    
    public func adapterContainerLayoutUpdatedSize(_ size: CGSize, intrinsicInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, statusBarHeight: CGFloat, inputHeight: CGFloat, orientation: UIInterfaceOrientation, isRegular: Bool, animated: Bool) {
        let layout = ContainerViewLayout(
            size: size,
            metrics: LayoutMetrics(widthClass: isRegular ? .regular : .compact, heightClass: isRegular ? .regular : .compact),
            deviceMetrics: DeviceMetrics(screenSize: size, scale: UIScreen.main.scale, statusBarHeight: statusBarHeight, onScreenNavigationHeight: nil),
            intrinsicInsets: intrinsicInsets,
            safeInsets: safeInsets,
            additionalInsets: .zero,
            statusBarHeight: statusBarHeight,
            inputHeight: inputHeight,
            inputHeightIsInteractivellyChanging: false,
            inVoiceOver: false
        )
        self.orientation = orientation
        self.containerLayoutUpdated(layout, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        return session.hasItemsConforming(toTypeIdentifiers: [kUTTypeImage as String])
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        //self.chatDisplayNode.updateDropInteraction(isActive: true)
        
        let operation: UIDropOperation
        operation = .copy
        return UIDropProposal(operation: operation)
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] imageItems in
            guard let strongSelf = self else {
                return
            }
            let images = imageItems as! [UIImage]
            
            //strongSelf.chatDisplayNode.updateDropInteraction(isActive: false)
            if images.count == 1, let image = images.first, max(image.size.width, image.size.height) > 1.0 {
                let entity = DrawingStickerEntity(content: .image(image))
                strongSelf.node.insertEntity.invoke(entity)
            }
        }
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        //self.chatDisplayNode.updateDropInteraction(isActive: false)
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        //self.chatDisplayNode.updateDropInteraction(isActive: false)
    }
}
