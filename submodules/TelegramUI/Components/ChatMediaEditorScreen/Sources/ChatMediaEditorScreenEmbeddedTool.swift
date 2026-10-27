import Foundation
import UIKit
import Display
import MediaEditorBottomControls

extension ChatMediaEditorScreen.Node {
    private var embeddedToolControllers: [ViewController] {
        var result: [ViewController] = []
        if let drawingScreen = self.drawingScreen {
            result.append(drawingScreen)
        }
        if let toolsScreen = self.toolsScreen {
            result.append(toolsScreen)
        }
        return result
    }

    func embedToolController(_ controller: ViewController) {
        guard let layout = self.validLayout else {
            return
        }
        mediaEditorEmbedToolController(controller, in: self.view, below: nil, layout: layout)
        if let toolbarView = self.toolbar.view {
            self.view.insertSubview(toolbarView, aboveSubview: controller.view)
        }
    }

    func dismissEmbeddedToolController(_ controller: ViewController, animateOut: (@escaping () -> Void) -> Void) {
        mediaEditorDismissEmbeddedToolController(controller, animateOut: animateOut, remove: { [weak self] controller in
            self?.removeEmbeddedToolController(controller)
        })
    }

    func removeEmbeddedToolController(_ controller: ViewController) {
        guard mediaEditorRemoveEmbeddedToolController(controller, from: self.view) else {
            return
        }
        if chatMediaEditorBottomControlsPlacement(hasEmbeddedTool: !self.embeddedToolControllers.isEmpty) == .belowCaptionDim, let toolbarView = self.toolbar.view, toolbarView.superview === self.view {
            self.view.insertSubview(toolbarView, belowSubview: self.captionDimView)
        }
    }

    func updateEmbeddedToolLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        mediaEditorUpdateEmbeddedToolLayout(self.embeddedToolControllers, in: self.view, layout: layout, transition: transition)
    }
}
