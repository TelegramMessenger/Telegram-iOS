import Foundation
import UIKit
import Display
import TelegramPresentationData
import ShimmerEffect

/// A list's stand-in while its first content loads: skeleton post rows down to the bottom of its size, under
/// one shimmer. It takes no touches, so the list beneath it can still be dragged.
public final class NewsFeedSkeletonView: UIView {
    private let shimmerNode = ShimmerEffectNode()
    private var currentSize: CGSize?
    private var currentTheme: PresentationTheme?
    private var currentRowLayout: NewsFeedSkeletonRowLayout?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.addSubview(self.shimmerNode.view)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    public func update(size: CGSize, theme: PresentationTheme, rowLayout: NewsFeedSkeletonRowLayout) {
        if self.currentSize == size && self.currentTheme === theme && self.currentRowLayout == rowLayout {
            return
        }
        self.currentSize = size
        self.currentTheme = theme
        self.currentRowLayout = rowLayout

        var shapes: [ShimmerEffectNode.Shape] = []
        if rowLayout.height > 0.0 {
            let rowCount = Int(ceil(size.height / rowLayout.height))
            for index in 0 ..< rowCount {
                shapes.append(contentsOf: newsFeedSkeletonRowShapes(rowLayout, y: CGFloat(index) * rowLayout.height))
            }
        }
        self.shimmerNode.frame = CGRect(origin: CGPoint(), size: size)
        self.shimmerNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
        self.shimmerNode.update(backgroundColor: theme.list.plainBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: size)
    }
}
