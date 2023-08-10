import Foundation
import UIKit
import CoreServices
import AsyncDisplayKit
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
import MultilineTextComponent
import ContextUI
import ChatEntityKeyboardInputNode
import EntityKeyboard
import TelegramUIPreferences
import FastBlur
import MediaEditor

public struct DrawingResultData {
    public let data: Data?
    public let drawingImage: UIImage?
    public let entities: [CodableDrawingEntity]
}

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
private let cancelButtonTag = GenericComponentViewTag()
private let doneButtonTag = GenericComponentViewTag()

private final class DrawingScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let sourceHint: DrawingScreen.SourceHint?
    let existingStickerPickerInputData: Promise<StickerPickerInputData>?
    let isVideo: Bool
    let isAvatar: Bool
    let isInteractingWithEntities: Bool
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
    let insertSticker: ActionSlot<Void>
    let insertText: ActionSlot<Void>
    let updateEntityView: ActionSlot<(UUID, Bool)>
    let endEditingTextEntityView: ActionSlot<(UUID, Bool)>
    let entityViewForEntity: (DrawingEntity) -> DrawingEntityView?
    let presentGallery: (() -> Void)?
    let apply: ActionSlot<Void>
    let dismiss: ActionSlot<Void>
    
    let presentColorPicker: (DrawingColor) -> Void
    let presentFastColorPicker: (UIView) -> Void
    let updateFastColorPickerPan: (CGPoint) -> Void
    let dismissFastColorPicker: () -> Void
    let presentFontPicker: (UIView) -> Void
    
    init(
        context: AccountContext,
        sourceHint: DrawingScreen.SourceHint?,
        existingStickerPickerInputData: Promise<StickerPickerInputData>?,
        isVideo: Bool,
        isAvatar: Bool,
        isInteractingWithEntities: Bool,
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
        insertSticker: ActionSlot<Void>,
        insertText: ActionSlot<Void>,
        updateEntityView: ActionSlot<(UUID, Bool)>,
        endEditingTextEntityView: ActionSlot<(UUID, Bool)>,
        entityViewForEntity: @escaping (DrawingEntity) -> DrawingEntityView?,
        presentGallery: (() -> Void)?,
        apply: ActionSlot<Void>,
        dismiss: ActionSlot<Void>,
        presentColorPicker: @escaping (DrawingColor) -> Void,
        presentFastColorPicker: @escaping (UIView) -> Void,
        updateFastColorPickerPan: @escaping (CGPoint) -> Void,
        dismissFastColorPicker: @escaping () -> Void,
        presentFontPicker: @escaping (UIView) -> Void
    ) {
        self.context = context
        self.sourceHint = sourceHint
        self.existingStickerPickerInputData = existingStickerPickerInputData
        self.isVideo = isVideo
        self.isAvatar = isAvatar
        self.isInteractingWithEntities = isInteractingWithEntities
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
        self.insertSticker = insertSticker
        self.insertText = insertText
        self.updateEntityView = updateEntityView
        self.endEditingTextEntityView = endEditingTextEntityView
        self.entityViewForEntity = entityViewForEntity
        self.presentGallery = presentGallery
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
        if lhs.isVideo != rhs.isVideo {
            return false
        }
        if lhs.isAvatar != rhs.isAvatar {
            return false
        }
        if lhs.isInteractingWithEntities != rhs.isInteractingWithEntities {
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
        private let insertSticker: ActionSlot<Void>
        private let insertText: ActionSlot<Void>
        fileprivate var presentGallery: (() -> Void)?
        private let updateEntityView: ActionSlot<(UUID, Bool)>
        private let endEditingTextEntityView: ActionSlot<(UUID, Bool)>
        private let entityViewForEntity: (DrawingEntity) -> DrawingEntityView?
        private let present: (ViewController) -> Void
        
        var currentMode: Mode
        var drawingState: DrawingState
        var drawingViewState: DrawingView.NavigationState
        var currentColor: DrawingColor
        var selectedEntity: DrawingEntity?
        
        var lastSize: CGFloat = 0.5
        
        private let stickerPickerInputData: Promise<StickerPickerInputData>
            
        init(
            context: AccountContext,
            existingStickerPickerInputData: Promise<StickerPickerInputData>?,
            updateToolState: ActionSlot<DrawingToolState>,
            insertEntity: ActionSlot<DrawingEntity>,
            deselectEntity: ActionSlot<Void>,
            updateEntitiesPlayback: ActionSlot<Bool>,
            dismissEyedropper: ActionSlot<Void>,
            toggleWithEraser: ActionSlot<Void>,
            toggleWithPreviousTool: ActionSlot<Void>,
            insertSticker: ActionSlot<Void>,
            insertText: ActionSlot<Void>,
            presentGallery: (() -> Void)?,
            updateEntityView: ActionSlot<(UUID, Bool)>,
            endEditingTextEntityView: ActionSlot<(UUID, Bool)>,
            entityViewForEntity: @escaping (DrawingEntity) -> DrawingEntityView?,
            present: @escaping (ViewController) -> Void)
        {
            self.context = context
            self.updateToolState = updateToolState
            self.insertEntity = insertEntity
            self.deselectEntity = deselectEntity
            self.updateEntitiesPlayback = updateEntitiesPlayback
            self.dismissEyedropper = dismissEyedropper
            self.toggleWithEraser = toggleWithEraser
            self.toggleWithPreviousTool = toggleWithPreviousTool
            self.insertSticker = insertSticker
            self.insertText = insertText
            self.presentGallery = presentGallery
            self.updateEntityView = updateEntityView
            self.endEditingTextEntityView = endEditingTextEntityView
            self.entityViewForEntity = entityViewForEntity
            self.present = present
            
            self.currentMode = .drawing
            self.drawingState = .initial
            self.drawingViewState = DrawingView.NavigationState(canUndo: false, canRedo: false, canClear: false, canZoomOut: false, isDrawing: false)
            self.currentColor = self.drawingState.tools.first?.color ?? DrawingColor(rgb: 0xffffff)
            
            self.updateToolState.invoke(self.drawingState.currentToolState)
                        
            if let existingStickerPickerInputData {
                self.stickerPickerInputData = existingStickerPickerInputData
            } else {
                self.stickerPickerInputData = Promise<StickerPickerInputData>()
                
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
                        hasSearch: true,
                        forceHasPremium: true
                    )
                    
                    let stickerItems = EmojiPagerContentComponent.stickerInputData(
                        context: context,
                        animationCache: context.animationCache,
                        animationRenderer: context.animationRenderer,
                        stickerNamespaces: [Namespaces.ItemCollection.CloudStickerPacks],
                        stickerOrderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers, Namespaces.OrderedItemList.CloudRecentStickers, Namespaces.OrderedItemList.CloudAllPremiumStickers],
                        chatPeerId: context.account.peerId,
                        hasSearch: true,
                        hasTrending: true,
                        forceHasPremium: true
                    )
                                        
                    let signal = combineLatest(queue: .mainQueue(),
                                               emojiItems,
                                               stickerItems
                    ) |> map { emoji, stickers -> StickerPickerInputData in
                        return StickerPickerInputData(emoji: emoji, stickers: stickers, gifs: nil)
                    }
                    
                    stickerPickerInputData.set(signal)
                })
            }
            
            super.init()
            
            self.loadToolState()
            
            self.toggleWithEraser.connect { [weak self] _ in
                if let self {
                    if self.drawingState.selectedTool == .eraser {
                        self.updateSelectedTool(self.nextToEraserTool)
                    } else {
                        self.updateSelectedTool(.eraser)
                    }
                }
            }
            
            self.toggleWithPreviousTool.connect { [weak self] _ in
                if let self {
                    self.updateSelectedTool(self.previousTool)
                }
            }
            
            self.insertText.connect { [weak self] _ in
                if let self {
                    self.addTextEntity()
                }
            }
            
            self.insertSticker.connect { [weak self] _ in
                if let self {
                    self.presentStickerPicker()
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
                self.updateEntityView.invoke((selectedEntity.uuid, false))
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
                self.updateEntityView.invoke((selectedEntity.uuid, false))
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
            let textEntity = DrawingTextEntity(text: NSAttributedString(), style: .filled, animation: .none, font: .sanFrancisco, alignment: .center, fontSize: 1.0, color: DrawingColor(color: .white))
            self.insertEntity.invoke(textEntity)
        }
        
        func presentStickerPicker() {
            self.currentMode = .sticker
            
            self.updateEntitiesPlayback.invoke(false)
            let controller = StickerPickerScreen(context: self.context, inputData: self.stickerPickerInputData.get())
            if let presentGallery = self.presentGallery {
                controller.presentGallery = presentGallery
            }
            controller.completion = { [weak self] content in
                self?.updateEntitiesPlayback.invoke(true)
                
                if let content {
                    let stickerEntity = DrawingStickerEntity(content: content)
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
        return State(
            context: self.context,
            existingStickerPickerInputData: self.existingStickerPickerInputData,
            updateToolState: self.updateToolState,
            insertEntity: self.insertEntity,
            deselectEntity: self.deselectEntity,
            updateEntitiesPlayback: self.updateEntitiesPlayback,
            dismissEyedropper: self.dismissEyedropper,
            toggleWithEraser: self.toggleWithEraser,
            toggleWithPreviousTool: self.toggleWithPreviousTool,
            insertSticker: self.insertSticker,
            insertText: self.insertText,
            presentGallery: self.presentGallery,
            updateEntityView: self.updateEntityView,
            endEditingTextEntityView: self.endEditingTextEntityView,
            entityViewForEntity: self.entityViewForEntity,
            present: self.present
        )
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
            
            let updateEntityView = component.updateEntityView
            let endEditingTextEntityView = component.endEditingTextEntityView
            
            state.presentGallery = component.presentGallery
            
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
            
            var controlsAreVisible = true
            if state.drawingViewState.isDrawing || component.isInteractingWithEntities {
                controlsAreVisible = false
            }
                             
            var controlsBottomInset: CGFloat = 0.0
            let previewSize: CGSize
            var previewTopInset: CGFloat = environment.statusBarHeight + 5.0
            if case .regular = environment.metrics.widthClass {
                let previewHeight = context.availableSize.height - previewTopInset - 75.0
                previewSize = CGSize(width: floorToScreenPixels(previewHeight / 1.77778), height: previewHeight)
            } else {
                previewSize = CGSize(width: context.availableSize.width, height: floorToScreenPixels(context.availableSize.width * 1.77778))
                if context.availableSize.height < previewSize.height + 30.0 {
                    previewTopInset = 0.0
                    controlsBottomInset = -50.0
                }
            }
            let previewBottomInset = context.availableSize.height - previewSize.height - previewTopInset
            
            var topInset = environment.safeInsets.top + 31.0
            if component.sourceHint == .storyEditor {
                topInset = previewTopInset + 31.0
            }

            let bottomInset: CGFloat = environment.inputHeight > 0.0 ? environment.inputHeight : 145.0
            
            var leftEdge: CGFloat = environment.safeInsets.left
            var rightEdge: CGFloat = context.availableSize.width - environment.safeInsets.right
            var availableWidth = context.availableSize.width
            if case .regular = environment.metrics.widthClass {
                availableWidth = 430.0
                leftEdge = floorToScreenPixels((context.availableSize.width - availableWidth) / 2.0)
                rightEdge = floorToScreenPixels((context.availableSize.width - availableWidth) / 2.0) + availableWidth
            }
            
            if component.sourceHint != .storyEditor {
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
            }
            
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
            )
            
            var additionalBottomInset: CGFloat = 0.0
            if component.sourceHint == .storyEditor {
                additionalBottomInset = max(0.0, previewBottomInset - environment.safeInsets.bottom - 49.0)
            }
            
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
                                nextStyle = .regular
                            case .stroke:
                                nextStyle = .regular
                            }
                            textEntity.style = nextStyle
                            updateEntityView.invoke((textEntity.uuid, false))
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
                            updateEntityView.invoke((textEntity.uuid, false))
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
                            updateEntityView.invoke((textEntity.uuid, false))
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
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - textSettings.size.height / 2.0 - 89.0 - additionalBottomInset))
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
                    .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch1Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch2Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch3Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch4Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch5Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch6Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch7Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: offsetX, y: context.availableSize.height - environment.safeInsets.bottom - swatch7Button.size.height / 2.0 - 57.0 - additionalBottomInset))
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
            )
         
            if state.selectedEntity is DrawingStickerEntity || state.selectedEntity is DrawingTextEntity {
            } else {
                let tools = tools.update(
                    component: ToolsComponent(
                        state: component.isVideo || component.sourceHint == .storyEditor ? state.drawingState.forVideo() : state.drawingState,
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
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - tools.size.height / 2.0 - 78.0 - additionalBottomInset))
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
                    .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                                    updateEntityView.invoke((entity.uuid, false))
                                } else if let entity = state.selectedEntity as? DrawingBubbleEntity {
                                    if case .fill = entity.drawType {
                                        entity.drawType = .stroke
                                    } else {
                                        entity.drawType = .fill
                                    }
                                    updateEntityView.invoke((entity.uuid, false))
                                } else if let entity = state.selectedEntity as? DrawingVectorEntity {
                                    if case .oneSidedArrow = entity.type {
                                        entity.type = .twoSidedArrow
                                    } else if case .twoSidedArrow = entity.type {
                                        entity.type = .line
                                    } else {
                                        entity.type = .oneSidedArrow
                                    }
                                    updateEntityView.invoke((entity.uuid, false))
                                }
                                state.updated(transition: .easeInOut(duration: 0.2))
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(fillButtonTag),
                        availableSize: CGSize(width: 30.0, height: 30.0),
                        transition: .immediate
                    )
                    context.add(fillButton
                        .position(CGPoint(x: context.availableSize.width / 2.0 - (hasFlip ? 46.0 : 0.0), y: topInset))
                        .appear(.default(scale: true))
                        .disappear(.default(scale: true))
                        .opacity(!controlsAreVisible ? 0.0 : 1.0)
                        .shadow(component.sourceHint == .storyEditor ? Shadow(color: UIColor(rgb: 0x000000, alpha: 0.35), radius: 2.0, offset: .zero) : nil)
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
                                    updateEntityView.invoke((entity.uuid, false))
                                } else if let entity = state.selectedEntity as? DrawingStickerEntity {
                                    entity.mirrored = !entity.mirrored
                                    updateEntityView.invoke((entity.uuid, true))
                                }
                                state.updated(transition: .easeInOut(duration: 0.2))
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(flipButtonTag),
                        availableSize: CGSize(width: 30.0, height: 30.0),
                        transition: .immediate
                    )
                    context.add(flipButton
                        .position(CGPoint(x: context.availableSize.width / 2.0 + (isFilled != nil ? 46.0 : 0.0), y: topInset))
                        .appear(.default(scale: true))
                        .disappear(.default(scale: true))
                        .opacity(!controlsAreVisible ? 0.0 : 1.0)
                        .shadow(component.sourceHint == .storyEditor ? Shadow(color: UIColor(rgb: 0x000000, alpha: 0.35), radius: 2.0, offset: .zero) : nil)
                    )
                }
            }
            
            var sizeSliderVisible = false
            var isEditingText = false
            var sizeValue: CGFloat?
            if let textEntity = state.selectedEntity as? DrawingTextEntity, let entityView = component.entityViewForEntity(textEntity) as? DrawingTextEntityView {
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
                .opacity(sizeSliderVisible && controlsAreVisible ? 1.0 : 0.0)
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
                .opacity(isEditingText || !controlsAreVisible ? 0.0 : 1.0)
                .shadow(component.sourceHint == .storyEditor ? Shadow(color: UIColor(rgb: 0x000000, alpha: 0.35), radius: 2.0, offset: .zero) : nil)
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
                .opacity(state.drawingViewState.canRedo && !isEditingText && controlsAreVisible ? 1.0 : 0.0)
                .shadow(component.sourceHint == .storyEditor ? Shadow(color: UIColor(rgb: 0x000000, alpha: 0.35), radius: 2.0, offset: .zero) : nil)
            )
            
            let clearAllButton = clearAllButton.update(
                component: Button(
                    content: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: strings.Paint_Clear, font: Font.regular(17.0), textColor: .white)),
                            textShadowColor: component.sourceHint == .storyEditor ? UIColor(rgb: 0x000000, alpha: 0.35) : nil,
                            textShadowBlur: 2.0
                        )
                    ),
                    isEnabled: state.drawingViewState.canClear,
                    action: {
                        dismissEyedropper.invoke(Void())
                        performAction.invoke(.clear)
                    }
                ).tagged(clearAllButtonTag),
                availableSize: CGSize(width: 180.0, height: 30.0),
                transition: context.transition
            )
            context.add(clearAllButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - clearAllButton.size.width / 2.0 - 13.0, y: topInset))
                .scale(isEditingText ? 0.01 : 1.0)
                .opacity(isEditingText || !controlsAreVisible ? 0.0 : 1.0)
            )
            
            let textCancelButton = textCancelButton.update(
                component: Button(
                    content: AnyComponent(
                        Text(text: environment.strings.Common_Cancel, font: Font.regular(17.0), color: .white)
                    ),
                    action: { [weak state] in
                        if let entity = state?.selectedEntity as? DrawingTextEntity {
                            endEditingTextEntityView.invoke((entity.uuid, true))
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
                        if let entity = state?.selectedEntity as? DrawingTextEntity {
                            endEditingTextEntityView.invoke((entity.uuid, false))
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
                .position(CGPoint(x: leftEdge + colorButton.size.width / 2.0 + 2.0, y: context.availableSize.height - environment.safeInsets.bottom - colorButton.size.height / 2.0 - 89.0 - additionalBottomInset))
                .appear(.default(scale: true))
                .disappear(.default(scale: true))
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
                .position(CGPoint(x: rightEdge - addButton.size.width / 2.0 - 2.0, y: context.availableSize.height - environment.safeInsets.bottom - addButton.size.height / 2.0 - 89.0 - additionalBottomInset))
                .appear(.default(scale: true))
                .disappear(.default(scale: true))
                .cornerRadius(12.0)
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
            
            var doneButtonPosition = CGPoint(x: context.availableSize.width - environment.safeInsets.right - doneButton.size.width / 2.0 - 3.0, y: context.availableSize.height - environment.safeInsets.bottom - doneButton.size.height / 2.0 - 2.0 - UIScreenPixel)
            if component.sourceHint == .storyEditor {
                doneButtonPosition.x = doneButtonPosition.x - 2.0
                if case .regular = environment.metrics.widthClass {
                    doneButtonPosition.x -= 20.0
                }
                doneButtonPosition.y = floorToScreenPixels(context.availableSize.height - previewBottomInset + 3.0 + doneButton.size.height / 2.0) + controlsBottomInset
            }
            context.add(doneButton
                .position(doneButtonPosition)
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
                .opacity(controlsAreVisible ? 1.0 : 0.0)
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
            var modeAndSizePosition = CGPoint(x: context.availableSize.width / 2.0 - (modeRightInset - 57.0) / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - modeAndSize.size.height / 2.0 - 9.0)
            if component.sourceHint == .storyEditor {
                modeAndSizePosition.y = floorToScreenPixels(context.availableSize.height - previewBottomInset + 8.0 + modeAndSize.size.height / 2.0) + controlsBottomInset
            }
            context.add(modeAndSize
                .position(modeAndSizePosition)
                .opacity(controlsAreVisible ? 1.0 : 0.0)
            )
            
            var animatingOut = false
            if let appearanceTransition = context.transition.userData(DrawingScreenTransition.self), case .animateOut = appearanceTransition {
                animatingOut = true
            }
            
            if animatingOut && component.sourceHint == .storyEditor {
                
            } else {
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
                    ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(cancelButtonTag),
                    availableSize: CGSize(width: 33.0, height: 33.0),
                    transition: .immediate
                )
                var backButtonPosition = CGPoint(x: environment.safeInsets.left + backButton.size.width / 2.0 + 3.0, y: context.availableSize.height - environment.safeInsets.bottom - backButton.size.height / 2.0 - 2.0 - UIScreenPixel)
                if component.sourceHint == .storyEditor {
                    backButtonPosition.x = backButtonPosition.x + 2.0
                    if case .regular = environment.metrics.widthClass {
                        backButtonPosition.x += 20.0
                    }
                    backButtonPosition.y = floorToScreenPixels(context.availableSize.height - previewBottomInset + 3.0 + backButton.size.height / 2.0) + controlsBottomInset
                }
                context.add(backButton
                    .position(backButtonPosition)
                    .opacity(controlsAreVisible ? 1.0 : 0.0)
                )
            }
            
            return context.availableSize
        }
    }
}

public class DrawingScreen: ViewController, TGPhotoDrawingInterfaceController, UIDropInteractionDelegate {
    fileprivate final class Node: ViewControllerTracingNode {
        private weak var controller: DrawingScreen?
        private let context: AccountContext
        private var interaction: DrawingToolsInteraction?
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
        fileprivate let insertSticker: ActionSlot<Void>
        fileprivate let insertText: ActionSlot<Void>
        private let updateEntityView: ActionSlot<(UUID, Bool)>
        private let endEditingTextEntityView: ActionSlot<(UUID, Bool)>
        private var isInteractingWithEntities = false
        
        private let apply: ActionSlot<Void>
        private let dismiss: ActionSlot<Void>
        
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
                
        private var presentationData: PresentationData
        private let hapticFeedback = HapticFeedback()
        private var validLayout: (ContainerViewLayout, UIInterfaceOrientation?)?
        
        var _drawingView: DrawingView?
        var drawingView: DrawingView {
            if self._drawingView == nil, let controller = self.controller {
                if let externalDrawingView = controller.externalDrawingView {
                    self._drawingView = externalDrawingView
                } else {
                    self._drawingView = DrawingView(size: controller.size)
                }
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
                    if let self, let interaction = self.interaction {
                        if let _ = interaction.colorPickerScreen {
                            interaction.dismissColorPicker()
                        } else {
                            self.requestPresentColorPicker.invoke(Void())
                        }
                    }
                }
                self._drawingView?.requestedEraserToggle = { [weak self] in
                    if let self {
                        self.toggleWithEraser.invoke(Void())
                    }
                }
                self._drawingView?.requestedToolsToggle = { [weak self] in
                    if let self {
                        self.toggleWithPreviousTool.invoke(Void())
                    }
                }
                self.performAction.connect { [weak self] action in
                    if let self {
                        if case .clear = action {
                            let actionSheet = ActionSheetController(presentationData: self.presentationData.withUpdated(theme: defaultDarkColorPresentationTheme))
                            actionSheet.setItemGroups([
                                ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: self.presentationData.strings.Paint_ClearConfirm, color: .destructive, action: { [weak actionSheet, weak self] in
                                        actionSheet?.dismissAnimated()
                                        
                                        self?._drawingView?.performAction(action)
                                    })
                                ]),
                                ActionSheetItemGroup(items: [
                                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                                        actionSheet?.dismissAnimated()
                                    })
                                ])
                            ])
                            self.controller?.present(actionSheet, in: .window(.root))
                        } else {
                            self._drawingView?.performAction(action)
                        }
                    }
                }
                self.updateToolState.connect { [weak self] state in
                    if let self {
                        self._drawingView?.updateToolState(state)
                    }
                }
                self.previewBrushSize.connect { [weak self] size in
                    if let self {
                        self._drawingView?.setBrushSizePreview(size)
                    }
                }
                self.dismissEyedropper.connect { [weak self] in
                    if let self {
                        self.interaction?.dismissCurrentEyedropper()
                    }
                }
            }
            return self._drawingView!
        }
        
        var _entitiesView: DrawingEntitiesView?
        var entitiesView: DrawingEntitiesView {
            if self._entitiesView == nil, let controller = self.controller {
                if let externalEntitiesView = controller.externalEntitiesView {
                    self._entitiesView = externalEntitiesView
                } else {
                    self._entitiesView = DrawingEntitiesView(context: self.context, size: controller.size)
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
                self.insertEntity.connect { [weak self] entity in
                    if let self, let interaction = self.interaction {
                        interaction.insertEntity(entity)
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
                self.updateEntityView.connect { [weak self] uuid, animated in
                    if let strongSelf = self, let entitiesView = strongSelf._entitiesView {
                        entitiesView.getView(for: uuid)?.update(animated: animated)
                    }
                }
                self.endEditingTextEntityView.connect { [weak self] uuid, reset in
                    if let strongSelf = self, let entitiesView = strongSelf._entitiesView {
                        if let textEntityView = entitiesView.getView(for: uuid) as? DrawingTextEntityView {
                            textEntityView.endEditing(reset: reset)
                        }
                    }
                }
            }
            return self._entitiesView!
        }
        
        private var _selectionContainerView: DrawingSelectionContainerView?
        var selectionContainerView: DrawingSelectionContainerView {
            if self._selectionContainerView == nil, let controller = self.controller {
                if let externalSelectionContainerView = controller.externalSelectionContainerView {
                    self._selectionContainerView = externalSelectionContainerView
                } else {
                    self._selectionContainerView = DrawingSelectionContainerView(frame: .zero)
                }
                
            }
            return self._selectionContainerView!
        }
        
        private var _contentWrapperView: UIView?
        var contentWrapperView: UIView {
            if self._contentWrapperView == nil {
                self._contentWrapperView = UIView()
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
            self.insertSticker = ActionSlot<Void>()
            self.insertText = ActionSlot<Void>()
            self.updateEntityView = ActionSlot<(UUID, Bool)>()
            self.endEditingTextEntityView = ActionSlot<(UUID, Bool)>()
            self.apply = ActionSlot<Void>()
            self.dismiss = ActionSlot<Void>()
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
                        
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
            
            guard let controller = self.controller else {
                return
            }
            self.interaction = DrawingToolsInteraction(
                context: self.context,
                drawingView: self.drawingView,
                entitiesView: self.entitiesView,
                contentWrapperView: self.contentWrapperView,
                selectionContainerView: self.selectionContainerView,
                isVideo: controller.isVideo,
                autoselectEntityOnPan: false,
                updateSelectedEntity: { [weak self] entity in
                    if let self {
                        self.updateSelectedEntity.invoke(entity)
                    }
                },
                updateVideoPlayback: { [weak controller] isPlaying in
                    if let controller {
                        controller.updateVideoPlayback(isPlaying)
                    }
                },
                updateColor: { [weak self] color in
                    if let self {
                        self.updateColor.invoke(color)
                    }
                },
                onInteractionUpdated: { [weak self] isInteracting in
                    if let self {
                        self.isInteractingWithEntities = isInteracting
                        self.requestUpdate(transition: .easeInOut(duration: 0.2))
                    }
                },
                onTextEditingEnded: { _ in },
                editEntity: { _ in },
                getCurrentImage: { [weak controller] in
                    return controller?.getCurrentImage()
                },
                getControllerNode: { [weak self] in
                    return self
                },
                present: { [weak self] c, i, a in
                    if let self {
                        self.controller?.present(c, in: i, with: a)
                    }
                },
                addSubview: { [weak self] view in
                    if let self {
                        self.view.addSubview(view)
                    }
                }
            )
        }
        
        func animateIn() {
            self.entitiesView.selectEntity(nil)
            
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
                if self.controller?.sourceHint == .storyEditor {
                    view.isHidden = true
                }
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
        
        func requestUpdate(transition: Transition = .immediate) {
            if let (layout, orientation) = self.validLayout {
                self.containerLayoutUpdated(layout: layout, orientation: orientation, transition: transition)
            }
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
                        sourceHint: controller.sourceHint,
                        existingStickerPickerInputData: controller.existingStickerPickerInputData,
                        isVideo: controller.isVideo,
                        isAvatar: controller.isAvatar,
                        isInteractingWithEntities: self.isInteractingWithEntities,
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
                        insertSticker: self.insertSticker,
                        insertText: self.insertText,
                        updateEntityView: self.updateEntityView,
                        endEditingTextEntityView: self.endEditingTextEntityView,
                        entityViewForEntity: { [weak self] entity in
                            if let self, let entityView = self.entitiesView.getView(for: entity.uuid) {
                                return entityView
                            } else {
                                return nil
                            }
                        },
                        presentGallery: self.controller?.presentGallery,
                        apply: self.apply,
                        dismiss: self.dismiss,
                        presentColorPicker: { [weak self] initialColor in
                            self?.interaction?.presentColorPicker(initialColor: initialColor)
                        },
                        presentFastColorPicker: { [weak self] sourceView in
                            self?.interaction?.presentFastColorPicker(sourceView: sourceView)
                        },
                        updateFastColorPickerPan: { [weak self] point in
                            self?.interaction?.updateFastColorPickerPan(point)
                        },
                        dismissFastColorPicker: { [weak self] in
                            self?.interaction?.dismissFastColorPicker()
                        },
                        presentFontPicker: { [weak self] sourceView in
                            self?.interaction?.presentFontPicker(sourceView: sourceView)
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
            
            self.interaction?.containerLayoutUpdated(layout: layout, transition: transition)
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    public enum SourceHint {
        case storyEditor
    }
    
    private let context: AccountContext
    private let sourceHint: SourceHint?
    private let size: CGSize
    private let originalSize: CGSize
    private let isVideo: Bool
    private let isAvatar: Bool
    private let externalDrawingView: DrawingView?
    private let externalEntitiesView: DrawingEntitiesView?
    private let externalSelectionContainerView: DrawingSelectionContainerView?
    private let existingStickerPickerInputData: Promise<StickerPickerInputData>?
    
    public var requestDismiss: () -> Void = {}
    public var requestApply: () -> Void = {}
    public var getCurrentImage: () -> UIImage? = { return nil }
    public var updateVideoPlayback: (Bool) -> Void = { _ in }
    
    public var presentGallery: (() -> Void)?
    
    public init(context: AccountContext, sourceHint: SourceHint? = nil, size: CGSize, originalSize: CGSize, isVideo: Bool, isAvatar: Bool, drawingView: DrawingView?, entitiesView: (UIView & TGPhotoDrawingEntitiesView)?, selectionContainerView: DrawingSelectionContainerView?, existingStickerPickerInputData: Promise<StickerPickerInputData>? = nil) {
        self.context = context
        self.sourceHint = sourceHint
        self.size = size
        self.originalSize = originalSize
        self.isVideo = isVideo
        self.isAvatar = isAvatar
        self.existingStickerPickerInputData = existingStickerPickerInputData
        
        if let drawingView {
            self.externalDrawingView = drawingView
        } else {
            self.externalDrawingView = nil
        }
        
        if let entitiesView = entitiesView as? DrawingEntitiesView {
            self.externalEntitiesView = entitiesView
        } else {
            self.externalEntitiesView = nil
        }
        
        if let selectionContainerView = selectionContainerView {
            self.externalSelectionContainerView = selectionContainerView
        } else {
            self.externalSelectionContainerView = nil
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
    
    public var contentWrapperView: UIView {
        return self.node.contentWrapperView
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
        
        let dropInteraction = UIDropInteraction(delegate: self)
        self.drawingView.addInteraction(dropInteraction)
    }
    
    public func generateDrawingResultData() -> DrawingResultData? {
        if self.drawingView.isEmpty && self.entitiesView.entities.isEmpty {
            return nil
        }
        
        let drawingImage = self.drawingView.drawingImage
        
        let _ = self.entitiesView.entitiesData
        let codableEntities = self.entitiesView.entities.filter { !($0 is DrawingMediaEntity) }.compactMap({ CodableDrawingEntity(entity: $0) })
        return DrawingResultData(data: self.drawingView.drawingData, drawingImage: drawingImage, entities: codableEntities)
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
                    if let sticker = sticker as? DrawingStickerEntity, case let .file(file) = sticker.content {
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
        self.entitiesView.selectEntity(nil)
        
        self.node.animateOut(completion: {
            completion()
        })
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
            if images.count == 1, let image = images.first, max(image.size.width, image.size.height) > 1.0 {
                let entity = DrawingStickerEntity(content: .image(image, .sticker))
                strongSelf.node.insertEntity.invoke(entity)
            }
        }
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
    }
    
    @available(iOSApplicationExtension 11.0, iOS 11.0, *)
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
    }
}

public final class DrawingToolsInteraction {
    private let context: AccountContext
    private let drawingView: DrawingView
    private let entitiesView: DrawingEntitiesView
    private weak var contentWrapperView: UIView?
    private let selectionContainerView: DrawingSelectionContainerView
    private let isVideo: Bool
    private let autoSelectEntityOnPan: Bool
    private let updateSelectedEntity: (DrawingEntity?) -> Void
    private let updateVideoPlayback: (Bool) -> Void
    private let updateColor: (DrawingColor) -> Void
    
    private let onInteractionUpdated: (Bool) -> Void
    private let onTextEditingEnded: (Bool) -> Void
    private let editEntity: (DrawingEntity) -> Void
        
    public let getCurrentImage: () -> UIImage?
    private let getControllerNode: () -> ASDisplayNode?
    private let present: (ViewController, PresentationContextType, Any?) -> Void
    private let addSubview: (UIView) -> Void
    
    private let textEditAccessoryView: UIInputView
    private let textEditAccessoryHost: ComponentView<Empty>
    
    private var currentEyedropperView: EyedropperView?
    private weak var currentMenuController: ContextMenuController?
    
    private let hapticFeedback = HapticFeedback()
    
    private var isActive = false
    private var validLayout: ContainerViewLayout?
    
    public init(
        context: AccountContext,
        drawingView: DrawingView,
        entitiesView: DrawingEntitiesView,
        contentWrapperView: UIView,
        selectionContainerView: DrawingSelectionContainerView,
        isVideo: Bool,
        autoselectEntityOnPan: Bool,
        updateSelectedEntity: @escaping (DrawingEntity?) -> Void,
        updateVideoPlayback: @escaping (Bool) -> Void,
        updateColor: @escaping (DrawingColor) -> Void,
        onInteractionUpdated: @escaping (Bool) -> Void,
        onTextEditingEnded: @escaping (Bool) -> Void,
        editEntity: @escaping (DrawingEntity) -> Void,
        getCurrentImage: @escaping () -> UIImage?,
        getControllerNode: @escaping () -> ASDisplayNode?,
        present: @escaping (ViewController, PresentationContextType, Any?) -> Void,
        addSubview: @escaping (UIView) -> Void
    ) {
        self.context = context
        self.drawingView = drawingView
        self.entitiesView = entitiesView
        self.contentWrapperView = contentWrapperView
        self.selectionContainerView = selectionContainerView
        self.isVideo = isVideo
        self.autoSelectEntityOnPan = autoselectEntityOnPan
        self.updateSelectedEntity = updateSelectedEntity
        self.updateVideoPlayback = updateVideoPlayback
        self.updateColor = updateColor
        self.onInteractionUpdated = onInteractionUpdated
        self.onTextEditingEnded = onTextEditingEnded
        self.editEntity = editEntity
        self.getCurrentImage = getCurrentImage
        self.getControllerNode = getControllerNode
        self.present = present
        self.addSubview = addSubview
        
        self.textEditAccessoryView = UIInputView(frame: CGRect(origin: .zero, size: CGSize(width: 100.0, height: 44.0)), inputViewStyle: .keyboard)
        self.textEditAccessoryHost = ComponentView<Empty>()
        
        self.activate()
    }
    
    public func reset() {
        self.drawingView.stateUpdated = { _ in }
    }
    
    public func activate() {
        self.isActive = true
        
        self.entitiesView.autoSelectEntities = self.autoSelectEntityOnPan
        self.entitiesView.selectionContainerView = self.selectionContainerView
        self.entitiesView.selectionChanged = { [weak self] entity in
            if let self {
                self.updateSelectedEntity(entity)
            }
        }
        self.entitiesView.onInteractionUpdated = { [weak self] isInteracting in
            if let self {
                self.onInteractionUpdated(isInteracting)
            }
        }
        self.entitiesView.requestedMenuForEntityView = { [weak self] entityView, isTopmost in
            guard let self, let node = self.getControllerNode() else {
                return
            }
            if self.currentMenuController != nil {
                if let entityView = entityView as? DrawingTextEntityView {
                    entityView.beginEditing(accessoryView: self.textEditAccessoryView)
                }
                return
            }
            
            var isVideo = false
            if let entity = entityView.entity as? DrawingStickerEntity {
                if case .dualVideoReference = entity.content {
                    isVideo = true
                }
            }
            
            guard !isVideo else {
                return
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            var actions: [ContextMenuAction] = []
            actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_Delete, accessibilityLabel: presentationData.strings.Paint_Delete), action: { [weak self, weak entityView] in
                if let self, let entityView {
                    self.entitiesView.remove(uuid: entityView.entity.uuid, animated: true)
                }
            }))
            if let entityView = entityView as? DrawingLocationEntityView {
                actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_Edit, accessibilityLabel: presentationData.strings.Paint_Edit), action: { [weak self, weak entityView] in
                    if let self, let entityView {
                        self.editEntity(entityView.entity)
                        self.entitiesView.selectEntity(entityView.entity)
                    }
                }))
            } else if let entityView = entityView as? DrawingTextEntityView {
                actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_Edit, accessibilityLabel: presentationData.strings.Paint_Edit), action: { [weak self, weak entityView] in
                    if let self, let entityView {
                        entityView.beginEditing(accessoryView: self.textEditAccessoryView)
                        self.entitiesView.selectEntity(entityView.entity)
                    }
                }))
            } else if entityView is DrawingStickerEntityView || entityView is DrawingBubbleEntityView {
                actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_Flip, accessibilityLabel: presentationData.strings.Paint_Flip), action: { [weak self] in
                    if let self {
                        self.flipSelectedEntity()
                    }
                }))
            }
            if !isTopmost && !isVideo {
                actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_MoveForward, accessibilityLabel: presentationData.strings.Paint_MoveForward), action: { [weak self, weak entityView] in
                    if let self, let entityView {
                        self.entitiesView.bringToFront(uuid: entityView.entity.uuid)
                    }
                }))
            }
            if !isVideo {
                actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_Duplicate, accessibilityLabel: presentationData.strings.Paint_Duplicate), action: { [weak self, weak entityView] in
                    if let self, let entityView {
                        let newEntity = self.entitiesView.duplicate(entityView.entity)
                        self.entitiesView.selectEntity(newEntity)
                    }
                }))
            }
            let entityFrame = entityView.convert(entityView.selectionBounds, to: node.view).offsetBy(dx: 0.0, dy: -6.0)
            let controller = ContextMenuController(actions: actions)
            let bounds = node.bounds.insetBy(dx: 0.0, dy: 160.0)
            self.present(
                controller,
                .window(.root),
                ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak node] in
                    if let node {
                        return (node, entityFrame, node, bounds)
                    } else {
                        return nil
                    }
                })
            )
            self.currentMenuController = controller
        }
    }
        
    public func deactivate() {
        self.isActive = false
    }
    
    public func insertEntity(_ entity: DrawingEntity, scale: CGFloat? = nil, position: CGPoint? = nil) {
        self.entitiesView.prepareNewEntity(entity, scale: scale, position: position)
        self.entitiesView.add(entity)
        self.entitiesView.selectEntity(entity, animate: !(entity is DrawingTextEntity))
        
        if let entityView = self.entitiesView.getView(for: entity.uuid) {
            if let textEntityView = entityView as? DrawingTextEntityView {
                textEntityView.beginEditing(accessoryView: self.textEditAccessoryView)
                
                textEntityView.replaceWithImage = { [weak self] image, isSticker in
                    if let self {
                        self.insertEntity(DrawingStickerEntity(content: .image(image, isSticker ? .sticker : .rectangle)), scale: 2.5)
                    }
                }
            } else {
                if self.isVideo {
                    entityView.seek(to: 0.0)
                }
                
                entityView.animateInsertion()
            }
        }
    }
    
    public func endTextEditing(reset: Bool) {
        if let entityView = self.entitiesView.selectedEntityView as? DrawingTextEntityView {
            entityView.endEditing(reset: reset)
            self.onTextEditingEnded(reset)
        }
    }
    
    public func updateEntitySize(_ size: CGFloat) {
        if let selectedEntityView = self.entitiesView.selectedEntityView {
            if let textEntity = selectedEntityView.entity as? DrawingTextEntity {
                textEntity.fontSize = size
            } else {
                selectedEntityView.entity.lineWidth = size
            }
            selectedEntityView.update()
        }
    }
    
    public func flipSelectedEntity() {
        if let selectedEntityView = self.entitiesView.selectedEntityView {
            let selectedEntity = selectedEntityView.entity
            if let entity = selectedEntity as? DrawingBubbleEntity {
                var updatedTailPosition = entity.tailPosition
                updatedTailPosition.x = 1.0 - updatedTailPosition.x
                entity.tailPosition = updatedTailPosition
                selectedEntityView.update(animated: false)
            } else if let entity = selectedEntity as? DrawingStickerEntity {
                entity.mirrored = !entity.mirrored
                selectedEntityView.update(animated: true)
            }
        }
    }
    
    func presentEyedropper(retryLaterForVideo: Bool = true, dismissed: @escaping () -> Void) {
        self.entitiesView.pause()
        
        if self.isVideo && retryLaterForVideo {
            self.updateVideoPlayback(false)
            Queue.mainQueue().after(0.1) {
                self.presentEyedropper(retryLaterForVideo: false, dismissed: dismissed)
            }
            return
        }

        let currentImage = self.getCurrentImage()
        
        let sourceImage = generateImage(self.drawingView.imageSize, contextGenerator: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            if let cgImage = currentImage?.cgImage {
                context.draw(cgImage, in: bounds)
            }
            if self.drawingView.superview !== self.entitiesView {
                if let cgImage = self.drawingView.drawingImage?.cgImage {
                    context.draw(cgImage, in: bounds)
                }
            }
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            self.entitiesView.layer.render(in: context)
        }, opaque: true, scale: 1.0)
        
        guard let sourceImage, var contentWrapperView = self.contentWrapperView, let controllerView = self.getControllerNode()?.view else {
            return
        }
        
        if contentWrapperView.frame.width.isZero {
            contentWrapperView = self.entitiesView.superview!
        }
        
        let eyedropperView = EyedropperView(containerSize: contentWrapperView.frame.size, drawingView: self.drawingView, sourceImage: sourceImage)
        eyedropperView.completed = { [weak self] color in
            if let self {
                self.updateColor(color)
                self.entitiesView.play()
                self.updateVideoPlayback(true)

                dismissed()
            }
        }
        eyedropperView.dismissed = { [weak self] in
            if let self {
                self.entitiesView.play()
                self.updateVideoPlayback(true)
            }
        }
        eyedropperView.frame = contentWrapperView.convert(contentWrapperView.bounds, to: controllerView)
        self.addSubview(eyedropperView)
        self.currentEyedropperView = eyedropperView
    }
    
    func dismissCurrentEyedropper() {
        if let currentEyedropperView = self.currentEyedropperView {
            self.currentEyedropperView = nil
            currentEyedropperView.dismiss()
        }
    }
    
    weak var colorPickerScreen: ColorPickerScreen?
    func presentColorPicker(initialColor: DrawingColor, dismissed: @escaping () -> Void = {}) {
        self.dismissCurrentEyedropper()
        self.dismissFontPicker()
        
        self.hapticFeedback.impact(.medium)
        var didDismiss = false
        let colorController = ColorPickerScreen(context: self.context, initialColor: initialColor, updated: { [weak self] color in
            if let self {
                self.updateColor(color)
            }
        }, openEyedropper: { [weak self] in
            if let self {
                self.presentEyedropper(dismissed: dismissed)
            }
        }, dismissed: {
            if !didDismiss {
                didDismiss = true
                dismissed()
            }
        })
        self.present(colorController, .window(.root), nil)
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
            if let self {
                self.updateColor(color)
            }
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
        guard !self.dismissFontPicker(), let validLayout = self.validLayout else {
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
                
                if let layout = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout: layout, transition: .easeInOut(duration: 0.2))
                }
            })))
        }
        
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
        let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(ReferenceContentSource(sourceView: sourceView, contentArea: CGRect(origin: .zero, size: CGSize(width: validLayout.size.width, height: validLayout.size.height - (validLayout.inputHeight ?? 0.0))), customPosition: CGPoint(x: 0.0, y: 1.0))), items: .single(ContextController.Items(content: .list(items))))
        self.present(contextController, .window(.root), nil)
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
        
        if let layout = self.validLayout {
            self.containerLayoutUpdated(layout: layout, transition: .immediate)
        }
    }
    
    public func containerLayoutUpdated(layout: ContainerViewLayout, transition: Transition) {
        self.validLayout = layout
        
        guard self.isActive else {
            return
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
                                    nextStyle = .regular
                                case .stroke:
                                    nextStyle = .regular
                                }
                                textEntity.style = nextStyle
                                entityView.update()
                                
                                if let layout = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout: layout, transition: .immediate)
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
                                
                                if let layout = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout: layout, transition: .immediate)
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
                                
                                if let layout = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout: layout, transition: .immediate)
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
}
