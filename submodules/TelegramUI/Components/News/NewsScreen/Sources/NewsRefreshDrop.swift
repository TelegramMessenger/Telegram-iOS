import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import GlassBackgroundComponent
import LottieSettings
import NewsFeedSupport
import NewsFeedComponents

/// The drop: a glass circle in the island's glass container (merged with the island on iOS 26), with the sticker in
/// the accent colour inside it (spec §2.1, §2.4). Once the new posts are in, it shrinks and fades on their card's top
/// edge as their block fades in (`pose.scale`, `pose.alpha`; spec §3). It stays in the hierarchy at 0.01 pt when
/// unused, so the first pull frame does not build a glass view.
final class NewsRefreshDrop {
    let glassView = GlassBackgroundView()
    private let stickerLayer = SimpleLayer()
    private let stickerMaskLayer = SimpleLayer()
    private var frames: NewsStickerFrames?
    private var isLoadingFrames = false

    init() {
        self.glassView.isUserInteractionEnabled = false
        self.stickerLayer.mask = self.stickerMaskLayer
        self.glassView.contentView.layer.addSublayer(self.stickerLayer)
    }

    func update(pose: NewsRefreshDropPose, islandSize: CGSize, theme: PresentationTheme, lottieSettings: LottieRenderingSettings) {
        if self.frames == nil, !self.isLoadingFrames {
            self.isLoadingFrames = true
            NewsStickerFrames.load(settings: lottieSettings, completion: { [weak self] frames in
                self?.frames = frames
            })
        }
        let diameter = pose.isVisible ? max(pose.diameter, 0.01) : 0.01
        let size = CGSize(width: diameter, height: diameter)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Bounds and centre, not frame: the view carries the shrink as a transform.
        self.glassView.bounds = CGRect(origin: CGPoint(), size: size)
        self.glassView.center = CGPoint(x: islandSize.width * 0.5, y: islandSize.height + pose.top + diameter * 0.5)
        self.glassView.transform = pose.scale == 1.0 ? .identity : CGAffineTransform(scaleX: pose.scale, y: pose.scale)
        self.glassView.alpha = pose.alpha
        self.glassView.update(size: size, cornerRadius: diameter * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel), isInteractive: false, isVisible: pose.isVisible, transition: .immediate)

        let icon = NewsRefreshMetrics.iconSize * pose.iconScale
        self.stickerLayer.bounds = CGRect(origin: CGPoint(), size: CGSize(width: icon, height: icon))
        self.stickerLayer.position = CGPoint(x: diameter * 0.5, y: diameter * 0.5)
        self.stickerLayer.transform = CATransform3DMakeRotation(pose.iconAngle, 0.0, 0.0, 1.0)
        self.stickerLayer.backgroundColor = theme.list.itemAccentColor.cgColor
        self.stickerLayer.opacity = Float(pose.isVisible ? pose.iconAlpha : 0.0)
        self.stickerMaskLayer.frame = self.stickerLayer.bounds
        self.stickerMaskLayer.contents = self.frames?.image(at: pose.iconTime)
        if pose.iconBlur > 0.01, let blur = CALayer.blur() {
            blur.setValue(pose.iconBlur as NSNumber, forKey: "inputRadius")
            self.stickerLayer.filters = [blur]
        } else if self.stickerLayer.filters != nil {
            self.stickerLayer.filters = nil
        }
        CATransaction.commit()
    }
}
