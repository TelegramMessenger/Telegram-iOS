import Foundation
import UIKit
import Display
import MediaEditor
import MediaEditorScreen

public func chatMediaEditorToolsMediaGeometry(values: MediaEditorValues, previewFrame: CGRect) -> MediaToolsScreen.ChatMediaGeometry? {
    let state = chatMediaEditorCropState(values: values)
    if state.isDefault {
        return nil
    }
    let placement = chatMediaEditorCropPreviewPlacement(state: state, frameSize: previewFrame.size)
    let transform = CATransform3DConcat(CATransform3DMakeScale(state.mirrored ? -1.0 : 1.0, 1.0, 1.0), placement.mediaTransform)
    return MediaToolsScreen.ChatMediaGeometry(
        size: CGSize(width: state.originalSize.width * placement.scale, height: state.originalSize.height * placement.scale),
        center: CGPoint(x: previewFrame.minX + placement.center.x, y: previewFrame.minY + placement.center.y),
        transform: transform
    )
}

public func chatMediaEditorHighlightedToolsTabs(values: MediaEditorValues) -> Set<ChatMediaEditorToolsTab> {
    var result = Set<ChatMediaEditorToolsTab>()
    if values.hasAdjustments {
        result.insert(.adjustments)
    }
    if values.hasTint {
        result.insert(.tint)
    }
    if values.hasBlur {
        result.insert(.blur)
    }
    if values.hasCurves {
        result.insert(.curves)
    }
    return result
}

extension ChatMediaEditorScreen.Node {
    var hasToolsChanges: Bool {
        let values = self.mediaEditor.values
        return values.hasAdjustments || values.hasTint || values.hasBlur || values.hasCurves
    }

    var canEnhance: Bool {
        switch self.subject {
        case .image, .video, .asset:
            return true
        }
    }

    var highlightedToolsTabs: Set<ChatMediaEditorToolsTab> {
        return chatMediaEditorHighlightedToolsTabs(values: self.mediaEditor.values)
    }

    func openTools() {
        guard self.activeTool == nil, let layout = self.validLayout else {
            return
        }
        if self.entitiesView.hasSelection {
            self.entitiesView.selectEntity(nil)
        }

        self.activeTool = .tools
        self.toolsSection = .adjustments
        self.toolStartValues = self.mediaEditor.values
        self.updateEntityInteraction()
        self.requestLayout(transition: .animated(duration: 0.3, curve: .spring))

        let toolsScreen = MediaToolsScreen(
            context: self.context,
            mediaEditor: self.mediaEditor,
            hiddenTools: self.canEnhance ? [] : [.enhance],
            layoutStyle: self.toolsLayoutStyle(layout: layout),
            externalControls: true
        )
        toolsScreen.dismissed = { [weak self] in
            guard let self else {
                return
            }
            self.toolsScreen = nil
            self.setInteractionTracking(false, source: "tools")
            self.selectionEditCommitted()
            self.activeTool = nil
            self.updateEntityInteraction()
            self.requestLayout(transition: .animated(duration: 0.3, curve: .spring))
        }
        toolsScreen.externalValuesUpdated = { [weak self] in
            guard let self, self.activeTool == .tools else {
                return
            }
            let highlighted = self.highlightedToolsTabs
            if highlighted != self.lastHighlightedToolsTabs {
                self.lastHighlightedToolsTabs = highlighted
                self.requestLayout(transition: .animated(duration: 0.2, curve: .easeInOut))
            }
        }
        toolsScreen.externalTrackingUpdated = { [weak self] isTracking in
            self?.setInteractionTracking(isTracking, source: "tools")
        }
        self.lastHighlightedToolsTabs = self.highlightedToolsTabs
        self.toolsScreen = toolsScreen
        self.embedToolController(toolsScreen)
    }

    func toolsLayoutStyle(layout: ContainerViewLayout) -> MediaToolsScreen.LayoutStyle {
        let previewFrame = self.previewFrame(layout: layout)
        let sidePanelFrame = self.toolbarSide(layout: layout).flatMap { side in
            chatMediaEditorLandscapeToolsPanelFrame(size: layout.size, safeInsets: self.editorSafeInsets(layout: layout), side: side)
        }
        return .chat(
            previewFrame: previewFrame,
            mediaGeometry: chatMediaEditorToolsMediaGeometry(values: self.mediaEditor.values, previewFrame: previewFrame),
            sidePanelFrame: sidePanelFrame
        )
    }

    func updateToolsLayoutStyle(layout: ContainerViewLayout) {
        guard self.activeTool == .tools, let toolsScreen = self.toolsScreen else {
            return
        }
        toolsScreen.updateLayoutStyle(self.toolsLayoutStyle(layout: layout))
    }

    func selectToolsSection(_ tab: ChatMediaEditorToolsTab) {
        guard self.activeTool == .tools, let toolsScreen = self.toolsScreen, self.toolsSection != tab else {
            return
        }
        self.toolsSection = tab
        let section: MediaToolsScreen.Section
        switch tab {
        case .adjustments:
            section = .adjustments
        case .tint:
            section = .tint
        case .blur:
            section = .blur
        case .curves:
            section = .curves
        }
        toolsScreen.select(section: section)
        self.requestLayout(transition: .animated(duration: 0.3, curve: .spring))
    }

    func closeTools(apply: Bool) {
        guard let toolsScreen = self.toolsScreen else {
            return
        }
        self.dismissEmbeddedToolController(toolsScreen, animateOut: { completion in
            toolsScreen.requestExternalDismiss(apply: apply, completion: completion)
        })
    }
}
