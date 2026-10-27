import Foundation
import UIKit
import AsyncDisplayKit
import TelegramCore
import MessageWidget

/// widget-sandbox v0.2 (sdk-v1 §2.16, integration.md `context.preview`; design W3): an inline result's widget as the
/// results lists preview it, drawn the way its sent bubble will draw it. It has:
/// - the result's state and `isPreview`, with no viewer and no chat type;
/// - no storage and no bridge (a preview asks nothing);
/// - no touches: a tap on it selects the result, so the node takes none and the row under it does.
///
/// It runs a registry of its own, keyed by the result: another result is another widget. Main thread only: `update` is
/// the main-thread pass the widget boots in (widgets exist only where layout runs on main).
public final class MessageWidgetPreviewNode: ASDisplayNode {
    private static let path: [Int] = []

    /// The widget reported a new height (an auto-height widget), so a row laid out from the anchors can lay out again;
    /// a fixed height reports none. Delivered on a later main-queue turn, never inside `update` (a list's apply).
    public var onContentHeightChange: ((CGFloat) -> Void)?

    /// The last `update`, for the pass a hidden preview runs once it is shown.
    private struct Arguments {
        let ownerId: AnyHashable
        let widget: TelegramMediaWidget
        let theme: MessageWidgetInstance.Theme
        let locale: String
        let stoppedLabel: String
        let contentWidth: CGFloat
        let displaySize: CGSize
    }

    private let registry = MessageWidgetRegistry()
    private let clipView = UIView()
    /// Holds the widget's view at its own size, scaled from its top-left corner to the drawn size.
    private let scaleView = UIView()
    private var arguments: Arguments?
    private var payload: Data?
    private var source = ""
    private var lastReportedHeight: CGFloat?
    private var widgetVisible = true
    /// The result and source whose widget failed to start: remembered, never booted again, as the bubble's registry
    /// remembers it; hiding the preview clears the registry's. Learned only from a failure that lands while the preview
    /// is on screen: one landing after the row left (a slow parse past its ceiling) goes with its instance, so the next
    /// show parses again.
    private var failedOwnerId: AnyHashable?
    private var failedSource: String?

    /// The running widget's view, nil when there is none.
    public var widgetView: MessageWidgetView? {
        return self.registry.view(path: MessageWidgetPreviewNode.path, source: self.source) as? MessageWidgetView
    }

    public override init() {
        super.init()
        self.isUserInteractionEnabled = false
        self.registry.context = MessageWidgetContext(isPreview: true)
        self.registry.storage = .empty
        // A late snapshot (a boot done after the pass's wait, a new height, a failure): the view is laid out again on a
        // later main-queue turn, as the bubble's relayout does, and a new height reported.
        self.registry.onLayoutChange = { [weak self] in
            DispatchQueue.main.async {
                self?.runPass()
            }
        }
    }

    /// Shows the preview of `widget` for the result `ownerId`, laid out `contentWidth` wide and drawn scaled into
    /// `displaySize` from the node's top-left corner; the caller sets the node's frame. It runs in the app's language
    /// (`locale`, SDK v1 §2.9) and badges a stopped widget with `stoppedLabel`, as its sent bubble will.
    public func update(widget: TelegramMediaWidget, ownerId: AnyHashable, theme: MessageWidgetInstance.Theme, locale: String, stoppedLabel: String, contentWidth: CGFloat, displaySize: CGSize, cornerRadius: CGFloat) {
        assert(Thread.isMainThread)
        if self.clipView.superview == nil {
            self.clipView.clipsToBounds = true
            self.scaleView.layer.anchorPoint = CGPoint()
            self.clipView.addSubview(self.scaleView)
            self.view.addSubview(self.clipView)
        }
        if self.arguments?.ownerId != ownerId {
            self.lastReportedHeight = nil
        }
        if self.payload != widget.payload {
            self.payload = widget.payload
            self.source = widget.html() ?? ""
            self.lastReportedHeight = nil
        }
        self.arguments = Arguments(ownerId: ownerId, widget: widget, theme: theme, locale: locale, stoppedLabel: stoppedLabel, contentWidth: contentWidth, displaySize: displaySize)
        self.clipView.frame = CGRect(origin: CGPoint(), size: displaySize)
        self.clipView.layer.cornerRadius = cornerRadius
        self.runPass()
    }

