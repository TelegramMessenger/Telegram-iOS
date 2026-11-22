import Foundation
import UIKit
import Display
import TelegramPresentationData
import NewsFeedSupport

/// A list's stand-in while its first content loads: skeleton post rows down to the bottom of its size, under
/// one shimmer band (Feed2 Skeleton.swift). It takes no touches, so the list beneath it can still be dragged.
public final class NewsFeedSkeletonView: UIView {
    private let shapesView = NewsSkeletonShapesView()
    private var currentSize: CGSize?
    private var currentTheme: PresentationTheme?
    private var currentRowLayout: NewsSkeletonModelRow?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.addSubview(self.shapesView)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    public func update(size: CGSize, theme: PresentationTheme, rowLayout: NewsSkeletonModelRow) {
        if self.currentSize == size && self.currentTheme === theme && self.currentRowLayout == rowLayout {
            return
        }
        self.currentSize = size
        self.currentTheme = theme
        self.currentRowLayout = rowLayout

        self.shapesView.frame = CGRect(origin: CGPoint(), size: size)
        self.shapesView.update(size: size, shapes: newsSkeletonShapes(plain: rowLayout, width: size.width, height: size.height, pixel: UIScreenPixel), theme: theme)
    }
}
