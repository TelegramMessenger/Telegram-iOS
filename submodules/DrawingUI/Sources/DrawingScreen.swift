import Foundation
import UIKit
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
import ContextUI

enum DrawingToolState: Equatable {
    enum Key: CaseIterable {
        case pen
        case marker
        case neon
        case pencil
        case lasso
        case eraser
    }
    
    struct BrushState: Equatable {
        enum Mode: Equatable {
            case round
            case arrow
        }
        
        let color: DrawingColor
        let size: CGFloat
        let mode: Mode
        
        func withUpdatedColor(_ color: DrawingColor) -> BrushState {
            return BrushState(color: color, size: self.size, mode: self.mode)
        }
        
        func withUpdatedSize(_ size: CGFloat) -> BrushState {
            return BrushState(color: self.color, size: size, mode: self.mode)
        }
        
        func withUpdatedMode(_ mode: Mode) -> BrushState {
            return BrushState(color: self.color, size: self.size, mode: mode)
        }
    }
    
    struct EraserState: Equatable {
        enum Mode: Equatable {
            case bitmap
            case vector
            case blur
        }
        
        let size: CGFloat
        let mode: Mode
        
        func withUpdatedSize(_ size: CGFloat) -> EraserState {
            return EraserState(size: size, mode: self.mode)
        }
        
        func withUpdatedMode(_ mode: Mode) -> EraserState {
            return EraserState(size: self.size, mode: mode)
        }
    }
    
    case pen(BrushState)
    case marker(BrushState)
    case neon(BrushState)
    case pencil(BrushState)
    case lasso
    case eraser(EraserState)
    
    func withUpdatedColor(_ color: DrawingColor) -> DrawingToolState {
        switch self {
        case let .pen(state):
            return .pen(state.withUpdatedColor(color))
        case let .marker(state):
            return .marker(state.withUpdatedColor(color))
        case let .neon(state):
            return .neon(state.withUpdatedColor(color))
        case let .pencil(state):
            return .pencil(state.withUpdatedColor(color))
        case .lasso, .eraser:
            return self
        }
    }
    
    func withUpdatedSize(_ size: CGFloat) -> DrawingToolState {
        switch self {
        case let .pen(state):
            return .pen(state.withUpdatedSize(size))
        case let .marker(state):
            return .marker(state.withUpdatedSize(size))
        case let .neon(state):
            return .neon(state.withUpdatedSize(size))
        case let .pencil(state):
            return .pencil(state.withUpdatedSize(size))
        case .lasso:
            return self
        case let .eraser(state):
            return .eraser(state.withUpdatedSize(size))
        }
    }
    
    func withUpdatedBrushMode(_ mode: BrushState.Mode) -> DrawingToolState {
        switch self {
        case let .pen(state):
            return .pen(state.withUpdatedMode(mode))
        case let .marker(state):
            return .marker(state.withUpdatedMode(mode))
        case let .neon(state):
            return .neon(state.withUpdatedMode(mode))
        case let .pencil(state):
            return .pencil(state.withUpdatedMode(mode))
        case .lasso, .eraser:
            return self
        }
    }
    
    func withUpdatedEraserMode(_ mode: EraserState.Mode) -> DrawingToolState {
        switch self {
        case .pen:
            return self
        case .marker:
            return self
        case .neon:
            return self
        case .pencil:
            return self
        case .lasso:
            return self
        case let .eraser(state):
            return .eraser(state.withUpdatedMode(mode))
        }
    }
    
    var color: DrawingColor? {
        switch self {
        case let .pen(state), let .marker(state), let .neon(state), let .pencil(state):
            return state.color
        default:
            return nil
        }
    }
    
    var size: CGFloat? {
        switch self {
        case let .pen(state), let .marker(state), let .neon(state), let .pencil(state):
            return state.size
        case let .eraser(state):
            return state.size
        default:
            return nil
        }
    }
    
    var brushMode: DrawingToolState.BrushState.Mode? {
        switch self {
        case let .pen(state), let .marker(state), let .neon(state), let .pencil(state):
            return state.mode
        default:
            return nil
        }
    }
    
    var eraserMode: DrawingToolState.EraserState.Mode? {
        switch self {
        case let .eraser(state):
            return state.mode
        default:
            return nil
        }
    }
    
    var key: DrawingToolState.Key {
        switch self {
        case .pen:
            return .pen
        case .marker:
            return .marker
        case .neon:
            return .neon
        case .pencil:
            return .pencil
        case .lasso:
            return .lasso
        case .eraser:
            return .eraser
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
        return .lasso
    }
    
    func withUpdatedSelectedTool(_ selectedTool: DrawingToolState.Key) -> DrawingState {
        return DrawingState(
            selectedTool: selectedTool,
            tools: self.tools
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
    
    func withUpdatedBrushMode(_ mode: DrawingToolState.BrushState.Mode) -> DrawingState {
        var tools = self.tools
        if let index = tools.firstIndex(where: { $0.key == self.selectedTool }) {
            let updated = tools[index].withUpdatedBrushMode(mode)
            tools.remove(at: index)
            tools.insert(updated, at: index)
        }
        
        return DrawingState(
            selectedTool: self.selectedTool,
            tools: tools
        )
    }
    
    func withUpdatedEraserMode(_ mode: DrawingToolState.EraserState.Mode) -> DrawingState {
        var tools = self.tools
        if let index = tools.firstIndex(where: { $0.key == self.selectedTool }) {
            let updated = tools[index].withUpdatedEraserMode(mode)
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
                .pen(DrawingToolState.BrushState(color: DrawingColor(rgb: 0xffffff), size: 0.3, mode: .round)),
                .marker(DrawingToolState.BrushState(color: DrawingColor(rgb: 0xfee21b), size: 0.5, mode: .round)),
                .neon(DrawingToolState.BrushState(color: DrawingColor(rgb: 0x34ffab), size: 0.5, mode: .round)),
                .pencil(DrawingToolState.BrushState(color: DrawingColor(rgb: 0x2570f0), size: 0.5, mode: .round)),
                .lasso,
                .eraser(DrawingToolState.EraserState(size: 0.5, mode: .bitmap))
            ]
        )
    }
}

private final class ReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, customPosition: CGPoint(x: 7.0, y: 3.0))
    }
}