    /// Whether the row is on screen (the list's visibility). Only a preview on screen runs a widget: the list's preload
    /// rows run none, and one leaving the screen stops its own, so a fling through many widget results runs only the
    /// visible ones. Shown again, it boots afresh: a preview has no state of its own to keep.
    public func setVisible(_ visible: Bool) {
        guard self.widgetVisible != visible else {
            return
        }
        self.widgetVisible = visible
        self.runPass()
    }

    /// The registry's pass with the last `update` while on screen; off screen, the widget stops.
    private func runPass() {
        guard let arguments = self.arguments else {
            return
        }
        guard self.widgetVisible, !(self.failedOwnerId == arguments.ownerId && self.failedSource == self.source) else {
            self.registry.destroyAll()
            for subview in self.scaleView.subviews {
                subview.removeFromSuperview()
            }
            return
        }
        let path = MessageWidgetPreviewNode.path
        let widget = arguments.widget
        self.registry.locale = arguments.locale
        self.registry.stoppedLabel = arguments.stoppedLabel
        self.registry.state = MessageWidgetState(chatData: widget.chatData, publicData: widget.publicData)
        // As the bubble passes it: a fixed height bounds the document, else the 600 pt bound.
        self.registry.maximumHeight = widget.height > 0 ? min(max(CGFloat(widget.height), MessageWidgetBubbleSize.minimumHeight), MessageWidgetBubbleSize.maximumHeight) : MessageWidgetBubbleSize.maximumHeight
        self.registry.beginPass(ownerId: arguments.ownerId, theme: arguments.theme)
        let size = self.registry.size(path: path, source: self.source, width: arguments.contentWidth)
        self.registry.endPass()
        if self.registry.runState(path: path, source: self.source)?.failedToStart == true {
            self.failedOwnerId = arguments.ownerId
            self.failedSource = self.source
        }
        // A boot done within the pass's wait has reported already, and no late snapshot will say so.
        self.noteReportedHeight()

        if let size, let live = self.registry.view(path: path, source: self.source) {
            for subview in self.scaleView.subviews where subview !== live {
                subview.removeFromSuperview()
            }
            if live.superview !== self.scaleView {
                self.scaleView.addSubview(live)
            }
            // Laid out at its own width; its height is the content's, which the clip cuts at the drawn size.
            let liveSize = CGSize(width: size.width, height: max(size.height, self.registry.reportedHeight(path: path, source: self.source) ?? 0.0))
            let scale = size.width > 0.0 ? arguments.displaySize.width / size.width : 1.0
            self.scaleView.transform = .identity
            self.scaleView.bounds = CGRect(origin: CGPoint(), size: liveSize)
            self.scaleView.layer.position = CGPoint()
            self.scaleView.transform = CGAffineTransform(scaleX: scale, y: scale)
            live.frame = CGRect(origin: CGPoint(), size: liveSize)
        } else {
            for subview in self.scaleView.subviews {
                subview.removeFromSuperview()
            }
        }
    }

    /// Reports a new height of an auto-height widget (the runtime clamps what it reports to 50…600, as the bubble's
    /// height is); a fixed height is the row's whatever the widget reports.
    private func noteReportedHeight() {
        guard let arguments = self.arguments, arguments.widget.height <= 0 else {
            return
        }
        guard let reported = self.registry.reportedHeight(path: MessageWidgetPreviewNode.path, source: self.source), reported != self.lastReportedHeight else {
            return
        }
        self.lastReportedHeight = reported
        let ownerId = arguments.ownerId
        DispatchQueue.main.async { [weak self] in
            // Dropped if the node shows another result by then.
            guard let self, self.arguments?.ownerId == ownerId, self.lastReportedHeight == reported else {
                return
            }
            self.onContentHeightChange?(reported)
        }
    }
}
