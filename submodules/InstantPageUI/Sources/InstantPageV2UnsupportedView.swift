import Foundation
import UIKit
import Display
import UnsupportedContentPill

/// Hosts the shared unsupported-content pill as a V2 item view.
///
/// The pill itself owns its geometry, colours and wallpaper handling; this wrapper only positions
/// it and forwards the button tap up to the page view's `unsupportedActionTapped`.
final class InstantPageV2UnsupportedView: UIView, InstantPageItemView {
    private var item: InstantPageV2UnsupportedItem
    private let pillView: UnsupportedContentPillView

    var onActionTapped: (() -> Void)?

    var itemFrame: CGRect {
        return self.item.frame
    }

    init(item: InstantPageV2UnsupportedItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext?) {
        self.item = item
        self.pillView = UnsupportedContentPillView()

        super.init(frame: item.frame)

        self.addSubview(self.pillView)
        self.pillView.action = { [weak self] in
            self?.onActionTapped?()
        }

        self.update(item: item, theme: theme, renderContext: renderContext)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(item: InstantPageV2UnsupportedItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext?) {
        self.item = item

        let size = item.frame.size
        self.pillView.frame = CGRect(origin: CGPoint(), size: size)
        self.pillView.update(
            layout: item.layout,
            colors: theme.unsupportedPillColors,
            strings: item.strings,
            size: size,
            wallpaperBackgroundNode: renderContext?.wallpaperBackgroundNode(),
            animation: .None
        )
    }
}