enum DrawingScreenTransition {
    case animateIn
    case animateOut
}

private let undoButtonTag = GenericComponentViewTag()
private let clearAllButtonTag = GenericComponentViewTag()
private let colorButtonTag = GenericComponentViewTag()
private let addButtonTag = GenericComponentViewTag()
private let toolsTag = GenericComponentViewTag()
private let modeTag = GenericComponentViewTag()
private let doneButtonTag = GenericComponentViewTag()

private final class DrawingScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let present: (ViewController) -> Void
    let updateState: ActionSlot<DrawingView.NavigationState>
    let updateColor: ActionSlot<DrawingColor>
    let performAction: ActionSlot<DrawingView.Action>
    let updateToolState: ActionSlot<DrawingToolState>
    let updateSelectedEntity: ActionSlot<DrawingEntity?>
    let insertEntity: ActionSlot<DrawingEntity>
    let deselectEntity: ActionSlot<Void>
    let updatePlayback: ActionSlot<Bool>
    let previewBrushSize: ActionSlot<CGFloat?>
    let apply: ActionSlot<Void>
    let dismiss: ActionSlot<Void>
    
    let presentColorPicker: (DrawingColor) -> Void
    let presentFastColorPicker: (UIView) -> Void
    let updateFastColorPickerPan: (CGPoint) -> Void
    let dismissFastColorPicker: () -> Void
    
    init(
        context: AccountContext,
        present: @escaping (ViewController) -> Void,
        updateState: ActionSlot<DrawingView.NavigationState>,
        updateColor: ActionSlot<DrawingColor>,
        performAction: ActionSlot<DrawingView.Action>,
        updateToolState: ActionSlot<DrawingToolState>,
        updateSelectedEntity: ActionSlot<DrawingEntity?>,
        insertEntity: ActionSlot<DrawingEntity>,
        deselectEntity: ActionSlot<Void>,
        updatePlayback: ActionSlot<Bool>,
        previewBrushSize: ActionSlot<CGFloat?>,
        apply: ActionSlot<Void>,
        dismiss: ActionSlot<Void>,
        presentColorPicker: @escaping (DrawingColor) -> Void,
        presentFastColorPicker: @escaping (UIView) -> Void,
        updateFastColorPickerPan: @escaping (CGPoint) -> Void,
        dismissFastColorPicker: @escaping () -> Void
    ) {
        self.context = context
        self.present = present
        self.updateState = updateState
        self.updateColor = updateColor
        self.performAction = performAction
        self.updateToolState = updateToolState
        self.updateSelectedEntity = updateSelectedEntity
        self.insertEntity = insertEntity
        self.deselectEntity = deselectEntity
        self.updatePlayback = updatePlayback
        self.previewBrushSize = previewBrushSize
        self.apply = apply
        self.dismiss = dismiss
        self.presentColorPicker = presentColorPicker
        self.presentFastColorPicker = presentFastColorPicker
        self.updateFastColorPickerPan = updateFastColorPickerPan
        self.dismissFastColorPicker = dismissFastColorPicker
    }
    
    static func ==(lhs: DrawingScreenComponent, rhs: DrawingScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
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
            case round
            case arrow
            case remove
            case blur
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
                case .round:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushRound"), color: .white)!
                case .arrow:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushArrow"), color: .white)!
                case .remove:
                    image = generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushRemove"), color: .white)!
                case .blur:
                    image = UIImage(bundleImageName: "Media Editor/BrushBlur")!
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
        private let updatePlayback: ActionSlot<Bool>
        private let present: (ViewController) -> Void
        
        var currentMode: Mode
        var drawingState: DrawingState
        var drawingViewState: DrawingView.NavigationState
        var toolIsFocused = false
        var currentColor: DrawingColor
        var selectedEntity: DrawingEntity?
    
        init(context: AccountContext, updateToolState: ActionSlot<DrawingToolState>, insertEntity: ActionSlot<DrawingEntity>, deselectEntity: ActionSlot<Void>, updatePlayback: ActionSlot<Bool>, present: @escaping (ViewController) -> Void) {
            self.context = context
            self.updateToolState = updateToolState
            self.insertEntity = insertEntity
            self.deselectEntity = deselectEntity
            self.updatePlayback = updatePlayback
            self.present = present
            
            self.currentMode = .drawing
            self.drawingState = .initial
            self.drawingViewState = DrawingView.NavigationState(canUndo: false, canRedo: false, canClear: false, canZoomOut: false)
            self.currentColor = self.drawingState.tools.first?.color ?? DrawingColor(rgb: 0xffffff)
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
        
        func updateSelectedTool(_ tool: DrawingToolState.Key) {
            self.drawingState = self.drawingState.withUpdatedSelectedTool(tool)
            self.currentColor = self.drawingState.currentToolState.color ?? self.currentColor
            self.updateToolState.invoke(self.drawingState.currentToolState)
            self.updated(transition: .easeInOut(duration: 0.2))
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
        
        func updateBrushMode(_ mode: DrawingToolState.BrushState.Mode) {
            self.drawingState = self.drawingState.withUpdatedBrushMode(mode)
            self.updateToolState.invoke(self.drawingState.currentToolState)
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func updateEraserMode(_ mode: DrawingToolState.EraserState.Mode) {
            self.drawingState = self.drawingState.withUpdatedEraserMode(mode)
            self.updateToolState.invoke(self.drawingState.currentToolState)
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func updateToolIsFocused(_ isFocused: Bool) {
            self.toolIsFocused = isFocused
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func updateDrawingState(_ state: DrawingView.NavigationState) {
            self.drawingViewState = state
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func updateSelectedEntity(_ entity: DrawingEntity?) {
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
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func presentShapePicker(_ sourceView: UIView) {
            let items: [ContextMenuItem] = [
                .action(
                    ContextMenuActionItem(
                        text: "Rectangle",
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
                        text: "Ellipse",
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
                        text: "Bubble",
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
                        text: "Star",
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
                        text: "Arrow",
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/ShapeArrow"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.insertEntity.invoke(DrawingVectorEntity(type: .oneSidedArrow, color: strongSelf.currentColor, lineWidth: 0.5))
                            }
                        }
                    )
                )
            ]
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(ReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))))
            self.present(contextController)
        }
        
        func presentBrushModePicker(_ sourceView: UIView) {
            let items: [ContextMenuItem] = [
                .action(
                    ContextMenuActionItem(
                        text: "Round",
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushRound"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.updateBrushMode(.round)
                            }
                        }
                    )
                ),
                .action(
                    ContextMenuActionItem(
                        text: "Arrow",
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushArrow"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            if let strongSelf = self {
                                strongSelf.updateBrushMode(.arrow)
                            }
                        }
                    )
                )
            ]
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(ReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))))
            self.present(contextController)
        }
        
        func presentEraserModePicker(_ sourceView: UIView) {
            let items: [ContextMenuItem] = [
                .action(
                    ContextMenuActionItem(
                        text: "Eraser",
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushRound"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            self?.updateEraserMode(.bitmap)
                        }
                    )
                ),
                .action(
                    ContextMenuActionItem(
                        text: "Object Eraser",
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushRemove"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            self?.updateEraserMode(.vector)
                        }
                    )
                ),
                .action(
                    ContextMenuActionItem(
                        text: "Background Blur",
                        icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Media Editor/BrushBlur"), color: theme.contextMenu.primaryColor)},
                        action: { [weak self] f in
                            f.dismissWithResult(.default)
                            self?.updateEraserMode(.blur)
                        }
                    )
                )
            ]
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkPresentationTheme)
            let contextController = ContextController(account: self.context.account, presentationData: presentationData, source: .reference(ReferenceContentSource(sourceView: sourceView)), items: .single(ContextController.Items(content: .list(items))))
            self.present(contextController)
        }
        
        func updateCurrentMode(_ mode: Mode) {
            self.currentMode = mode
            if let selectedEntity = self.selectedEntity {
                if selectedEntity is DrawingStickerEntity || selectedEntity is DrawingTextEntity {
                    self.deselectEntity.invoke(Void())
                }
            }
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func addTextEntity() {
            let textEntity = DrawingTextEntity(text: "", style: .regular, font: .sanFrancisco, alignment: .center, fontSize: 1.0, color: self.currentColor)
            self.insertEntity.invoke(textEntity)
        }
        
        func presentStickerPicker() {
            self.currentMode = .sticker
            
            self.updatePlayback.invoke(false)
            let controller = StickerPickerScreen(context: self.context)
            controller.completion = { [weak self] file in
                self?.updatePlayback.invoke(true)
                
                if let file = file {
                    let stickerEntity = DrawingStickerEntity(file: file)
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
        return State(context: self.context, updateToolState: self.updateToolState, insertEntity: self.insertEntity, deselectEntity: self.deselectEntity, updatePlayback: self.updatePlayback, present: self.present)
    }
    
    static var body: Body {
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
        
        let addButton = Child(Button.self)
        
        let flipButton = Child(Button.self)
        let fillButton = Child(Button.self)
        let fillButtonTag = GenericComponentViewTag()
        
        let stickerFlipButton = Child(Button.self)
        
        let backButton = Child(Button.self)
        let doneButton = Child(Button.self)
        
        let brushModeButton = Child(Button.self)
        let brushModeButtonTag = GenericComponentViewTag()
        
        let textSize = Child(TextSizeSliderComponent.self)
        let textCancelButton = Child(Button.self)
        let textDoneButton = Child(Button.self)
        
        let presetColors: [DrawingColor] = [
            DrawingColor(rgb: 0xffffff),
            DrawingColor(rgb: 0x000000),
            DrawingColor(rgb: 0x106bff),
            DrawingColor(rgb: 0x2ecb46),
            DrawingColor(rgb: 0xfd8d0e),
            DrawingColor(rgb: 0xfc1a4d),
            DrawingColor(rgb: 0xaf39ee)
        ]
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            let controller = environment.controller
            
            let previewBrushSize = component.previewBrushSize
            let performAction = component.performAction
            component.updateState.connect { [weak state] updatedState in
                state?.updateDrawingState(updatedState)
            }
            component.updateColor.connect { [weak state] color in
                state?.updateColor(color)
            }
            component.updateSelectedEntity.connect { [weak state] entity in
                state?.updateSelectedEntity(entity)
            }
            
            let apply = component.apply
            let dismiss = component.dismiss
            
            let presentColorPicker = component.presentColorPicker
            let presentFastColorPicker = component.presentFastColorPicker
            let updateFastColorPickerPan = component.updateFastColorPickerPan
            let dismissFastColorPicker = component.dismissFastColorPicker
                        
            if let textEntity = state.selectedEntity as? DrawingTextEntity {
                let textSettings = textSettings.update(
                    component: TextSettingsComponent(
                        color: nil,
                        style: DrawingTextStyle(style: textEntity.style),
                        alignment: DrawingTextAlignment(alignment: textEntity.alignment),
                        font: DrawingTextFont(font: textEntity.font),
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
                        updateFont: { [weak state, weak textEntity] font in
                            guard let textEntity = textEntity else {
                                return
                            }
                            textEntity.font = font.font
                            if let entityView = textEntity.currentEntityView {
                                entityView.update()
                            }
                            state?.updated(transition: .easeInOut(duration: 0.2))
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - 84.0, height: 44.0),
                    transition: context.transition
                )
                context.add(textSettings
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - textSettings.size.height / 2.0 - 51.0))
                    .appear(.default(scale: false, alpha: true))
                    .disappear(.default(scale: false, alpha: true))
                )
            } else if state.currentMode == .sticker {
                
            } else if state.selectedEntity != nil {
                let rightButtonPosition = context.availableSize.width - environment.safeInsets.right - 44.0 / 2.0 - 3.0
                var offsetX: CGFloat = environment.safeInsets.left + 44.0 / 2.0 + 3.0
                let delta: CGFloat = (rightButtonPosition - offsetX) / 7.0
                offsetX += delta
                
                var delay: Double = 0.0
                let swatch1Button = swatch1Button.update(
                    component: ColorSwatchComponent(
                        type: .pallete(state.currentColor == presetColors[0]),
                        color: presetColors[0],
                        action: { [weak state] in
                            state?.updateColor(presetColors[0], animated: true)
                        }
                    ),
                    availableSize: CGSize(width: 33.0, height: 33.0),
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
                        type: .pallete(state.currentColor == presetColors[1]),
                        color: presetColors[1],
                        action: { [weak state] in
                            state?.updateColor(presetColors[1], animated: true)
                        }
                    ),
                    availableSize: CGSize(width: 33.0, height: 33.0),
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
                        type: .pallete(state.currentColor == presetColors[2]),
                        color: presetColors[2],
                        action: { [weak state] in
                            state?.updateColor(presetColors[2], animated: true)
                        }
                    ),
                    availableSize: CGSize(width: 33.0, height: 33.0),
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
                        type: .pallete(state.currentColor == presetColors[3]),
                        color: presetColors[3],
                        action: { [weak state] in
                            state?.updateColor(presetColors[3], animated: true)
                        }
                    ),
                    availableSize: CGSize(width: 33.0, height: 33.0),
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
                        type: .pallete(state.currentColor == presetColors[4]),
                        color: presetColors[4],
                        action: { [weak state] in
                            state?.updateColor(presetColors[4], animated: true)
                        }
                    ),
                    availableSize: CGSize(width: 33.0, height: 33.0),
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
                        type: .pallete(state.currentColor == presetColors[5]),
                        color: presetColors[5],
                        action: { [weak state] in
                            state?.updateColor(presetColors[5], animated: true)
                        }
                    ),
                    availableSize: CGSize(width: 33.0, height: 33.0),
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
                        type: .pallete(state.currentColor == presetColors[6]),
                        color: presetColors[6],
                        action: { [weak state] in
                            state?.updateColor(presetColors[6], animated: true)
                        }
                    ),
                    availableSize: CGSize(width: 33.0, height: 33.0),
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
            } else {
                let tools = tools.update(
                    component: ToolsComponent(
                        state: state.drawingState,
                        isFocused: state.toolIsFocused,
                        tag: toolsTag,
                        toolPressed: { [weak state] tool in
                            if let state = state {
                                if state.drawingState.selectedTool == tool, tool != .lasso {
                                    state.updateToolIsFocused(!state.toolIsFocused)
                                } else {
                                    state.updateSelectedTool(tool)
                                }
                            }
                        },
                        toolResized: { [weak state] _, size in
                            state?.updateBrushSize(size)
                            if state?.selectedEntity == nil {
                                previewBrushSize.invoke(size)
                            }
                        },
                        sizeReleased: {
                            previewBrushSize.invoke(nil)
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - environment.safeInsets.left - environment.safeInsets.right, height: 120.0),
                    transition: context.transition
                )
                context.add(tools
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - tools.size.height / 2.0 - 41.0))
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
            
            if let textEntity = state.selectedEntity as? DrawingTextEntity, let entityView = textEntity.currentEntityView as? DrawingTextEntityView, entityView.isEditing {
                let topInset = environment.safeInsets.top + 31.0
                let textSize = textSize.update(
                    component: TextSizeSliderComponent(
                        value: textEntity.fontSize,
                        updated: { [weak state] size in
                            state?.updateBrushSize(size)
                        }
                    ),
                    availableSize: CGSize(width: 30.0, height: 240.0),
                    transition: context.transition
                )
                context.add(textSize
                    .position(CGPoint(x: textSize.size.width / 2.0, y: topInset + (context.availableSize.height - topInset - environment.inputHeight) / 2.0))
                    .appear(Transition.Appear { _, view, transition in
                        transition.animateAlpha(view: view, from: 0.0, to: 1.0)
                        
                        transition.animatePosition(view: view, from: CGPoint(x: -33.0, y: 0.0), to: CGPoint(), additive: true)
                    })
                    .disappear(Transition.Disappear { view, transition, completion in
                        transition.setAlpha(view: view, alpha: 0.0, completion: { _ in
                            completion()
                        })
                        transition.animatePosition(view: view, from: CGPoint(), to: CGPoint(x: -33.0, y: 0.0), additive: true)
                    })
                )
                
                let textCancelButton = textCancelButton.update(
                    component: Button(
                        content: AnyComponent(
                            Text(text: "Cancel", font: Font.regular(17.0), color: .white)
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
                    .position(CGPoint(x: environment.safeInsets.left + textCancelButton.size.width / 2.0 + 13.0, y: environment.safeInsets.top + 31.0))
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                
                let textDoneButton = textDoneButton.update(
                    component: Button(
                        content: AnyComponent(
                            Text(text: "Done", font: Font.semibold(17.0), color: .white)
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
                    .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - textDoneButton.size.width / 2.0 - 13.0, y: environment.safeInsets.top + 31.0))
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
            } else {
                let undoButton = undoButton.update(
                    component: Button(
                        content: AnyComponent(
                            Image(image: state.image(.undo))
                        ),
                        isEnabled: state.drawingViewState.canUndo,
                        action: {
                            performAction.invoke(.undo)
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(undoButtonTag),
                    availableSize: CGSize(width: 24.0, height: 24.0),
                    transition: context.transition
                )
                context.add(undoButton
                    .position(CGPoint(x: environment.safeInsets.left + undoButton.size.width / 2.0 + 2.0, y: environment.safeInsets.top + 31.0))
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                
                if state.drawingViewState.canRedo {
                    let redoButton = redoButton.update(
                        component: Button(
                            content: AnyComponent(
                                Image(image: state.image(.redo))
                            ),
                            action: {
                                performAction.invoke(.redo)
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)),
                        availableSize: CGSize(width: 24.0, height: 24.0),
                        transition: context.transition
                    )
                    context.add(redoButton
                        .position(CGPoint(x: environment.safeInsets.left + undoButton.size.width + 2.0 + redoButton.size.width / 2.0, y: environment.safeInsets.top + 31.0))
                        .appear(.default(scale: true, alpha: true))
                        .disappear(.default(scale: true, alpha: true))
                    )
                }
                
                let clearAllButton = clearAllButton.update(
                    component: Button(
                        content: AnyComponent(
                            Text(text: "Clear All", font: Font.regular(17.0), color: .white)
                        ),
                        isEnabled: state.drawingViewState.canClear,
                        action: {
                            performAction.invoke(.clear)
                        }
                    ).tagged(clearAllButtonTag),
                    availableSize: CGSize(width: 100.0, height: 30.0),
                    transition: context.transition
                )
                context.add(clearAllButton
                    .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - clearAllButton.size.width / 2.0 - 13.0, y: environment.safeInsets.top + 31.0))
                    .appear(.default(scale: true, alpha: true))
                    .disappear(.default(scale: true, alpha: true))
                )
                
                if state.drawingViewState.canZoomOut {
                    let zoomOutButton = zoomOutButton.update(
                        component: Button(
                            content: AnyComponent(
                                ZoomOutButtonContent(
                                    title: "Zoom Out",
                                    image: state.image(.zoomOut)
                                )
                            ),
                            action: {
                                performAction.invoke(.zoomOut)
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)),
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
            
            var isEditingSize = false
            if state.toolIsFocused {
                isEditingSize = true
            } else if let entity = state.selectedEntity {
                if entity is DrawingSimpleShapeEntity || entity is DrawingVectorEntity || entity is DrawingBubbleEntity {
                    isEditingSize = true
                }
            }
            
            if !state.toolIsFocused {
                var color: DrawingColor?
                if let entity = state.selectedEntity, !(entity is DrawingTextEntity) && presetColors.contains(entity.color) {
                    color = nil
                } else {
                    color = state.currentColor
                }
                
                if let _ = state.selectedEntity as? DrawingStickerEntity {
                    let stickerFlipButton = stickerFlipButton.update(
                        component: Button(
                            content: AnyComponent(
                                Image(image: state.image(.flip))
                            ),
                            action: { [weak state] in
                                guard let state = state else {
                                    return
                                }
                                if let entity = state.selectedEntity as? DrawingStickerEntity {
                                    entity.mirrored = !entity.mirrored
                                    entity.currentEntityView?.update(animated: true)
                                }
                                state.updated(transition: .easeInOut(duration: 0.2))
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)),
                        availableSize: CGSize(width: 33.0, height: 33.0),
                        transition: .immediate
                    )
                    context.add(stickerFlipButton
                        .position(CGPoint(x: environment.safeInsets.left + stickerFlipButton.size.width / 2.0 + 3.0, y: context.availableSize.height - environment.safeInsets.bottom - stickerFlipButton.size.height / 2.0 - 51.0))
                        .appear(.default(scale: true))
                        .disappear(.default(scale: true))
                    )
                } else {
                    if [.lasso, .eraser].contains(state.drawingState.selectedTool) {
                        
                    } else {
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
                            .position(CGPoint(x: environment.safeInsets.left + colorButton.size.width / 2.0 + 3.0, y: context.availableSize.height - environment.safeInsets.bottom - colorButton.size.height / 2.0 - 51.0))
                            .appear(.default(scale: true))
                            .disappear(.default(scale: true))
                        )
                    }
                }
            }
            
            var isModeControlEnabled = true
            var modeRightInset: CGFloat = 57.0
            if isEditingSize {
                if state.toolIsFocused {
                    let title: String
                    let image: UIImage?
                    var isEraser = false
                    if let mode = state.drawingState.toolState(for: state.drawingState.selectedTool).brushMode {
                        switch mode {
                        case .round:
                            title = "Round"
                            image = state.image(.round)
                        case .arrow:
                            title = "Arrow"
                            image = state.image(.arrow)
                        }
                    } else if let mode = state.drawingState.toolState(for: state.drawingState.selectedTool).eraserMode {
                        isEraser = true
                        switch mode {
                        case .bitmap:
                            title = "Eraser"
                            image = state.image(.round)
                        case .vector:
                            title = "Object"
                            image = state.image(.remove)
                        case .blur:
                            title = "Blur"
                            image = state.image(.blur)
                        }
                    } else {
                        title = ""
                        image = nil
                    }
                    
                    let brushModeButton = brushModeButton.update(
                        component: Button(
                            content: AnyComponent(
                                BrushButtonContent(
                                    title: title,
                                    image: image ?? UIImage()
                                )
                            ),
                            action: { [weak state] in
                                guard let controller = controller() as? DrawingScreen else {
                                    return
                                }
                                if let buttonView = controller.node.componentHost.findTaggedView(tag: brushModeButtonTag) as? Button.View {
                                    if isEraser {
                                        state?.presentEraserModePicker(buttonView)
                                    } else {
                                        state?.presentBrushModePicker(buttonView)
                                    }
                                }
                            }
                        ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(brushModeButtonTag),
                        availableSize: CGSize(width: 75.0, height: 33.0),
                        transition: .immediate
                    )
                    context.add(brushModeButton
                        .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - brushModeButton.size.width / 2.0 - 5.0, y: context.availableSize.height - environment.safeInsets.bottom - brushModeButton.size.height / 2.0 - 2.0 - UIScreenPixel))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                    
                    modeRightInset += 35.0
                } else {
                    var isFilled = false
                    if let entity = state.selectedEntity as? DrawingSimpleShapeEntity, case .fill = entity.drawType {
                        isFilled = true
                        isModeControlEnabled = false
                    } else if let entity = state.selectedEntity as? DrawingBubbleEntity, case .fill = entity.drawType {
                        isFilled = true
                        isModeControlEnabled = false
                    }
                    
                    if let _ = state.selectedEntity as? DrawingBubbleEntity {
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
                                    }
                                    state.updated(transition: .easeInOut(duration: 0.2))
                                }
                            ).minSize(CGSize(width: 44.0, height: 44.0)),
                            availableSize: CGSize(width: 33.0, height: 33.0),
                            transition: .immediate
                        )
                        context.add(flipButton
                            .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - flipButton.size.width / 2.0 - 3.0 - flipButton.size.width, y: context.availableSize.height - environment.safeInsets.bottom - flipButton.size.height / 2.0 - 2.0 - UIScreenPixel))
                            .appear(.default(scale: true))
                            .disappear(.default(scale: true))
                        )
                        modeRightInset += 35.0
                    }
                    
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
                        availableSize: CGSize(width: 33.0, height: 33.0),
                        transition: .immediate
                    )
                    context.add(fillButton
                        .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - fillButton.size.width / 2.0 - 3.0, y: context.availableSize.height - environment.safeInsets.bottom - fillButton.size.height / 2.0 - 2.0 - UIScreenPixel))
                        .appear(.default(scale: true))
                        .disappear(.default(scale: true))
                    )
                }
            } else {
                let addButton = addButton.update(
                    component: Button(
                        content: AnyComponent(ZStack([
                            AnyComponentWithIdentity(
                                id: "background",
                                component: AnyComponent(
                                    BlurredRectangle(
                                        color:  UIColor(rgb: 0x888888, alpha: 0.3),
                                        radius: 16.5
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
                                if let buttonView = controller.node.componentHost.findTaggedView(tag: addButtonTag) as? Button.View {
                                    state.presentShapePicker(buttonView)
                                }
                            case .sticker:
                                state.presentStickerPicker()
                            case .text:
                                state.addTextEntity()
                            }
                        }
                    ).minSize(CGSize(width: 44.0, height: 44.0)).tagged(addButtonTag),
                    availableSize: CGSize(width: 33.0, height: 33.0),
                    transition: .immediate
                )
                context.add(addButton
                    .position(CGPoint(x: context.availableSize.width - environment.safeInsets.right - addButton.size.width / 2.0 - 3.0, y: context.availableSize.height - environment.safeInsets.bottom - addButton.size.height / 2.0 - 51.0))
                    .appear(.default(scale: true))
                    .disappear(.default(scale: true))
                )
                
                let doneButton = doneButton.update(
                    component: Button(
                        content: AnyComponent(
                            Image(image: state.image(.done))
                        ),
                        action: {
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
            }
            
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
                    values: ["Draw", "Sticker", "Text"],
                    sizeValue: selectedSize,
                    isEditing: isEditingSize,
                    isEnabled: isModeControlEnabled,
                    rightInset: modeRightInset - 57.0,
                    tag: modeTag,
                    selectedIndex: selectedIndex,
                    selectionChanged: { [weak state] index in
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
                availableSize: CGSize(width: context.availableSize.width - 57.0 - modeRightInset, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(modeAndSize
                .position(CGPoint(x: context.availableSize.width / 2.0 - (modeRightInset - 57.0) / 2.0, y: context.availableSize.height - environment.safeInsets.bottom - modeAndSize.size.height / 2.0 - 9.0))
                .opacity(isModeControlEnabled ? 1.0 : 0.4)
            )
            
            var animatingOut = false
            if let appearanceTransition = context.transition.userData(DrawingScreenTransition.self), case .animateOut = appearanceTransition {
                animatingOut = true
            }
            
            let deselectEntity = component.deselectEntity
            let backButton = backButton.update(
                component: Button(
                    content: AnyComponent(
                        LottieAnimationComponent(
                            animation: LottieAnimationComponent.AnimationItem(
                                name: "media_backToCancel",
                                mode: .animating(loop: false),
                                range: isEditingSize || animatingOut ? (0.5, 1.0) : (0.0, 0.5)
                            ),
                            colors: ["__allcolors__": .white],
                            size: CGSize(width: 33.0, height: 33.0)
                        )
                    ),
                    action: { [weak state] in
                        if let state = state {
                            if state.toolIsFocused {
                                state.updateToolIsFocused(false)
                            } else if let selectedEntity = state.selectedEntity, !(selectedEntity is DrawingStickerEntity || selectedEntity is DrawingTextEntity) {
                                deselectEntity.invoke(Void())
                            } else {
                                dismiss.invoke(Void())
                            }
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

public class DrawingScreen: ViewController, TGPhotoDrawingInterfaceController {
    fileprivate final class Node: ViewControllerTracingNode, FPSCounterDelegate {
        private weak var controller: DrawingScreen?
        private let context: AccountContext
        private let updateState: ActionSlot<DrawingView.NavigationState>
        private let updateColor: ActionSlot<DrawingColor>
        private let performAction: ActionSlot<DrawingView.Action>
        private let updateToolState: ActionSlot<DrawingToolState>
        private let updateSelectedEntity: ActionSlot<DrawingEntity?>
        private let insertEntity: ActionSlot<DrawingEntity>
        private let deselectEntity: ActionSlot<Void>
        private let updatePlayback: ActionSlot<Bool>
        private let previewBrushSize: ActionSlot<CGFloat?>
        private let apply: ActionSlot<Void>
        private let dismiss: ActionSlot<Void>
        
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        
        private let textEditAccessoryView: UIInputView
        private let textEditAccessoryHost: ComponentView<Empty>
                
        private var presentationData: PresentationData
        private let hapticFeedback = HapticFeedback()
        private var validLayout: ContainerViewLayout?
        
        private let fpsCounter = FPSCounter()
        private var fpsLabel: UILabel?
        
        private var _drawingView: DrawingView?
        var drawingView: DrawingView {
            if self._drawingView == nil, let controller = self.controller {
                self._drawingView = DrawingView(size: controller.size)
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
                self._drawingView?.requestMenu = { [weak self] elements, rect in
                    if let strongSelf = self, let drawingView = strongSelf._drawingView {
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        var actions: [ContextMenuAction] = []
                        actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_Delete, accessibilityLabel: presentationData.strings.Paint_Delete), action: { [weak self] in
                            if let strongSelf = self {
                                strongSelf._drawingView?.removeElements(elements)
                            }
                        }))
                        actions.append(ContextMenuAction(content: .text(title: presentationData.strings.Paint_Duplicate, accessibilityLabel: presentationData.strings.Paint_Duplicate), action: { [weak self] in
                            if let strongSelf = self {
                                strongSelf._drawingView?.removeElements(elements)
                            }
                        }))
                        let strokeFrame = drawingView.lassoView.convert(rect, to: strongSelf.view).offsetBy(dx: 0.0, dy: -6.0)
                        let controller = ContextMenuController(actions: actions)
                        strongSelf.currentMenuController = controller
                        strongSelf.controller?.present(
                            controller,
                            in: .window(.root),
                            with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                                if let strongSelf = self {
                                    return (strongSelf, strokeFrame, strongSelf, strongSelf.bounds)
                                } else {
                                    return nil
                                }
                            })
                        )
                    }
                }
                self.performAction.connect { [weak self] action in
                    if let strongSelf = self {
                        strongSelf._drawingView?.performAction(action)
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
            }
            return self._drawingView!
        }
        
        private weak var currentMenuController: ContextMenuController?
        private var _entitiesView: DrawingEntitiesView?
        var entitiesView: DrawingEntitiesView {
            if self._entitiesView == nil, let controller = self.controller {
                self._entitiesView = DrawingEntitiesView(context: self.context, size: controller.size, entities: [])
                self._drawingView?.entitiesView = self._entitiesView
                let entitiesLayer = self.entitiesView.layer
                self._drawingView?.getFullImage = { [weak self, weak entitiesLayer] withDrawing in
                    if let strongSelf = self, let controller = strongSelf.controller, let currentImage = controller.getCurrentImage() {
                        if withDrawing {
                            let image = generateImage(controller.size, contextGenerator: { size, context in
                                let bounds = CGRect(origin: .zero, size: size)
                                if let cgImage = currentImage.cgImage {
                                    context.draw(cgImage, in: bounds)
                                }
                                if let cgImage = strongSelf.drawingView.drawingImage?.cgImage {
                                    context.draw(cgImage, in: bounds)
                                }
                                context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
                                context.scaleBy(x: 1.0, y: -1.0)
                                context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
                                entitiesLayer?.render(in: context)
                            }, opaque: true, scale: 1.0)
                            return image
                        } else {
                            return currentImage
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
                            strongSelf.entitiesView.remove(uuid: entityView.entity.uuid)
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
                        actions.append(ContextMenuAction(content: .text(title: "Move Forward", accessibilityLabel: "Move Forward"), action: { [weak self, weak entityView] in
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
                                return (strongSelf, entityFrame, strongSelf, strongSelf.bounds)
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
                        
                        if let entityView = entitiesView.getView(for: entity.uuid) as? DrawingTextEntityView {
                            entityView.beginEditing(accessoryView: strongSelf.textEditAccessoryView)
                        }
                    }
                }
                self.deselectEntity.connect { [weak self] in
                    if let strongSelf = self, let entitiesView = strongSelf._entitiesView {
                        entitiesView.selectEntity(nil)
                    }
                }
                self.updatePlayback.connect { [weak self] play in
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
        
        init(controller: DrawingScreen, context: AccountContext) {
            self.controller = controller
            self.context = context
            self.updateState = ActionSlot<DrawingView.NavigationState>()
            self.updateColor = ActionSlot<DrawingColor>()
            self.performAction = ActionSlot<DrawingView.Action>()
            self.updateToolState = ActionSlot<DrawingToolState>()
            self.updateSelectedEntity = ActionSlot<DrawingEntity?>()
            self.insertEntity = ActionSlot<DrawingEntity>()
            self.deselectEntity = ActionSlot<Void>()
            self.updatePlayback = ActionSlot<Bool>()
            self.previewBrushSize = ActionSlot<CGFloat?>()
            self.apply = ActionSlot<Void>()
            self.dismiss = ActionSlot<Void>()
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            self.textEditAccessoryView = UIInputView(frame: CGRect(origin: .zero, size: CGSize(width: 100.0, height: 44.0)), inputViewStyle: .keyboard)
            self.textEditAccessoryHost = ComponentView<Empty>()
            
            super.init()
            
            self.apply.connect { [weak self] _ in
                self?.controller?.requestApply()
            }
            self.dismiss.connect { [weak self] _ in
                self?.controller?.requestDismiss()
            }
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
            self.view.disablesInteractiveTransitionGestureRecognizer = true
            
            if self.fpsLabel == nil {
                let fpsLabel = UILabel(frame: CGRect(origin: CGPoint(x: 30.0, y: 10.0), size: CGSize(width: 120.0, height: 44.0)))
                fpsLabel.alpha = 0.1
                fpsLabel.textColor = .white
//                self.view.addSubview(fpsLabel)
                self.fpsLabel = fpsLabel
                
                self.fpsCounter.delegate = self
                self.fpsCounter.startTracking()
            }
        }
        
        func fpsCounter(_ counter: FPSCounter, didUpdateFramesPerSecond fps: Int) {
            self.fpsLabel?.text = "\(fps)"
        }
        
        func presentEyedropper(dismissed: @escaping () -> Void) {
            guard let controller = self.controller else {
                return
            }
            self.entitiesView.pause()
            
            guard let currentImage = controller.getCurrentImage() else {
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
                    dismissed()
                }
            }
            eyedropperView.frame = controller.contentWrapperView.convert(controller.contentWrapperView.bounds, to: controller.view)
            controller.view.addSubview(eyedropperView)
        }
        
        func presentColorPicker(initialColor: DrawingColor, dismissed: @escaping () -> Void = {}) {
            guard let controller = self.controller else {
                return
            }
            self.hapticFeedback.impact(.medium)
            let colorController = ColorPickerScreen(context: self.context, initialColor: initialColor, updated: { [weak self] color in
                self?.updateColor.invoke(color)
            }, openEyedropper: { [weak self] in
                self?.presentEyedropper(dismissed: dismissed)
            }, dismissed: {
                dismissed()
            })
            controller.present(colorController, in: .window(.root))
        }
        
        private var fastColorPickerView: ColorSpectrumPickerView?
        func presentFastColorPicker(sourceView: UIView) {
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
        
        func animateIn() {
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
        }
        
        func animateOut(completion: @escaping () -> Void) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, animateOut: true, transition: .easeInOut(duration: 0.2))
            }
            
            if let buttonView = self.componentHost.findTaggedView(tag: undoButtonTag) {
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
            if let view = self.componentHost.findTaggedView(tag: toolsTag) as? ToolsComponent.View {
                view.animateOut(completion: {})
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
        
        func containerLayoutUpdated(layout: ContainerViewLayout, animateOut: Bool = false, transition: Transition) {
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(top: layout.intrinsicInsets.top + layout.safeInsets.top, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom, right: layout.safeInsets.right),
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
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
                        updatePlayback: self.updatePlayback,
                        previewBrushSize: self.previewBrushSize,
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
                        }
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: animateOut,
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
                let accessorySize = self.textEditAccessoryHost.update(
                    transition: isFirstTime ? .immediate : .easeInOut(duration: 0.2),
                    component: AnyComponent(
                        TextSettingsComponent(
                            color: textEntity.color,
                            style: DrawingTextStyle(style: textEntity.style),
                            alignment: DrawingTextAlignment(alignment: textEntity.alignment),
                            font: DrawingTextFont(font: textEntity.font),
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
                                
                                if let layout = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout: layout, transition: .immediate)
                                }
                            },
                            toggleAlignment: { [weak self] in
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
                            updateFont: { [weak self] font in
                                guard let strongSelf = self, let entityView = strongSelf.entitiesView.selectedEntityView as? DrawingTextEntityView, let textEntity = entityView.entity as? DrawingTextEntity else {
                                    return
                                }
                                textEntity.font = font.font
                                entityView.update()
                                
                                if let layout = strongSelf.validLayout {
                                    strongSelf.containerLayoutUpdated(layout: layout, transition: .immediate)
                                }
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
                    UIView.performWithoutAnimation {
                        self.textEditAccessoryView.frame = CGRect(origin: .zero, size: accessorySize)
                        componentView.frame = CGRect(origin: .zero, size: accessorySize)
                    }
                }
            }
        }
    }
    
    fileprivate var node: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private let size: CGSize
    
    public var requestDismiss: (() -> Void)!
    public var requestApply: (() -> Void)!
    public var getCurrentImage: (() -> UIImage?)!
    
    public init(context: AccountContext, size: CGSize) {
        self.context = context
        self.size = size
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Hide
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
    
    required public init(coder: NSCoder) {
        preconditionFailure()
    }
        
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context)

        super.displayNodeDidLoad()
    }
    
    public func generateResultData() -> TGPaintingData! {
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
        var legacyEntities: [TGPhotoPaintEntity] = []
    
        for entity in self.entitiesView.entities {
            if entity.isAnimated {
                hasAnimatedEntities = true
            }
            if let entity = entity as? DrawingStickerEntity {
                let coder = PostboxEncoder()
                coder.encodeRootObject(entity.file)
                
                let baseSize = max(10.0, min(entity.referenceDrawingSize.width, entity.referenceDrawingSize.height) * 0.38)
                if let stickerEntity = TGPhotoPaintStickerEntity(document: coder.makeData(), baseSize: CGSize(width: baseSize, height: baseSize), animated: entity.isAnimated) {
                    stickerEntity.position = entity.position
                    stickerEntity.scale = entity.scale
                    stickerEntity.angle = entity.rotation
                    legacyEntities.append(stickerEntity)
                }
            } else if let entity = entity as? DrawingTextEntity, let view = self.entitiesView.getView(for: entity.uuid) as? DrawingTextEntityView {
                let textEntity = TGPhotoPaintStaticEntity()
                textEntity.position = entity.position
                textEntity.angle = entity.rotation
                textEntity.renderImage = view.getRenderImage()
                legacyEntities.append(textEntity)
            } else if let _ = entity as? DrawingSimpleShapeEntity {
                
            } else if let _ = entity as? DrawingBubbleEntity {
                
            } else if let _ = entity as? DrawingVectorEntity {
                
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
        
        var image = paintingImage
        var stillImage: UIImage?
        if hasAnimatedEntities {
            stillImage = finalImage
        } else {
            image = finalImage
        }
        
        return TGPaintingData(painting: nil, image: image, stillImage: stillImage, entities: legacyEntities, undoManager: nil)
    }
    
    public func resultImage() -> UIImage! {
        let image = generateImage(self.drawingView.imageSize, contextGenerator: { size, context in
            let bounds = CGRect(origin: .zero, size: size)
            context.clear(bounds)
            if let cgImage = self.drawingView.drawingImage?.cgImage {
                context.draw(cgImage, in: bounds)
            }
            context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
            self.entitiesView.layer.render(in: context)
        }, opaque: false, scale: 1.0)
        return image
    }
    
    public func animateOut(_ completion: (() -> Void)!) {
        self.selectionContainerView.alpha = 0.0
        
        self.node.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
    
    public func adapterContainerLayoutUpdatedSize(_ size: CGSize, intrinsicInsets: UIEdgeInsets, safeInsets: UIEdgeInsets, statusBarHeight: CGFloat, inputHeight: CGFloat, animated: Bool) {
        let layout = ContainerViewLayout(
            size: size,
            metrics: LayoutMetrics(widthClass: .compact, heightClass: .compact),
            deviceMetrics: DeviceMetrics(screenSize: size, scale: UIScreen.main.scale, statusBarHeight: statusBarHeight, onScreenNavigationHeight: nil),
            intrinsicInsets: intrinsicInsets,
            safeInsets: safeInsets,
            additionalInsets: .zero,
            statusBarHeight: statusBarHeight,
            inputHeight: inputHeight,
            inputHeightIsInteractivellyChanging: false,
            inVoiceOver: false
        )
        self.containerLayoutUpdated(layout, transition: animated ? .animated(duration: 0.3, curve: .easeInOut) : .immediate)
    }
}
